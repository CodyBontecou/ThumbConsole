use crate::state::{ids_equal, profile_id};
use crate::{ButtonBindings, KeyBinding, OutputBinding, PersistentState};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::{BTreeMap, BTreeSet};
use std::error::Error;
use std::fmt;

pub const MAXIMUM_CONFIGURATION_DOCUMENT_BYTES: usize = 8 * 1024 * 1024;
pub const MAXIMUM_CONFIGURATION_PROFILES: usize = 256;
pub const MAXIMUM_CONFIGURATION_PROFILE_ID_BYTES: usize = 128;
pub const MAXIMUM_CONFIGURATION_PROFILE_NAME_CHARACTERS: usize = 256;
pub const MAXIMUM_CONFIGURATION_BINDING_STROKES: usize = 32;
const MAXIMUM_PROFILE_BINDING_MAPS: usize = 512;

/// Credential-free configuration state transformed by drafts and the Swift
/// operation bridge. Server identity and trusted-client data cannot be encoded
/// in this type and therefore cannot enter a draft or bridge request by field.
#[derive(Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ConfigurationDocument {
    pub profiles: Vec<Value>,
    #[serde(rename = "activeProfileID")]
    pub active_profile_id: String,
    #[serde(rename = "defaultProfileID")]
    pub default_profile_id: String,
    #[serde(default)]
    pub key_bindings: ButtonBindings<KeyBinding>,
    #[serde(default)]
    pub output_bindings: ButtonBindings<OutputBinding>,
    #[serde(default)]
    pub profile_key_bindings: BTreeMap<String, ButtonBindings<KeyBinding>>,
    #[serde(default)]
    pub profile_output_bindings: BTreeMap<String, ButtonBindings<OutputBinding>>,
}

impl fmt::Debug for ConfigurationDocument {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("ConfigurationDocument")
            .field("profile_count", &self.profiles.len())
            .field("active_profile_id_bytes", &self.active_profile_id.len())
            .field("default_profile_id_bytes", &self.default_profile_id.len())
            .field("key_binding_count", &self.key_bindings.len())
            .field("output_binding_count", &self.output_bindings.len())
            .field(
                "profile_key_binding_map_count",
                &self.profile_key_bindings.len(),
            )
            .field(
                "profile_output_binding_map_count",
                &self.profile_output_bindings.len(),
            )
            .finish()
    }
}

impl ConfigurationDocument {
    pub fn from_state(state: &PersistentState) -> Result<Self, ConfigurationDocumentError> {
        let document = Self {
            profiles: state.profiles.clone(),
            active_profile_id: state.active_profile_id.clone(),
            default_profile_id: state.default_profile_id.clone(),
            key_bindings: state.key_bindings.clone(),
            output_bindings: state.output_bindings.clone(),
            profile_key_bindings: state.profile_key_bindings.clone(),
            profile_output_bindings: state.profile_output_bindings.clone(),
        };
        document.validate()?;

        let encoded = serde_json::to_vec(&document)
            .map_err(|_| ConfigurationDocumentError::EncodingFailed)?;
        if state
            .trusted_clients
            .keys()
            .any(|token| !token.is_empty() && contains_subslice(&encoded, token.as_bytes()))
        {
            return Err(ConfigurationDocumentError::ContainsTrustedCredential);
        }
        Ok(document)
    }

    pub fn validate(&self) -> Result<(), ConfigurationDocumentError> {
        let encoded =
            serde_json::to_vec(self).map_err(|_| ConfigurationDocumentError::EncodingFailed)?;
        if encoded.len() > MAXIMUM_CONFIGURATION_DOCUMENT_BYTES {
            return Err(ConfigurationDocumentError::TooLarge(encoded.len()));
        }
        if self.profiles.is_empty() || self.profiles.len() > MAXIMUM_CONFIGURATION_PROFILES {
            return Err(ConfigurationDocumentError::InvalidProfileCount(
                self.profiles.len(),
            ));
        }
        if self.profile_key_bindings.len() > MAXIMUM_PROFILE_BINDING_MAPS
            || self.profile_output_bindings.len() > MAXIMUM_PROFILE_BINDING_MAPS
        {
            return Err(ConfigurationDocumentError::TooManyProfileBindingMaps);
        }

        let mut profile_ids = BTreeSet::new();
        let mut canonical_ids = Vec::with_capacity(self.profiles.len());
        for profile in &self.profiles {
            let object = profile
                .as_object()
                .ok_or(ConfigurationDocumentError::MalformedProfile)?;
            let id = profile_id(profile).ok_or(ConfigurationDocumentError::MalformedProfile)?;
            if id.is_empty() || id.len() > MAXIMUM_CONFIGURATION_PROFILE_ID_BYTES {
                return Err(ConfigurationDocumentError::InvalidProfileId);
            }
            let normalized_id = id.to_ascii_lowercase();
            if !profile_ids.insert(normalized_id) {
                return Err(ConfigurationDocumentError::DuplicateProfileId);
            }
            let name = object
                .get("name")
                .and_then(Value::as_str)
                .ok_or(ConfigurationDocumentError::MalformedProfile)?;
            if name.trim().is_empty()
                || name.chars().count() > MAXIMUM_CONFIGURATION_PROFILE_NAME_CHARACTERS
            {
                return Err(ConfigurationDocumentError::InvalidProfileName);
            }
            if !object.get("customization").is_some_and(Value::is_object) {
                return Err(ConfigurationDocumentError::MalformedCustomization);
            }
            canonical_ids.push(id);
        }
        if !canonical_ids
            .iter()
            .any(|id| ids_equal(id, &self.active_profile_id))
        {
            return Err(ConfigurationDocumentError::ActiveProfileMissing);
        }
        if !canonical_ids
            .iter()
            .any(|id| ids_equal(id, &self.default_profile_id))
        {
            return Err(ConfigurationDocumentError::DefaultProfileMissing);
        }

        validate_key_bindings(&self.key_bindings)?;
        validate_output_bindings(&self.output_bindings)?;
        for bindings in self.profile_key_bindings.values() {
            validate_key_bindings(bindings)?;
        }
        for bindings in self.profile_output_bindings.values() {
            validate_output_bindings(bindings)?;
        }
        Ok(())
    }

    /// Install an already validated document without touching credentials or
    /// the authoritative configuration revision. The commit layer owns the
    /// compare-and-swap revision update and atomic persistence ordering.
    pub fn install_into(
        &self,
        state: &mut PersistentState,
    ) -> Result<(), ConfigurationDocumentError> {
        self.validate()?;
        state.profiles.clone_from(&self.profiles);
        state.active_profile_id.clone_from(&self.active_profile_id);
        state
            .default_profile_id
            .clone_from(&self.default_profile_id);
        state.key_bindings.clone_from(&self.key_bindings);
        state.output_bindings.clone_from(&self.output_bindings);
        state
            .profile_key_bindings
            .clone_from(&self.profile_key_bindings);
        state
            .profile_output_bindings
            .clone_from(&self.profile_output_bindings);
        Ok(())
    }
}

fn validate_key_bindings(
    bindings: &ButtonBindings<KeyBinding>,
) -> Result<(), ConfigurationDocumentError> {
    if bindings.len() > 128 {
        return Err(ConfigurationDocumentError::TooManyBindings);
    }
    if bindings.iter().any(|(_, binding)| {
        let count = binding.strokes().len();
        count == 0 || count > MAXIMUM_CONFIGURATION_BINDING_STROKES
    }) {
        return Err(ConfigurationDocumentError::InvalidBindingSequence);
    }
    Ok(())
}

fn validate_output_bindings(
    bindings: &ButtonBindings<OutputBinding>,
) -> Result<(), ConfigurationDocumentError> {
    if bindings.len() > 128 {
        return Err(ConfigurationDocumentError::TooManyBindings);
    }
    for (_, binding) in bindings.iter() {
        if binding.gamepad_buttons.len() > 32 {
            return Err(ConfigurationDocumentError::TooManyGamepadOutputs);
        }
        if let Some(keyboard) = &binding.keyboard {
            let count = keyboard.strokes().len();
            if count == 0 || count > MAXIMUM_CONFIGURATION_BINDING_STROKES {
                return Err(ConfigurationDocumentError::InvalidBindingSequence);
            }
        }
    }
    Ok(())
}

fn contains_subslice(haystack: &[u8], needle: &[u8]) -> bool {
    !needle.is_empty()
        && haystack
            .windows(needle.len())
            .any(|window| window == needle)
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ConfigurationDocumentError {
    EncodingFailed,
    TooLarge(usize),
    InvalidProfileCount(usize),
    TooManyProfileBindingMaps,
    MalformedProfile,
    InvalidProfileId,
    DuplicateProfileId,
    InvalidProfileName,
    MalformedCustomization,
    ActiveProfileMissing,
    DefaultProfileMissing,
    TooManyBindings,
    InvalidBindingSequence,
    TooManyGamepadOutputs,
    ContainsTrustedCredential,
}

impl fmt::Display for ConfigurationDocumentError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EncodingFailed => formatter.write_str("configuration document could not be encoded"),
            Self::TooLarge(bytes) => write!(
                formatter,
                "configuration document is {bytes} bytes; maximum is {MAXIMUM_CONFIGURATION_DOCUMENT_BYTES}"
            ),
            Self::InvalidProfileCount(count) => write!(
                formatter,
                "configuration contains {count} profiles; expected 1 through {MAXIMUM_CONFIGURATION_PROFILES}"
            ),
            Self::TooManyProfileBindingMaps => formatter.write_str("configuration has too many profile binding maps"),
            Self::MalformedProfile => formatter.write_str("configuration contains a malformed profile"),
            Self::InvalidProfileId => formatter.write_str("configuration contains an invalid profile ID"),
            Self::DuplicateProfileId => formatter.write_str("configuration contains duplicate profile IDs"),
            Self::InvalidProfileName => formatter.write_str("configuration contains an invalid profile name"),
            Self::MalformedCustomization => formatter.write_str("configuration contains a malformed customization"),
            Self::ActiveProfileMissing => formatter.write_str("active profile does not exist in the configuration"),
            Self::DefaultProfileMissing => formatter.write_str("default profile does not exist in the configuration"),
            Self::TooManyBindings => formatter.write_str("configuration contains too many bindings"),
            Self::InvalidBindingSequence => formatter.write_str("configuration contains an invalid binding sequence"),
            Self::TooManyGamepadOutputs => formatter.write_str("configuration contains too many gamepad outputs"),
            Self::ContainsTrustedCredential => formatter.write_str("configuration contains trusted credential material and cannot enter a draft"),
        }
    }
}

impl Error for ConfigurationDocumentError {}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::TrustedClient;

    #[test]
    fn document_round_trip_changes_only_configuration_fields() {
        let mut state = PersistentState::minimal("server-id").unwrap();
        state.trusted_clients.insert(
            "secret-token".to_owned(),
            TrustedClient {
                name: "Phone".to_owned(),
                created_at: 1,
                last_seen_at: 2,
            },
        );
        let mut document = ConfigurationDocument::from_state(&state).unwrap();
        document.profiles[0]["name"] = Value::String("Edited".to_owned());
        document.validate().unwrap();

        let revision = state.configuration_revision;
        document.install_into(&mut state).unwrap();
        assert_eq!(state.profiles[0]["name"], "Edited");
        assert_eq!(state.configuration_revision, revision);
        assert!(state.trusted_clients.contains_key("secret-token"));
        assert_eq!(state.server_id, "server-id");
    }

    #[test]
    fn document_rejects_credentials_even_across_free_form_profile_fields() {
        let mut state = PersistentState::minimal("server-id").unwrap();
        let token = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_";
        state.trusted_clients.insert(
            token.to_owned(),
            TrustedClient {
                name: "Phone".to_owned(),
                created_at: 1,
                last_seen_at: 2,
            },
        );
        state.profiles[0]["futureField"] = Value::String(format!("prefix-{token}-suffix"));
        assert_eq!(
            ConfigurationDocument::from_state(&state),
            Err(ConfigurationDocumentError::ContainsTrustedCredential)
        );
    }

    #[test]
    fn validation_preserves_unknown_fields_but_rejects_duplicate_ids() {
        let state = PersistentState::minimal("server-id").unwrap();
        let mut document = ConfigurationDocument::from_state(&state).unwrap();
        document.profiles[0]["futureNested"] = serde_json::json!({"untouched": [1, 2, 3]});
        document.validate().unwrap();
        document.profiles.push(document.profiles[0].clone());
        assert_eq!(
            document.validate(),
            Err(ConfigurationDocumentError::DuplicateProfileId)
        );
    }
}
