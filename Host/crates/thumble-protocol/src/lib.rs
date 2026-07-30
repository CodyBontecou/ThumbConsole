//! Portable Thumble controller protocol messages and wire encoding.
//!
//! The JSON model mirrors `Sources/Shared/ControllerProtocol.swift`. Complex
//! control-plane payloads intentionally remain [`serde_json::Value`] values so
//! a Rust host can forward fields introduced by newer clients without losing
//! them.

mod message;
mod wire;

pub use message::{
    ButtonPressState, ControllerCapability, ControllerMessage, ControllerMessageType,
    ControllerPointerButton, ControllerPointerEventKind, GameButton,
    GamepadProfileOrientationPreference, KeypadElementInputPart, VirtualGamepadStick,
    VirtualGamepadTrigger,
};
pub use wire::{ControllerWireCodec, ControllerWireCodecError};
