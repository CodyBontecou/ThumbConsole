//! Deterministic, platform-neutral Thumble host state and input handling.
//!
//! This crate owns no sockets, files, clocks, randomness, or OS input APIs.
//! Adapters feed decoded [`thumble_protocol::ControllerMessage`] values into
//! [`HostCore`] and execute the returned typed [`Effect`] values.

mod binding;
mod configuration;
mod controller_snapshot;
mod core;
mod resolver;
mod state;

pub use binding::{ButtonBindings, KeyBinding, KeyStroke, OutputBinding};
pub use configuration::{
    ConfigurationDocument, ConfigurationDocumentError, MAXIMUM_CONFIGURATION_BINDING_STROKES,
    MAXIMUM_CONFIGURATION_DOCUMENT_BYTES, MAXIMUM_CONFIGURATION_PROFILES,
};
pub use controller_snapshot::{
    ControllerCanvasSnapshot, ControllerControlBarItemSnapshot, ControllerElementOutputSnapshot,
    ControllerElementSnapshot, ControllerFrameSnapshot, ControllerGroupSnapshot,
    ControllerLayerSnapshot, ControllerLayoutQualityIssueSnapshot, ControllerLayoutQualitySnapshot,
    ControllerOrientation, ControllerProfileSnapshot, ControllerSemanticKeyStrokeSnapshot,
    ControllerSnapshot, ControllerSnapshotError, ControllerStyleAppearanceSnapshot,
    ControllerStyleColorSnapshot, ControllerStyleHapticSnapshot, ControllerStyleIconSnapshot,
    ControllerStyleShadowSnapshot, ControllerStyleSnapshot, ControllerStyleStateSnapshot,
    MAXIMUM_CONTROLLER_SNAPSHOT_ELEMENTS, MAXIMUM_CONTROLLER_SNAPSHOT_LAYERS,
    MAXIMUM_CONTROLLER_SNAPSHOT_LAYOUT_ISSUES, MAXIMUM_CONTROLLER_SNAPSHOT_STYLES,
};
pub use core::{
    ConnectionId, CoreError, CoreTime, Effect, HostCore, LocalControlError, StatusCounters,
    StatusSnapshot, TokenSource,
};
pub use state::{
    minimal_default_customization, minimal_default_profile, ConfigurationCommitRecord,
    PersistentState, StateError, TrustedClient, CURRENT_SCHEMA_VERSION, DEFAULT_PROFILE_ID,
    INITIAL_CONFIGURATION_REVISION, MAXIMUM_RECENT_CONFIGURATION_COMMITS,
};
