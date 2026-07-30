use crate::paths::HostPaths;
use serde::de::DeserializeOwned;
use serde::Deserialize;
use serde_json::Value as JsonValue;
use std::collections::BTreeMap;
use std::fs::{self, File, OpenOptions};
use std::io::{self, Cursor, Read, Write};
use std::os::unix::fs::{MetadataExt, OpenOptionsExt, PermissionsExt};
use std::path::{Path, PathBuf};
#[cfg(target_os = "macos")]
use std::process::{Command, Stdio};
use thumble_core::{
    minimal_default_customization, ButtonBindings, KeyBinding, OutputBinding, PersistentState,
    TrustedClient,
};
use uuid::Uuid;

// These legacy defaults identifiers are an interoperability contract with
// existing Thumble installations. They intentionally retain their pre-rename
// values so migration preserves server identity, pairing, and profiles.
const DEFAULTS_DOMAIN: &str = "com.codybontecou.PocketPadMac";
const SERVER_ID_KEY: &str = "PocketPadMac.serverIdentity.v1";
const TRUSTED_CLIENTS_KEY: &str = "PocketPadMac.trustedClients.v1";
const PROFILES_KEY: &str = "PocketPad.gamepadConfigurationProfiles.v1";
const CUSTOMIZATION_KEY: &str = "PocketPad.gamepadCustomization.v1";
const KEY_BINDINGS_V2_KEY: &str = "PocketPadMac.keyBindings.v2";
const KEY_BINDINGS_V1_KEY: &str = "PocketPadMac.keyBindings.v1";
const PROFILE_KEY_BINDINGS_KEY: &str = "PocketPadMac.profileKeyBindings.v1";
const OUTPUT_BINDINGS_KEY: &str = "PocketPadMac.outputBindings.v1";
const PROFILE_OUTPUT_BINDINGS_KEY: &str = "PocketPadMac.profileOutputBindings.v1";

pub fn load_or_migrate(paths: &HostPaths) -> Result<PersistentState, String> {
    paths
        .ensure_state_dir()
        .map_err(|error| format!("create state directory: {error}"))?;
    if paths.state_file.exists() {
        let mut state = load(&paths.state_file)?;
        let original_schema_version = state.schema_version;
        state
            .normalize()
            .map_err(|error| format!("normalize persistent state: {error}"))?;
        if state.schema_version != original_schema_version {
            save_atomic(&paths.state_file, &state)?;
        } else {
            restrict_file(&paths.state_file)?;
        }
        return Ok(state);
    }

    let generated_id = Uuid::new_v4().to_string();
    install_initial_state(paths, migration_source(paths)?, &generated_id)
}

fn install_initial_state(
    paths: &HostPaths,
    source: Option<Vec<u8>>,
    generated_id: &str,
) -> Result<PersistentState, String> {
    let mut state = match source {
        Some(source) => migrate_plist_bytes(&source, generated_id).map_err(|error| {
            format!(
                "legacy Thumble defaults were found but could not be migrated; no new state was written: {error}"
            )
        })?,
        None => PersistentState::minimal(generated_id.to_owned())
            .expect("a generated UUID is a valid server ID"),
    };
    state
        .normalize()
        .map_err(|error| format!("normalize migrated state: {error}"))?;
    save_atomic(&paths.state_file, &state)?;
    Ok(state)
}

pub fn load(path: &Path) -> Result<PersistentState, String> {
    const MAXIMUM_STATE_BYTES: u64 = 16 * 1024 * 1024;
    let file = OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_NOFOLLOW)
        .open(path)
        .map_err(|error| format!("read {}: {error}", path.display()))?;
    let metadata = file
        .metadata()
        .map_err(|error| format!("inspect {}: {error}", path.display()))?;
    if !metadata.is_file()
        || metadata.uid() != unsafe { libc::geteuid() }
        || metadata.permissions().mode() & 0o077 != 0
        || metadata.len() > MAXIMUM_STATE_BYTES
    {
        return Err(format!(
            "state file {} failed ownership, mode, type, or size validation",
            path.display()
        ));
    }
    let mut data = Vec::with_capacity(usize::try_from(metadata.len()).unwrap_or(0));
    file.take(MAXIMUM_STATE_BYTES.saturating_add(1))
        .read_to_end(&mut data)
        .map_err(|error| format!("read {}: {error}", path.display()))?;
    if data.len() as u64 > MAXIMUM_STATE_BYTES {
        return Err(format!(
            "state file {} exceeds its size limit",
            path.display()
        ));
    }
    serde_json::from_slice(&data).map_err(|error| format!("decode {}: {error}", path.display()))
}

pub fn redact_known_auth_tokens(path: &Path, text: &str) -> String {
    let Ok(state) = load(path) else {
        return text.to_owned();
    };
    state
        .trusted_clients
        .keys()
        .filter(|token| !token.is_empty())
        .fold(text.to_owned(), |redacted, token| {
            redacted.replace(token, "[REDACTED]")
        })
}

pub fn save_atomic(path: &Path, state: &PersistentState) -> Result<(), String> {
    let parent = path
        .parent()
        .ok_or_else(|| format!("state path {} has no parent", path.display()))?;
    if let Ok(metadata) = fs::symlink_metadata(parent) {
        if metadata.file_type().is_symlink()
            || !metadata.is_dir()
            || metadata.uid() != unsafe { libc::geteuid() }
        {
            return Err("state directory failed ownership or symlink validation".to_owned());
        }
    }
    fs::create_dir_all(parent).map_err(|error| format!("create {}: {error}", parent.display()))?;
    fs::set_permissions(parent, fs::Permissions::from_mode(0o700))
        .map_err(|error| format!("protect {}: {error}", parent.display()))?;
    let metadata = fs::symlink_metadata(parent)
        .map_err(|error| format!("inspect {}: {error}", parent.display()))?;
    if metadata.file_type().is_symlink()
        || !metadata.is_dir()
        || metadata.uid() != unsafe { libc::geteuid() }
        || metadata.permissions().mode() & 0o077 != 0
    {
        return Err("state directory failed ownership or permission validation".to_owned());
    }

    let data = serde_json::to_vec_pretty(state)
        .map_err(|error| format!("encode persistent state: {error}"))?;
    let temporary = parent.join(format!(
        ".{}.{}.tmp",
        path.file_name()
            .and_then(|name| name.to_str())
            .unwrap_or("state"),
        Uuid::new_v4().simple()
    ));
    let result = (|| -> io::Result<()> {
        let mut file = OpenOptions::new()
            .write(true)
            .create_new(true)
            .mode(0o600)
            .open(&temporary)?;
        file.write_all(&data)?;
        file.write_all(b"\n")?;
        file.sync_all()?;
        fs::rename(&temporary, path)?;
        fs::set_permissions(path, fs::Permissions::from_mode(0o600))?;
        File::open(parent)?.sync_all()?;
        Ok(())
    })();
    if result.is_err() {
        let _ = fs::remove_file(&temporary);
    }
    result.map_err(|error| format!("atomically write {}: {error}", path.display()))
}

pub fn migrate_plist_file(path: &Path, generated_id: &str) -> Result<PersistentState, String> {
    let data = fs::read(path).map_err(|error| format!("read {}: {error}", path.display()))?;
    migrate_plist_bytes(&data, generated_id)
}

pub fn migrate_plist_bytes(data: &[u8], generated_id: &str) -> Result<PersistentState, String> {
    let plist = plist::Value::from_reader(Cursor::new(data))
        .map_err(|error| format!("decode legacy defaults plist: {error}"))?;
    let dictionary = plist
        .as_dictionary()
        .ok_or_else(|| "legacy defaults plist is not a dictionary".to_owned())?;
    let server_id = match dictionary.get(SERVER_ID_KEY) {
        Some(value) => value
            .as_string()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .ok_or_else(|| format!("legacy key {SERVER_ID_KEY} is not a non-empty string"))?,
        None => generated_id,
    };
    let mut state = PersistentState::minimal(server_id.to_owned())
        .map_err(|error| format!("create migration fallback: {error}"))?;

    if let Some(data) = optional_data(dictionary, TRUSTED_CLIENTS_KEY)? {
        migrate_trusted_clients(data, &mut state)?;
    }
    let migrated_profiles = match optional_data(dictionary, PROFILES_KEY)? {
        Some(data) => migrate_profiles(data, &mut state)?,
        None => false,
    };
    if !migrated_profiles {
        if let Some(data) = optional_data(dictionary, CUSTOMIZATION_KEY)? {
            migrate_standalone_customization(data, &mut state)?;
        }
    }

    let v1_bindings = dictionary.get(KEY_BINDINGS_V1_KEY);
    let migrated_key_bindings = match optional_data(dictionary, KEY_BINDINGS_V2_KEY)? {
        Some(data) => match parse_bindings::<KeyBinding>(data) {
            Some(bindings) => Some(bindings),
            None => match v1_bindings {
                Some(value) => Some(parse_legacy_key_bindings(value)?),
                None => {
                    return Err(format!(
                        "legacy key {KEY_BINDINGS_V2_KEY} contains invalid binding JSON"
                    ));
                }
            },
        },
        None => v1_bindings.map(parse_legacy_key_bindings).transpose()?,
    };
    if let Some(bindings) = migrated_key_bindings {
        state.key_bindings = bindings;
    }

    if let Some(data) = optional_data(dictionary, PROFILE_KEY_BINDINGS_KEY)? {
        state.profile_key_bindings =
            parse_profile_bindings::<KeyBinding>(data).ok_or_else(|| {
                format!("legacy key {PROFILE_KEY_BINDINGS_KEY} contains invalid binding JSON")
            })?;
    }

    let mut output_bindings = keyboard_outputs(&state.key_bindings);
    if let Some(data) = optional_data(dictionary, OUTPUT_BINDINGS_KEY)? {
        let migrated = parse_bindings::<OutputBinding>(data).ok_or_else(|| {
            format!("legacy key {OUTPUT_BINDINGS_KEY} contains invalid output JSON")
        })?;
        overlay_bindings(&mut output_bindings, &migrated);
    }
    state.output_bindings = output_bindings;

    let mut profile_output_bindings = state
        .profile_key_bindings
        .iter()
        .map(|(profile_id, bindings)| (profile_id.clone(), keyboard_outputs(bindings)))
        .collect::<BTreeMap<_, _>>();
    if let Some(data) = optional_data(dictionary, PROFILE_OUTPUT_BINDINGS_KEY)? {
        let migrated = parse_profile_bindings::<OutputBinding>(data).ok_or_else(|| {
            format!("legacy key {PROFILE_OUTPUT_BINDINGS_KEY} contains invalid output JSON")
        })?;
        for (profile_id, bindings) in migrated {
            overlay_bindings(
                profile_output_bindings.entry(profile_id).or_default(),
                &bindings,
            );
        }
    }
    state.profile_output_bindings = profile_output_bindings;

    state
        .normalize()
        .map_err(|error| format!("normalize legacy defaults: {error}"))?;
    Ok(state)
}

fn migration_source(paths: &HostPaths) -> Result<Option<Vec<u8>>, String> {
    #[cfg(target_os = "macos")]
    if paths
        .state_dir
        .ancestors()
        .nth(3)
        .is_some_and(effective_user_home_matches)
    {
        if let Some(exported) = export_defaults()? {
            return Ok(Some(exported));
        }
    }

    let preferences = paths
        .state_dir
        .ancestors()
        .nth(3)
        .map(|home| {
            home.join("Library/Preferences")
                .join(format!("{DEFAULTS_DOMAIN}.plist"))
        })
        .or_else(default_preferences_path);
    let Some(path) = preferences else {
        return Ok(None);
    };
    match fs::read(&path) {
        Ok(data) => Ok(Some(data)),
        Err(error) if error.kind() == io::ErrorKind::NotFound => Ok(None),
        Err(error) => Err(format!(
            "read detected legacy preferences {}: {error}",
            path.display()
        )),
    }
}

#[cfg(target_os = "macos")]
fn effective_user_home_matches(path: &Path) -> bool {
    // SAFETY: getpwuid returns process-global immutable storage. The bytes are
    // copied into a Path before the comparison.
    unsafe {
        let entry = libc::getpwuid(libc::geteuid());
        if entry.is_null() || (*entry).pw_dir.is_null() {
            return false;
        }
        use std::os::unix::ffi::OsStrExt;
        let bytes = std::ffi::CStr::from_ptr((*entry).pw_dir).to_bytes();
        path == Path::new(std::ffi::OsStr::from_bytes(bytes))
    }
}

#[cfg(target_os = "macos")]
fn export_defaults() -> Result<Option<Vec<u8>>, String> {
    let output = Command::new("/usr/bin/defaults")
        .args(["export", DEFAULTS_DOMAIN, "-"])
        .stdin(Stdio::null())
        .output()
        .map_err(|error| format!("export legacy defaults domain: {error}"))?;
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(format!(
            "export legacy defaults domain failed with {}: {}",
            output.status,
            stderr.trim()
        ));
    }
    if output.stdout.is_empty() {
        return Err("legacy defaults export succeeded without data".to_owned());
    }
    Ok(Some(output.stdout))
}

fn default_preferences_path() -> Option<PathBuf> {
    std::env::var_os("HOME")
        .filter(|home| !home.is_empty())
        .map(PathBuf::from)
        .map(|home| {
            home.join("Library/Preferences")
                .join(format!("{DEFAULTS_DOMAIN}.plist"))
        })
}

fn optional_data<'a>(
    dictionary: &'a plist::Dictionary,
    key: &str,
) -> Result<Option<&'a [u8]>, String> {
    match dictionary.get(key) {
        None => Ok(None),
        Some(value) => value
            .as_data()
            .map(Some)
            .ok_or_else(|| format!("legacy key {key} is not Data")),
    }
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct LegacyTrustedClient {
    token: String,
    #[serde(alias = "name")]
    client_name: String,
    created_at: i64,
    last_seen_at: i64,
}

fn migrate_trusted_clients(data: &[u8], state: &mut PersistentState) -> Result<(), String> {
    let clients = serde_json::from_slice::<Vec<LegacyTrustedClient>>(data)
        .map_err(|error| format!("decode legacy trusted clients: {error}"))?;
    for client in clients {
        let token = client.token.trim();
        if token.is_empty() {
            return Err("legacy trusted client contains an empty token".to_owned());
        }
        state.trusted_clients.insert(
            token.to_owned(),
            TrustedClient {
                name: if client.client_name.trim().is_empty() {
                    "Client".to_owned()
                } else {
                    client.client_name
                },
                created_at: client.created_at,
                last_seen_at: client.last_seen_at,
            },
        );
    }
    Ok(())
}

fn migrate_profiles(data: &[u8], state: &mut PersistentState) -> Result<bool, String> {
    let value = serde_json::from_slice::<JsonValue>(data)
        .map_err(|error| format!("decode legacy profile store: {error}"))?;
    let object = value
        .as_object()
        .ok_or_else(|| "legacy profile store is not a JSON object".to_owned())?;
    let profiles = object
        .get("profiles")
        .and_then(JsonValue::as_array)
        .ok_or_else(|| "legacy profile store has no profiles array".to_owned())?;
    for profile in profiles {
        if profile
            .get("id")
            .and_then(JsonValue::as_str)
            .is_none_or(|id| id.trim().is_empty())
        {
            return Err("legacy profile store contains a profile without an ID".to_owned());
        }
    }
    if !profiles.is_empty() {
        let mut migrated = profiles.clone();
        for profile in &mut migrated {
            let profile = profile
                .as_object_mut()
                .ok_or_else(|| "legacy profile is not a JSON object".to_owned())?;
            profile
                .entry("customization".to_owned())
                .or_insert_with(minimal_default_customization);
            for key in [
                "customization",
                "landscapeCustomization",
                "portraitCustomization",
            ] {
                if let Some(customization) = profile.get_mut(key) {
                    ensure_customization_elements(customization)?;
                }
            }
        }
        state.profiles = migrated;
    }
    if let Some(active) = object
        .get("activeProfileID")
        .or_else(|| object.get("activeProfileId"))
        .and_then(JsonValue::as_str)
    {
        state.active_profile_id = active.to_owned();
    }
    if let Some(default) = object
        .get("defaultProfileID")
        .or_else(|| object.get("defaultProfileId"))
        .and_then(JsonValue::as_str)
    {
        state.default_profile_id = default.to_owned();
    }
    Ok(!profiles.is_empty())
}

fn migrate_standalone_customization(
    data: &[u8],
    state: &mut PersistentState,
) -> Result<(), String> {
    let customization = serde_json::from_slice::<JsonValue>(data)
        .map_err(|error| format!("decode legacy standalone customization: {error}"))?;
    if !customization.is_object() {
        return Err("legacy standalone customization is not a JSON object".to_owned());
    }
    let mut customization = customization;
    ensure_customization_elements(&mut customization)?;
    let profile = state
        .profiles
        .first_mut()
        .and_then(JsonValue::as_object_mut)
        .ok_or_else(|| "migration fallback profile is malformed".to_owned())?;
    profile.insert(
        "name".to_owned(),
        JsonValue::String("Current Setup".to_owned()),
    );
    profile.insert("customization".to_owned(), customization);
    Ok(())
}

fn ensure_customization_elements(customization: &mut JsonValue) -> Result<(), String> {
    let object = customization
        .as_object_mut()
        .ok_or_else(|| "legacy customization is not a JSON object".to_owned())?;
    if object
        .get("elements")
        .and_then(JsonValue::as_array)
        .is_some_and(|elements| !elements.is_empty())
    {
        return Ok(());
    }

    let button_customizations = object.get("buttonCustomizations");
    let label_overrides = object.get("labelOverrides");
    let mut elements = Vec::new();
    for (id, label, button) in [
        ("00000000-0000-0000-0000-000000000101", "Up", "up"),
        ("00000000-0000-0000-0000-000000000102", "Down", "down"),
        ("00000000-0000-0000-0000-000000000103", "Left", "left"),
        ("00000000-0000-0000-0000-000000000104", "Right", "right"),
        ("00000000-0000-0000-0000-000000000105", "Action 1", "jump"),
        ("00000000-0000-0000-0000-000000000106", "Action 2", "attack"),
        ("00000000-0000-0000-0000-000000000107", "Action 3", "dash"),
        ("00000000-0000-0000-0000-000000000108", "Action 4", "focus"),
        ("00000000-0000-0000-0000-000000000109", "Menu", "map"),
        ("00000000-0000-0000-0000-000000000110", "Pause", "pause"),
    ] {
        let layout = swift_dictionary_value(button_customizations, button)
            .cloned()
            .unwrap_or_else(|| serde_json::json!({}));
        if layout.get("isHidden").and_then(JsonValue::as_bool) == Some(true) {
            continue;
        }
        let label = swift_dictionary_value(label_overrides, button)
            .and_then(JsonValue::as_str)
            .filter(|label| !label.trim().is_empty())
            .unwrap_or(label);
        elements.push(serde_json::json!({
            "id": id,
            "label": label,
            "kind": "button",
            "layout": layout,
            "builtInButton": button,
            "legacySlot": button,
            "partOutputs": []
        }));
    }

    if let Some(custom_buttons) = object.get("customButtons").and_then(JsonValue::as_array) {
        for custom in custom_buttons {
            let custom = custom
                .as_object()
                .ok_or_else(|| "legacy custom button is not a JSON object".to_owned())?;
            let id = custom
                .get("id")
                .and_then(JsonValue::as_str)
                .filter(|id| !id.trim().is_empty())
                .ok_or_else(|| "legacy custom button has no stable ID".to_owned())?;
            let layout = custom
                .get("layout")
                .cloned()
                .unwrap_or_else(|| serde_json::json!({}));
            if layout.get("isHidden").and_then(JsonValue::as_bool) == Some(true) {
                continue;
            }
            let mapped_button = custom
                .get("mappedButton")
                .and_then(JsonValue::as_str)
                .unwrap_or("custom1");
            let label = custom
                .get("label")
                .and_then(JsonValue::as_str)
                .filter(|label| !label.trim().is_empty())
                .unwrap_or("Button");
            let mut element = serde_json::Map::from_iter([
                ("id".to_owned(), JsonValue::String(id.to_owned())),
                ("label".to_owned(), JsonValue::String(label.to_owned())),
                (
                    "kind".to_owned(),
                    custom
                        .get("controlKind")
                        .cloned()
                        .unwrap_or_else(|| JsonValue::String("button".to_owned())),
                ),
                ("layout".to_owned(), layout),
                (
                    "legacySlot".to_owned(),
                    JsonValue::String(mapped_button.to_owned()),
                ),
                ("partOutputs".to_owned(), JsonValue::Array(Vec::new())),
            ]);
            for key in [
                "visualRole",
                "joystickMapping",
                "joystickOutputSettings",
                "triggerSettings",
                "trackpadSettings",
            ] {
                if let Some(value) = custom.get(key) {
                    element.insert(key.to_owned(), value.clone());
                }
            }
            elements.push(JsonValue::Object(element));
        }
    }

    object.insert("elements".to_owned(), JsonValue::Array(elements));
    Ok(())
}

fn swift_dictionary_value<'a>(
    dictionary: Option<&'a JsonValue>,
    key: &str,
) -> Option<&'a JsonValue> {
    match dictionary? {
        JsonValue::Object(object) => object.get(key),
        JsonValue::Array(entries) => entries
            .chunks_exact(2)
            .find_map(|entry| (entry[0].as_str() == Some(key)).then_some(&entry[1])),
        _ => None,
    }
}

fn normalized_binding_json(mut value: JsonValue) -> JsonValue {
    fn visit(value: &mut JsonValue) {
        match value {
            JsonValue::Object(object) => {
                if let Some(raw) = object
                    .get("modifiers")
                    .and_then(JsonValue::as_object)
                    .and_then(|modifiers| modifiers.get("rawValue"))
                    .and_then(JsonValue::as_u64)
                {
                    object.insert("modifiers".to_owned(), JsonValue::from(raw));
                }
                for child in object.values_mut() {
                    visit(child);
                }
            }
            JsonValue::Array(array) => array.iter_mut().for_each(visit),
            _ => {}
        }
    }
    visit(&mut value);
    value
}

fn parse_bindings<T: DeserializeOwned>(data: &[u8]) -> Option<ButtonBindings<T>> {
    let value = serde_json::from_slice::<JsonValue>(data).ok()?;
    serde_json::from_value(normalized_binding_json(value)).ok()
}

fn parse_profile_bindings<T: DeserializeOwned>(
    data: &[u8],
) -> Option<BTreeMap<String, ButtonBindings<T>>> {
    let value = serde_json::from_slice::<JsonValue>(data).ok()?;
    serde_json::from_value(normalized_binding_json(value)).ok()
}

fn parse_legacy_key_bindings(value: &plist::Value) -> Result<ButtonBindings<KeyBinding>, String> {
    if let Some(data) = value.as_data() {
        if let Some(bindings) = parse_bindings::<KeyBinding>(data) {
            return Ok(bindings);
        }
        let value = serde_json::from_slice::<JsonValue>(data)
            .map_err(|error| format!("decode legacy numeric key bindings: {error}"))?;
        let object = value
            .as_object()
            .ok_or_else(|| "legacy numeric key bindings are not a JSON object".to_owned())?;
        let mut bindings = ButtonBindings::default();
        for (button, key_code) in object {
            let key_code = key_code
                .as_u64()
                .and_then(|value| u16::try_from(value).ok())
                .ok_or_else(|| format!("legacy key binding {button} has an invalid key code"))?;
            bindings.insert_raw(button.clone(), KeyBinding::new(key_code, 0));
        }
        return Ok(bindings);
    }

    let dictionary = value
        .as_dictionary()
        .ok_or_else(|| format!("legacy key {KEY_BINDINGS_V1_KEY} has an unsupported type"))?;
    let mut bindings = ButtonBindings::default();
    for (button, key_code) in dictionary {
        let key_code = key_code
            .as_signed_integer()
            .and_then(|value| u16::try_from(value).ok())
            .ok_or_else(|| format!("legacy key binding {button} has an invalid key code"))?;
        bindings.insert_raw(button.clone(), KeyBinding::new(key_code, 0));
    }
    Ok(bindings)
}

fn keyboard_outputs(bindings: &ButtonBindings<KeyBinding>) -> ButtonBindings<OutputBinding> {
    let mut outputs = ButtonBindings::default();
    for (button, binding) in bindings.iter() {
        outputs.insert_raw(button.to_owned(), OutputBinding::keyboard(binding.clone()));
    }
    outputs
}

fn overlay_bindings<T: Clone>(target: &mut ButtonBindings<T>, overlay: &ButtonBindings<T>) {
    for (button, binding) in overlay.iter() {
        target.insert_raw(button.to_owned(), binding.clone());
    }
}

fn restrict_file(path: &Path) -> Result<(), String> {
    fs::set_permissions(path, fs::Permissions::from_mode(0o600))
        .map_err(|error| format!("protect {}: {error}", path.display()))
}

#[cfg(test)]
mod tests {
    use super::*;
    use plist::{Dictionary, Value};
    use serde_json::json;
    use tempfile::tempdir;

    fn fixture_plist() -> Vec<u8> {
        let profile_id = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE";
        let trusted = json!([{
            "token": "fixture-auth-token",
            "clientName": "Fixture iPhone",
            "createdAt": 111,
            "lastSeenAt": 222
        }]);
        let profiles = json!({
            "profiles": [{
                "id": profile_id,
                "name": "Migrated",
                "customization": {"elements": []},
                "futureField": {"survives": true}
            }],
            "activeProfileID": profile_id,
            "defaultProfileID": profile_id
        });
        let key_bindings = json!({
            "jump": {"keyCode": 49, "modifiers": {"rawValue": 3}},
            "futureButton": {"keyCode": 7, "modifiers": 0}
        });
        let profile_key_bindings = json!({
            profile_id: {"attack": {"keyCode": 40, "modifiers": 8}}
        });
        let output_bindings = json!({
            "jump": {"keyboard": {"keyCode": 36, "modifiers": 1}, "gamepadButtons": ["south"]}
        });
        let profile_output_bindings = json!({
            profile_id: {"pause": {"keyboard": {"keyCode": 53, "modifiers": 0}, "gamepadButtons": []}}
        });

        let mut dictionary = Dictionary::new();
        dictionary.insert(
            SERVER_ID_KEY.to_owned(),
            Value::String("SERVER-FIXTURE-ID".to_owned()),
        );
        dictionary.insert(
            TRUSTED_CLIENTS_KEY.to_owned(),
            Value::Data(serde_json::to_vec(&trusted).unwrap()),
        );
        dictionary.insert(
            PROFILES_KEY.to_owned(),
            Value::Data(serde_json::to_vec(&profiles).unwrap()),
        );
        dictionary.insert(
            KEY_BINDINGS_V2_KEY.to_owned(),
            Value::Data(serde_json::to_vec(&key_bindings).unwrap()),
        );
        dictionary.insert(
            PROFILE_KEY_BINDINGS_KEY.to_owned(),
            Value::Data(serde_json::to_vec(&profile_key_bindings).unwrap()),
        );
        dictionary.insert(
            OUTPUT_BINDINGS_KEY.to_owned(),
            Value::Data(serde_json::to_vec(&output_bindings).unwrap()),
        );
        dictionary.insert(
            PROFILE_OUTPUT_BINDINGS_KEY.to_owned(),
            Value::Data(serde_json::to_vec(&profile_output_bindings).unwrap()),
        );
        let mut bytes = Vec::new();
        plist::to_writer_xml(&mut bytes, &Value::Dictionary(dictionary)).unwrap();
        bytes
    }

    #[test]
    fn realistic_xml_defaults_migration_preserves_every_independent_layer() {
        let state = migrate_plist_bytes(&fixture_plist(), "generated-fallback").unwrap();
        let profile_id = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE";

        assert_eq!(state.server_id, "SERVER-FIXTURE-ID");
        assert_eq!(
            state.trusted_clients["fixture-auth-token"].name,
            "Fixture iPhone"
        );
        assert_eq!(state.active_profile_id, profile_id);
        assert_eq!(state.default_profile_id, profile_id);
        assert_eq!(state.profiles[0]["futureField"]["survives"], true);
        assert_eq!(state.key_bindings.get_raw("jump").unwrap().modifiers, 3);
        assert_eq!(
            state.key_bindings.get_raw("futureButton").unwrap().key_code,
            7
        );
        assert_eq!(
            state.profile_key_bindings[profile_id]
                .get_raw("attack")
                .unwrap()
                .modifiers,
            8
        );
        assert_eq!(
            state
                .output_bindings
                .get_raw("jump")
                .unwrap()
                .keyboard
                .as_ref()
                .unwrap()
                .key_code,
            36
        );
        assert!(state
            .output_bindings
            .get_raw("jump")
            .unwrap()
            .gamepad_buttons
            .contains("south"));
        assert_eq!(
            state.profile_output_bindings[profile_id]
                .get_raw("attack")
                .unwrap()
                .keyboard
                .as_ref()
                .unwrap()
                .key_code,
            40
        );
        assert_eq!(
            state.profile_output_bindings[profile_id]
                .get_raw("pause")
                .unwrap()
                .keyboard
                .as_ref()
                .unwrap()
                .key_code,
            53
        );
    }

    #[test]
    fn malformed_v2_key_bindings_fall_back_to_v1_data() {
        let mut root = Dictionary::new();
        root.insert(
            KEY_BINDINGS_V2_KEY.to_owned(),
            Value::Data(b"not json".to_vec()),
        );
        root.insert(
            KEY_BINDINGS_V1_KEY.to_owned(),
            Value::Data(br#"{"jump":{"keyCode":49,"modifiers":2}}"#.to_vec()),
        );
        let mut bytes = Vec::new();
        plist::to_writer_xml(&mut bytes, &Value::Dictionary(root)).unwrap();

        let state = migrate_plist_bytes(&bytes, "fallback").unwrap();
        assert_eq!(state.key_bindings.get_raw("jump").unwrap().key_code, 49);
        assert_eq!(state.key_bindings.get_raw("jump").unwrap().modifiers, 2);
    }

    #[test]
    fn malformed_critical_piece_fails_closed_before_state_installation() {
        let mut root = Dictionary::new();
        root.insert(
            SERVER_ID_KEY.to_owned(),
            Value::String("kept-server".to_owned()),
        );
        root.insert(
            TRUSTED_CLIENTS_KEY.to_owned(),
            Value::Data(b"not json".to_vec()),
        );
        root.insert(
            KEY_BINDINGS_V2_KEY.to_owned(),
            Value::Data(br#"{"jump":{"keyCode":49,"modifiers":0}}"#.to_vec()),
        );
        let mut bytes = Vec::new();
        plist::to_writer_xml(&mut bytes, &Value::Dictionary(root)).unwrap();

        let directory = tempdir().unwrap();
        let paths = HostPaths::new(
            directory.path().to_path_buf(),
            directory.path().join("control.sock"),
        );
        let error = install_initial_state(&paths, Some(bytes), "fallback").unwrap_err();
        assert!(error.contains("trusted clients"), "{error}");
        assert!(!paths.state_file.exists());
    }

    #[test]
    fn pre_profile_customization_and_keyboard_outputs_are_preserved() {
        let customization = json!({
            "labelOverrides": ["attack", "Strike"],
            "buttonCustomizations": ["jump", {"isHidden": true}],
            "customButtons": [{
                "id": "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF",
                "mappedButton": "custom3",
                "label": "Orb",
                "layout": {},
                "controlKind": "button"
            }],
            "futureCustomizationField": {"survives": true}
        });
        let key_bindings = json!({
            "jump": {"keyCode": 49, "modifiers": 2},
            "attack": {"keyCode": 40, "modifiers": 0},
            "custom3": {"keyCode": 7, "modifiers": 1}
        });
        let partial_outputs = json!({
            "attack": {"gamepadButtons": []}
        });
        let mut root = Dictionary::new();
        root.insert(
            CUSTOMIZATION_KEY.to_owned(),
            Value::Data(serde_json::to_vec(&customization).unwrap()),
        );
        root.insert(
            KEY_BINDINGS_V2_KEY.to_owned(),
            Value::Data(serde_json::to_vec(&key_bindings).unwrap()),
        );
        root.insert(
            OUTPUT_BINDINGS_KEY.to_owned(),
            Value::Data(serde_json::to_vec(&partial_outputs).unwrap()),
        );
        let mut bytes = Vec::new();
        plist::to_writer_xml(&mut bytes, &Value::Dictionary(root)).unwrap();

        let state = migrate_plist_bytes(&bytes, "fallback").unwrap();
        assert_eq!(state.profiles[0]["name"], "Current Setup");
        assert_eq!(
            state.profiles[0]["customization"]["futureCustomizationField"]["survives"],
            true
        );
        let elements = state.profiles[0]["customization"]["elements"]
            .as_array()
            .unwrap();
        assert!(!elements
            .iter()
            .any(|element| element["builtInButton"] == "jump"));
        assert!(elements
            .iter()
            .any(|element| element["builtInButton"] == "attack" && element["label"] == "Strike"));
        assert!(elements.iter().any(|element| {
            element["id"] == "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF"
                && element["legacySlot"] == "custom3"
        }));
        assert_eq!(
            state
                .resolve_element_output(
                    "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF",
                    thumble_protocol::KeypadElementInputPart::Primary,
                )
                .unwrap()
                .keyboard,
            Some(KeyBinding::new(7, 1))
        );
        assert_eq!(
            state.output_bindings.get_raw("jump").unwrap().keyboard,
            Some(KeyBinding::new(49, 2))
        );
        assert_eq!(
            state.output_bindings.get_raw("attack").unwrap(),
            &OutputBinding::default()
        );
    }

    #[test]
    fn known_auth_tokens_are_removed_from_errors_and_logs() {
        let directory = tempdir().unwrap();
        let path = directory.path().join("state.json");
        let mut state = PersistentState::minimal("server").unwrap();
        state.trusted_clients.insert(
            "secret-auth-token".to_owned(),
            TrustedClient {
                name: "Phone".to_owned(),
                created_at: 1,
                last_seen_at: 2,
            },
        );
        save_atomic(&path, &state).unwrap();
        assert_eq!(
            redact_known_auth_tokens(&path, "failure secret-auth-token detail"),
            "failure [REDACTED] detail"
        );
    }

    #[test]
    fn existing_schema_one_state_is_atomically_upgraded_with_initial_revision() {
        let directory = tempdir().unwrap();
        let paths = HostPaths::new(
            directory.path().to_path_buf(),
            directory.path().join("control.sock"),
        );
        paths.ensure_state_dir().unwrap();
        let state = PersistentState::minimal("server").unwrap();
        let mut legacy = serde_json::to_value(state).unwrap();
        legacy["schemaVersion"] = json!(1);
        legacy
            .as_object_mut()
            .unwrap()
            .remove("configurationRevision");
        fs::write(&paths.state_file, serde_json::to_vec(&legacy).unwrap()).unwrap();
        fs::set_permissions(&paths.state_file, fs::Permissions::from_mode(0o600)).unwrap();

        let migrated = load_or_migrate(&paths).unwrap();
        assert_eq!(
            migrated.schema_version,
            thumble_core::CURRENT_SCHEMA_VERSION
        );
        assert_eq!(
            migrated.configuration_revision,
            thumble_core::INITIAL_CONFIGURATION_REVISION
        );
        let persisted = load(&paths.state_file).unwrap();
        assert_eq!(persisted, migrated);
    }

    #[test]
    fn atomic_state_file_is_private_and_round_trips() {
        let directory = tempdir().unwrap();
        let path = directory.path().join("state.json");
        let state = PersistentState::minimal("server").unwrap();
        save_atomic(&path, &state).unwrap();
        assert_eq!(load(&path).unwrap(), state);
        assert_eq!(
            fs::metadata(path).unwrap().permissions().mode() & 0o777,
            0o600
        );
    }
}
