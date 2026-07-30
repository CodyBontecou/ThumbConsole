use serde_json::json;
use thumble_protocol::{
    ButtonPressState, ControllerCapability, ControllerMessage, ControllerMessageType,
    ControllerPointerButton, ControllerPointerEventKind, ControllerWireCodec,
    ControllerWireCodecError, GameButton, GamepadProfileOrientationPreference,
    KeypadElementInputPart, VirtualGamepadStick, VirtualGamepadTrigger,
};

#[test]
fn v1_encodes_and_decodes_every_button_code_and_state() {
    for button in GameButton::ALL {
        for state in ButtonPressState::ALL {
            let frame = ControllerWireCodec::encode_button(button, state);
            assert_eq!(frame.len(), 14);
            assert_eq!(&frame[0..4], &[b'P', b'P', 1, 1]);
            assert_eq!(&frame[4..12], &[0; 8]);
            assert_eq!(frame[12], button.compact_wire_code());
            assert_eq!(frame[13], state.compact_wire_code());

            let decoded = ControllerWireCodec::decode(&frame).unwrap();
            assert_eq!(decoded.message_type, ControllerMessageType::Button);
            assert_eq!(decoded.button, Some(button));
            assert_eq!(decoded.state, Some(state));
            assert_eq!(decoded.timestamp, 0);
            assert_eq!(decoded.input_protocol_version, None);
        }
    }
}

#[test]
fn v2_encodes_and_decodes_every_button_code_and_state() {
    for button in GameButton::ALL {
        for state in ButtonPressState::ALL {
            let generation = u64::MAX - u64::from(button.compact_wire_code());
            let sequence = 0x0102_0304_0506_0708;
            let press_identifier = 0x8877_6655_4433_2211;
            let frame = ControllerWireCodec::encode_button_with_sequence(
                button,
                state,
                sequence,
                Some(press_identifier),
                Some(generation),
            );

            assert_eq!(frame.len(), 32);
            assert_eq!(&frame[0..4], &[b'P', b'P', 2, 1]);
            assert_eq!(frame[4], button.compact_wire_code());
            assert_eq!(frame[5], state.compact_wire_code());
            assert_eq!(frame[6], 1);
            assert_eq!(frame[7], 0);
            assert_eq!(&frame[8..16], &generation.to_le_bytes());
            assert_eq!(&frame[16..24], &sequence.to_le_bytes());
            assert_eq!(&frame[24..32], &press_identifier.to_le_bytes());

            let decoded = ControllerWireCodec::decode(&frame).unwrap();
            assert_eq!(decoded.message_type, ControllerMessageType::Button);
            assert_eq!(decoded.button, Some(button));
            assert_eq!(decoded.state, Some(state));
            assert_eq!(decoded.timestamp, 0);
            assert_eq!(decoded.input_protocol_version, Some(2));
            assert_eq!(decoded.input_generation, Some(generation));
            assert_eq!(decoded.input_sequence, Some(sequence));
            assert_eq!(decoded.press_identifier, Some(press_identifier));
            assert_eq!(
                ControllerWireCodec::input_sequence_number(&decoded),
                Some(sequence)
            );
            assert_eq!(
                ControllerWireCodec::input_press_identifier(&decoded),
                Some(press_identifier)
            );
        }
    }
}

#[test]
fn generic_encode_selects_exact_v2_layout() {
    let mut message = ControllerMessage::new(ControllerMessageType::Button, i64::MIN);
    message.button = Some(GameButton::Attack);
    message.state = Some(ButtonPressState::Up);
    message.sent_at = Some(999);
    message.input_protocol_version = Some(2);
    message.input_generation = Some(u64::MAX - 10);
    message.input_sequence = Some(u64::MAX - 20);
    message.press_identifier = Some(u64::MAX - 30);

    let frame = ControllerWireCodec::encode(&message).unwrap();
    let expected = ControllerWireCodec::encode_button_with_sequence(
        GameButton::Attack,
        ButtonPressState::Up,
        u64::MAX - 20,
        Some(u64::MAX - 30),
        Some(u64::MAX - 10),
    );
    assert_eq!(frame, expected);

    let decoded = ControllerWireCodec::decode(&frame).unwrap();
    assert_eq!(decoded.timestamp, 0);
    assert_eq!(decoded.sent_at, None);
}

#[test]
fn v2_absent_press_identifier_uses_zero_storage_and_ignores_it_when_decoding() {
    let mut frame = ControllerWireCodec::encode_button_with_sequence(
        GameButton::Map,
        ButtonPressState::Down,
        4,
        None,
        Some(3),
    );
    assert_eq!(frame[6], 0);
    assert_eq!(&frame[24..32], &[0; 8]);

    frame[24..32].copy_from_slice(&u64::MAX.to_le_bytes());
    let decoded = ControllerWireCodec::decode(&frame).unwrap();
    assert_eq!(decoded.press_identifier, None);
}

#[test]
fn v1_control_message_codes_and_signed_timestamp_layout_match_swift() {
    let cases = [
        (ControllerMessageType::ReleaseAll, 2),
        (ControllerMessageType::Heartbeat, 3),
        (ControllerMessageType::Ping, 4),
        (ControllerMessageType::Pong, 5),
    ];
    for (message_type, code) in cases {
        let message = ControllerMessage::new(message_type, i64::MIN + i64::from(code));
        let frame = ControllerWireCodec::encode(&message).unwrap();
        assert_eq!(frame.len(), 14);
        assert_eq!(&frame[0..4], &[b'P', b'P', 1, code]);
        assert_eq!(&frame[4..12], &message.timestamp.to_le_bytes());
        assert_eq!(&frame[12..14], &[u8::MAX, u8::MAX]);
        assert_eq!(ControllerWireCodec::decode(&frame).unwrap(), message);
    }
}

#[test]
fn v1_sequence_packing_matches_swift_clamping_and_helpers() {
    let frame = ControllerWireCodec::encode_button_with_sequence(
        GameButton::Dash,
        ButtonPressState::Down,
        42,
        Some(1_234),
        None,
    );
    assert_eq!(frame.len(), 14);
    let decoded = ControllerWireCodec::decode(&frame).unwrap();
    assert_eq!(
        ControllerWireCodec::button_sequence_number(&decoded),
        Some(42)
    );
    assert_eq!(
        ControllerWireCodec::button_press_identifier(&decoded),
        Some(1_234)
    );

    let clamped = ControllerWireCodec::encode_button_with_sequence(
        GameButton::Dash,
        ButtonPressState::Up,
        0,
        Some(u64::MAX),
        None,
    );
    let decoded = ControllerWireCodec::decode(&clamped).unwrap();
    assert_eq!(
        ControllerWireCodec::input_sequence_number(&decoded),
        Some(1)
    );
    assert_eq!(
        ControllerWireCodec::input_press_identifier(&decoded),
        Some(ControllerWireCodec::MAXIMUM_BUTTON_PRESS_IDENTIFIER)
    );

    let maximum = ControllerWireCodec::input_sequence_timestamp(u64::MAX, None);
    let bits = maximum as u64;
    assert_eq!(
        bits & ControllerWireCodec::MAXIMUM_BUTTON_SEQUENCE_NUMBER,
        ControllerWireCodec::MAXIMUM_BUTTON_SEQUENCE_NUMBER
    );
}

#[test]
fn noncompact_types_and_rich_compact_types_fall_back_to_json() {
    for message_type in ControllerMessageType::ALL {
        let mut message = ControllerMessage::new(message_type, 1);
        if message_type == ControllerMessageType::Button {
            message.button = Some(GameButton::Jump);
            message.state = Some(ButtonPressState::Down);
        }
        message.client_name = Some("forces JSON without changing the kind".into());
        let data = ControllerWireCodec::encode(&message).unwrap();
        assert_eq!(data.first(), Some(&b'{'), "{message_type:?}");
        assert_eq!(ControllerWireCodec::decode(&data).unwrap(), message);
    }

    let missing_state = ControllerMessage::new(ControllerMessageType::Button, 1);
    assert_eq!(
        ControllerWireCodec::encode(&missing_state).unwrap().first(),
        Some(&b'{')
    );

    let mut wrong_v2 = ControllerMessage::new(ControllerMessageType::Button, 1);
    wrong_v2.button = Some(GameButton::Jump);
    wrong_v2.state = Some(ButtonPressState::Down);
    wrong_v2.input_protocol_version = Some(1);
    wrong_v2.input_generation = Some(2);
    wrong_v2.input_sequence = Some(3);
    assert_eq!(
        ControllerWireCodec::encode(&wrong_v2).unwrap().first(),
        Some(&b'{')
    );
}

#[test]
fn every_swift_json_only_field_prevents_lossy_compact_encoding() {
    let base = || ControllerMessage::new(ControllerMessageType::Heartbeat, 1);
    let mut messages = Vec::new();

    let mut value = base();
    value.pairing_code = Some("1".into());
    messages.push(value);
    let mut value = base();
    value.message = Some("x".into());
    messages.push(value);
    let mut value = base();
    value.realtime_token = Some("x".into());
    messages.push(value);
    let mut value = base();
    value.auth_token = Some("x".into());
    messages.push(value);
    let mut value = base();
    value.server_id = Some("x".into());
    messages.push(value);
    let mut value = base();
    value.element_id = Some("729B071A-B5BB-4A91-B2A7-F644C61E5920".into());
    messages.push(value);
    let mut value = base();
    value.element_part = Some(KeypadElementInputPart::Primary);
    messages.push(value);
    let mut value = base();
    value.gamepad_customization = Some(json!({"future": true}));
    messages.push(value);
    let mut value = base();
    value.gamepad_profiles = Some(vec![json!({"future": true})]);
    messages.push(value);
    let mut value = base();
    value.skin_packages = Some(vec!["AA==".into()]);
    messages.push(value);
    let mut value = base();
    value.skin_reference = Some(json!({"identifier": "x"}));
    messages.push(value);
    let mut value = base();
    value.binding_presentations = Some(vec![json!({"future": true})]);
    messages.push(value);
    let mut value = base();
    value.gamepad_profile_id = Some("id".into());
    messages.push(value);
    let mut value = base();
    value.default_gamepad_profile_id = Some("id".into());
    messages.push(value);
    let mut value = base();
    value.capabilities = Some(vec![ControllerCapability::SkinPackages]);
    messages.push(value);
    let mut value = base();
    value.gamepad_profile_orientation_preference_mutation =
        Some(GamepadProfileOrientationPreference::Portrait);
    messages.push(value);
    let mut value = base();
    value.client_device_info = Some(json!({"future": true}));
    messages.push(value);
    let mut value = base();
    value.pointer_event = Some(ControllerPointerEventKind::Move);
    messages.push(value);
    let mut value = base();
    value.pointer_button = Some(ControllerPointerButton::Right);
    messages.push(value);
    let mut value = base();
    value.delta_x = Some(1.0);
    messages.push(value);
    let mut value = base();
    value.delta_y = Some(1.0);
    messages.push(value);
    let mut value = base();
    value.analog_stick = Some(VirtualGamepadStick::Left);
    messages.push(value);
    let mut value = base();
    value.analog_trigger = Some(VirtualGamepadTrigger::Right);
    messages.push(value);
    let mut value = base();
    value.analog_x = Some(1.0);
    messages.push(value);
    let mut value = base();
    value.analog_y = Some(1.0);
    messages.push(value);
    let mut value = base();
    value.analog_value = Some(1.0);
    messages.push(value);
    let mut value = base();
    value.analog_sequence = Some(1);
    messages.push(value);

    for message in messages {
        let data = ControllerWireCodec::encode(&message).unwrap();
        assert_eq!(data.first(), Some(&b'{'), "{message:?}");
        assert_eq!(ControllerWireCodec::decode(&data).unwrap(), message);
    }
}

#[test]
fn malformed_compact_candidates_use_json_fallback_instead_of_partial_decode() {
    let valid_v1 = ControllerWireCodec::encode_button(GameButton::Up, ButtonPressState::Down);
    let v1_mutations: &[(usize, u8)] = &[(0, b'X'), (1, b'X'), (2, 2), (3, 0), (12, 0), (13, 0)];
    for &(index, byte) in v1_mutations {
        let mut malformed = valid_v1.clone();
        malformed[index] = byte;
        assert!(matches!(
            ControllerWireCodec::decode(&malformed),
            Err(ControllerWireCodecError::Json(_))
        ));
    }

    let valid_v2 = ControllerWireCodec::encode_button_with_sequence(
        GameButton::Up,
        ButtonPressState::Down,
        1,
        Some(2),
        Some(3),
    );
    let v2_mutations: &[(usize, u8)] = &[
        (0, b'X'),
        (1, b'X'),
        (2, 1),
        (3, 2),
        (4, 0),
        (5, 0),
        (6, 2),
        (7, 1),
    ];
    for &(index, byte) in v2_mutations {
        let mut malformed = valid_v2.clone();
        malformed[index] = byte;
        assert!(matches!(
            ControllerWireCodec::decode(&malformed),
            Err(ControllerWireCodecError::Json(_))
        ));
    }
}

#[test]
fn nonbutton_v1_frames_tolerate_unknown_optional_button_and_state_codes() {
    let mut frame =
        ControllerWireCodec::encode(&ControllerMessage::new(ControllerMessageType::Heartbeat, 5))
            .unwrap();
    frame[12] = 0;
    frame[13] = 254;
    let decoded = ControllerWireCodec::decode(&frame).unwrap();
    assert_eq!(decoded.message_type, ControllerMessageType::Heartbeat);
    assert_eq!(decoded.button, None);
    assert_eq!(decoded.state, None);
}

#[test]
fn json_fallback_accepts_legacy_and_large_messages_up_to_eight_mib() {
    let json = br#"{"type":"element_input","elementID":"id","elementPart":"joystick_left","state":"down","timestamp":1,"inputProtocolVersion":2,"inputGeneration":3,"inputSequence":4,"pressIdentifier":5}"#;
    let decoded = ControllerWireCodec::decode(json).unwrap();
    assert_eq!(decoded.message_type, ControllerMessageType::ElementInput);
    assert_eq!(
        decoded.element_part,
        Some(KeypadElementInputPart::JoystickLeft)
    );
    assert_eq!(decoded.input_sequence, Some(4));

    let mut maximum = br#"{"type":"hello","timestamp":1}"#.to_vec();
    maximum.resize(ControllerWireCodec::MAXIMUM_INBOUND_PAYLOAD_SIZE, b' ');
    assert_eq!(
        ControllerWireCodec::decode(&maximum).unwrap().message_type,
        ControllerMessageType::Hello
    );

    maximum.push(b' ');
    match ControllerWireCodec::decode(&maximum) {
        Err(ControllerWireCodecError::InboundPayloadTooLarge {
            actual_bytes,
            maximum_bytes,
        }) => {
            assert_eq!(actual_bytes, 8 * 1024 * 1024 + 1);
            assert_eq!(maximum_bytes, 8 * 1024 * 1024);
        }
        other => panic!("expected payload-size error, got {other:?}"),
    }
}
