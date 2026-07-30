use serde_json::json;
use std::collections::{BTreeMap, BTreeSet};
use thumble_core::{
    ButtonBindings, KeyBinding, KeyStroke, OutputBinding, PersistentState, StateError,
    TrustedClient, CURRENT_SCHEMA_VERSION, DEFAULT_PROFILE_ID, INITIAL_CONFIGURATION_REVISION,
};
use thumble_protocol::{GameButton, KeypadElementInputPart};

#[test]
fn key_bindings_accept_legacy_mac_and_direct_shared_json_shapes() {
    let legacy: KeyBinding = serde_json::from_value(json!({
        "keyCode": 40,
        "modifiers": 9,
        "sequence": [
            {"keyCode": 11, "modifiers": 8},
            {"keyCode": 4, "modifiers": 0}
        ]
    }))
    .unwrap();
    assert_eq!(legacy.key_code, 40);
    assert_eq!(legacy.modifiers, 9);
    assert_eq!(legacy.strokes()[0], KeyStroke::new(11, 8));

    let direct: KeyBinding = serde_json::from_value(json!({
        "keyCode": 40,
        "modifiersRawValue": 3,
        "sequence": [
            {"keyCode": 12, "modifiersRawValue": 1},
            {"keyCode": 13, "modifiersRawValue": 2}
        ]
    }))
    .unwrap();
    assert_eq!(direct.modifiers, 3);
    assert_eq!(direct.strokes()[1], KeyStroke::new(13, 2));

    let serialized = serde_json::to_value(direct).unwrap();
    assert_eq!(serialized["modifiers"], 3);
    assert!(serialized.get("modifiersRawValue").is_none());
    assert_eq!(serialized["sequence"][0]["modifiers"], 1);
}

#[test]
fn portable_state_round_trips_tokens_profiles_and_binding_layers_losslessly() {
    let mut state = PersistentState::minimal("stable-server").unwrap();
    state.trusted_clients.insert(
        "opaque-token".to_owned(),
        TrustedClient {
            name: "Phone".to_owned(),
            created_at: 10,
            last_seen_at: 20,
        },
    );
    state.profiles[0]["futureProfileField"] = json!({"kept": [1, true, null]});
    state.profiles[0]["customization"]["futureCustomizationField"] = json!("kept");
    state
        .profile_key_bindings
        .get_mut(DEFAULT_PROFILE_ID)
        .unwrap()
        .insert(GameButton::Custom8, KeyBinding::new(99, 4));

    let bytes = serde_json::to_vec(&state).unwrap();
    let decoded: PersistentState = serde_json::from_slice(&bytes).unwrap();
    assert_eq!(decoded, state);
    assert_eq!(
        decoded.profiles[0]["futureProfileField"],
        json!({"kept": [1, true, null]})
    );
    assert_eq!(
        decoded.profiles[0]["customization"]["futureCustomizationField"],
        "kept"
    );
    assert_eq!(decoded.trusted_clients["opaque-token"].last_seen_at, 20);
}

#[test]
fn empty_migration_state_gets_a_swift_decodable_minimal_profile() {
    let mut state = PersistentState::minimal("stable-server").unwrap();
    state.profiles.clear();
    state.active_profile_id = "missing".to_owned();
    state.default_profile_id = "missing".to_owned();
    state.normalize().unwrap();

    assert_eq!(state.profiles.len(), 1);
    assert_eq!(state.active_profile_id, DEFAULT_PROFILE_ID);
    assert_eq!(state.default_profile_id, DEFAULT_PROFILE_ID);
    let profile = &state.profiles[0];
    assert_eq!(profile["id"], DEFAULT_PROFILE_ID);
    assert_eq!(profile["name"], "Default");
    assert!(profile["customization"].is_object());
    assert_eq!(
        profile["customization"]["elements"]
            .as_array()
            .unwrap()
            .len(),
        10
    );
    assert_eq!(
        state
            .resolve_element_output(
                "00000000-0000-0000-0000-000000000105",
                KeypadElementInputPart::Primary,
            )
            .unwrap()
            .keyboard,
        Some(KeyBinding::new(36, 0))
    );
    assert_eq!(profile["orientationPreference"], "automatic");
    assert_eq!(profile["outputMode"], "keyboard");
}

#[test]
fn direct_element_output_in_orientation_variant_beats_primary_legacy_mapping() {
    let mut state = PersistentState::minimal("server").unwrap();
    state.profiles = vec![json!({
        "id": "profile-a",
        "name": "Raw",
        "unknown": {"preserve": true},
        "customization": {
            "elements": [{
                "id": "ELEMENT-1",
                "legacySlot": "jump",
                "futureElementField": 42
            }]
        },
        "landscapeCustomization": {
            "elements": [{
                "id": "element-1",
                "output": {
                    "keyboard": {
                        "keyCode": 7,
                        "modifiersRawValue": 5,
                        "sequence": [
                            {"keyCode": 7, "modifiersRawValue": 5},
                            {"keyCode": 8, "modifiersRawValue": 0}
                        ]
                    },
                    "gamepadButtons": ["south"]
                },
                "unknownLandscapeField": "retained"
            }]
        }
    })];
    state.active_profile_id = "profile-a".to_owned();
    state.default_profile_id = "profile-a".to_owned();
    state.normalize().unwrap();

    let output = state
        .resolve_element_output("Element-1", KeypadElementInputPart::Primary)
        .unwrap();
    let keyboard = output.keyboard.unwrap();
    assert_eq!(
        keyboard.strokes(),
        vec![KeyStroke::new(7, 5), KeyStroke::new(8, 0)]
    );
    assert_eq!(output.gamepad_buttons, BTreeSet::from(["south".to_owned()]));
    assert_eq!(state.profiles[0]["unknown"]["preserve"], true);
    assert_eq!(
        state.profiles[0]["landscapeCustomization"]["elements"][0]["unknownLandscapeField"],
        "retained"
    );
}

#[test]
fn part_outputs_support_swift_dictionary_arrays_and_joystick_legacy_fallback() {
    let mut state = PersistentState::minimal("server").unwrap();
    state.profiles = vec![json!({
        "id": "profile-a",
        "customization": {
            "elements": [{
                "id": "joystick",
                "partOutputs": [
                    "joystick_left",
                    {"keyboard": {"keyCode": 12, "modifiersRawValue": 1}}
                ],
                "joystickMapping": {
                    "up": "custom1",
                    "down": "custom2",
                    "left": "custom3",
                    "right": "custom4"
                }
            }]
        }
    })];
    state.active_profile_id = "profile-a".to_owned();
    state.default_profile_id = "profile-a".to_owned();
    let mut profile_outputs = ButtonBindings::default();
    profile_outputs.insert(
        GameButton::Custom1,
        OutputBinding::keyboard(KeyBinding::new(126, 0)),
    );
    state
        .profile_output_bindings
        .insert("profile-a".to_owned(), profile_outputs);
    state.normalize().unwrap();

    assert_eq!(
        state
            .resolve_element_output("joystick", KeypadElementInputPart::JoystickLeft)
            .unwrap()
            .keyboard,
        Some(KeyBinding::new(12, 1))
    );
    assert_eq!(
        state
            .resolve_element_output("joystick", KeypadElementInputPart::JoystickUp)
            .unwrap()
            .keyboard,
        Some(KeyBinding::new(126, 0))
    );
}

#[test]
fn profile_output_overlays_global_and_explicit_empty_output_suppresses_key_fallback() {
    let mut state = PersistentState::minimal("server").unwrap();
    let global_jump = state.resolve_button_output(GameButton::Jump).unwrap();
    assert_eq!(global_jump.keyboard, Some(KeyBinding::new(36, 0)));

    let mut profile_outputs = ButtonBindings::default();
    profile_outputs.insert(
        GameButton::Jump,
        OutputBinding::keyboard(KeyBinding::new(49, 2)),
    );
    profile_outputs.insert(GameButton::Attack, OutputBinding::default());
    state
        .profile_output_bindings
        .insert(DEFAULT_PROFILE_ID.to_owned(), profile_outputs);

    assert_eq!(
        state
            .resolve_button_output(GameButton::Jump)
            .unwrap()
            .keyboard,
        Some(KeyBinding::new(49, 2))
    );
    assert_eq!(
        state.resolve_button_output(GameButton::Attack).unwrap(),
        OutputBinding::default()
    );
}

#[test]
fn profile_keyboard_binding_precedes_global_output_fallback() {
    let mut state = PersistentState::minimal("server").unwrap();
    state.profile_output_bindings.clear();
    state
        .profile_key_bindings
        .get_mut(DEFAULT_PROFILE_ID)
        .unwrap()
        .insert(GameButton::Jump, KeyBinding::new(49, 2));

    assert_eq!(
        state
            .resolve_button_output(GameButton::Jump)
            .unwrap()
            .keyboard,
        Some(KeyBinding::new(49, 2))
    );
}

#[test]
fn trusted_clients_are_keyed_by_token_not_duplicated_inside_values() {
    let value = json!({
        "schemaVersion": 1,
        "serverID": "server",
        "trustedClients": {
            "opaque": {"name": "Phone", "createdAt": 1, "lastSeenAt": 2}
        },
        "profiles": [{"id": "p", "customization": {}}],
        "activeProfileID": "p",
        "defaultProfileID": "p",
        "keyBindings": {},
        "outputBindings": {},
        "profileKeyBindings": {},
        "profileOutputBindings": {}
    });
    let state: PersistentState = serde_json::from_value(value).unwrap();
    assert_eq!(state.trusted_clients["opaque"].name, "Phone");
    let encoded = serde_json::to_value(state).unwrap();
    assert!(encoded["trustedClients"]["opaque"].get("token").is_none());
}

#[test]
fn unknown_binding_keys_survive_deterministic_serialization() {
    let mut bindings = ButtonBindings::default();
    bindings.insert_raw("future-button", KeyBinding::new(1, 0));
    bindings.insert(GameButton::Up, KeyBinding::new(126, 0));
    let value = serde_json::to_value(&bindings).unwrap();
    let keys = value
        .as_object()
        .unwrap()
        .keys()
        .cloned()
        .collect::<Vec<_>>();
    assert_eq!(keys, vec!["future-button", "up"]);

    let round_trip: ButtonBindings<KeyBinding> = serde_json::from_value(value).unwrap();
    assert_eq!(
        round_trip.get_raw("future-button"),
        Some(&KeyBinding::new(1, 0))
    );
}

#[test]
fn schema_one_state_migrates_to_a_revisioned_configuration() {
    let state = PersistentState::minimal("stable-server").unwrap();
    let mut encoded = serde_json::to_value(state).unwrap();
    encoded["schemaVersion"] = json!(1);
    encoded
        .as_object_mut()
        .unwrap()
        .remove("configurationRevision");

    let mut decoded: PersistentState = serde_json::from_value(encoded).unwrap();
    assert_eq!(
        decoded.configuration_revision,
        INITIAL_CONFIGURATION_REVISION
    );
    decoded.normalize().unwrap();
    assert_eq!(decoded.schema_version, CURRENT_SCHEMA_VERSION);
    assert_eq!(
        decoded.configuration_revision,
        INITIAL_CONFIGURATION_REVISION
    );
}

#[test]
fn configuration_revisions_are_monotonic_and_fail_on_exhaustion() {
    let mut state = PersistentState::minimal("stable-server").unwrap();
    assert_eq!(state.bump_configuration_revision().unwrap(), 2);
    assert_eq!(state.bump_configuration_revision().unwrap(), 3);
    state.configuration_revision = u64::MAX;
    assert_eq!(
        state.bump_configuration_revision(),
        Err(StateError::ConfigurationRevisionExhausted)
    );
}

#[test]
fn output_binding_retains_unsupported_gamepad_names_without_advertising_them() {
    let binding = OutputBinding {
        keyboard: None,
        gamepad_buttons: BTreeSet::from(["futureGamepadButton".to_owned()]),
    };
    let mut bindings = BTreeMap::new();
    bindings.insert("profile".to_owned(), binding.clone());
    let value = serde_json::to_value(&binding).unwrap();
    assert_eq!(value["gamepadButtons"], json!(["futureGamepadButton"]));
    assert_eq!(
        serde_json::to_value(OutputBinding::keyboard(KeyBinding::new(1, 0))).unwrap()
            ["gamepadButtons"],
        json!([])
    );
    assert_eq!(bindings["profile"], binding);
}
