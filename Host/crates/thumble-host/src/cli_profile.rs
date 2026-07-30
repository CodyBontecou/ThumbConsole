use crate::authority::{
    prepare_configuration_commit, ConfigurationCommitError, ConfigurationCommitInput,
    PreparedConfigurationCommit,
};
use crate::bridge::ConfigurationBridge;
use crate::control::ConfigurationSaveSummary;
use crate::draft_operation::{
    is_supported_device_frame_id, ConfigurationControlBarItem, ConfigurationGamepadButton,
    ConfigurationOperation, ConfigurationOrientationPreference, ConfigurationOutputMode,
    ConfigurationVariant, ControlBarItemChanges, ControlBarMoveDirection, ControllerTemplate,
    CustomizationChanges, GamepadOutputEdit, GeneratedProfileDestination, GenerationPreset,
    KeyboardOutputEdit, LayerMoveDestination, LayoutRepairCanvas, LayoutRepairTarget,
    OrientationVariant, SemanticKeyStroke, SemanticModifier, StyleAppearance,
};
use crate::drafts::{ConfigurationDraft, DraftError, DraftStore};
use crate::paths::HostPaths;
use crate::storage;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::BTreeSet;
use thumble_core::{
    ConfigurationDocument, ControllerControlBarItemSnapshot, ControllerGroupSnapshot,
    ControllerLayerSnapshot, ControllerStyleSnapshot, KeyBinding, OutputBinding, PersistentState,
};
use thumble_protocol::{GameButton, KeypadElementInputPart};
use uuid::Uuid;

pub const CLI_PROFILE_SCHEMA_VERSION: u32 = 6;
const MAXIMUM_PROFILE_SELECTORS: usize = 256;
const MAXIMUM_SELECTOR_CHARACTERS: usize = 256;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CliProfileRequest {
    pub schema_version: u32,
    #[serde(
        rename = "invocationID",
        default,
        skip_serializing_if = "Option::is_none"
    )]
    pub invocation_id: Option<Uuid>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub expected_configuration_revision: Option<u64>,
    pub command: CliProfileCommand,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", deny_unknown_fields)]
pub enum CliProfileCommand {
    #[serde(rename = "authority.status")]
    AuthorityStatus,
    #[serde(rename = "profile.list")]
    List,
    #[serde(rename = "profile.select")]
    Select { target: ProfileSelector },
    #[serde(rename = "profile.default")]
    SetDefault { target: ProfileSelector },
    #[serde(rename = "profile.rename")]
    Rename {
        target: ProfileSelector,
        name: String,
    },
    #[serde(rename = "profile.duplicate")]
    Duplicate {
        #[serde(default, skip_serializing_if = "Option::is_none")]
        target: Option<ProfileSelector>,
        #[serde(default, skip_serializing_if = "Option::is_none")]
        name: Option<String>,
    },
    #[serde(rename = "profile.delete")]
    Delete { targets: Vec<ProfileSelector> },
    #[serde(rename = "profile.reset")]
    Reset {
        #[serde(default, skip_serializing_if = "Option::is_none")]
        target: Option<ProfileSelector>,
    },
    #[serde(rename = "profile.move")]
    Move {
        targets: Vec<ProfileSelector>,
        destination: ProfileMoveDestination,
    },
    #[serde(rename = "generation.generate")]
    GenerationGenerate {
        select: bool,
        #[serde(rename = "makeDefault")]
        make_default: bool,
    },
    #[serde(rename = "template.install")]
    TemplateInstall {
        template: ControllerTemplate,
        #[serde(default, skip_serializing_if = "Option::is_none")]
        name: Option<String>,
        select: bool,
        #[serde(rename = "makeDefault")]
        make_default: bool,
    },
    #[serde(rename = "customization.set")]
    CustomizationSet {
        target: ProfileSelector,
        variant: ConfigurationVariant,
        #[serde(default, skip_serializing_if = "Vec::is_empty")]
        changes: Vec<CustomizationChanges>,
        #[serde(rename = "frameID", default, skip_serializing_if = "Option::is_none")]
        frame_id: Option<String>,
    },
    #[serde(rename = "customization.fix")]
    CustomizationFix {
        profile: ProfileSelector,
        variant: ConfigurationVariant,
        target: Box<LayoutRepairTarget>,
        canvas: Box<LayoutRepairCanvas>,
        #[serde(rename = "includeLocked")]
        include_locked: bool,
    },
    #[serde(rename = "style.list")]
    StyleList { target: ProfileSelector },
    #[serde(rename = "style.show")]
    StyleShow {
        target: ProfileSelector,
        #[serde(rename = "styleID")]
        style_id: String,
    },
    #[serde(rename = "layer.list")]
    LayerList {
        target: ProfileSelector,
        #[serde(default = "primary_configuration_variant")]
        variant: ConfigurationVariant,
    },
    #[serde(rename = "layer.move")]
    LayerMove {
        target: ProfileSelector,
        #[serde(rename = "elementID")]
        element_id: String,
        destination: LayerMoveDestination,
    },
    #[serde(rename = "layer.forward")]
    LayerForward {
        target: ProfileSelector,
        #[serde(rename = "elementID")]
        element_id: String,
    },
    #[serde(rename = "layer.backward")]
    LayerBackward {
        target: ProfileSelector,
        #[serde(rename = "elementID")]
        element_id: String,
    },
    #[serde(rename = "layer.front")]
    LayerFront {
        target: ProfileSelector,
        #[serde(rename = "elementID")]
        element_id: String,
    },
    #[serde(rename = "layer.back")]
    LayerBack {
        target: ProfileSelector,
        #[serde(rename = "elementID")]
        element_id: String,
    },
    #[serde(rename = "group.list")]
    GroupList {
        target: ProfileSelector,
        variant: ConfigurationVariant,
    },
    #[serde(rename = "group.create")]
    GroupCreate {
        target: ProfileSelector,
        variant: ConfigurationVariant,
        name: String,
        #[serde(rename = "elementIDs")]
        element_ids: Vec<String>,
    },
    #[serde(rename = "group.rename")]
    GroupRename {
        target: ProfileSelector,
        variant: ConfigurationVariant,
        group: String,
        name: String,
    },
    #[serde(rename = "group.duplicate")]
    GroupDuplicate {
        target: ProfileSelector,
        variant: ConfigurationVariant,
        group: String,
        #[serde(default, skip_serializing_if = "Option::is_none")]
        name: Option<String>,
        #[serde(rename = "offsetX")]
        offset_x: f64,
        #[serde(rename = "offsetY")]
        offset_y: f64,
    },
    #[serde(rename = "group.ungroup")]
    GroupUngroup {
        target: ProfileSelector,
        variant: ConfigurationVariant,
        group: String,
    },
    #[serde(rename = "group.hide")]
    GroupHide {
        target: ProfileSelector,
        variant: ConfigurationVariant,
        group: String,
    },
    #[serde(rename = "group.show")]
    GroupShow {
        target: ProfileSelector,
        variant: ConfigurationVariant,
        group: String,
    },
    #[serde(rename = "group.lock")]
    GroupLock {
        target: ProfileSelector,
        variant: ConfigurationVariant,
        group: String,
    },
    #[serde(rename = "group.unlock")]
    GroupUnlock {
        target: ProfileSelector,
        variant: ConfigurationVariant,
        group: String,
    },
    #[serde(rename = "group.nudge")]
    GroupNudge {
        target: ProfileSelector,
        variant: ConfigurationVariant,
        group: String,
        #[serde(rename = "canvasFrameID")]
        canvas_frame_id: String,
        #[serde(rename = "deltaX")]
        delta_x: f64,
        #[serde(rename = "deltaY")]
        delta_y: f64,
    },
    #[serde(rename = "group.forward")]
    GroupForward {
        target: ProfileSelector,
        variant: ConfigurationVariant,
        group: String,
    },
    #[serde(rename = "group.backward")]
    GroupBackward {
        target: ProfileSelector,
        variant: ConfigurationVariant,
        group: String,
    },
    #[serde(rename = "group.front")]
    GroupFront {
        target: ProfileSelector,
        variant: ConfigurationVariant,
        group: String,
    },
    #[serde(rename = "group.back")]
    GroupBack {
        target: ProfileSelector,
        variant: ConfigurationVariant,
        group: String,
    },
    #[serde(rename = "style.create")]
    StyleCreate {
        target: ProfileSelector,
        #[serde(rename = "styleID")]
        style_id: String,
        name: String,
        appearance: Box<StyleAppearance>,
    },
    #[serde(rename = "style.rename")]
    StyleRename {
        target: ProfileSelector,
        #[serde(rename = "styleID")]
        style_id: String,
        name: String,
    },
    #[serde(rename = "style.apply")]
    StyleApply {
        target: ProfileSelector,
        variant: ConfigurationVariant,
        #[serde(rename = "styleID")]
        style_id: String,
        #[serde(rename = "elementID")]
        element_id: String,
    },
    #[serde(rename = "style.detach")]
    StyleDetach {
        target: ProfileSelector,
        variant: ConfigurationVariant,
        #[serde(rename = "elementID")]
        element_id: String,
    },
    #[serde(rename = "style.delete")]
    StyleDelete {
        target: ProfileSelector,
        #[serde(rename = "styleID")]
        style_id: String,
    },
    #[serde(rename = "orientation.get")]
    OrientationGet { target: ProfileSelector },
    #[serde(rename = "orientation.set")]
    OrientationSet {
        target: ProfileSelector,
        preference: ConfigurationOrientationPreference,
    },
    #[serde(rename = "orientation.copy")]
    OrientationCopy {
        target: ProfileSelector,
        source: OrientationVariant,
        destination: OrientationVariant,
        #[serde(rename = "automaticallyArrange")]
        automatically_arrange: bool,
    },
    #[serde(rename = "binding.list")]
    BindingList { target: ProfileSelector },
    #[serde(rename = "binding.display")]
    BindingDisplay { target: ProfileSelector },
    #[serde(rename = "binding.set")]
    BindingSet {
        target: ProfileSelector,
        button: GameButton,
        sequence: Vec<SemanticKeyStroke>,
    },
    #[serde(rename = "binding.clear")]
    BindingClear {
        target: ProfileSelector,
        button: GameButton,
    },
    #[serde(rename = "binding.reset")]
    BindingReset {
        target: ProfileSelector,
        button: GameButton,
    },
    #[serde(rename = "binding.reset-all")]
    BindingResetAll { target: ProfileSelector },
    #[serde(rename = "output.list")]
    OutputList { target: ProfileSelector },
    #[serde(rename = "output.mode.get")]
    OutputModeGet { target: ProfileSelector },
    #[serde(rename = "output.mode")]
    OutputMode {
        target: ProfileSelector,
        mode: ConfigurationOutputMode,
    },
    #[serde(rename = "output.set")]
    OutputSet {
        target: ProfileSelector,
        button: GameButton,
        #[serde(rename = "keyboardEdit")]
        keyboard_edit: KeyboardOutputEdit,
        #[serde(rename = "gamepadEdit")]
        gamepad_edit: GamepadOutputEdit,
    },
    #[serde(rename = "output.reset")]
    OutputReset {
        target: ProfileSelector,
        button: GameButton,
    },
    #[serde(rename = "output.reset-all")]
    OutputResetAll { target: ProfileSelector },
    #[serde(rename = "device.get")]
    DeviceGet {
        target: ProfileSelector,
        variant: ConfigurationVariant,
    },
    #[serde(rename = "device.set")]
    DeviceSet {
        target: ProfileSelector,
        variant: ConfigurationVariant,
        #[serde(rename = "frameID")]
        frame_id: String,
    },
    #[serde(rename = "control-bar.list")]
    ControlBarList {
        target: ProfileSelector,
        variant: ConfigurationVariant,
    },
    #[serde(rename = "control-bar.set")]
    ControlBarSet {
        target: ProfileSelector,
        variant: ConfigurationVariant,
        items: Vec<ConfigurationControlBarItem>,
    },
    #[serde(rename = "control-bar.add")]
    ControlBarAdd {
        target: ProfileSelector,
        variant: ConfigurationVariant,
        item: ConfigurationControlBarItem,
    },
    #[serde(rename = "control-bar.remove")]
    ControlBarRemove {
        target: ProfileSelector,
        variant: ConfigurationVariant,
        item: ConfigurationControlBarItem,
    },
    #[serde(rename = "control-bar.move")]
    ControlBarMove {
        target: ProfileSelector,
        variant: ConfigurationVariant,
        item: ConfigurationControlBarItem,
        direction: ControlBarMoveDirection,
    },
    #[serde(rename = "control-bar.reset")]
    ControlBarReset {
        target: ProfileSelector,
        variant: ConfigurationVariant,
    },
    #[serde(rename = "control-bar.item.show")]
    ControlBarItemShow {
        target: ProfileSelector,
        variant: ConfigurationVariant,
        item: ConfigurationControlBarItem,
    },
    #[serde(rename = "control-bar.item.set")]
    ControlBarItemSet {
        target: ProfileSelector,
        variant: ConfigurationVariant,
        item: ConfigurationControlBarItem,
        changes: Box<ControlBarItemChanges>,
    },
    #[serde(rename = "control-bar.item.reset")]
    ControlBarItemReset {
        target: ProfileSelector,
        variant: ConfigurationVariant,
        item: ConfigurationControlBarItem,
    },
}

fn primary_configuration_variant() -> ConfigurationVariant {
    ConfigurationVariant::Primary
}

impl CliProfileCommand {
    fn is_binding_output_read(&self) -> bool {
        matches!(
            self,
            Self::BindingList { .. }
                | Self::BindingDisplay { .. }
                | Self::OutputList { .. }
                | Self::OutputModeGet { .. }
                | Self::DeviceGet { .. }
                | Self::ControlBarList { .. }
                | Self::ControlBarItemShow { .. }
                | Self::StyleList { .. }
                | Self::StyleShow { .. }
                | Self::LayerList { .. }
                | Self::GroupList { .. }
        )
    }

    fn kind(&self) -> &'static str {
        match self {
            Self::AuthorityStatus => "authority.status",
            Self::List => "profile.list",
            Self::Select { .. } => "profile.select",
            Self::SetDefault { .. } => "profile.default",
            Self::Rename { .. } => "profile.rename",
            Self::Duplicate { .. } => "profile.duplicate",
            Self::Delete { .. } => "profile.delete",
            Self::Reset { .. } => "profile.reset",
            Self::Move { .. } => "profile.move",
            Self::GenerationGenerate { .. } => "generation.generate",
            Self::TemplateInstall { .. } => "template.install",
            Self::CustomizationSet { .. } => "customization.set",
            Self::CustomizationFix { .. } => "customization.fix",
            Self::StyleList { .. } => "style.list",
            Self::StyleShow { .. } => "style.show",
            Self::LayerList { .. } => "layer.list",
            Self::LayerMove { .. } => "layer.move",
            Self::LayerForward { .. } => "layer.forward",
            Self::LayerBackward { .. } => "layer.backward",
            Self::LayerFront { .. } => "layer.front",
            Self::LayerBack { .. } => "layer.back",
            Self::GroupList { .. } => "group.list",
            Self::GroupCreate { .. } => "group.create",
            Self::GroupRename { .. } => "group.rename",
            Self::GroupDuplicate { .. } => "group.duplicate",
            Self::GroupUngroup { .. } => "group.ungroup",
            Self::GroupHide { .. } => "group.hide",
            Self::GroupShow { .. } => "group.show",
            Self::GroupLock { .. } => "group.lock",
            Self::GroupUnlock { .. } => "group.unlock",
            Self::GroupNudge { .. } => "group.nudge",
            Self::GroupForward { .. } => "group.forward",
            Self::GroupBackward { .. } => "group.backward",
            Self::GroupFront { .. } => "group.front",
            Self::GroupBack { .. } => "group.back",
            Self::StyleCreate { .. } => "style.create",
            Self::StyleRename { .. } => "style.rename",
            Self::StyleApply { .. } => "style.apply",
            Self::StyleDetach { .. } => "style.detach",
            Self::StyleDelete { .. } => "style.delete",
            Self::OrientationGet { .. } => "orientation.get",
            Self::OrientationSet { .. } => "orientation.set",
            Self::OrientationCopy { .. } => "orientation.copy",
            Self::BindingList { .. } => "binding.list",
            Self::BindingDisplay { .. } => "binding.display",
            Self::BindingSet { .. } => "binding.set",
            Self::BindingClear { .. } => "binding.clear",
            Self::BindingReset { .. } => "binding.reset",
            Self::BindingResetAll { .. } => "binding.reset-all",
            Self::OutputList { .. } => "output.list",
            Self::OutputModeGet { .. } => "output.mode.get",
            Self::OutputMode { .. } => "output.mode",
            Self::OutputSet { .. } => "output.set",
            Self::OutputReset { .. } => "output.reset",
            Self::OutputResetAll { .. } => "output.reset-all",
            Self::DeviceGet { .. } => "device.get",
            Self::DeviceSet { .. } => "device.set",
            Self::ControlBarList { .. } => "control-bar.list",
            Self::ControlBarSet { .. } => "control-bar.set",
            Self::ControlBarAdd { .. } => "control-bar.add",
            Self::ControlBarRemove { .. } => "control-bar.remove",
            Self::ControlBarMove { .. } => "control-bar.move",
            Self::ControlBarReset { .. } => "control-bar.reset",
            Self::ControlBarItemShow { .. } => "control-bar.item.show",
            Self::ControlBarItemSet { .. } => "control-bar.item.set",
            Self::ControlBarItemReset { .. } => "control-bar.item.reset",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", deny_unknown_fields)]
pub enum ProfileSelector {
    #[serde(rename = "active")]
    Active,
    #[serde(rename = "default")]
    Default,
    #[serde(rename = "id")]
    Id {
        #[serde(rename = "profileID")]
        profile_id: Uuid,
    },
    #[serde(rename = "name")]
    Name { name: String },
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", deny_unknown_fields)]
pub enum ProfileMoveDestination {
    #[serde(rename = "index")]
    Index { index: usize },
    #[serde(rename = "before")]
    Before { profile: ProfileSelector },
    #[serde(rename = "after")]
    After { profile: ProfileSelector },
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CliProfileSummary {
    #[serde(rename = "profileID")]
    pub profile_id: Uuid,
    pub name: String,
    pub active: bool,
    pub default: bool,
    pub index: usize,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CliProfileCatalog {
    pub configuration_revision: u64,
    pub profiles: Vec<CliProfileSummary>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CliOrientationSummary {
    pub configuration_revision: u64,
    #[serde(rename = "profileID")]
    pub profile_id: Uuid,
    pub profile_name: String,
    pub orientation: ConfigurationOrientationPreference,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum CliProjectionKind {
    BindingList,
    BindingDisplay,
    OutputList,
    OutputMode,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CliSemanticOutput {
    pub keyboard: Vec<SemanticKeyStroke>,
    pub gamepad_buttons: Vec<ConfigurationGamepadButton>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CliBindingOutputRow {
    pub button: GameButton,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub output: Option<CliSemanticOutput>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CliBindingDisplayEntry {
    #[serde(rename = "elementID")]
    pub element_id: Uuid,
    pub part: KeypadElementInputPart,
    pub output: CliSemanticOutput,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CliBindingDisplayGroup {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub orientation: Option<OrientationVariant>,
    pub entries: Vec<CliBindingDisplayEntry>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CliBindingOutputProjection {
    pub kind: CliProjectionKind,
    pub configuration_revision: u64,
    #[serde(rename = "profileID")]
    pub profile_id: Uuid,
    pub profile_name: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub output_mode: Option<ConfigurationOutputMode>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub rows: Option<Vec<CliBindingOutputRow>>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub display_groups: Option<Vec<CliBindingDisplayGroup>>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CliDeviceProjection {
    pub configuration_revision: u64,
    #[serde(rename = "profileID")]
    pub profile_id: Uuid,
    pub profile_name: String,
    pub variant: ConfigurationVariant,
    #[serde(rename = "frameID", default, skip_serializing_if = "Option::is_none")]
    pub frame_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub custom_width: Option<u16>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub custom_height: Option<u16>,
    pub frame_orientation: OrientationVariant,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CliControlBarItemSummary {
    pub order: usize,
    pub item: ConfigurationControlBarItem,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CliControlBarProjection {
    pub configuration_revision: u64,
    #[serde(rename = "profileID")]
    pub profile_id: Uuid,
    pub profile_name: String,
    pub variant: ConfigurationVariant,
    pub items: Vec<CliControlBarItemSummary>,
}

#[derive(Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CliStyleProjection {
    pub configuration_revision: u64,
    #[serde(rename = "profileID")]
    pub profile_id: Uuid,
    pub profile_name: String,
    pub styles: Vec<ControllerStyleSnapshot>,
}

impl std::fmt::Debug for CliStyleProjection {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        formatter
            .debug_struct("CliStyleProjection")
            .field("configuration_revision", &self.configuration_revision)
            .field("profile_id", &self.profile_id)
            .field("style_count", &self.styles.len())
            .finish_non_exhaustive()
    }
}

#[derive(Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CliLayerProjection {
    pub configuration_revision: u64,
    #[serde(rename = "profileID")]
    pub profile_id: Uuid,
    pub profile_name: String,
    pub variant: ConfigurationVariant,
    pub layers: Vec<ControllerLayerSnapshot>,
}

impl std::fmt::Debug for CliLayerProjection {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        formatter
            .debug_struct("CliLayerProjection")
            .field("configuration_revision", &self.configuration_revision)
            .field("profile_id", &self.profile_id)
            .field("layer_count", &self.layers.len())
            .finish_non_exhaustive()
    }
}

#[derive(Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CliGroupProjection {
    pub configuration_revision: u64,
    #[serde(rename = "profileID")]
    pub profile_id: Uuid,
    pub profile_name: String,
    pub variant: ConfigurationVariant,
    pub groups: Vec<ControllerGroupSnapshot>,
}

impl std::fmt::Debug for CliGroupProjection {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        formatter
            .debug_struct("CliGroupProjection")
            .field("configuration_revision", &self.configuration_revision)
            .field("profile_id", &self.profile_id)
            .field("variant", &self.variant)
            .field("group_count", &self.groups.len())
            .finish_non_exhaustive()
    }
}

#[derive(Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CliControlBarItemProjection {
    pub configuration_revision: u64,
    #[serde(rename = "profileID")]
    pub profile_id: Uuid,
    pub profile_name: String,
    pub variant: ConfigurationVariant,
    pub order: usize,
    pub item: ConfigurationControlBarItem,
    pub appearance: ControllerControlBarItemSnapshot,
}

impl std::fmt::Debug for CliControlBarItemProjection {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        formatter
            .debug_struct("CliControlBarItemProjection")
            .field("configuration_revision", &self.configuration_revision)
            .field("profile_id", &self.profile_id)
            .field("variant", &self.variant)
            .field("order", &self.order)
            .field("item", &self.item)
            .field(
                "unsupported_content_omitted",
                &self.appearance.unsupported_content_omitted,
            )
            .finish_non_exhaustive()
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CliProfileOutcome {
    pub operation: String,
    pub profile_names: Vec<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub destination: Option<String>,
    pub removed_every_profile: bool,
    pub changed: bool,
    pub configuration_revision: u64,
    #[serde(rename = "draftID")]
    pub draft_id: Uuid,
    #[serde(rename = "commitID")]
    pub commit_id: Uuid,
    pub idempotent_replay: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CliProfileError {
    pub code: String,
    pub message: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub expected_revision: Option<u64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub actual_revision: Option<u64>,
    #[serde(default, skip_serializing_if = "Option::is_none", rename = "draftID")]
    pub draft_id: Option<Uuid>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub draft_revision: Option<u64>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub conflict_paths: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CliProfileResponse {
    pub schema_version: u32,
    pub ok: bool,
    #[serde(rename = "invocationID")]
    pub invocation_id: Uuid,
    pub authority_mode: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub authority_present: Option<bool>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub catalog: Option<CliProfileCatalog>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub orientation: Option<CliOrientationSummary>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub projection: Option<CliBindingOutputProjection>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub control_bar: Option<CliControlBarProjection>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub control_bar_item: Option<CliControlBarItemProjection>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub device: Option<CliDeviceProjection>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub styles: Option<CliStyleProjection>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub layers: Option<CliLayerProjection>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub groups: Option<CliGroupProjection>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub outcome: Option<CliProfileOutcome>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub error: Option<CliProfileError>,
}

impl CliProfileResponse {
    pub fn authority_status(invocation_id: Uuid, present: bool) -> Self {
        Self {
            schema_version: CLI_PROFILE_SCHEMA_VERSION,
            ok: true,
            invocation_id,
            authority_mode: "status".to_owned(),
            authority_present: Some(present),
            catalog: None,
            orientation: None,
            projection: None,
            control_bar: None,
            control_bar_item: None,
            device: None,
            styles: None,
            layers: None,
            groups: None,
            outcome: None,
            error: None,
        }
    }

    pub fn transport_failure(
        invocation_id: Uuid,
        authority_mode: &str,
        code: &str,
        message: &str,
    ) -> Self {
        Self::failure(
            invocation_id,
            authority_mode,
            TransactionFailure::new(code, message),
        )
    }

    fn success(invocation_id: Uuid, authority_mode: &str, result: TransactionResult) -> Self {
        let (
            catalog,
            orientation,
            projection,
            control_bar,
            control_bar_item,
            device,
            styles,
            layers,
            groups,
            outcome,
        ) = result;
        Self {
            schema_version: CLI_PROFILE_SCHEMA_VERSION,
            ok: true,
            invocation_id,
            authority_mode: authority_mode.to_owned(),
            authority_present: None,
            catalog,
            orientation,
            projection,
            control_bar,
            control_bar_item,
            device,
            styles,
            layers,
            groups,
            outcome,
            error: None,
        }
    }

    fn failure(invocation_id: Uuid, authority_mode: &str, failure: TransactionFailure) -> Self {
        Self {
            schema_version: CLI_PROFILE_SCHEMA_VERSION,
            ok: false,
            invocation_id,
            authority_mode: authority_mode.to_owned(),
            authority_present: None,
            catalog: None,
            orientation: None,
            projection: None,
            control_bar: None,
            control_bar_item: None,
            device: None,
            styles: None,
            layers: None,
            groups: None,
            outcome: None,
            error: Some(*failure.error),
        }
    }
}

#[derive(Debug)]
pub(crate) struct TransactionFailure {
    error: Box<CliProfileError>,
}

impl TransactionFailure {
    pub(crate) fn new(code: &str, message: &str) -> Self {
        Self {
            error: Box::new(CliProfileError {
                code: code.to_owned(),
                message: message.to_owned(),
                expected_revision: None,
                actual_revision: None,
                draft_id: None,
                draft_revision: None,
                conflict_paths: Vec::new(),
            }),
        }
    }

    pub(crate) fn with_revision(mut self, expected: u64, actual: u64) -> Self {
        self.error.expected_revision = Some(expected);
        self.error.actual_revision = Some(actual);
        self
    }

    fn with_draft(mut self, draft: &ConfigurationDraft) -> Self {
        self.error.draft_id = Uuid::parse_str(&draft.draft_id).ok();
        self.error.draft_revision = Some(draft.draft_revision);
        self
    }
}

type TransactionResult = (
    Option<CliProfileCatalog>,
    Option<CliOrientationSummary>,
    Option<CliBindingOutputProjection>,
    Option<CliControlBarProjection>,
    Option<CliControlBarItemProjection>,
    Option<CliDeviceProjection>,
    Option<CliStyleProjection>,
    Option<CliLayerProjection>,
    Option<CliGroupProjection>,
    Option<CliProfileOutcome>,
);

#[derive(Debug)]
struct PlannedTransaction {
    operations: Vec<ConfigurationOperation>,
    profile_names: Vec<String>,
    destination: Option<String>,
    removed_every_profile: bool,
}

pub(crate) fn execute_profile_transaction<F>(
    paths: &HostPaths,
    state: &PersistentState,
    request: &CliProfileRequest,
    authority_mode: &str,
    mut save: F,
) -> CliProfileResponse
where
    F: FnMut(&str, u64, u64, &str, &str) -> Result<ConfigurationSaveSummary, TransactionFailure>,
{
    let invocation_id = request.invocation_id.unwrap_or_else(Uuid::new_v4);
    let result = (|| -> Result<TransactionResult, TransactionFailure> {
        validate_request(request)?;
        validate_request_credentials(&request.command, state)?;
        let catalog = catalog_from_state(state)?;
        if matches!(request.command, CliProfileCommand::List) {
            return Ok((
                Some(catalog),
                None,
                None,
                None,
                None,
                None,
                None,
                None,
                None,
                None,
            ));
        }
        if let CliProfileCommand::OrientationGet { target } = &request.command {
            let orientation = orientation_summary_from_state(state, target, &catalog)?;
            return Ok((
                None,
                Some(orientation),
                None,
                None,
                None,
                None,
                None,
                None,
                None,
                None,
            ));
        }
        if let CliProfileCommand::ControlBarList { target, variant } = &request.command {
            let projection = control_bar_projection_from_state(state, target, *variant, &catalog)?;
            return Ok((
                None,
                None,
                None,
                Some(projection),
                None,
                None,
                None,
                None,
                None,
                None,
            ));
        }
        if let CliProfileCommand::ControlBarItemShow {
            target,
            variant,
            item,
        } = &request.command
        {
            let projection =
                control_bar_item_projection_from_state(state, target, *variant, *item, &catalog)?;
            return Ok((
                None,
                None,
                None,
                None,
                Some(projection),
                None,
                None,
                None,
                None,
                None,
            ));
        }
        if let CliProfileCommand::DeviceGet { target, variant } = &request.command {
            let projection = device_projection_from_state(state, target, *variant, &catalog)?;
            return Ok((
                None,
                None,
                None,
                None,
                None,
                Some(projection),
                None,
                None,
                None,
                None,
            ));
        }
        match &request.command {
            CliProfileCommand::StyleList { target } => {
                let projection = style_projection_from_state(state, target, None, &catalog)?;
                return Ok((
                    None,
                    None,
                    None,
                    None,
                    None,
                    None,
                    Some(projection),
                    None,
                    None,
                    None,
                ));
            }
            CliProfileCommand::StyleShow { target, style_id } => {
                let projection =
                    style_projection_from_state(state, target, Some(style_id), &catalog)?;
                return Ok((
                    None,
                    None,
                    None,
                    None,
                    None,
                    None,
                    Some(projection),
                    None,
                    None,
                    None,
                ));
            }
            CliProfileCommand::LayerList { target, variant } => {
                let projection = layer_projection_from_state(state, target, *variant, &catalog)?;
                return Ok((
                    None,
                    None,
                    None,
                    None,
                    None,
                    None,
                    None,
                    Some(projection),
                    None,
                    None,
                ));
            }
            CliProfileCommand::GroupList { target, variant } => {
                let projection = group_projection_from_state(state, target, *variant, &catalog)?;
                return Ok((
                    None,
                    None,
                    None,
                    None,
                    None,
                    None,
                    None,
                    None,
                    Some(projection),
                    None,
                ));
            }
            _ => {}
        }
        if request.command.is_binding_output_read() {
            let projection =
                binding_output_projection_from_state(state, &request.command, &catalog)?;
            return Ok((
                None,
                None,
                Some(projection),
                None,
                None,
                None,
                None,
                None,
                None,
                None,
            ));
        }
        if matches!(request.command, CliProfileCommand::AuthorityStatus) {
            return Err(TransactionFailure::new(
                "invalid_request",
                "authority status must be handled before authority routing",
            ));
        }

        let draft_id = deterministic_uuid(invocation_id, "configuration-draft");
        let commit_id = deterministic_uuid(invocation_id, "configuration-commit");
        let request_digest = request_digest(&request.command)?;
        if let Some(record) = state.recent_configuration_commit(&commit_id.hyphenated().to_string())
        {
            if record.draft_id != draft_id.hyphenated().to_string()
                || record.client_request_digest.as_deref() != Some(request_digest.as_str())
            {
                return Err(TransactionFailure::new(
                    "commit_id_conflict",
                    "invocation ID was already used for different profile transaction content",
                ));
            }
            let outcome = CliProfileOutcome {
                operation: request.command.kind().to_owned(),
                profile_names: replay_profile_names(&request.command, &catalog, invocation_id),
                destination: replay_destination(&request.command),
                removed_every_profile: replay_removed_every_profile(
                    &request.command,
                    &catalog,
                    invocation_id,
                ),
                changed: record.result_configuration_revision != record.base_configuration_revision,
                configuration_revision: record.result_configuration_revision,
                draft_id,
                commit_id,
                idempotent_replay: true,
            };
            return Ok((
                None,
                None,
                None,
                None,
                None,
                None,
                None,
                None,
                None,
                Some(outcome),
            ));
        }
        if let Some(expected) = request.expected_configuration_revision {
            if expected != catalog.configuration_revision {
                return Err(TransactionFailure::new(
                    "configuration_revision_conflict",
                    "authoritative configuration changed after the revision-tagged read",
                )
                .with_revision(expected, catalog.configuration_revision));
            }
        }

        let plan = plan_transaction(&request.command, &catalog, &state.profiles, invocation_id)?;
        let store = DraftStore::new(paths);
        let draft_id_text = draft_id.hyphenated().to_string();
        let mut draft = store
            .begin_with_id(
                state,
                catalog.configuration_revision,
                &draft_id_text,
                now_millis(),
            )
            .map_err(|error| {
                let failure = draft_failure(error);
                match store.get(&draft_id_text, now_millis()) {
                    Ok(existing) => failure.with_draft(&existing),
                    Err(_) => failure,
                }
            })?;

        for (ordinal, operation) in plan.operations.iter().enumerate() {
            let operation_id = deterministic_uuid(
                invocation_id,
                &format!("{}:operation:{ordinal}", request.command.kind()),
            )
            .hyphenated()
            .to_string();
            let operation_digest =
                DraftStore::operation_digest(operation).map_err(draft_failure)?;
            if let Some(existing) = draft
                .operation_log
                .iter()
                .find(|record| record.operation_id == operation_id)
            {
                if existing.operation_digest != operation_digest {
                    return Err(TransactionFailure::new(
                        "operation_id_conflict",
                        "deterministic operation ID was reused with different content",
                    )
                    .with_draft(&draft));
                }
                continue;
            }
            let edited = if operation.requires_bridge() {
                let bridge = ConfigurationBridge::discover().map_err(|_| {
                    TransactionFailure::new(
                        "configuration_bridge_failed",
                        "required exact-sibling configuration bridge is unavailable or failed validation",
                    )
                    .with_draft(&draft)
                })?;
                store.edit_with(
                    &draft.draft_id,
                    draft.draft_revision,
                    &operation_id,
                    operation,
                    now_millis(),
                    |document| {
                        bridge
                            .apply(document, operation, now_millis())
                            .map_err(DraftError::Bridge)
                    },
                )
            } else {
                store.edit(
                    &draft.draft_id,
                    draft.draft_revision,
                    &operation_id,
                    operation,
                    now_millis(),
                )
            }
            .map_err(|error| draft_failure(error).with_draft(&draft))?;
            draft = edited.draft;
        }

        draft.working_document.validate().map_err(|_| {
            TransactionFailure::new(
                "invalid_configuration",
                "profile transaction produced an invalid configuration",
            )
            .with_draft(&draft)
        })?;
        // Validate the complete post-edit safe summary before the only save so
        // no response-shaping failure can make a successful commit ambiguous.
        let _ = catalog_from_document(
            &draft.working_document,
            catalog.configuration_revision,
            state,
        )?;
        let summary = save(
            &draft.draft_id,
            draft.draft_revision,
            catalog.configuration_revision,
            &commit_id.hyphenated().to_string(),
            &request_digest,
        )
        .map_err(|failure| {
            let mut error = *failure.error;
            error.draft_id = Some(draft_id);
            error.draft_revision = Some(draft.draft_revision);
            TransactionFailure {
                error: Box::new(error),
            }
        })?;
        let outcome = CliProfileOutcome {
            operation: request.command.kind().to_owned(),
            profile_names: plan.profile_names,
            destination: plan.destination,
            removed_every_profile: plan.removed_every_profile,
            changed: summary.changed,
            configuration_revision: summary.configuration_revision,
            draft_id,
            commit_id,
            idempotent_replay: summary.idempotent_replay,
        };
        Ok((
            None,
            None,
            None,
            None,
            None,
            None,
            None,
            None,
            None,
            Some(outcome),
        ))
    })();

    match result {
        Ok(result) => CliProfileResponse::success(invocation_id, authority_mode, result),
        Err(failure) => CliProfileResponse::failure(invocation_id, authority_mode, failure),
    }
}

pub fn execute_offline_authority(
    paths: &HostPaths,
    request: &CliProfileRequest,
) -> CliProfileResponse {
    let invocation_id = request.invocation_id.unwrap_or_else(Uuid::new_v4);
    let state = match storage::load_or_migrate(paths) {
        Ok(state) => state,
        Err(_) => {
            return CliProfileResponse::transport_failure(
                invocation_id,
                "offline",
                "state_load_failed",
                "Rust authority state could not be loaded or migrated",
            )
        }
    };
    execute_profile_transaction(
        paths,
        &state,
        request,
        "offline",
        |draft_id, draft_revision, base_revision, commit_id, request_digest| {
            let store = DraftStore::new(paths);
            let PreparedConfigurationCommit { candidate, summary } = prepare_configuration_commit(
                &state,
                &store,
                ConfigurationCommitInput {
                    draft_id,
                    expected_draft_revision: draft_revision,
                    expected_configuration_revision: base_revision,
                    commit_id,
                    client_request_digest: Some(request_digest),
                    now_millis: now_millis(),
                },
            )
            .map_err(commit_failure)?;
            if let Some(candidate) = candidate {
                storage::save_atomic(&paths.state_file, &candidate).map_err(|_| {
                    TransactionFailure::new(
                        "configuration_persistence_failed",
                        "authoritative configuration could not be persisted atomically",
                    )
                })?;
                let _ = store.discard(draft_id, draft_revision, now_millis());
            }
            Ok(summary)
        },
    )
}

pub(crate) fn commit_failure(error: ConfigurationCommitError) -> TransactionFailure {
    match error {
        ConfigurationCommitError::InvalidCommitIdentity => TransactionFailure::new(
            "invalid_commit_identity",
            "draft and commit identities must be exact UUIDs",
        ),
        ConfigurationCommitError::InvalidRequestDigest => TransactionFailure::new(
            "invalid_request_digest",
            "profile transaction digest is invalid",
        ),
        ConfigurationCommitError::CommitIdConflict => TransactionFailure::new(
            "commit_id_conflict",
            "commit ID was already used for different transaction content",
        ),
        ConfigurationCommitError::ConfigurationRevisionConflict { expected, actual } => {
            TransactionFailure::new(
                "configuration_revision_conflict",
                "authoritative configuration changed; retry with the same invocation ID to resume",
            )
            .with_revision(expected, actual)
        }
        ConfigurationCommitError::Draft(error) => draft_failure(error),
        ConfigurationCommitError::InvalidConfiguration(_) => TransactionFailure::new(
            "invalid_configuration",
            "profile transaction produced an invalid configuration",
        ),
    }
}

fn validate_request_credentials(
    command: &CliProfileCommand,
    state: &PersistentState,
) -> Result<(), TransactionFailure> {
    let encoded = serde_json::to_vec(command).map_err(|_| {
        TransactionFailure::new(
            "invalid_request",
            "CLI profile request could not be encoded",
        )
    })?;
    if state.trusted_clients.keys().any(|token| {
        !token.is_empty()
            && encoded
                .windows(token.len())
                .any(|window| window == token.as_bytes())
    }) {
        return Err(TransactionFailure::new(
            "unsafe_profile_request",
            "profile request overlaps credential material and was rejected",
        ));
    }
    Ok(())
}

fn validate_request(request: &CliProfileRequest) -> Result<(), TransactionFailure> {
    if request.schema_version != CLI_PROFILE_SCHEMA_VERSION {
        return Err(TransactionFailure::new(
            "unsupported_schema_version",
            "CLI profile helper schema version is unsupported",
        ));
    }
    let encoded = serde_json::to_vec(request).map_err(|_| {
        TransactionFailure::new(
            "invalid_request",
            "CLI profile request could not be encoded",
        )
    })?;
    if encoded.len() > 64 * 1024 {
        return Err(TransactionFailure::new(
            "request_too_large",
            "CLI profile request exceeds its size limit",
        ));
    }
    if request.expected_configuration_revision.is_some()
        && matches!(
            &request.command,
            CliProfileCommand::AuthorityStatus
                | CliProfileCommand::List
                | CliProfileCommand::OrientationGet { .. }
                | CliProfileCommand::BindingList { .. }
                | CliProfileCommand::BindingDisplay { .. }
                | CliProfileCommand::OutputList { .. }
                | CliProfileCommand::OutputModeGet { .. }
                | CliProfileCommand::DeviceGet { .. }
                | CliProfileCommand::ControlBarList { .. }
                | CliProfileCommand::ControlBarItemShow { .. }
                | CliProfileCommand::StyleList { .. }
                | CliProfileCommand::StyleShow { .. }
                | CliProfileCommand::LayerList { .. }
                | CliProfileCommand::GroupList { .. }
        )
    {
        return Err(TransactionFailure::new(
            "invalid_request",
            "expected configuration revision is accepted only for mutations",
        ));
    }
    match &request.command {
        CliProfileCommand::Rename { name, .. } => validate_name(name)?,
        CliProfileCommand::Duplicate {
            name: Some(name), ..
        }
        | CliProfileCommand::TemplateInstall {
            name: Some(name), ..
        } => validate_name(name)?,
        CliProfileCommand::Delete { targets } | CliProfileCommand::Move { targets, .. } => {
            if targets.is_empty() || targets.len() > MAXIMUM_PROFILE_SELECTORS {
                return Err(TransactionFailure::new(
                    "invalid_profile_selection",
                    "profile selection count is invalid",
                ));
            }
        }
        CliProfileCommand::DeviceSet { frame_id, .. }
            if !is_supported_device_frame_id(frame_id) =>
        {
            return Err(TransactionFailure::new(
                "unsupported_device_frame",
                "device frame is outside the checked-in safe catalog",
            ));
        }
        CliProfileCommand::CustomizationSet {
            changes, frame_id, ..
        } => {
            if changes.len() > 5 || (changes.is_empty() && frame_id.is_none()) {
                return Err(TransactionFailure::new(
                    "invalid_customization_changes",
                    "customization request must contain one to five bounded changes",
                ));
            }
            if frame_id
                .as_deref()
                .is_some_and(|frame_id| !is_supported_device_frame_id(frame_id))
            {
                return Err(TransactionFailure::new(
                    "unsupported_device_frame",
                    "device frame is outside the checked-in safe catalog",
                ));
            }
            for changes in changes {
                ConfigurationOperation::CustomizationSet {
                    profile_id: Uuid::nil().hyphenated().to_string(),
                    variant: ConfigurationVariant::Primary,
                    changes: changes.clone(),
                }
                .validate_bridge_input()
                .map_err(|_| {
                    TransactionFailure::new(
                        "invalid_customization_changes",
                        "customization changes are empty or outside safe bounds",
                    )
                })?;
            }
        }
        CliProfileCommand::CustomizationFix {
            variant,
            target,
            canvas,
            include_locked,
            ..
        } => {
            ConfigurationOperation::CustomizationFix {
                profile_id: Uuid::nil().hyphenated().to_string(),
                variant: *variant,
                target: target.clone(),
                canvas: canvas.clone(),
                include_locked: *include_locked,
            }
            .validate_bridge_input()
            .map_err(|_| {
                TransactionFailure::new(
                    "invalid_layout_repair",
                    "layout repair target or canvas is outside safe bounds",
                )
            })?;
        }
        CliProfileCommand::StyleCreate {
            style_id,
            name,
            appearance,
            ..
        } => {
            ConfigurationOperation::StyleCreate {
                profile_id: Uuid::nil().hyphenated().to_string(),
                style_id: style_id.clone(),
                name: name.clone(),
                appearance: appearance.clone(),
            }
            .validate_bridge_input()
            .map_err(|_| {
                TransactionFailure::new(
                    "invalid_style",
                    "style identifier, name, or appearance is outside safe bounds",
                )
            })?;
        }
        CliProfileCommand::StyleRename { style_id, name, .. } => {
            ConfigurationOperation::StyleRename {
                profile_id: Uuid::nil().hyphenated().to_string(),
                style_id: style_id.clone(),
                name: name.clone(),
            }
            .validate_bridge_input()
            .map_err(|_| {
                TransactionFailure::new(
                    "invalid_style",
                    "style identifier or name is outside safe bounds",
                )
            })?;
        }
        CliProfileCommand::StyleApply {
            style_id,
            element_id,
            ..
        } => {
            ConfigurationOperation::StyleApply {
                profile_id: Uuid::nil().hyphenated().to_string(),
                variant: ConfigurationVariant::Primary,
                style_id: style_id.clone(),
                element_id: element_id.clone(),
            }
            .validate_bridge_input()
            .map_err(|_| {
                TransactionFailure::new(
                    "invalid_style",
                    "style or element identifier is outside safe bounds",
                )
            })?;
        }
        CliProfileCommand::StyleDetach { element_id, .. } => {
            ConfigurationOperation::StyleDetach {
                profile_id: Uuid::nil().hyphenated().to_string(),
                variant: ConfigurationVariant::Primary,
                element_id: element_id.clone(),
            }
            .validate_bridge_input()
            .map_err(|_| {
                TransactionFailure::new(
                    "invalid_style",
                    "element identifier is outside safe bounds",
                )
            })?;
        }
        CliProfileCommand::StyleDelete { style_id, .. } => {
            ConfigurationOperation::StyleDelete {
                profile_id: Uuid::nil().hyphenated().to_string(),
                style_id: style_id.clone(),
            }
            .validate_bridge_input()
            .map_err(|_| {
                TransactionFailure::new("invalid_style", "style identifier is outside safe bounds")
            })?;
        }
        CliProfileCommand::LayerMove {
            element_id,
            destination,
            ..
        } => {
            validate_cli_element_selector(element_id)?;
            match destination {
                LayerMoveDestination::Index { index } if *index < 0 => {
                    return Err(TransactionFailure::new(
                        "invalid_layer_destination",
                        "layer destination index must be zero or greater",
                    ));
                }
                LayerMoveDestination::Before { element_id }
                | LayerMoveDestination::After { element_id } => {
                    validate_cli_element_selector(element_id)?;
                }
                _ => {}
            }
        }
        CliProfileCommand::LayerForward { element_id, .. }
        | CliProfileCommand::LayerBackward { element_id, .. }
        | CliProfileCommand::LayerFront { element_id, .. }
        | CliProfileCommand::LayerBack { element_id, .. } => {
            validate_cli_element_selector(element_id)?;
        }
        CliProfileCommand::GroupCreate { element_ids, .. } => {
            if element_ids.is_empty() || element_ids.len() > 64 {
                return Err(TransactionFailure::new(
                    "invalid_group_children",
                    "group creation requires between 1 and 64 elements",
                ));
            }
            for element_id in element_ids {
                validate_cli_element_selector(element_id)?;
            }
        }
        CliProfileCommand::GroupRename { group, .. }
        | CliProfileCommand::GroupUngroup { group, .. }
        | CliProfileCommand::GroupHide { group, .. }
        | CliProfileCommand::GroupShow { group, .. }
        | CliProfileCommand::GroupLock { group, .. }
        | CliProfileCommand::GroupUnlock { group, .. }
        | CliProfileCommand::GroupForward { group, .. }
        | CliProfileCommand::GroupBackward { group, .. }
        | CliProfileCommand::GroupFront { group, .. }
        | CliProfileCommand::GroupBack { group, .. } => validate_cli_group_selector(group)?,
        CliProfileCommand::GroupDuplicate {
            group,
            offset_x,
            offset_y,
            ..
        } => {
            validate_cli_group_selector(group)?;
            validate_group_offset(*offset_x, "offsetX")?;
            validate_group_offset(*offset_y, "offsetY")?;
        }
        CliProfileCommand::GroupNudge {
            group,
            canvas_frame_id,
            delta_x,
            delta_y,
            ..
        } => {
            validate_cli_group_selector(group)?;
            if canvas_frame_id.trim().is_empty() || canvas_frame_id.len() > 128 {
                return Err(TransactionFailure::new(
                    "invalid_device_frame",
                    "group nudge canvas frame must be a bounded checked-in frame ID",
                ));
            }
            validate_group_nudge(*delta_x, "deltaX")?;
            validate_group_nudge(*delta_y, "deltaY")?;
        }
        CliProfileCommand::OrientationCopy {
            source,
            destination,
            ..
        } if source == destination => {
            return Err(TransactionFailure::new(
                "identical_orientations",
                "source and destination orientations must differ",
            ));
        }
        _ => {}
    }
    Ok(())
}

fn plan_transaction(
    command: &CliProfileCommand,
    catalog: &CliProfileCatalog,
    profiles: &[serde_json::Value],
    invocation_id: Uuid,
) -> Result<PlannedTransaction, TransactionFailure> {
    match command {
        CliProfileCommand::Select { target } => {
            let profile = resolve_selector(target, catalog)?;
            Ok(plan_one(
                ConfigurationOperation::ProfileSelect {
                    profile_id: profile.profile_id.hyphenated().to_string(),
                },
                profile.name.clone(),
            ))
        }
        CliProfileCommand::SetDefault { target } => {
            let profile = resolve_selector(target, catalog)?;
            Ok(plan_one(
                ConfigurationOperation::ProfileSetDefault {
                    profile_id: profile.profile_id.hyphenated().to_string(),
                },
                profile.name.clone(),
            ))
        }
        CliProfileCommand::Rename { target, name } => {
            let profile = resolve_selector(target, catalog)?;
            let name = normalized_name(name)?;
            Ok(plan_one(
                ConfigurationOperation::ProfileRename {
                    profile_id: profile.profile_id.hyphenated().to_string(),
                    name: name.clone(),
                },
                name,
            ))
        }
        CliProfileCommand::Duplicate { target, name } => {
            let source = resolve_optional_selector(target.as_ref(), catalog)?;
            let duplicate_name = match name {
                Some(name) if !name.trim().is_empty() => normalized_name(name)?,
                _ => format!("{} Copy", source.name),
            };
            let new_profile_id = deterministic_uuid(invocation_id, "profile.duplicate:new-profile");
            Ok(PlannedTransaction {
                operations: vec![ConfigurationOperation::ProfileDuplicate {
                    profile_id: source.profile_id.hyphenated().to_string(),
                    new_profile_id: new_profile_id.hyphenated().to_string(),
                    name: duplicate_name.clone(),
                }],
                profile_names: vec![source.name.clone(), duplicate_name],
                destination: None,
                removed_every_profile: false,
            })
        }
        CliProfileCommand::Delete { targets } => {
            let selected = resolve_selectors(targets, catalog)?;
            let removed_every_profile = selected.len() == catalog.profiles.len();
            let replacement =
                deterministic_uuid(invocation_id, "profile.delete:replacement-profile");
            let operations = selected
                .iter()
                .enumerate()
                .map(|(ordinal, profile)| ConfigurationOperation::ProfileDelete {
                    profile_id: profile.profile_id.hyphenated().to_string(),
                    replacement_profile_id: (removed_every_profile
                        && ordinal + 1 == selected.len())
                    .then(|| replacement.hyphenated().to_string()),
                })
                .collect();
            Ok(PlannedTransaction {
                operations,
                profile_names: selected
                    .iter()
                    .map(|profile| profile.name.clone())
                    .collect(),
                destination: None,
                removed_every_profile,
            })
        }
        CliProfileCommand::Reset { target } => {
            let profile = resolve_optional_selector(target.as_ref(), catalog)?;
            Ok(plan_one(
                ConfigurationOperation::ProfileReset {
                    profile_id: profile.profile_id.hyphenated().to_string(),
                },
                profile.name.clone(),
            ))
        }
        CliProfileCommand::Move {
            targets,
            destination,
        } => plan_move(targets, destination, catalog),
        CliProfileCommand::GenerationGenerate {
            select,
            make_default,
        } => {
            let preset = GenerationPreset::HollowKnight;
            let name = "Hollow Knight".to_owned();
            let destination = generated_profile_destination(
                &name,
                catalog,
                invocation_id,
                "generation.generate:new-profile",
            );
            let new_element_ids = deterministic_ids(
                invocation_id,
                "generation.generate:new-element",
                preset.custom_element_id_count(),
            );
            Ok(PlannedTransaction {
                operations: vec![ConfigurationOperation::GenerationGenerate {
                    preset,
                    preset_revision: preset.revision(),
                    destination,
                    new_element_ids,
                    select: *select,
                    make_default: *make_default,
                }],
                profile_names: vec![name],
                destination: None,
                removed_every_profile: false,
            })
        }
        CliProfileCommand::TemplateInstall {
            template,
            name,
            select,
            make_default,
        } => {
            let name = match name {
                Some(name) => normalized_name(name)?,
                None => template.display_name().to_owned(),
            };
            let destination = generated_profile_destination(
                &name,
                catalog,
                invocation_id,
                "template.install:new-profile",
            );
            let new_element_ids = deterministic_ids(
                invocation_id,
                "template.install:new-element",
                template.custom_element_id_count(),
            );
            Ok(PlannedTransaction {
                operations: vec![ConfigurationOperation::TemplateInstall {
                    template: *template,
                    template_revision: template.revision(),
                    destination,
                    name: Some(name.clone()),
                    new_element_ids,
                    select: *select,
                    make_default: *make_default,
                }],
                profile_names: vec![name],
                destination: None,
                removed_every_profile: false,
            })
        }
        CliProfileCommand::CustomizationSet {
            target,
            variant,
            changes,
            frame_id,
        } => {
            let profile = resolve_selector(target, catalog)?;
            let profile_id = profile.profile_id.hyphenated().to_string();
            let mut operations =
                Vec::with_capacity(changes.len() + usize::from(frame_id.is_some()));
            if let Some(frame_id) = frame_id {
                operations.push(ConfigurationOperation::DeviceSet {
                    profile_id: profile_id.clone(),
                    variant: *variant,
                    frame_id: frame_id.clone(),
                });
            }
            operations.extend(changes.iter().cloned().map(|changes| {
                ConfigurationOperation::CustomizationSet {
                    profile_id: profile_id.clone(),
                    variant: *variant,
                    changes,
                }
            }));
            Ok(PlannedTransaction {
                operations,
                profile_names: vec![profile.name.clone()],
                destination: None,
                removed_every_profile: false,
            })
        }
        CliProfileCommand::CustomizationFix {
            profile,
            variant,
            target,
            canvas,
            include_locked,
        } => {
            let profile = resolve_selector(profile, catalog)?;
            Ok(plan_one(
                ConfigurationOperation::CustomizationFix {
                    profile_id: profile.profile_id.hyphenated().to_string(),
                    variant: *variant,
                    target: target.clone(),
                    canvas: canvas.clone(),
                    include_locked: *include_locked,
                },
                profile.name.clone(),
            ))
        }
        CliProfileCommand::LayerMove {
            target,
            element_id,
            destination,
        } => {
            let profile = resolve_selector(target, catalog)?;
            let raw_profile = profiles.get(profile.index).ok_or_else(|| {
                TransactionFailure::new(
                    "unsafe_profile_catalog",
                    "layer profile is missing from the revision-tagged catalog",
                )
            })?;
            let element_id =
                resolve_cli_element_id(raw_profile, ConfigurationVariant::Primary, element_id)?;
            let destination = match destination {
                LayerMoveDestination::Index { index } => {
                    LayerMoveDestination::Index { index: *index }
                }
                LayerMoveDestination::Before { element_id } => LayerMoveDestination::Before {
                    element_id: resolve_cli_element_id(
                        raw_profile,
                        ConfigurationVariant::Primary,
                        element_id,
                    )?,
                },
                LayerMoveDestination::After { element_id } => LayerMoveDestination::After {
                    element_id: resolve_cli_element_id(
                        raw_profile,
                        ConfigurationVariant::Primary,
                        element_id,
                    )?,
                },
            };
            Ok(plan_one(
                ConfigurationOperation::LayerMove {
                    profile_id: profile.profile_id.hyphenated().to_string(),
                    variant: ConfigurationVariant::Primary,
                    element_id,
                    destination,
                },
                profile.name.clone(),
            ))
        }
        CliProfileCommand::LayerForward { target, element_id }
        | CliProfileCommand::LayerBackward { target, element_id }
        | CliProfileCommand::LayerFront { target, element_id }
        | CliProfileCommand::LayerBack { target, element_id } => {
            let profile = resolve_selector(target, catalog)?;
            let raw_profile = profiles.get(profile.index).ok_or_else(|| {
                TransactionFailure::new(
                    "unsafe_profile_catalog",
                    "layer profile is missing from the revision-tagged catalog",
                )
            })?;
            let element_id =
                resolve_cli_element_id(raw_profile, ConfigurationVariant::Primary, element_id)?;
            let profile_id = profile.profile_id.hyphenated().to_string();
            let operation = match command {
                CliProfileCommand::LayerForward { .. } => ConfigurationOperation::LayerForward {
                    profile_id,
                    variant: ConfigurationVariant::Primary,
                    element_id,
                },
                CliProfileCommand::LayerBackward { .. } => ConfigurationOperation::LayerBackward {
                    profile_id,
                    variant: ConfigurationVariant::Primary,
                    element_id,
                },
                CliProfileCommand::LayerFront { .. } => ConfigurationOperation::LayerFront {
                    profile_id,
                    variant: ConfigurationVariant::Primary,
                    element_id,
                },
                CliProfileCommand::LayerBack { .. } => ConfigurationOperation::LayerBack {
                    profile_id,
                    variant: ConfigurationVariant::Primary,
                    element_id,
                },
                _ => unreachable!(),
            };
            Ok(plan_one(operation, profile.name.clone()))
        }
        CliProfileCommand::GroupCreate {
            target,
            variant,
            name,
            element_ids,
        } => {
            let profile = resolve_selector(target, catalog)?;
            let raw_profile = profiles.get(profile.index).ok_or_else(|| {
                TransactionFailure::new(
                    "unsafe_profile_catalog",
                    "group profile is missing from the revision-tagged catalog",
                )
            })?;
            let element_ids = element_ids
                .iter()
                .map(|element_id| resolve_cli_element_id(raw_profile, *variant, element_id))
                .collect::<Result<Vec<_>, _>>()?;
            Ok(plan_one(
                ConfigurationOperation::GroupCreate {
                    profile_id: profile.profile_id.hyphenated().to_string(),
                    variant: *variant,
                    group_id: deterministic_uuid(invocation_id, "group.create:new-group")
                        .hyphenated()
                        .to_string(),
                    name: normalized_name(name)?,
                    element_ids,
                },
                profile.name.clone(),
            ))
        }
        CliProfileCommand::GroupRename {
            target,
            variant,
            group,
            name,
        } => {
            let profile = resolve_selector(target, catalog)?;
            let raw_profile = profiles.get(profile.index).ok_or_else(|| {
                TransactionFailure::new(
                    "unsafe_profile_catalog",
                    "group profile is missing from the revision-tagged catalog",
                )
            })?;
            let (group_id, _) = resolve_cli_group(raw_profile, *variant, group)?;
            Ok(plan_one(
                ConfigurationOperation::GroupRename {
                    profile_id: profile.profile_id.hyphenated().to_string(),
                    variant: *variant,
                    group_id,
                    name: normalized_name(name)?,
                },
                profile.name.clone(),
            ))
        }
        CliProfileCommand::GroupDuplicate {
            target,
            variant,
            group,
            name,
            offset_x,
            offset_y,
        } => {
            let profile = resolve_selector(target, catalog)?;
            let raw_profile = profiles.get(profile.index).ok_or_else(|| {
                TransactionFailure::new(
                    "unsafe_profile_catalog",
                    "group profile is missing from the revision-tagged catalog",
                )
            })?;
            let (group_id, child_count) = resolve_cli_group(raw_profile, *variant, group)?;
            Ok(plan_one(
                ConfigurationOperation::GroupDuplicate {
                    profile_id: profile.profile_id.hyphenated().to_string(),
                    variant: *variant,
                    group_id,
                    new_group_id: deterministic_uuid(invocation_id, "group.duplicate:new-group")
                        .hyphenated()
                        .to_string(),
                    name: name
                        .as_ref()
                        .map(|name| normalized_name(name))
                        .transpose()?,
                    new_element_ids: deterministic_ids(
                        invocation_id,
                        "group.duplicate:new-element",
                        child_count,
                    ),
                    offset_x: *offset_x,
                    offset_y: *offset_y,
                },
                profile.name.clone(),
            ))
        }
        CliProfileCommand::GroupNudge {
            target,
            variant,
            group,
            canvas_frame_id,
            delta_x,
            delta_y,
        } => {
            let profile = resolve_selector(target, catalog)?;
            let raw_profile = profiles.get(profile.index).ok_or_else(|| {
                TransactionFailure::new(
                    "unsafe_profile_catalog",
                    "group profile is missing from the revision-tagged catalog",
                )
            })?;
            let (group_id, _) = resolve_cli_group(raw_profile, *variant, group)?;
            Ok(plan_one(
                ConfigurationOperation::GroupNudge {
                    profile_id: profile.profile_id.hyphenated().to_string(),
                    variant: *variant,
                    group_id,
                    canvas_frame_id: canvas_frame_id.clone(),
                    delta_x: *delta_x,
                    delta_y: *delta_y,
                },
                profile.name.clone(),
            ))
        }
        CliProfileCommand::GroupUngroup {
            target,
            variant,
            group,
        }
        | CliProfileCommand::GroupHide {
            target,
            variant,
            group,
        }
        | CliProfileCommand::GroupShow {
            target,
            variant,
            group,
        }
        | CliProfileCommand::GroupLock {
            target,
            variant,
            group,
        }
        | CliProfileCommand::GroupUnlock {
            target,
            variant,
            group,
        }
        | CliProfileCommand::GroupForward {
            target,
            variant,
            group,
        }
        | CliProfileCommand::GroupBackward {
            target,
            variant,
            group,
        }
        | CliProfileCommand::GroupFront {
            target,
            variant,
            group,
        }
        | CliProfileCommand::GroupBack {
            target,
            variant,
            group,
        } => {
            let profile = resolve_selector(target, catalog)?;
            let raw_profile = profiles.get(profile.index).ok_or_else(|| {
                TransactionFailure::new(
                    "unsafe_profile_catalog",
                    "group profile is missing from the revision-tagged catalog",
                )
            })?;
            let (group_id, _) = resolve_cli_group(raw_profile, *variant, group)?;
            let profile_id = profile.profile_id.hyphenated().to_string();
            let operation = match command {
                CliProfileCommand::GroupUngroup { .. } => ConfigurationOperation::GroupUngroup {
                    profile_id,
                    variant: *variant,
                    group_id,
                },
                CliProfileCommand::GroupHide { .. } => ConfigurationOperation::GroupHide {
                    profile_id,
                    variant: *variant,
                    group_id,
                },
                CliProfileCommand::GroupShow { .. } => ConfigurationOperation::GroupShow {
                    profile_id,
                    variant: *variant,
                    group_id,
                },
                CliProfileCommand::GroupLock { .. } => ConfigurationOperation::GroupLock {
                    profile_id,
                    variant: *variant,
                    group_id,
                },
                CliProfileCommand::GroupUnlock { .. } => ConfigurationOperation::GroupUnlock {
                    profile_id,
                    variant: *variant,
                    group_id,
                },
                CliProfileCommand::GroupForward { .. } => ConfigurationOperation::GroupForward {
                    profile_id,
                    variant: *variant,
                    group_id,
                },
                CliProfileCommand::GroupBackward { .. } => ConfigurationOperation::GroupBackward {
                    profile_id,
                    variant: *variant,
                    group_id,
                },
                CliProfileCommand::GroupFront { .. } => ConfigurationOperation::GroupFront {
                    profile_id,
                    variant: *variant,
                    group_id,
                },
                CliProfileCommand::GroupBack { .. } => ConfigurationOperation::GroupBack {
                    profile_id,
                    variant: *variant,
                    group_id,
                },
                _ => unreachable!(),
            };
            Ok(plan_one(operation, profile.name.clone()))
        }
        CliProfileCommand::StyleCreate {
            target,
            style_id,
            name,
            appearance,
        } => {
            let profile = resolve_selector(target, catalog)?;
            Ok(plan_one(
                ConfigurationOperation::StyleCreate {
                    profile_id: profile.profile_id.hyphenated().to_string(),
                    style_id: style_id.clone(),
                    name: name.clone(),
                    appearance: appearance.clone(),
                },
                profile.name.clone(),
            ))
        }
        CliProfileCommand::StyleRename {
            target,
            style_id,
            name,
        } => {
            let profile = resolve_selector(target, catalog)?;
            Ok(plan_one(
                ConfigurationOperation::StyleRename {
                    profile_id: profile.profile_id.hyphenated().to_string(),
                    style_id: style_id.clone(),
                    name: name.clone(),
                },
                profile.name.clone(),
            ))
        }
        CliProfileCommand::StyleApply {
            target,
            variant,
            style_id,
            element_id,
        } => {
            let profile = resolve_selector(target, catalog)?;
            let raw_profile = profiles.get(profile.index).ok_or_else(|| {
                TransactionFailure::new(
                    "unsafe_profile_catalog",
                    "style profile is missing from the revision-tagged catalog",
                )
            })?;
            let element_id = resolve_cli_element_id(raw_profile, *variant, element_id)?;
            Ok(plan_one(
                ConfigurationOperation::StyleApply {
                    profile_id: profile.profile_id.hyphenated().to_string(),
                    variant: *variant,
                    style_id: style_id.clone(),
                    element_id,
                },
                profile.name.clone(),
            ))
        }
        CliProfileCommand::StyleDetach {
            target,
            variant,
            element_id,
        } => {
            let profile = resolve_selector(target, catalog)?;
            let raw_profile = profiles.get(profile.index).ok_or_else(|| {
                TransactionFailure::new(
                    "unsafe_profile_catalog",
                    "style profile is missing from the revision-tagged catalog",
                )
            })?;
            let element_id = resolve_cli_element_id(raw_profile, *variant, element_id)?;
            Ok(plan_one(
                ConfigurationOperation::StyleDetach {
                    profile_id: profile.profile_id.hyphenated().to_string(),
                    variant: *variant,
                    element_id,
                },
                profile.name.clone(),
            ))
        }
        CliProfileCommand::StyleDelete { target, style_id } => {
            let profile = resolve_selector(target, catalog)?;
            Ok(plan_one(
                ConfigurationOperation::StyleDelete {
                    profile_id: profile.profile_id.hyphenated().to_string(),
                    style_id: style_id.clone(),
                },
                profile.name.clone(),
            ))
        }
        CliProfileCommand::OrientationSet { target, preference } => {
            let profile = resolve_selector(target, catalog)?;
            Ok(plan_one(
                ConfigurationOperation::OrientationSet {
                    profile_id: profile.profile_id.hyphenated().to_string(),
                    preference: *preference,
                },
                profile.name.clone(),
            ))
        }
        CliProfileCommand::OrientationCopy {
            target,
            source,
            destination,
            automatically_arrange,
        } => {
            let profile = resolve_selector(target, catalog)?;
            let raw_profile = profiles.get(profile.index).ok_or_else(|| {
                TransactionFailure::new(
                    "unsafe_profile_catalog",
                    "orientation profile is missing from the revision-tagged catalog",
                )
            })?;
            if !orientation_source_exists(raw_profile, *source) {
                return Err(TransactionFailure::new(
                    "missing_orientation",
                    "source orientation has no saved layout or matching primary layout",
                ));
            }
            Ok(PlannedTransaction {
                operations: vec![ConfigurationOperation::OrientationCopy {
                    profile_id: profile.profile_id.hyphenated().to_string(),
                    source: *source,
                    destination: *destination,
                    automatically_arrange: *automatically_arrange,
                }],
                profile_names: vec![profile.name.clone()],
                destination: Some(orientation_name(*destination).to_owned()),
                removed_every_profile: false,
            })
        }
        CliProfileCommand::BindingSet {
            target,
            button,
            sequence,
        } => {
            let profile = resolve_selector(target, catalog)?;
            Ok(plan_one(
                ConfigurationOperation::BindingSet {
                    profile_id: profile.profile_id.hyphenated().to_string(),
                    button: *button,
                    sequence: sequence.clone(),
                },
                profile.name.clone(),
            ))
        }
        CliProfileCommand::BindingClear { target, button } => {
            let profile = resolve_selector(target, catalog)?;
            Ok(plan_one(
                ConfigurationOperation::BindingClear {
                    profile_id: profile.profile_id.hyphenated().to_string(),
                    button: *button,
                },
                profile.name.clone(),
            ))
        }
        CliProfileCommand::BindingReset { target, button } => {
            let profile = resolve_selector(target, catalog)?;
            Ok(plan_one(
                ConfigurationOperation::BindingReset {
                    profile_id: profile.profile_id.hyphenated().to_string(),
                    button: *button,
                },
                profile.name.clone(),
            ))
        }
        CliProfileCommand::BindingResetAll { target } => {
            let profile = resolve_selector(target, catalog)?;
            Ok(plan_one(
                ConfigurationOperation::BindingResetAll {
                    profile_id: profile.profile_id.hyphenated().to_string(),
                },
                profile.name.clone(),
            ))
        }
        CliProfileCommand::OutputMode { target, mode } => {
            let profile = resolve_selector(target, catalog)?;
            Ok(plan_one(
                ConfigurationOperation::OutputMode {
                    profile_id: profile.profile_id.hyphenated().to_string(),
                    mode: *mode,
                },
                profile.name.clone(),
            ))
        }
        CliProfileCommand::OutputSet {
            target,
            button,
            keyboard_edit,
            gamepad_edit,
        } => {
            let profile = resolve_selector(target, catalog)?;
            Ok(plan_one(
                ConfigurationOperation::OutputSet {
                    profile_id: profile.profile_id.hyphenated().to_string(),
                    button: *button,
                    keyboard_edit: keyboard_edit.clone(),
                    gamepad_edit: gamepad_edit.clone(),
                },
                profile.name.clone(),
            ))
        }
        CliProfileCommand::OutputReset { target, button } => {
            let profile = resolve_selector(target, catalog)?;
            Ok(plan_one(
                ConfigurationOperation::OutputReset {
                    profile_id: profile.profile_id.hyphenated().to_string(),
                    button: *button,
                },
                profile.name.clone(),
            ))
        }
        CliProfileCommand::OutputResetAll { target } => {
            let profile = resolve_selector(target, catalog)?;
            Ok(plan_one(
                ConfigurationOperation::OutputResetAll {
                    profile_id: profile.profile_id.hyphenated().to_string(),
                },
                profile.name.clone(),
            ))
        }
        CliProfileCommand::DeviceSet {
            target,
            variant,
            frame_id,
        } => {
            let profile = resolve_selector(target, catalog)?;
            Ok(plan_one(
                ConfigurationOperation::DeviceSet {
                    profile_id: profile.profile_id.hyphenated().to_string(),
                    variant: *variant,
                    frame_id: frame_id.clone(),
                },
                profile.name.clone(),
            ))
        }
        CliProfileCommand::ControlBarSet {
            target,
            variant,
            items,
        } => {
            let profile = resolve_selector(target, catalog)?;
            Ok(plan_one(
                ConfigurationOperation::ControlBarSet {
                    profile_id: profile.profile_id.hyphenated().to_string(),
                    variant: *variant,
                    items: items.clone(),
                },
                profile.name.clone(),
            ))
        }
        CliProfileCommand::ControlBarAdd {
            target,
            variant,
            item,
        } => {
            let profile = resolve_selector(target, catalog)?;
            Ok(plan_one(
                ConfigurationOperation::ControlBarAdd {
                    profile_id: profile.profile_id.hyphenated().to_string(),
                    variant: *variant,
                    item: *item,
                },
                profile.name.clone(),
            ))
        }
        CliProfileCommand::ControlBarRemove {
            target,
            variant,
            item,
        } => {
            let profile = resolve_selector(target, catalog)?;
            Ok(plan_one(
                ConfigurationOperation::ControlBarRemove {
                    profile_id: profile.profile_id.hyphenated().to_string(),
                    variant: *variant,
                    item: *item,
                },
                profile.name.clone(),
            ))
        }
        CliProfileCommand::ControlBarMove {
            target,
            variant,
            item,
            direction,
        } => {
            let profile = resolve_selector(target, catalog)?;
            Ok(plan_one(
                ConfigurationOperation::ControlBarMove {
                    profile_id: profile.profile_id.hyphenated().to_string(),
                    variant: *variant,
                    item: *item,
                    direction: *direction,
                },
                profile.name.clone(),
            ))
        }
        CliProfileCommand::ControlBarReset { target, variant } => {
            let profile = resolve_selector(target, catalog)?;
            Ok(plan_one(
                ConfigurationOperation::ControlBarReset {
                    profile_id: profile.profile_id.hyphenated().to_string(),
                    variant: *variant,
                },
                profile.name.clone(),
            ))
        }
        CliProfileCommand::ControlBarItemSet {
            target,
            variant,
            item,
            changes,
        } => {
            let profile = resolve_selector(target, catalog)?;
            Ok(plan_one(
                ConfigurationOperation::ControlBarItemSet {
                    profile_id: profile.profile_id.hyphenated().to_string(),
                    variant: *variant,
                    item: *item,
                    changes: changes.clone(),
                },
                profile.name.clone(),
            ))
        }
        CliProfileCommand::ControlBarItemReset {
            target,
            variant,
            item,
        } => {
            let profile = resolve_selector(target, catalog)?;
            Ok(plan_one(
                ConfigurationOperation::ControlBarItemReset {
                    profile_id: profile.profile_id.hyphenated().to_string(),
                    variant: *variant,
                    item: *item,
                },
                profile.name.clone(),
            ))
        }
        CliProfileCommand::List
        | CliProfileCommand::AuthorityStatus
        | CliProfileCommand::OrientationGet { .. }
        | CliProfileCommand::BindingList { .. }
        | CliProfileCommand::BindingDisplay { .. }
        | CliProfileCommand::OutputList { .. }
        | CliProfileCommand::OutputModeGet { .. }
        | CliProfileCommand::DeviceGet { .. }
        | CliProfileCommand::ControlBarList { .. }
        | CliProfileCommand::ControlBarItemShow { .. }
        | CliProfileCommand::StyleList { .. }
        | CliProfileCommand::StyleShow { .. }
        | CliProfileCommand::LayerList { .. }
        | CliProfileCommand::GroupList { .. } => Err(TransactionFailure::new(
            "invalid_request",
            "profile transaction command is not mutating",
        )),
    }
}

fn validate_cli_group_selector(value: &str) -> Result<(), TransactionFailure> {
    let trimmed = value.trim();
    if trimmed.is_empty() || trimmed.len() > 128 || trimmed.chars().any(char::is_control) {
        return Err(TransactionFailure::new(
            "invalid_group_selector",
            "group selector must contain 1 to 128 printable characters",
        ));
    }
    Ok(())
}

fn validate_group_offset(value: f64, _field: &str) -> Result<(), TransactionFailure> {
    if !value.is_finite() || !(-1.0..=1.0).contains(&value) {
        return Err(TransactionFailure::new(
            "invalid_group_offset",
            "group duplicate offsets must be finite and between -1 and 1",
        ));
    }
    Ok(())
}

fn validate_group_nudge(value: f64, _field: &str) -> Result<(), TransactionFailure> {
    if !value.is_finite() || !(-4_000.0..=4_000.0).contains(&value) {
        return Err(TransactionFailure::new(
            "invalid_group_nudge",
            "group nudge deltas must be finite and between -4000 and 4000",
        ));
    }
    Ok(())
}

fn validate_cli_element_selector(value: &str) -> Result<(), TransactionFailure> {
    let trimmed = value.trim();
    if trimmed.is_empty() || trimmed.chars().count() > 128 || trimmed.chars().any(char::is_control)
    {
        return Err(TransactionFailure::new(
            "invalid_element_selection",
            "element selector must contain between 1 and 128 safe characters",
        ));
    }
    Ok(())
}

fn resolve_cli_element_id(
    profile: &serde_json::Value,
    variant: ConfigurationVariant,
    input: &str,
) -> Result<String, TransactionFailure> {
    let primary = profile
        .get("customization")
        .filter(|value| value.is_object());
    let customization = match variant {
        ConfigurationVariant::Primary => primary,
        ConfigurationVariant::Landscape => profile
            .get("landscapeCustomization")
            .filter(|value| value.is_object())
            .or(primary),
        ConfigurationVariant::Portrait => profile
            .get("portraitCustomization")
            .filter(|value| value.is_object())
            .or(primary),
    }
    .and_then(serde_json::Value::as_object)
    .ok_or_else(|| {
        TransactionFailure::new(
            "unsafe_element_selection",
            "profile variant has no bounded element source",
        )
    })?;
    let normalized = normalized_lookup(input);
    let built_in = match normalized.as_str() {
        "up" => Some("up"),
        "down" => Some("down"),
        "left" => Some("left"),
        "right" => Some("right"),
        "jump" | "action1" => Some("jump"),
        "attack" | "action2" => Some("attack"),
        "dash" | "action3" => Some("dash"),
        "focus" | "action4" => Some("focus"),
        "map" | "menu" => Some("map"),
        "pause" => Some("pause"),
        _ => None,
    };
    if let Some(button) = built_in {
        return Ok(button.to_owned());
    }
    if matches!(
        normalized.as_str(),
        "controlbar" | "topbar" | "iosbar" | "controlbarhotspot" | "topbaractivation"
    ) {
        return Ok("top_bar_activation".to_owned());
    }
    if let Ok(id) = Uuid::parse_str(input) {
        return Ok(id.hyphenated().to_string());
    }
    let mut matches = customization
        .get("customButtons")
        .and_then(serde_json::Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(|button| {
            let id = button.get("id")?.as_str()?;
            let label = button
                .get("label")
                .and_then(serde_json::Value::as_str)
                .unwrap_or_default();
            let mapped = button
                .get("mappedButton")
                .and_then(serde_json::Value::as_str)
                .unwrap_or_default();
            (normalized_lookup(label) == normalized || normalized_lookup(mapped) == normalized)
                .then_some(id)
        })
        .collect::<Vec<_>>();
    matches.sort_unstable();
    matches.dedup_by(|left, right| left.eq_ignore_ascii_case(right));
    if matches.len() != 1 {
        return Err(TransactionFailure::new(
            if matches.is_empty() {
                "element_not_found"
            } else {
                "ambiguous_element"
            },
            "style element selector did not resolve to exactly one safe element",
        ));
    }
    Uuid::parse_str(matches[0])
        .map(|id| id.hyphenated().to_string())
        .map_err(|_| {
            TransactionFailure::new(
                "unsafe_element_selection",
                "resolved style element identifier is malformed",
            )
        })
}

fn resolve_cli_group(
    profile: &serde_json::Value,
    variant: ConfigurationVariant,
    input: &str,
) -> Result<(String, usize), TransactionFailure> {
    let primary = profile
        .get("customization")
        .filter(|value| value.is_object());
    let customization = match variant {
        ConfigurationVariant::Primary => primary,
        ConfigurationVariant::Landscape => profile
            .get("landscapeCustomization")
            .filter(|value| value.is_object())
            .or(primary),
        ConfigurationVariant::Portrait => profile
            .get("portraitCustomization")
            .filter(|value| value.is_object())
            .or(primary),
    }
    .ok_or_else(|| {
        TransactionFailure::new(
            "unsafe_group_selection",
            "profile variant has no bounded group source",
        )
    })?;
    let groups = customization
        .pointer("/designMetadata/groups")
        .and_then(serde_json::Value::as_array)
        .map(Vec::as_slice)
        .unwrap_or_default();
    if groups.len() > 64 {
        return Err(TransactionFailure::new(
            "unsafe_group_selection",
            "profile variant exceeds the bounded group limit",
        ));
    }
    let parsed_id = Uuid::parse_str(input).ok();
    let normalized = normalized_lookup(input);
    let group = groups.iter().find(|group| {
        let id = group
            .get("id")
            .and_then(serde_json::Value::as_str)
            .and_then(|value| Uuid::parse_str(value).ok());
        if parsed_id.is_some() && id == parsed_id {
            return true;
        }
        group
            .get("name")
            .and_then(serde_json::Value::as_str)
            .is_some_and(|name| normalized_lookup(name) == normalized)
    });
    let group = group.ok_or_else(|| {
        TransactionFailure::new(
            "group_not_found",
            "group selector did not resolve to a safe group",
        )
    })?;
    let id = group
        .get("id")
        .and_then(serde_json::Value::as_str)
        .and_then(|value| Uuid::parse_str(value).ok())
        .ok_or_else(|| {
            TransactionFailure::new(
                "unsafe_group_selection",
                "resolved group identifier is malformed",
            )
        })?;
    let child_count = group
        .get("children")
        .and_then(serde_json::Value::as_array)
        .map(Vec::len)
        .unwrap_or(0);
    if child_count > 64 {
        return Err(TransactionFailure::new(
            "unsafe_group_selection",
            "resolved group exceeds the bounded child limit",
        ));
    }
    Ok((id.hyphenated().to_string(), child_count))
}

fn generated_profile_destination(
    name: &str,
    catalog: &CliProfileCatalog,
    invocation_id: Uuid,
    new_profile_label: &str,
) -> GeneratedProfileDestination {
    catalog
        .profiles
        .iter()
        .find(|profile| profile.name.trim().eq_ignore_ascii_case(name.trim()))
        .map_or_else(
            || GeneratedProfileDestination::Create {
                new_profile_id: deterministic_uuid(invocation_id, new_profile_label)
                    .hyphenated()
                    .to_string(),
            },
            |profile| GeneratedProfileDestination::Replace {
                profile_id: profile.profile_id.hyphenated().to_string(),
            },
        )
}

fn deterministic_ids(invocation_id: Uuid, label: &str, count: usize) -> Vec<String> {
    (0..count)
        .map(|ordinal| {
            deterministic_uuid(invocation_id, &format!("{label}:{ordinal}"))
                .hyphenated()
                .to_string()
        })
        .collect()
}

fn plan_move(
    targets: &[ProfileSelector],
    destination: &ProfileMoveDestination,
    catalog: &CliProfileCatalog,
) -> Result<PlannedTransaction, TransactionFailure> {
    let moving = resolve_selectors(targets, catalog)?;
    let moving_ids = moving
        .iter()
        .map(|profile| profile.profile_id)
        .collect::<BTreeSet<_>>();
    let mut remaining = catalog
        .profiles
        .iter()
        .filter(|profile| !moving_ids.contains(&profile.profile_id))
        .cloned()
        .collect::<Vec<_>>();
    let (insertion_index, description) = match destination {
        ProfileMoveDestination::Index { index } => {
            if *index > remaining.len() {
                return Err(TransactionFailure::new(
                    "invalid_profile_index",
                    "profile move index is outside the remaining profile catalog",
                ));
            }
            (*index, format!("to index {index}"))
        }
        ProfileMoveDestination::Before { profile } => {
            let destination = resolve_selector(profile, catalog)?;
            if moving_ids.contains(&destination.profile_id) {
                return Err(TransactionFailure::new(
                    "invalid_profile_destination",
                    "destination profile cannot be moved in the same transaction",
                ));
            }
            let index = remaining
                .iter()
                .position(|candidate| candidate.profile_id == destination.profile_id)
                .ok_or_else(|| {
                    TransactionFailure::new(
                        "profile_not_found",
                        "destination profile is not in the safe catalog",
                    )
                })?;
            (index, format!("before \"{}\"", destination.name))
        }
        ProfileMoveDestination::After { profile } => {
            let destination = resolve_selector(profile, catalog)?;
            if moving_ids.contains(&destination.profile_id) {
                return Err(TransactionFailure::new(
                    "invalid_profile_destination",
                    "destination profile cannot be moved in the same transaction",
                ));
            }
            let index = remaining
                .iter()
                .position(|candidate| candidate.profile_id == destination.profile_id)
                .ok_or_else(|| {
                    TransactionFailure::new(
                        "profile_not_found",
                        "destination profile is not in the safe catalog",
                    )
                })?
                + 1;
            (index, format!("after \"{}\"", destination.name))
        }
    };
    remaining.splice(
        insertion_index..insertion_index,
        moving.iter().map(|profile| (*profile).clone()),
    );
    let operations = remaining
        .iter()
        .enumerate()
        .map(|(index, profile)| ConfigurationOperation::ProfileMove {
            profile_id: profile.profile_id.hyphenated().to_string(),
            index,
        })
        .collect();
    Ok(PlannedTransaction {
        operations,
        profile_names: moving.iter().map(|profile| profile.name.clone()).collect(),
        destination: Some(description),
        removed_every_profile: false,
    })
}

fn plan_one(operation: ConfigurationOperation, name: String) -> PlannedTransaction {
    PlannedTransaction {
        operations: vec![operation],
        profile_names: vec![name],
        destination: None,
        removed_every_profile: false,
    }
}

fn resolve_optional_selector<'a>(
    selector: Option<&ProfileSelector>,
    catalog: &'a CliProfileCatalog,
) -> Result<&'a CliProfileSummary, TransactionFailure> {
    match selector {
        Some(selector) => resolve_selector(selector, catalog),
        None => active_profile(catalog),
    }
}

fn resolve_selectors<'a>(
    selectors: &[ProfileSelector],
    catalog: &'a CliProfileCatalog,
) -> Result<Vec<&'a CliProfileSummary>, TransactionFailure> {
    let mut indexes = BTreeSet::new();
    for selector in selectors {
        indexes.insert(resolve_selector(selector, catalog)?.index);
    }
    Ok(indexes
        .into_iter()
        .filter_map(|index| catalog.profiles.get(index))
        .collect())
}

fn resolve_selector<'a>(
    selector: &ProfileSelector,
    catalog: &'a CliProfileCatalog,
) -> Result<&'a CliProfileSummary, TransactionFailure> {
    match selector {
        ProfileSelector::Active => active_profile(catalog),
        ProfileSelector::Default => catalog
            .profiles
            .iter()
            .find(|profile| profile.default)
            .ok_or_else(|| {
                TransactionFailure::new(
                    "default_profile_not_found",
                    "default profile is not in the safe catalog",
                )
            }),
        ProfileSelector::Id { profile_id } => catalog
            .profiles
            .iter()
            .find(|profile| profile.profile_id == *profile_id)
            .ok_or_else(|| {
                TransactionFailure::new(
                    "profile_not_found",
                    "profile UUID is not in the safe catalog",
                )
            }),
        ProfileSelector::Name { name } => resolve_name(name, catalog),
    }
}

fn active_profile(catalog: &CliProfileCatalog) -> Result<&CliProfileSummary, TransactionFailure> {
    catalog
        .profiles
        .iter()
        .find(|profile| profile.active)
        .ok_or_else(|| {
            TransactionFailure::new(
                "active_profile_not_found",
                "active profile is not in the safe catalog",
            )
        })
}

fn resolve_name<'a>(
    value: &str,
    catalog: &'a CliProfileCatalog,
) -> Result<&'a CliProfileSummary, TransactionFailure> {
    let trimmed = value.trim();
    if trimmed.is_empty()
        || trimmed.chars().count() > MAXIMUM_SELECTOR_CHARACTERS
        || trimmed.chars().any(char::is_control)
    {
        return Err(TransactionFailure::new(
            "invalid_profile_selection",
            "profile name selector is invalid",
        ));
    }
    let exact = catalog
        .profiles
        .iter()
        .filter(|profile| profile.name.eq_ignore_ascii_case(trimmed))
        .collect::<Vec<_>>();
    if exact.len() == 1 {
        return Ok(exact[0]);
    }
    if exact.len() > 1 {
        return Err(TransactionFailure::new(
            "ambiguous_profile_name",
            "profile name is ambiguous in the revision-tagged catalog",
        ));
    }
    let needle = normalized_lookup(trimmed);
    if needle.is_empty() {
        return Err(TransactionFailure::new(
            "profile_not_found",
            "profile name was not found in the revision-tagged catalog",
        ));
    }
    let partial = catalog
        .profiles
        .iter()
        .filter(|profile| normalized_lookup(&profile.name).contains(&needle))
        .collect::<Vec<_>>();
    match partial.as_slice() {
        [profile] => Ok(profile),
        [] => Err(TransactionFailure::new(
            "profile_not_found",
            "profile name was not found in the revision-tagged catalog",
        )),
        _ => Err(TransactionFailure::new(
            "ambiguous_profile_name",
            "profile name is ambiguous in the revision-tagged catalog",
        )),
    }
}

fn catalog_from_state(state: &PersistentState) -> Result<CliProfileCatalog, TransactionFailure> {
    catalog_from_parts(
        &state.profiles,
        &state.active_profile_id,
        &state.default_profile_id,
        state.configuration_revision,
        state.trusted_clients.keys().map(String::as_str),
    )
}

fn orientation_summary_from_state(
    state: &PersistentState,
    target: &ProfileSelector,
    catalog: &CliProfileCatalog,
) -> Result<CliOrientationSummary, TransactionFailure> {
    let profile = resolve_selector(target, catalog)?;
    let raw_profile = state.profiles.get(profile.index).ok_or_else(|| {
        TransactionFailure::new(
            "unsafe_profile_catalog",
            "orientation profile is missing from the revision-tagged catalog",
        )
    })?;
    let orientation = match raw_profile
        .get("orientationPreference")
        .and_then(serde_json::Value::as_str)
        .unwrap_or("automatic")
    {
        "automatic" => ConfigurationOrientationPreference::Automatic,
        "portrait" => ConfigurationOrientationPreference::Portrait,
        "landscape" => ConfigurationOrientationPreference::Landscape,
        _ => {
            return Err(TransactionFailure::new(
                "unsafe_orientation_summary",
                "orientation preference is outside the bounded typed projection",
            ));
        }
    };
    Ok(CliOrientationSummary {
        configuration_revision: catalog.configuration_revision,
        profile_id: profile.profile_id,
        profile_name: profile.name.clone(),
        orientation,
    })
}

fn layer_projection_from_state(
    state: &PersistentState,
    target: &ProfileSelector,
    variant: ConfigurationVariant,
    catalog: &CliProfileCatalog,
) -> Result<CliLayerProjection, TransactionFailure> {
    let profile = resolve_selector(target, catalog)?;
    let mut snapshot_state = state.clone();
    let raw_profile = snapshot_state
        .profiles
        .get_mut(profile.index)
        .and_then(serde_json::Value::as_object_mut)
        .ok_or_else(|| {
            TransactionFailure::new(
                "unsafe_layer_projection",
                "layer profile is missing from the revision-tagged catalog",
            )
        })?;
    let canonical_id = raw_profile
        .get("id")
        .and_then(serde_json::Value::as_str)
        .ok_or_else(|| {
            TransactionFailure::new(
                "unsafe_layer_projection",
                "layer profile identifier is malformed",
            )
        })?
        .to_owned();
    let primary = raw_profile.get("customization").cloned();
    let selected = match variant {
        ConfigurationVariant::Primary => primary.clone(),
        ConfigurationVariant::Landscape => raw_profile
            .get("landscapeCustomization")
            .cloned()
            .or_else(|| primary.clone()),
        ConfigurationVariant::Portrait => raw_profile
            .get("portraitCustomization")
            .cloned()
            .or(primary),
    }
    .filter(serde_json::Value::is_object)
    .ok_or_else(|| {
        TransactionFailure::new(
            "unsafe_layer_projection",
            "layer variant has no bounded customization source",
        )
    })?;
    raw_profile.insert("customization".to_owned(), selected);
    raw_profile.remove("landscapeCustomization");
    raw_profile.remove("portraitCustomization");
    raw_profile.insert(
        "orientationPreference".to_owned(),
        serde_json::Value::String("automatic".to_owned()),
    );
    snapshot_state.active_profile_id = canonical_id;
    let layers = snapshot_state
        .controller_snapshot()
        .map_err(|_| {
            TransactionFailure::new(
                "unsafe_layer_projection",
                "layer order could not be reduced to a bounded safe projection",
            )
        })?
        .layers;
    Ok(CliLayerProjection {
        configuration_revision: catalog.configuration_revision,
        profile_id: profile.profile_id,
        profile_name: profile.name.clone(),
        variant,
        layers,
    })
}

fn group_projection_from_state(
    state: &PersistentState,
    target: &ProfileSelector,
    variant: ConfigurationVariant,
    catalog: &CliProfileCatalog,
) -> Result<CliGroupProjection, TransactionFailure> {
    let profile = resolve_selector(target, catalog)?;
    let mut snapshot_state = state.clone();
    let raw_profile = snapshot_state
        .profiles
        .get_mut(profile.index)
        .and_then(serde_json::Value::as_object_mut)
        .ok_or_else(|| {
            TransactionFailure::new(
                "unsafe_group_projection",
                "group profile is missing from the revision-tagged catalog",
            )
        })?;
    let canonical_id = raw_profile
        .get("id")
        .and_then(serde_json::Value::as_str)
        .ok_or_else(|| {
            TransactionFailure::new(
                "unsafe_group_projection",
                "group profile identifier is malformed",
            )
        })?
        .to_owned();
    let primary = raw_profile.get("customization").cloned();
    let selected = match variant {
        ConfigurationVariant::Primary => primary.clone(),
        ConfigurationVariant::Landscape => raw_profile
            .get("landscapeCustomization")
            .cloned()
            .or_else(|| primary.clone()),
        ConfigurationVariant::Portrait => raw_profile
            .get("portraitCustomization")
            .cloned()
            .or(primary),
    }
    .filter(serde_json::Value::is_object)
    .ok_or_else(|| {
        TransactionFailure::new(
            "unsafe_group_projection",
            "group variant has no bounded customization source",
        )
    })?;
    raw_profile.insert("customization".to_owned(), selected);
    raw_profile.remove("landscapeCustomization");
    raw_profile.remove("portraitCustomization");
    raw_profile.insert(
        "orientationPreference".to_owned(),
        serde_json::Value::String("automatic".to_owned()),
    );
    snapshot_state.active_profile_id = canonical_id;
    let groups = snapshot_state
        .controller_snapshot()
        .map_err(|_| {
            TransactionFailure::new(
                "unsafe_group_projection",
                "group metadata could not be reduced to a bounded safe projection",
            )
        })?
        .groups;
    if groups.len() > 64 || groups.iter().any(|group| group.child_target_ids.len() > 64) {
        return Err(TransactionFailure::new(
            "unsafe_group_projection",
            "group metadata exceeds the bounded safe projection",
        ));
    }
    Ok(CliGroupProjection {
        configuration_revision: catalog.configuration_revision,
        profile_id: profile.profile_id,
        profile_name: profile.name.clone(),
        variant,
        groups,
    })
}

fn style_projection_from_state(
    state: &PersistentState,
    target: &ProfileSelector,
    style_id: Option<&str>,
    catalog: &CliProfileCatalog,
) -> Result<CliStyleProjection, TransactionFailure> {
    let profile = resolve_selector(target, catalog)?;
    let mut snapshot_state = state.clone();
    let raw_profile = snapshot_state
        .profiles
        .get_mut(profile.index)
        .and_then(serde_json::Value::as_object_mut)
        .ok_or_else(|| {
            TransactionFailure::new(
                "unsafe_style_projection",
                "style profile is missing from the revision-tagged catalog",
            )
        })?;
    let canonical_id = raw_profile
        .get("id")
        .and_then(serde_json::Value::as_str)
        .ok_or_else(|| {
            TransactionFailure::new(
                "unsafe_style_projection",
                "style profile identifier is malformed",
            )
        })?
        .to_owned();
    // Resource operations synchronize style libraries across saved variants.
    // Force the credential-redacting controller sanitizer to inspect primary,
    // matching the standalone style list/show source without exposing a profile.
    raw_profile.remove("landscapeCustomization");
    raw_profile.remove("portraitCustomization");
    raw_profile.insert(
        "orientationPreference".to_owned(),
        serde_json::Value::String("automatic".to_owned()),
    );
    snapshot_state.active_profile_id = canonical_id;
    let mut styles = snapshot_state
        .controller_snapshot()
        .map_err(|_| {
            TransactionFailure::new(
                "unsafe_style_projection",
                "style library could not be reduced to a bounded safe projection",
            )
        })?
        .styles;
    if let Some(style_id) = style_id {
        if style_id.is_empty()
            || style_id.chars().count() > 128
            || style_id.chars().any(char::is_control)
        {
            return Err(TransactionFailure::new(
                "invalid_style",
                "style identifier is outside safe bounds",
            ));
        }
        styles.retain(|style| style.id.eq_ignore_ascii_case(style_id));
        if styles.len() != 1 {
            return Err(TransactionFailure::new(
                "style_not_found",
                "style identifier did not resolve to one sanitized definition",
            ));
        }
    }
    Ok(CliStyleProjection {
        configuration_revision: catalog.configuration_revision,
        profile_id: profile.profile_id,
        profile_name: profile.name.clone(),
        styles,
    })
}

fn control_bar_projection_from_state(
    state: &PersistentState,
    target: &ProfileSelector,
    variant: ConfigurationVariant,
    catalog: &CliProfileCatalog,
) -> Result<CliControlBarProjection, TransactionFailure> {
    let profile = resolve_selector(target, catalog)?;
    let raw_profile = state.profiles.get(profile.index).ok_or_else(|| {
        TransactionFailure::new(
            "unsafe_profile_catalog",
            "control-bar profile is missing from the revision-tagged catalog",
        )
    })?;
    let primary = raw_profile
        .get("customization")
        .filter(|value| value.is_object());
    let selected = match variant {
        ConfigurationVariant::Primary => primary,
        ConfigurationVariant::Landscape => raw_profile
            .get("landscapeCustomization")
            .filter(|value| value.is_object())
            .or(primary),
        ConfigurationVariant::Portrait => raw_profile
            .get("portraitCustomization")
            .filter(|value| value.is_object())
            .or(primary),
    }
    .and_then(serde_json::Value::as_object)
    .ok_or_else(|| {
        TransactionFailure::new(
            "unsafe_control_bar_projection",
            "profile variant has no bounded control-bar source",
        )
    })?;
    let values = selected.get("controlBarItems");
    let items = match values {
        None | Some(serde_json::Value::Null) => vec![
            ConfigurationControlBarItem::Status,
            ConfigurationControlBarItem::ProfileMenu,
            ConfigurationControlBarItem::LaunchTarget,
            ConfigurationControlBarItem::Spacer,
            ConfigurationControlBarItem::EditLayout,
            ConfigurationControlBarItem::Settings,
            ConfigurationControlBarItem::Home,
            ConfigurationControlBarItem::Connection,
        ],
        Some(value) => {
            let values = value.as_array().ok_or_else(|| {
                TransactionFailure::new(
                    "unsafe_control_bar_projection",
                    "control-bar item collection is malformed",
                )
            })?;
            if values.len() > 8 {
                return Err(TransactionFailure::new(
                    "unsafe_control_bar_projection",
                    "control-bar item collection exceeds its bound",
                ));
            }
            values
                .iter()
                .cloned()
                .map(|value| {
                    serde_json::from_value(value).map_err(|_| {
                        TransactionFailure::new(
                            "unsafe_control_bar_projection",
                            "control-bar item collection contains an unsupported item",
                        )
                    })
                })
                .collect::<Result<Vec<_>, _>>()?
        }
    };
    let mut unique = std::collections::HashSet::new();
    if !items.iter().copied().all(|item| unique.insert(item)) {
        return Err(TransactionFailure::new(
            "unsafe_control_bar_projection",
            "control-bar item collection contains duplicates",
        ));
    }
    Ok(CliControlBarProjection {
        configuration_revision: catalog.configuration_revision,
        profile_id: profile.profile_id,
        profile_name: profile.name.clone(),
        variant,
        items: items
            .into_iter()
            .enumerate()
            .map(|(index, item)| CliControlBarItemSummary {
                order: index + 1,
                item,
            })
            .collect(),
    })
}

fn device_projection_from_state(
    state: &PersistentState,
    target: &ProfileSelector,
    variant: ConfigurationVariant,
    catalog: &CliProfileCatalog,
) -> Result<CliDeviceProjection, TransactionFailure> {
    let profile = resolve_selector(target, catalog)?;
    let raw_profile = state.profiles.get(profile.index).ok_or_else(|| {
        TransactionFailure::new(
            "unsafe_device_projection",
            "device profile is missing from the revision-tagged catalog",
        )
    })?;
    let primary = raw_profile
        .get("customization")
        .filter(|value| value.is_object());
    let selected = match variant {
        ConfigurationVariant::Primary => primary,
        ConfigurationVariant::Landscape => raw_profile
            .get("landscapeCustomization")
            .filter(|value| value.is_object())
            .or(primary),
        ConfigurationVariant::Portrait => raw_profile
            .get("portraitCustomization")
            .filter(|value| value.is_object())
            .or(primary),
    }
    .ok_or_else(|| {
        TransactionFailure::new(
            "unsafe_device_projection",
            "profile variant has no bounded device source",
        )
    })?;
    let frame_id = selected
        .get("deviceCanvas")
        .and_then(|canvas| canvas.get("frameID"))
        .and_then(serde_json::Value::as_str)
        .unwrap_or("iphone-17-pro-landscape");
    let frame_orientation = if frame_id.ends_with("-landscape") {
        OrientationVariant::Landscape
    } else if frame_id.ends_with("-portrait") {
        OrientationVariant::Portrait
    } else {
        return Err(TransactionFailure::new(
            "unsafe_device_projection",
            "stored device frame has no safe orientation",
        ));
    };
    let (frame_id, custom_width, custom_height) = if is_supported_device_frame_id(frame_id) {
        (Some(frame_id.to_owned()), None, None)
    } else if let Some((width, height)) = safe_custom_frame_dimensions(frame_id) {
        (None, Some(width), Some(height))
    } else {
        return Err(TransactionFailure::new(
            "unsafe_device_projection",
            "stored device frame is outside the checked-in or bounded custom catalog",
        ));
    };
    Ok(CliDeviceProjection {
        configuration_revision: catalog.configuration_revision,
        profile_id: profile.profile_id,
        profile_name: profile.name.clone(),
        variant,
        frame_id,
        custom_width,
        custom_height,
        frame_orientation,
    })
}

fn safe_custom_frame_dimensions(frame_id: &str) -> Option<(u16, u16)> {
    let body = frame_id.strip_prefix("custom-")?;
    let dimensions = body
        .strip_suffix("-landscape")
        .or_else(|| body.strip_suffix("-portrait"))?;
    let (width, height) = dimensions.split_once('x')?;
    if width.is_empty()
        || height.is_empty()
        || !width.bytes().all(|byte| byte.is_ascii_digit())
        || !height.bytes().all(|byte| byte.is_ascii_digit())
    {
        return None;
    }
    let width = width.parse::<u16>().ok()?;
    let height = height.parse::<u16>().ok()?;
    ((240..=1_800).contains(&width) && (240..=1_800).contains(&height)).then_some((width, height))
}

fn control_bar_item_projection_from_state(
    state: &PersistentState,
    target: &ProfileSelector,
    variant: ConfigurationVariant,
    item: ConfigurationControlBarItem,
    catalog: &CliProfileCatalog,
) -> Result<CliControlBarItemProjection, TransactionFailure> {
    let collection = control_bar_projection_from_state(state, target, variant, catalog)?;
    let order = collection
        .items
        .iter()
        .find(|summary| summary.item == item)
        .map(|summary| summary.order)
        .ok_or_else(|| {
            TransactionFailure::new(
                "control_bar_item_not_found",
                "selected item is not present in the control-bar variant",
            )
        })?;
    let profile = resolve_selector(target, catalog)?;
    let raw_profile = state.profiles.get(profile.index).ok_or_else(|| {
        TransactionFailure::new(
            "unsafe_profile_catalog",
            "control-bar item profile is missing from the revision-tagged catalog",
        )
    })?;
    let primary = raw_profile
        .get("customization")
        .filter(|value| value.is_object());
    let selected = match variant {
        ConfigurationVariant::Primary => primary,
        ConfigurationVariant::Landscape => raw_profile
            .get("landscapeCustomization")
            .filter(|value| value.is_object())
            .or(primary),
        ConfigurationVariant::Portrait => raw_profile
            .get("portraitCustomization")
            .filter(|value| value.is_object())
            .or(primary),
    }
    .cloned()
    .ok_or_else(|| {
        TransactionFailure::new(
            "unsafe_control_bar_projection",
            "profile variant has no bounded control-bar item source",
        )
    })?;

    // Reuse the hardened MCP snapshot sanitizer against an in-memory selected
    // profile/variant view. No state, credentials, bindings, or raw profile
    // document crosses this boundary.
    let mut projection_state = state.clone();
    projection_state.active_profile_id = profile.profile_id.hyphenated().to_string();
    let selected_profile = projection_state
        .profiles
        .get_mut(profile.index)
        .and_then(serde_json::Value::as_object_mut)
        .ok_or_else(|| {
            TransactionFailure::new(
                "unsafe_control_bar_projection",
                "selected control-bar profile is malformed",
            )
        })?;
    selected_profile.insert("customization".to_owned(), selected.clone());
    selected_profile.insert("landscapeCustomization".to_owned(), selected.clone());
    selected_profile.insert("portraitCustomization".to_owned(), selected);
    let snapshot = projection_state.controller_snapshot().map_err(|_| {
        TransactionFailure::new(
            "unsafe_control_bar_projection",
            "control-bar item could not be sanitized into a bounded projection",
        )
    })?;
    let item_name = serde_json::to_value(item)
        .ok()
        .and_then(|value| value.as_str().map(str::to_owned))
        .ok_or_else(|| {
            TransactionFailure::new(
                "unsafe_control_bar_projection",
                "control-bar item identifier could not be sanitized",
            )
        })?;
    let appearance = snapshot
        .control_bar_items
        .into_iter()
        .find(|candidate| candidate.item == item_name)
        .ok_or_else(|| {
            TransactionFailure::new(
                "control_bar_item_not_found",
                "selected item is not present in the sanitized control-bar variant",
            )
        })?;
    Ok(CliControlBarItemProjection {
        configuration_revision: catalog.configuration_revision,
        profile_id: collection.profile_id,
        profile_name: collection.profile_name,
        variant,
        order,
        item,
        appearance,
    })
}

fn binding_output_projection_from_state(
    state: &PersistentState,
    command: &CliProfileCommand,
    catalog: &CliProfileCatalog,
) -> Result<CliBindingOutputProjection, TransactionFailure> {
    let target = match command {
        CliProfileCommand::BindingList { target }
        | CliProfileCommand::BindingDisplay { target }
        | CliProfileCommand::OutputList { target }
        | CliProfileCommand::OutputModeGet { target } => target,
        _ => {
            return Err(TransactionFailure::new(
                "invalid_request",
                "binding/output projection requires a read command",
            ));
        }
    };
    let profile = resolve_selector(target, catalog)?;
    let raw_profile = state.profiles.get(profile.index).ok_or_else(|| {
        TransactionFailure::new(
            "unsafe_profile_catalog",
            "binding/output profile is missing from the revision-tagged catalog",
        )
    })?;
    let mode = profile_output_mode(raw_profile)?;
    let profile_id = profile.profile_id.hyphenated().to_string();
    // Legacy Swift profiles may predate per-profile maps. Match the standalone
    // CLI's bounded default-map fallback without materializing or exposing it
    // until a real transaction writes that selected profile.
    let fallback_keys = crate::bridge::default_recommended_keys();
    let key_bindings = state
        .profile_key_bindings
        .iter()
        .find(|(id, _)| id.eq_ignore_ascii_case(&profile_id))
        .map(|(_, bindings)| bindings)
        .unwrap_or(&fallback_keys);
    let mut fallback_outputs = thumble_core::ButtonBindings::default();
    crate::bridge::replace_with_keyboard_outputs(&mut fallback_outputs, key_bindings);
    let custom_outputs = state
        .profile_output_bindings
        .iter()
        .find(|(id, _)| id.eq_ignore_ascii_case(&profile_id))
        .map(|(_, bindings)| bindings)
        .unwrap_or(&fallback_outputs);
    let effective_outputs = effective_output_map(mode, key_bindings, custom_outputs);
    let (kind, rows, display_groups) = match command {
        CliProfileCommand::BindingList { .. } => (
            CliProjectionKind::BindingList,
            Some(binding_rows(key_bindings)?),
            None,
        ),
        CliProfileCommand::OutputList { .. } => (
            CliProjectionKind::OutputList,
            Some(output_rows(&effective_outputs)?),
            None,
        ),
        CliProfileCommand::OutputModeGet { .. } => (CliProjectionKind::OutputMode, None, None),
        CliProfileCommand::BindingDisplay { .. } => (
            CliProjectionKind::BindingDisplay,
            None,
            Some(binding_display_groups(raw_profile, &effective_outputs)?),
        ),
        _ => unreachable!(),
    };
    Ok(CliBindingOutputProjection {
        kind,
        configuration_revision: catalog.configuration_revision,
        profile_id: profile.profile_id,
        profile_name: profile.name.clone(),
        output_mode: Some(mode),
        rows,
        display_groups,
    })
}

fn profile_output_mode(
    profile: &serde_json::Value,
) -> Result<ConfigurationOutputMode, TransactionFailure> {
    match profile
        .get("outputMode")
        .and_then(serde_json::Value::as_str)
        .unwrap_or("custom")
    {
        "keyboard" => Ok(ConfigurationOutputMode::Keyboard),
        "controller" => Ok(ConfigurationOutputMode::Controller),
        "custom" => Ok(ConfigurationOutputMode::Custom),
        _ => Err(TransactionFailure::new(
            "unsafe_binding_projection",
            "profile output mode is outside the typed projection",
        )),
    }
}

fn effective_output_map(
    mode: ConfigurationOutputMode,
    keys: &thumble_core::ButtonBindings<KeyBinding>,
    custom: &thumble_core::ButtonBindings<OutputBinding>,
) -> thumble_core::ButtonBindings<OutputBinding> {
    match mode {
        ConfigurationOutputMode::Keyboard => keyboard_output_map(keys),
        ConfigurationOutputMode::Controller => controller_output_map(),
        ConfigurationOutputMode::Custom if custom.is_empty() => keyboard_output_map(keys),
        ConfigurationOutputMode::Custom => custom.clone(),
    }
}

fn keyboard_output_map(
    keys: &thumble_core::ButtonBindings<KeyBinding>,
) -> thumble_core::ButtonBindings<OutputBinding> {
    let mut outputs = thumble_core::ButtonBindings::default();
    for button in GameButton::ALL {
        if let Some(binding) = keys.get(&button) {
            outputs.insert(button, OutputBinding::keyboard(binding.clone()));
        }
    }
    outputs
}

fn controller_output_map() -> thumble_core::ButtonBindings<OutputBinding> {
    let mut outputs = thumble_core::ButtonBindings::default();
    for (button, gamepad) in [
        (GameButton::Up, "dpadUp"),
        (GameButton::Down, "dpadDown"),
        (GameButton::Left, "dpadLeft"),
        (GameButton::Right, "dpadRight"),
        (GameButton::Jump, "south"),
        (GameButton::Attack, "east"),
        (GameButton::Dash, "west"),
        (GameButton::Focus, "north"),
        (GameButton::Map, "select"),
        (GameButton::Pause, "start"),
        (GameButton::Custom1, "leftShoulder"),
        (GameButton::Custom2, "rightShoulder"),
        (GameButton::Custom3, "leftStickPress"),
        (GameButton::Custom4, "rightStickPress"),
        (GameButton::Custom5, "leftTriggerButton"),
        (GameButton::Custom6, "rightTriggerButton"),
        (GameButton::Custom7, "home"),
    ] {
        let mut output = OutputBinding::default();
        output.gamepad_buttons.insert(gamepad.to_owned());
        outputs.insert(button, output);
    }
    outputs
}

fn binding_rows(
    bindings: &thumble_core::ButtonBindings<KeyBinding>,
) -> Result<Vec<CliBindingOutputRow>, TransactionFailure> {
    GameButton::ALL
        .into_iter()
        .map(|button| {
            Ok(CliBindingOutputRow {
                button,
                output: bindings
                    .get(&button)
                    .map(|binding| semantic_output(Some(binding), std::iter::empty()))
                    .transpose()?,
            })
        })
        .collect()
}

fn output_rows(
    bindings: &thumble_core::ButtonBindings<OutputBinding>,
) -> Result<Vec<CliBindingOutputRow>, TransactionFailure> {
    GameButton::ALL
        .into_iter()
        .map(|button| {
            Ok(CliBindingOutputRow {
                button,
                output: bindings
                    .get(&button)
                    .map(|output| {
                        semantic_output(
                            output.keyboard.as_ref(),
                            output.gamepad_buttons.iter().map(String::as_str),
                        )
                    })
                    .transpose()?,
            })
        })
        .collect()
}

fn semantic_output<'a>(
    keyboard: Option<&KeyBinding>,
    gamepad_buttons: impl Iterator<Item = &'a str>,
) -> Result<CliSemanticOutput, TransactionFailure> {
    let keyboard = keyboard
        .map(semantic_keyboard)
        .transpose()?
        .unwrap_or_default();
    let gamepad_buttons = gamepad_buttons
        .map(configuration_gamepad_button)
        .collect::<Result<Vec<_>, _>>()?;
    if gamepad_buttons.len() > 17 {
        return Err(TransactionFailure::new(
            "unsafe_binding_projection",
            "gamepad output exceeds its semantic projection bound",
        ));
    }
    Ok(CliSemanticOutput {
        keyboard,
        gamepad_buttons,
    })
}

fn semantic_keyboard(binding: &KeyBinding) -> Result<Vec<SemanticKeyStroke>, TransactionFailure> {
    let strokes = binding.strokes();
    if strokes.is_empty() || strokes.len() > 32 {
        return Err(TransactionFailure::new(
            "unsafe_binding_projection",
            "keyboard sequence exceeds its semantic projection bound",
        ));
    }
    strokes
        .into_iter()
        .map(|stroke| {
            let key =
                crate::draft_operation::semantic_key_name(stroke.key_code).ok_or_else(|| {
                    TransactionFailure::new(
                        "unsafe_binding_projection",
                        "keyboard binding contains an unsupported semantic key",
                    )
                })?;
            if stroke.modifiers > 15 {
                return Err(TransactionFailure::new(
                    "unsafe_binding_projection",
                    "keyboard binding contains unsupported modifier bits",
                ));
            }
            let mut modifiers = Vec::new();
            for (bit, modifier) in [
                (1, SemanticModifier::Command),
                (2, SemanticModifier::Shift),
                (4, SemanticModifier::Option),
                (8, SemanticModifier::Control),
            ] {
                if stroke.modifiers & bit != 0 {
                    modifiers.push(modifier);
                }
            }
            Ok(SemanticKeyStroke {
                key: key.to_owned(),
                modifiers,
            })
        })
        .collect()
}

fn configuration_gamepad_button(
    value: &str,
) -> Result<ConfigurationGamepadButton, TransactionFailure> {
    serde_json::from_value(serde_json::Value::String(value.to_owned())).map_err(|_| {
        TransactionFailure::new(
            "unsafe_binding_projection",
            "output contains an unsupported virtual gamepad button",
        )
    })
}

fn binding_display_groups(
    profile: &serde_json::Value,
    effective_outputs: &thumble_core::ButtonBindings<OutputBinding>,
) -> Result<Vec<CliBindingDisplayGroup>, TransactionFailure> {
    let landscape = binding_display_entries(
        orientation_customization(profile, OrientationVariant::Landscape)?,
        effective_outputs,
    )?;
    let portrait = binding_display_entries(
        orientation_customization(profile, OrientationVariant::Portrait)?,
        effective_outputs,
    )?;
    if landscape == portrait {
        Ok(vec![CliBindingDisplayGroup {
            orientation: None,
            entries: landscape,
        }])
    } else {
        Ok(vec![
            CliBindingDisplayGroup {
                orientation: Some(OrientationVariant::Landscape),
                entries: landscape,
            },
            CliBindingDisplayGroup {
                orientation: Some(OrientationVariant::Portrait),
                entries: portrait,
            },
        ])
    }
}

fn orientation_customization(
    profile: &serde_json::Value,
    orientation: OrientationVariant,
) -> Result<&serde_json::Value, TransactionFailure> {
    let key = match orientation {
        OrientationVariant::Landscape => "landscapeCustomization",
        OrientationVariant::Portrait => "portraitCustomization",
    };
    profile
        .get(key)
        .or_else(|| profile.get("customization"))
        .filter(|value| value.is_object())
        .ok_or_else(|| {
            TransactionFailure::new(
                "unsafe_binding_projection",
                "profile orientation has no bounded customization source",
            )
        })
}

fn binding_display_entries(
    customization: &serde_json::Value,
    effective_outputs: &thumble_core::ButtonBindings<OutputBinding>,
) -> Result<Vec<CliBindingDisplayEntry>, TransactionFailure> {
    let elements = normalized_binding_elements(customization)?;
    let mut entries = Vec::new();
    for element in elements {
        let element_id = element
            .get("id")
            .and_then(serde_json::Value::as_str)
            .and_then(|id| Uuid::parse_str(id).ok())
            .ok_or_else(|| {
                TransactionFailure::new(
                    "unsafe_binding_projection",
                    "binding display element ID is not an exact UUID",
                )
            })?;
        let kind = element
            .get("kind")
            .and_then(serde_json::Value::as_str)
            .unwrap_or("button");
        if !matches!(
            kind,
            "button" | "joystick" | "trigger" | "trackpad" | "text" | "decoration"
        ) {
            return Err(TransactionFailure::new(
                "unsafe_binding_projection",
                "binding display element kind is unsupported",
            ));
        }
        let explicit_parts = safe_part_outputs(&element)?;
        let mut parts = vec![KeypadElementInputPart::Primary];
        for part in explicit_parts.keys().copied() {
            if !parts.contains(&part) {
                parts.push(part);
            }
        }
        if kind == "joystick" {
            for part in [
                KeypadElementInputPart::JoystickUp,
                KeypadElementInputPart::JoystickDown,
                KeypadElementInputPart::JoystickLeft,
                KeypadElementInputPart::JoystickRight,
            ] {
                if !parts.contains(&part) {
                    parts.push(part);
                }
            }
        }
        if kind == "trigger" && !parts.contains(&KeypadElementInputPart::TriggerDigital) {
            parts.push(KeypadElementInputPart::TriggerDigital);
        }
        parts.sort_by_key(|part| element_part_order(*part));
        for part in parts {
            let direct = if part == KeypadElementInputPart::Primary {
                element
                    .get("output")
                    .map(parse_safe_output)
                    .transpose()?
                    .filter(|output| {
                        output.keyboard.is_some() || !output.gamepad_buttons.is_empty()
                    })
            } else {
                explicit_parts.get(&part).cloned()
            };
            let output = match direct {
                Some(output) => Some(output),
                None => legacy_button_for_part(&element, part)?
                    .and_then(|button| effective_outputs.get(&button).cloned()),
            };
            let Some(output) = output else { continue };
            let output = semantic_output(
                output.keyboard.as_ref(),
                output.gamepad_buttons.iter().map(String::as_str),
            )?;
            if output.keyboard.is_empty() && output.gamepad_buttons.is_empty() {
                continue;
            }
            entries.push(CliBindingDisplayEntry {
                element_id,
                part,
                output,
            });
            if entries.len() > 128 * 6 {
                return Err(TransactionFailure::new(
                    "unsafe_binding_projection",
                    "binding display exceeds its bounded entry count",
                ));
            }
        }
    }
    entries.sort_by(|left, right| {
        left.element_id
            .hyphenated()
            .to_string()
            .cmp(&right.element_id.hyphenated().to_string())
            .then_with(|| element_part_order(left.part).cmp(&element_part_order(right.part)))
    });
    Ok(entries)
}

fn normalized_binding_elements(
    customization: &serde_json::Value,
) -> Result<Vec<serde_json::Value>, TransactionFailure> {
    let object = customization.as_object().ok_or_else(|| {
        TransactionFailure::new(
            "unsafe_binding_projection",
            "binding display customization is malformed",
        )
    })?;
    let source = object
        .get("elements")
        .and_then(serde_json::Value::as_array)
        .cloned()
        .unwrap_or_default();
    if source.len() > 128 {
        return Err(TransactionFailure::new(
            "unsafe_binding_projection",
            "binding display source element count is too large",
        ));
    }
    let mut result = Vec::new();
    let mut seen = BTreeSet::new();
    for element in source {
        let Some(id) = element.get("id").and_then(serde_json::Value::as_str) else {
            return Err(TransactionFailure::new(
                "unsafe_binding_projection",
                "binding display element is missing an identifier",
            ));
        };
        let id = Uuid::parse_str(id).map_err(|_| {
            TransactionFailure::new(
                "unsafe_binding_projection",
                "binding display element identifier is malformed",
            )
        })?;
        if !seen.insert(id) || !element.is_object() {
            return Err(TransactionFailure::new(
                "unsafe_binding_projection",
                "binding display elements contain duplicates or malformed values",
            ));
        }
        result.push(element);
    }
    for button in [
        GameButton::Up,
        GameButton::Down,
        GameButton::Left,
        GameButton::Right,
        GameButton::Jump,
        GameButton::Attack,
        GameButton::Dash,
        GameButton::Focus,
        GameButton::Map,
        GameButton::Pause,
    ] {
        let id = built_in_element_id(button);
        if seen.insert(id) {
            result.push(serde_json::json!({
                "id": id.hyphenated().to_string(),
                "builtInButton": button,
                "legacySlot": button,
                "kind": "button"
            }));
        }
    }
    if let Some(custom_buttons) = object
        .get("customButtons")
        .and_then(serde_json::Value::as_array)
    {
        if custom_buttons.len() > 64 {
            return Err(TransactionFailure::new(
                "unsafe_binding_projection",
                "binding display custom-control count is too large",
            ));
        }
        for custom in custom_buttons {
            let id = custom
                .get("id")
                .and_then(serde_json::Value::as_str)
                .and_then(|id| Uuid::parse_str(id).ok())
                .ok_or_else(|| {
                    TransactionFailure::new(
                        "unsafe_binding_projection",
                        "binding display custom control has a malformed identifier",
                    )
                })?;
            if seen.insert(id) {
                result.push(serde_json::json!({
                    "id": id.hyphenated().to_string(),
                    "legacySlot": custom.get("mappedButton").cloned().unwrap_or(serde_json::json!("jump")),
                    "kind": custom.get("controlKind").cloned().unwrap_or(serde_json::json!("button")),
                    "joystickMapping": custom.get("joystickMapping").cloned()
                }));
            }
        }
    }
    if result.len() > 128 {
        return Err(TransactionFailure::new(
            "unsafe_binding_projection",
            "normalized binding display element count is too large",
        ));
    }
    Ok(result)
}

fn safe_part_outputs(
    element: &serde_json::Value,
) -> Result<std::collections::HashMap<KeypadElementInputPart, OutputBinding>, TransactionFailure> {
    let Some(value) = element.get("partOutputs") else {
        return Ok(std::collections::HashMap::new());
    };
    let values = value.as_array().ok_or_else(|| {
        TransactionFailure::new(
            "unsafe_binding_projection",
            "element part outputs are malformed",
        )
    })?;
    if values.len() % 2 != 0 || values.len() > 12 {
        return Err(TransactionFailure::new(
            "unsafe_binding_projection",
            "element part outputs exceed their typed bound",
        ));
    }
    let mut result = std::collections::HashMap::new();
    for pair in values.chunks_exact(2) {
        let part: KeypadElementInputPart =
            serde_json::from_value(pair[0].clone()).map_err(|_| {
                TransactionFailure::new(
                    "unsafe_binding_projection",
                    "element part output uses an unsupported part",
                )
            })?;
        let output = parse_safe_output(&pair[1])?;
        if result.insert(part, output).is_some() {
            return Err(TransactionFailure::new(
                "unsafe_binding_projection",
                "element part output is duplicated",
            ));
        }
    }
    Ok(result)
}

fn parse_safe_output(value: &serde_json::Value) -> Result<OutputBinding, TransactionFailure> {
    let object = value.as_object().ok_or_else(|| {
        TransactionFailure::new("unsafe_binding_projection", "element output is malformed")
    })?;
    if object
        .keys()
        .any(|key| !matches!(key.as_str(), "keyboard" | "gamepadButtons"))
        || object
            .get("keyboard")
            .is_some_and(|keyboard| !safe_keyboard_json(keyboard))
    {
        return Err(TransactionFailure::new(
            "unsafe_binding_projection",
            "element output contains unsupported content",
        ));
    }
    serde_json::from_value(value.clone()).map_err(|_| {
        TransactionFailure::new(
            "unsafe_binding_projection",
            "element output could not be converted to a semantic projection",
        )
    })
}

fn safe_keyboard_json(value: &serde_json::Value) -> bool {
    let Some(object) = value.as_object() else {
        return false;
    };
    if object.keys().any(|key| {
        !matches!(
            key.as_str(),
            "keyCode" | "modifiers" | "modifiersRawValue" | "sequence"
        )
    }) {
        return false;
    }
    object.get("sequence").is_none_or(|sequence| {
        sequence.as_array().is_some_and(|strokes| {
            !strokes.is_empty()
                && strokes.len() <= 32
                && strokes.iter().all(|stroke| {
                    stroke.as_object().is_some_and(|stroke| {
                        stroke.keys().all(|key| {
                            matches!(key.as_str(), "keyCode" | "modifiers" | "modifiersRawValue")
                        })
                    })
                })
        })
    })
}

fn legacy_button_for_part(
    element: &serde_json::Value,
    part: KeypadElementInputPart,
) -> Result<Option<GameButton>, TransactionFailure> {
    let value = match part {
        KeypadElementInputPart::Primary | KeypadElementInputPart::TriggerDigital => element
            .get("legacySlot")
            .or_else(|| element.get("builtInButton"))
            .cloned(),
        KeypadElementInputPart::JoystickUp
        | KeypadElementInputPart::JoystickDown
        | KeypadElementInputPart::JoystickLeft
        | KeypadElementInputPart::JoystickRight => {
            let key = match part {
                KeypadElementInputPart::JoystickUp => "up",
                KeypadElementInputPart::JoystickDown => "down",
                KeypadElementInputPart::JoystickLeft => "left",
                KeypadElementInputPart::JoystickRight => "right",
                _ => unreachable!(),
            };
            element
                .get("joystickMapping")
                .and_then(serde_json::Value::as_object)
                .and_then(|mapping| mapping.get(key))
                .cloned()
                .or_else(|| Some(serde_json::Value::String(key.to_owned())))
        }
    };
    value
        .map(|value| {
            serde_json::from_value(value).map_err(|_| {
                TransactionFailure::new(
                    "unsafe_binding_projection",
                    "element legacy mapping uses an unsupported button",
                )
            })
        })
        .transpose()
}

const fn element_part_order(part: KeypadElementInputPart) -> u8 {
    match part {
        KeypadElementInputPart::Primary => 0,
        KeypadElementInputPart::JoystickUp => 1,
        KeypadElementInputPart::JoystickDown => 2,
        KeypadElementInputPart::JoystickLeft => 3,
        KeypadElementInputPart::JoystickRight => 4,
        KeypadElementInputPart::TriggerDigital => 5,
    }
}

fn built_in_element_id(button: GameButton) -> Uuid {
    let suffix = match button {
        GameButton::Up => 101,
        GameButton::Down => 102,
        GameButton::Left => 103,
        GameButton::Right => 104,
        GameButton::Jump => 105,
        GameButton::Attack => 106,
        GameButton::Dash => 107,
        GameButton::Focus => 108,
        GameButton::Map => 109,
        GameButton::Pause => 110,
        GameButton::Custom1 => 111,
        GameButton::Custom2 => 112,
        GameButton::Custom3 => 113,
        GameButton::Custom4 => 114,
        GameButton::Custom5 => 115,
        GameButton::Custom6 => 116,
        GameButton::Custom7 => 117,
        GameButton::Custom8 => 118,
    };
    Uuid::parse_str(&format!("00000000-0000-0000-0000-{suffix:012}")).expect("fixed UUID")
}

fn orientation_source_exists(profile: &serde_json::Value, source: OrientationVariant) -> bool {
    let source_key = match source {
        OrientationVariant::Landscape => "landscapeCustomization",
        OrientationVariant::Portrait => "portraitCustomization",
    };
    if profile
        .get(source_key)
        .is_some_and(serde_json::Value::is_object)
    {
        return true;
    }
    profile
        .get("customization")
        .and_then(customization_orientation)
        == Some(source)
}

fn customization_orientation(customization: &serde_json::Value) -> Option<OrientationVariant> {
    let frame_id = customization
        .get("deviceCanvas")
        .and_then(|canvas| canvas.get("frameID"))
        .and_then(serde_json::Value::as_str)
        .unwrap_or("iphone-17-pro-landscape");
    let catalog: serde_json::Value =
        serde_json::from_str(include_str!("../../../../docs/mcp/device-frames-v1.json")).ok()?;
    if let Some(orientation) = catalog
        .get("frames")
        .and_then(serde_json::Value::as_array)
        .and_then(|frames| {
            frames.iter().find_map(|frame| {
                (frame.get("id").and_then(serde_json::Value::as_str) == Some(frame_id))
                    .then(|| frame.get("orientation").and_then(serde_json::Value::as_str))
                    .flatten()
            })
        })
    {
        return match orientation {
            "landscape" => Some(OrientationVariant::Landscape),
            "portrait" => Some(OrientationVariant::Portrait),
            _ => None,
        };
    }
    if frame_id.ends_with("-landscape") {
        Some(OrientationVariant::Landscape)
    } else if frame_id.ends_with("-portrait") {
        Some(OrientationVariant::Portrait)
    } else {
        None
    }
}

const fn orientation_name(orientation: OrientationVariant) -> &'static str {
    match orientation {
        OrientationVariant::Landscape => "landscape",
        OrientationVariant::Portrait => "portrait",
    }
}

fn catalog_from_document(
    document: &ConfigurationDocument,
    revision: u64,
    state: &PersistentState,
) -> Result<CliProfileCatalog, TransactionFailure> {
    catalog_from_parts(
        &document.profiles,
        &document.active_profile_id,
        &document.default_profile_id,
        revision,
        state.trusted_clients.keys().map(String::as_str),
    )
}

fn catalog_from_parts<'a>(
    profiles: &[serde_json::Value],
    active_profile_id: &str,
    default_profile_id: &str,
    revision: u64,
    auth_tokens: impl Iterator<Item = &'a str> + Clone,
) -> Result<CliProfileCatalog, TransactionFailure> {
    let tokens = auth_tokens.collect::<Vec<_>>();
    let mut summaries = Vec::with_capacity(profiles.len());
    for (index, profile) in profiles.iter().enumerate() {
        let id = profile
            .get("id")
            .and_then(serde_json::Value::as_str)
            .ok_or_else(|| {
                TransactionFailure::new(
                    "unsafe_profile_catalog",
                    "profile catalog contains a malformed identifier",
                )
            })?;
        let name = profile
            .get("name")
            .and_then(serde_json::Value::as_str)
            .ok_or_else(|| {
                TransactionFailure::new(
                    "unsafe_profile_catalog",
                    "profile catalog contains a malformed name",
                )
            })?;
        if tokens
            .iter()
            .any(|token| !token.is_empty() && (id.contains(token) || name.contains(token)))
        {
            return Err(TransactionFailure::new(
                "unsafe_profile_catalog",
                "profile summary overlaps credential material and was not returned",
            ));
        }
        let profile_id = Uuid::parse_str(id).map_err(|_| {
            TransactionFailure::new(
                "unsafe_profile_catalog",
                "profile catalog identifier is not an exact UUID",
            )
        })?;
        if name.trim().is_empty()
            || name.chars().count() > MAXIMUM_SELECTOR_CHARACTERS
            || name.chars().any(char::is_control)
        {
            return Err(TransactionFailure::new(
                "unsafe_profile_catalog",
                "profile catalog name is outside safe summary bounds",
            ));
        }
        summaries.push(CliProfileSummary {
            profile_id,
            name: name.to_owned(),
            active: id.eq_ignore_ascii_case(active_profile_id),
            default: id.eq_ignore_ascii_case(default_profile_id),
            index,
        });
    }
    if summaries.len() > MAXIMUM_PROFILE_SELECTORS
        || !summaries.iter().any(|profile| profile.active)
        || !summaries.iter().any(|profile| profile.default)
    {
        return Err(TransactionFailure::new(
            "unsafe_profile_catalog",
            "profile catalog failed bounded active/default validation",
        ));
    }
    Ok(CliProfileCatalog {
        configuration_revision: revision,
        profiles: summaries,
    })
}

fn request_digest(command: &CliProfileCommand) -> Result<String, TransactionFailure> {
    let encoded = serde_json::to_vec(command).map_err(|_| {
        TransactionFailure::new(
            "invalid_request",
            "profile transaction could not be canonicalized",
        )
    })?;
    Ok(format!("{:x}", Sha256::digest(encoded)))
}

fn deterministic_uuid(invocation_id: Uuid, label: &str) -> Uuid {
    Uuid::new_v5(&invocation_id, label.as_bytes())
}

fn normalized_name(value: &str) -> Result<String, TransactionFailure> {
    validate_name(value)?;
    Ok(value.trim().to_owned())
}

fn validate_name(value: &str) -> Result<(), TransactionFailure> {
    let trimmed = value.trim();
    if trimmed.is_empty()
        || trimmed.chars().count() > MAXIMUM_SELECTOR_CHARACTERS
        || trimmed.chars().any(char::is_control)
    {
        return Err(TransactionFailure::new(
            "invalid_profile_name",
            "profile name must contain between 1 and 256 characters",
        ));
    }
    Ok(())
}

fn normalized_lookup(value: &str) -> String {
    value
        .chars()
        .filter(|character| character.is_alphanumeric())
        .flat_map(char::to_lowercase)
        .collect()
}

fn replay_profile_names(
    command: &CliProfileCommand,
    catalog: &CliProfileCatalog,
    invocation_id: Uuid,
) -> Vec<String> {
    match command {
        CliProfileCommand::Rename { name, .. } => vec![name.trim().to_owned()],
        CliProfileCommand::Duplicate { target, name } => {
            let duplicate_id = deterministic_uuid(invocation_id, "profile.duplicate:new-profile");
            let duplicate_name = catalog
                .profiles
                .iter()
                .find(|profile| profile.profile_id == duplicate_id)
                .map(|profile| profile.name.clone())
                .or_else(|| name.as_ref().map(|name| name.trim().to_owned()))
                .unwrap_or_else(|| "profile copy".to_owned());
            let source_name = target
                .as_ref()
                .and_then(|selector| resolve_selector(selector, catalog).ok())
                .map(|profile| profile.name.clone())
                .unwrap_or_else(|| "profile".to_owned());
            vec![source_name, duplicate_name]
        }
        CliProfileCommand::Delete { targets } | CliProfileCommand::Move { targets, .. } => targets
            .iter()
            .map(|selector| {
                resolve_selector(selector, catalog)
                    .map(|profile| profile.name.clone())
                    .ok()
                    .or_else(|| selector_display(selector))
                    .unwrap_or_else(|| "profile".to_owned())
            })
            .collect(),
        CliProfileCommand::Select { target } | CliProfileCommand::SetDefault { target } => {
            vec![resolve_selector(target, catalog)
                .map(|profile| profile.name.clone())
                .unwrap_or_else(|_| {
                    selector_display(target).unwrap_or_else(|| "profile".to_owned())
                })]
        }
        CliProfileCommand::Reset { target } => vec![target
            .as_ref()
            .and_then(|selector| resolve_selector(selector, catalog).ok())
            .or_else(|| catalog.profiles.iter().find(|profile| profile.active))
            .map(|profile| profile.name.clone())
            .unwrap_or_else(|| "profile".to_owned())],
        CliProfileCommand::GenerationGenerate { .. } => vec!["Hollow Knight".to_owned()],
        CliProfileCommand::TemplateInstall { template, name, .. } => vec![name
            .as_ref()
            .map(|name| name.trim().to_owned())
            .unwrap_or_else(|| template.display_name().to_owned())],
        CliProfileCommand::CustomizationSet { target, .. }
        | CliProfileCommand::StyleCreate { target, .. }
        | CliProfileCommand::StyleRename { target, .. }
        | CliProfileCommand::StyleApply { target, .. }
        | CliProfileCommand::StyleDetach { target, .. }
        | CliProfileCommand::StyleDelete { target, .. }
        | CliProfileCommand::LayerMove { target, .. }
        | CliProfileCommand::LayerForward { target, .. }
        | CliProfileCommand::LayerBackward { target, .. }
        | CliProfileCommand::LayerFront { target, .. }
        | CliProfileCommand::LayerBack { target, .. }
        | CliProfileCommand::GroupCreate { target, .. }
        | CliProfileCommand::GroupRename { target, .. }
        | CliProfileCommand::GroupDuplicate { target, .. }
        | CliProfileCommand::GroupUngroup { target, .. }
        | CliProfileCommand::GroupHide { target, .. }
        | CliProfileCommand::GroupShow { target, .. }
        | CliProfileCommand::GroupLock { target, .. }
        | CliProfileCommand::GroupUnlock { target, .. }
        | CliProfileCommand::GroupNudge { target, .. }
        | CliProfileCommand::GroupForward { target, .. }
        | CliProfileCommand::GroupBackward { target, .. }
        | CliProfileCommand::GroupFront { target, .. }
        | CliProfileCommand::GroupBack { target, .. } => {
            vec![resolve_selector(target, catalog)
                .map(|profile| profile.name.clone())
                .unwrap_or_else(|_| {
                    selector_display(target).unwrap_or_else(|| "profile".to_owned())
                })]
        }
        CliProfileCommand::CustomizationFix {
            profile: target, ..
        }
        | CliProfileCommand::OrientationSet { target, .. }
        | CliProfileCommand::OrientationCopy { target, .. }
        | CliProfileCommand::BindingSet { target, .. }
        | CliProfileCommand::BindingClear { target, .. }
        | CliProfileCommand::BindingReset { target, .. }
        | CliProfileCommand::BindingResetAll { target }
        | CliProfileCommand::OutputMode { target, .. }
        | CliProfileCommand::OutputSet { target, .. }
        | CliProfileCommand::OutputReset { target, .. }
        | CliProfileCommand::OutputResetAll { target }
        | CliProfileCommand::DeviceSet { target, .. }
        | CliProfileCommand::ControlBarSet { target, .. }
        | CliProfileCommand::ControlBarAdd { target, .. }
        | CliProfileCommand::ControlBarRemove { target, .. }
        | CliProfileCommand::ControlBarMove { target, .. }
        | CliProfileCommand::ControlBarReset { target, .. }
        | CliProfileCommand::ControlBarItemSet { target, .. }
        | CliProfileCommand::ControlBarItemReset { target, .. } => {
            vec![resolve_selector(target, catalog)
                .map(|profile| profile.name.clone())
                .unwrap_or_else(|_| {
                    selector_display(target).unwrap_or_else(|| "profile".to_owned())
                })]
        }
        CliProfileCommand::AuthorityStatus
        | CliProfileCommand::List
        | CliProfileCommand::OrientationGet { .. }
        | CliProfileCommand::BindingList { .. }
        | CliProfileCommand::BindingDisplay { .. }
        | CliProfileCommand::OutputList { .. }
        | CliProfileCommand::OutputModeGet { .. }
        | CliProfileCommand::DeviceGet { .. }
        | CliProfileCommand::ControlBarList { .. }
        | CliProfileCommand::ControlBarItemShow { .. }
        | CliProfileCommand::StyleList { .. }
        | CliProfileCommand::StyleShow { .. }
        | CliProfileCommand::LayerList { .. }
        | CliProfileCommand::GroupList { .. } => Vec::new(),
    }
}

fn replay_removed_every_profile(
    command: &CliProfileCommand,
    catalog: &CliProfileCatalog,
    invocation_id: Uuid,
) -> bool {
    matches!(command, CliProfileCommand::Delete { .. })
        && catalog.profiles.iter().any(|profile| {
            profile.profile_id
                == deterministic_uuid(invocation_id, "profile.delete:replacement-profile")
        })
}

fn replay_destination(command: &CliProfileCommand) -> Option<String> {
    match command {
        CliProfileCommand::Move { destination, .. } => Some(match destination {
            ProfileMoveDestination::Index { index } => format!("to index {index}"),
            ProfileMoveDestination::Before { profile } => format!(
                "before \"{}\"",
                selector_display(profile).unwrap_or_else(|| "profile".to_owned())
            ),
            ProfileMoveDestination::After { profile } => format!(
                "after \"{}\"",
                selector_display(profile).unwrap_or_else(|| "profile".to_owned())
            ),
        }),
        CliProfileCommand::OrientationCopy { destination, .. } => {
            Some(orientation_name(*destination).to_owned())
        }
        _ => None,
    }
}

fn selector_display(selector: &ProfileSelector) -> Option<String> {
    match selector {
        ProfileSelector::Active => Some("active".to_owned()),
        ProfileSelector::Default => Some("default".to_owned()),
        ProfileSelector::Id { profile_id } => Some(profile_id.hyphenated().to_string()),
        ProfileSelector::Name { name } => Some(name.clone()),
    }
}

fn draft_failure(error: DraftError) -> TransactionFailure {
    match error {
        DraftError::ConfigurationRevisionConflict { expected, actual } => TransactionFailure::new(
            "configuration_revision_conflict",
            "configuration changed before the deterministic draft could begin",
        )
        .with_revision(expected, actual),
        DraftError::DraftRevisionConflict { expected, actual } => TransactionFailure::new(
            "draft_revision_conflict",
            "configuration draft changed; retry with the same invocation ID",
        )
        .with_revision(expected, actual),
        DraftError::DraftIdConflict => TransactionFailure::new(
            "draft_id_conflict",
            "invocation draft ID was already used for a different configuration base",
        ),
        DraftError::OperationIdConflict => TransactionFailure::new(
            "operation_id_conflict",
            "deterministic operation ID was reused with different content",
        ),
        DraftError::Bridge(_) => TransactionFailure::new(
            "configuration_bridge_failed",
            "required exact-sibling configuration bridge failed",
        ),
        DraftError::MergeConflict(paths) => {
            let mut failure = TransactionFailure::new(
                "configuration_merge_conflict",
                "configuration transaction conflicts with authoritative semantic paths",
            );
            failure.error.conflict_paths = paths.into_iter().take(128).collect();
            failure
        }
        DraftError::InvalidDraftId | DraftError::InvalidOperationId => TransactionFailure::new(
            "invalid_transaction_identity",
            "profile transaction identity is invalid",
        ),
        DraftError::NotFound | DraftError::Expired => TransactionFailure::new(
            "draft_unavailable",
            "configuration draft is unavailable; retry with the same invocation ID",
        ),
        DraftError::TooManyLiveDrafts | DraftError::TooManyOperations => TransactionFailure::new(
            "draft_limit_reached",
            "configuration draft safety limit was reached",
        ),
        DraftError::DraftRevisionExhausted => TransactionFailure::new(
            "draft_revision_exhausted",
            "configuration draft revision is exhausted",
        ),
        DraftError::Document(_)
        | DraftError::Operation(_)
        | DraftError::InvalidOperationOutcome => TransactionFailure::new(
            "invalid_configuration_operation",
            "profile operation was rejected by constrained validation",
        ),
        DraftError::Preview(_)
        | DraftError::InsecureDirectory
        | DraftError::InsecureFile
        | DraftError::UnsupportedVersion
        | DraftError::TooLarge(_)
        | DraftError::Malformed
        | DraftError::EncodingFailed
        | DraftError::Io(_) => TransactionFailure::new(
            "draft_storage_failed",
            "configuration draft storage failed closed",
        ),
    }
}

fn now_millis() -> i64 {
    use std::time::{SystemTime, UNIX_EPOCH};
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| i64::try_from(duration.as_millis()).unwrap_or(i64::MAX))
        .unwrap_or(0)
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    fn request(command: CliProfileCommand) -> CliProfileRequest {
        CliProfileRequest {
            schema_version: CLI_PROFILE_SCHEMA_VERSION,
            invocation_id: Some(Uuid::parse_str("aaaaaaaa-bbbb-5ccc-8ddd-eeeeeeeeeeee").unwrap()),
            expected_configuration_revision: None,
            command,
        }
    }

    #[test]
    fn deterministic_uuid_fixture_is_stable() {
        let invocation = Uuid::parse_str("aaaaaaaa-bbbb-5ccc-8ddd-eeeeeeeeeeee").unwrap();
        assert_eq!(
            deterministic_uuid(invocation, "configuration-commit")
                .hyphenated()
                .to_string(),
            "9c0aa11d-a11f-507e-b334-be9e76002f10"
        );
    }

    #[test]
    fn summary_catalog_never_contains_state_credentials_or_documents() {
        let mut state = PersistentState::minimal("server").unwrap();
        state.trusted_clients.insert(
            "secret-token".to_owned(),
            thumble_core::TrustedClient {
                name: "Phone".to_owned(),
                created_at: 1,
                last_seen_at: 2,
            },
        );
        let response = execute_profile_transaction(
            &HostPaths::new(
                tempdir().unwrap().path().to_path_buf(),
                std::path::PathBuf::from("/unused"),
            ),
            &state,
            &request(CliProfileCommand::List),
            "test",
            |_, _, _, _, _| unreachable!(),
        );
        let json = serde_json::to_string(&response).unwrap();
        assert!(!json.contains("secret-token"));
        assert!(!json.contains("customization"));
        assert!(!json.contains("server"));
    }

    #[test]
    fn orientation_projection_is_revision_tagged_typed_and_document_free() {
        let mut state = PersistentState::minimal("server").unwrap();
        state.configuration_revision = 7;
        state.profiles[0]["orientationPreference"] = serde_json::json!("portrait");
        state.profiles[0]["customization"]["futurePath"] =
            serde_json::json!("/private/not-for-projection");
        let response = execute_profile_transaction(
            &HostPaths::new(
                tempdir().unwrap().path().to_path_buf(),
                std::path::PathBuf::from("/unused"),
            ),
            &state,
            &request(CliProfileCommand::OrientationGet {
                target: ProfileSelector::Active,
            }),
            "test",
            |_, _, _, _, _| unreachable!(),
        );
        assert!(response.ok, "{:?}", response.error);
        let orientation = response.orientation.unwrap();
        assert_eq!(orientation.configuration_revision, 7);
        assert_eq!(
            orientation.orientation,
            ConfigurationOrientationPreference::Portrait
        );
        assert_eq!(orientation.profile_name, "Default");
        let json = serde_json::to_string(&orientation).unwrap();
        assert!(!json.contains("futurePath"));
        assert!(!json.contains("private"));
        assert!(!json.contains("customization"));
    }

    #[test]
    fn binding_and_output_projections_are_revision_tagged_semantic_and_document_free() {
        let mut state = PersistentState::minimal("server").unwrap();
        state.configuration_revision = 12;
        state.trusted_clients.insert(
            "secret-binding-token".to_owned(),
            thumble_core::TrustedClient {
                name: "Phone".to_owned(),
                created_at: 1,
                last_seen_at: 2,
            },
        );
        state.profiles[0]["customization"]["futurePath"] =
            serde_json::json!("/private/never-project");
        let paths = HostPaths::new(
            tempdir().unwrap().path().to_path_buf(),
            std::path::PathBuf::from("/unused"),
        );
        let binding = execute_profile_transaction(
            &paths,
            &state,
            &request(CliProfileCommand::BindingList {
                target: ProfileSelector::Active,
            }),
            "test",
            |_, _, _, _, _| unreachable!(),
        );
        assert!(binding.ok, "{:?}", binding.error);
        let projection = binding.projection.unwrap();
        assert_eq!(projection.configuration_revision, 12);
        assert_eq!(projection.kind, CliProjectionKind::BindingList);
        assert_eq!(projection.rows.as_ref().unwrap().len(), 18);
        let json = serde_json::to_string(&projection).unwrap();
        assert!(!json.to_ascii_lowercase().contains("keycode"));
        assert!(!json.contains("secret-binding-token"));
        assert!(!json.contains("never-project"));
        assert!(!json.contains("customization"));

        let display = execute_profile_transaction(
            &paths,
            &state,
            &request(CliProfileCommand::BindingDisplay {
                target: ProfileSelector::Active,
            }),
            "test",
            |_, _, _, _, _| unreachable!(),
        );
        assert!(display.ok, "{:?}", display.error);
        let groups = display.projection.unwrap().display_groups.unwrap();
        assert_eq!(groups.len(), 1);
        assert_eq!(groups[0].entries.len(), 10);

        let mut legacy_without_profile_maps = state.clone();
        legacy_without_profile_maps.profile_key_bindings.clear();
        legacy_without_profile_maps.profile_output_bindings.clear();
        let fallback = execute_profile_transaction(
            &paths,
            &legacy_without_profile_maps,
            &request(CliProfileCommand::BindingList {
                target: ProfileSelector::Active,
            }),
            "test",
            |_, _, _, _, _| unreachable!(),
        );
        assert!(fallback.ok, "{:?}", fallback.error);
        let jump = fallback
            .projection
            .unwrap()
            .rows
            .unwrap()
            .into_iter()
            .find(|row| row.button == GameButton::Jump)
            .and_then(|row| row.output)
            .unwrap();
        assert_eq!(jump.keyboard[0].key, "Return");

        state
            .profile_key_bindings
            .get_mut(thumble_core::DEFAULT_PROFILE_ID)
            .unwrap()
            .insert(GameButton::Jump, KeyBinding::new(u16::MAX, 0));
        let unsafe_projection = execute_profile_transaction(
            &paths,
            &state,
            &request(CliProfileCommand::BindingList {
                target: ProfileSelector::Active,
            }),
            "test",
            |_, _, _, _, _| unreachable!(),
        );
        assert!(!unsafe_projection.ok);
        assert_eq!(
            unsafe_projection.error.unwrap().code,
            "unsafe_binding_projection"
        );
    }

    #[test]
    fn style_projection_is_revision_tagged_bounded_and_omits_artifacts() {
        let mut state = PersistentState::minimal("server").unwrap();
        state.configuration_revision = 16;
        state.profiles[0]["customization"]["styleLibrary"] = serde_json::json!({"styles":[
            {
                "id":"safe","name":"Safe","appliesTo":["button"],
                "visualStyle":{"normal":{"fillStyle":{"kind":"solid","color":{"red":0.1,"green":0.2,"blue":0.3,"alpha":1}}}}
            },
            {
                "id":"unsafe","name":"Unsafe",
                "visualStyle":{
                    "normal":{"fillStyle":{"kind":"image","image":{"assetID":"secret-asset","path":"/private/nope"}}},
                    "icon":{"source":"asset","value":"secret-asset"}
                }
            }
        ]});
        let paths = HostPaths::new(
            tempdir().unwrap().path().to_path_buf(),
            std::path::PathBuf::from("/unused"),
        );
        let response = execute_profile_transaction(
            &paths,
            &state,
            &request(CliProfileCommand::StyleList {
                target: ProfileSelector::Active,
            }),
            "test",
            |_, _, _, _, _| unreachable!(),
        );
        assert!(response.ok, "{:?}", response.error);
        let projection = response.styles.unwrap();
        assert_eq!(projection.configuration_revision, 16);
        assert_eq!(projection.styles.len(), 2);
        assert!(
            projection
                .styles
                .iter()
                .find(|style| style.id == "unsafe")
                .unwrap()
                .unsupported_content_omitted
        );
        let encoded = serde_json::to_string(&projection).unwrap();
        assert!(!encoded.contains("secret-asset"));
        assert!(!encoded.contains("/private"));

        let shown = execute_profile_transaction(
            &paths,
            &state,
            &request(CliProfileCommand::StyleShow {
                target: ProfileSelector::Active,
                style_id: "SAFE".to_owned(),
            }),
            "test",
            |_, _, _, _, _| unreachable!(),
        );
        assert!(shown.ok, "{:?}", shown.error);
        assert_eq!(shown.styles.unwrap().styles[0].id, "safe");
    }

    #[test]
    fn device_projection_and_planning_are_catalog_typed_and_document_free() {
        let paths = HostPaths::new(
            tempdir().unwrap().path().to_path_buf(),
            std::path::PathBuf::from("/unused"),
        );
        let mut state = PersistentState::minimal("server").unwrap();
        state.configuration_revision = 19;
        state.profiles[0]["portraitCustomization"] = serde_json::json!({
            "deviceCanvas":{"frameID":"iphone-16-pro-portrait"},
            "futurePath":"/private/not-projected"
        });

        let primary = execute_profile_transaction(
            &paths,
            &state,
            &request(CliProfileCommand::DeviceGet {
                target: ProfileSelector::Active,
                variant: ConfigurationVariant::Primary,
            }),
            "test",
            |_, _, _, _, _| unreachable!(),
        );
        assert!(primary.ok, "{:?}", primary.error);
        let primary = primary.device.unwrap();
        assert_eq!(primary.configuration_revision, 19);
        assert_eq!(primary.frame_id.as_deref(), Some("iphone-17-pro-landscape"));
        assert_eq!(primary.frame_orientation, OrientationVariant::Landscape);

        let portrait = execute_profile_transaction(
            &paths,
            &state,
            &request(CliProfileCommand::DeviceGet {
                target: ProfileSelector::Active,
                variant: ConfigurationVariant::Portrait,
            }),
            "test",
            |_, _, _, _, _| unreachable!(),
        );
        assert!(portrait.ok, "{:?}", portrait.error);
        let portrait_json = serde_json::to_string(&portrait.device.unwrap()).unwrap();
        assert!(portrait_json.contains("iphone-16-pro-portrait"));
        assert!(!portrait_json.contains("private"));

        let catalog = catalog_from_state(&state).unwrap();
        let plan = plan_transaction(
            &CliProfileCommand::DeviceSet {
                target: ProfileSelector::Active,
                variant: ConfigurationVariant::Landscape,
                frame_id: "iphone-15-pro-landscape".to_owned(),
            },
            &catalog,
            &state.profiles,
            Uuid::parse_str("aaaaaaaa-bbbb-5ccc-8ddd-eeeeeeeeeeee").unwrap(),
        )
        .unwrap();
        assert!(matches!(
            plan.operations.as_slice(),
            [ConfigurationOperation::DeviceSet {
                variant: ConfigurationVariant::Landscape,
                frame_id,
                ..
            }] if frame_id == "iphone-15-pro-landscape"
        ));

        state.profiles[0]["customization"]["deviceCanvas"] =
            serde_json::json!({"frameID":"custom-999x777-landscape"});
        let custom_response = execute_profile_transaction(
            &paths,
            &state,
            &request(CliProfileCommand::DeviceGet {
                target: ProfileSelector::Active,
                variant: ConfigurationVariant::Primary,
            }),
            "test",
            |_, _, _, _, _| unreachable!(),
        );
        assert!(custom_response.ok, "{:?}", custom_response.error);
        let custom = custom_response.device.unwrap();
        assert!(custom.frame_id.is_none());
        assert_eq!(
            (custom.custom_width, custom.custom_height),
            (Some(999), Some(777))
        );
        assert!(!serde_json::to_string(&custom).unwrap().contains("custom-"));

        state.profiles[0]["customization"]["deviceCanvas"] =
            serde_json::json!({"frameID":"custom-999x777-landscape/private"});
        let unsafe_response = execute_profile_transaction(
            &paths,
            &state,
            &request(CliProfileCommand::DeviceGet {
                target: ProfileSelector::Active,
                variant: ConfigurationVariant::Primary,
            }),
            "test",
            |_, _, _, _, _| unreachable!(),
        );
        assert!(!unsafe_response.ok);
        assert_eq!(
            unsafe_response.error.unwrap().code,
            "unsafe_device_projection"
        );
    }

    #[test]
    fn control_bar_projection_and_planning_are_typed_variant_scoped_and_bounded() {
        let mut state = PersistentState::minimal("server").unwrap();
        state.configuration_revision = 14;
        state.profiles[0]["landscapeCustomization"] = serde_json::json!({
            "controlBarItems": ["settings", "home"],
            "controlBarItemCustomizations": [{
                "item": "settings",
                "appearance": {
                    "widthScale": 0.75,
                    "fillStyle": {"kind":"image","image":{"fileName":"/private/not-projected"}},
                    "futurePath": "/private/not-projected"
                }
            }],
            "futurePath": "/private/not-projected"
        });
        let paths = HostPaths::new(
            tempdir().unwrap().path().to_path_buf(),
            std::path::PathBuf::from("/unused"),
        );
        let response = execute_profile_transaction(
            &paths,
            &state,
            &request(CliProfileCommand::ControlBarList {
                target: ProfileSelector::Active,
                variant: ConfigurationVariant::Landscape,
            }),
            "test",
            |_, _, _, _, _| unreachable!(),
        );
        assert!(response.ok, "{:?}", response.error);
        let projection = response.control_bar.unwrap();
        assert_eq!(projection.configuration_revision, 14);
        assert_eq!(projection.variant, ConfigurationVariant::Landscape);
        assert_eq!(
            projection.items,
            vec![
                CliControlBarItemSummary {
                    order: 1,
                    item: ConfigurationControlBarItem::Settings,
                },
                CliControlBarItemSummary {
                    order: 2,
                    item: ConfigurationControlBarItem::Home,
                },
            ]
        );
        let json = serde_json::to_string(&projection).unwrap();
        assert!(!json.contains("futurePath"));
        assert!(!json.contains("private"));
        assert!(!json.contains("customization"));

        let item_response = execute_profile_transaction(
            &paths,
            &state,
            &request(CliProfileCommand::ControlBarItemShow {
                target: ProfileSelector::Active,
                variant: ConfigurationVariant::Landscape,
                item: ConfigurationControlBarItem::Settings,
            }),
            "test",
            |_, _, _, _, _| unreachable!(),
        );
        assert!(item_response.ok, "{:?}", item_response.error);
        let item_projection = item_response.control_bar_item.unwrap();
        assert_eq!(item_projection.order, 1);
        assert_eq!(item_projection.appearance.width_scale, 0.75);
        assert!(item_projection.appearance.fill.is_none());
        assert!(item_projection.appearance.unsupported_content_omitted);
        let item_json = serde_json::to_string(&item_projection).unwrap();
        assert!(!item_json.contains("private"));
        assert!(!item_json.contains("futurePath"));

        let catalog = catalog_from_state(&state).unwrap();
        let plan = plan_transaction(
            &CliProfileCommand::ControlBarMove {
                target: ProfileSelector::Active,
                variant: ConfigurationVariant::Landscape,
                item: ConfigurationControlBarItem::Home,
                direction: ControlBarMoveDirection::Up,
            },
            &catalog,
            &state.profiles,
            Uuid::parse_str("aaaaaaaa-bbbb-5ccc-8ddd-eeeeeeeeeeee").unwrap(),
        )
        .unwrap();
        assert!(matches!(
            plan.operations.as_slice(),
            [ConfigurationOperation::ControlBarMove {
                variant: ConfigurationVariant::Landscape,
                item: ConfigurationControlBarItem::Home,
                direction: ControlBarMoveDirection::Up,
                ..
            }]
        ));
        let item_plan = plan_transaction(
            &CliProfileCommand::ControlBarItemSet {
                target: ProfileSelector::Active,
                variant: ConfigurationVariant::Landscape,
                item: ConfigurationControlBarItem::Settings,
                changes: Box::new(ControlBarItemChanges {
                    width_scale: Some(0.9),
                    ..ControlBarItemChanges::default()
                }),
            },
            &catalog,
            &state.profiles,
            Uuid::parse_str("aaaaaaaa-bbbb-5ccc-8ddd-eeeeeeeeeeee").unwrap(),
        )
        .unwrap();
        assert!(matches!(
            item_plan.operations.as_slice(),
            [ConfigurationOperation::ControlBarItemSet {
                variant: ConfigurationVariant::Landscape,
                item: ConfigurationControlBarItem::Settings,
                ..
            }]
        ));

        let mut stale = request(CliProfileCommand::ControlBarItemReset {
            target: ProfileSelector::Active,
            variant: ConfigurationVariant::Landscape,
            item: ConfigurationControlBarItem::Settings,
        });
        stale.expected_configuration_revision = Some(13);
        let stale_response = execute_profile_transaction(
            &paths,
            &state,
            &stale,
            "test",
            |_, _, _, _, _| unreachable!(),
        );
        assert!(!stale_response.ok);
        let stale_error = stale_response.error.unwrap();
        assert_eq!(stale_error.code, "configuration_revision_conflict");
        assert_eq!(stale_error.expected_revision, Some(13));
        assert_eq!(stale_error.actual_revision, Some(14));

        state.profiles[0]["landscapeCustomization"]["controlBarItems"] =
            serde_json::json!(["home", "home"]);
        let rejected = execute_profile_transaction(
            &paths,
            &state,
            &request(CliProfileCommand::ControlBarList {
                target: ProfileSelector::Active,
                variant: ConfigurationVariant::Landscape,
            }),
            "test",
            |_, _, _, _, _| unreachable!(),
        );
        assert!(!rejected.ok);
        assert_eq!(
            rejected.error.unwrap().code,
            "unsafe_control_bar_projection"
        );
    }

    #[test]
    fn orientation_planning_accepts_matching_primary_source_and_rejects_missing_source() {
        let mut state = PersistentState::minimal("server").unwrap();
        state.profiles[0]["customization"]["deviceCanvas"] =
            serde_json::json!({"frameID":"iphone-17-pro-landscape"});
        let catalog = catalog_from_state(&state).unwrap();
        let command = CliProfileCommand::OrientationCopy {
            target: ProfileSelector::Active,
            source: OrientationVariant::Landscape,
            destination: OrientationVariant::Portrait,
            automatically_arrange: true,
        };
        let plan = plan_transaction(
            &command,
            &catalog,
            &state.profiles,
            Uuid::parse_str("aaaaaaaa-bbbb-5ccc-8ddd-eeeeeeeeeeee").unwrap(),
        )
        .unwrap();
        assert_eq!(plan.profile_names, vec!["Default"]);
        assert!(matches!(
            plan.operations.as_slice(),
            [ConfigurationOperation::OrientationCopy {
                source: OrientationVariant::Landscape,
                destination: OrientationVariant::Portrait,
                automatically_arrange: true,
                ..
            }]
        ));

        state.profiles[0]["customization"]["deviceCanvas"] =
            serde_json::json!({"frameID":"iphone-17-pro-portrait"});
        let catalog = catalog_from_state(&state).unwrap();
        let failure = plan_transaction(
            &command,
            &catalog,
            &state.profiles,
            Uuid::parse_str("bbbbbbbb-cccc-5ddd-8eee-ffffffffffff").unwrap(),
        )
        .unwrap_err();
        assert_eq!(failure.error.code, "missing_orientation");
    }

    #[test]
    fn customization_planning_is_typed_bounded_and_variant_scoped() {
        use crate::draft_operation::{
            ConfigurationAccentStyle, ConfigurationBackgroundEdit, ConfigurationBackgroundScope,
            ConfigurationLayoutMode, ConfigurationRgbaColor,
        };

        let mut state = PersistentState::minimal("server").unwrap();
        state.profiles[0]["customization"]["customButtons"] = serde_json::json!([{
            "id":"00000000-0000-0000-0000-000000000701",
            "mappedButton":"custom1",
            "label":"Right Stick"
        }]);
        let catalog = catalog_from_state(&state).unwrap();
        let command = CliProfileCommand::CustomizationSet {
            target: ProfileSelector::Active,
            variant: ConfigurationVariant::Portrait,
            changes: vec![
                CustomizationChanges {
                    layout_mode: Some(ConfigurationLayoutMode::Southpaw),
                    control_scale: None,
                    color_scheme: None,
                    accent_style: Some(ConfigurationAccentStyle::Purple),
                    shows_button_labels: Some(false),
                    background_edit: ConfigurationBackgroundEdit::Keep,
                },
                CustomizationChanges {
                    layout_mode: None,
                    control_scale: None,
                    color_scheme: None,
                    accent_style: None,
                    shows_button_labels: None,
                    background_edit: ConfigurationBackgroundEdit::Set {
                        scope: ConfigurationBackgroundScope::Dark,
                        color: ConfigurationRgbaColor {
                            red: 0.1,
                            green: 0.2,
                            blue: 0.3,
                            alpha: 1.0,
                        },
                    },
                },
            ],
            frame_id: Some("iphone-16-pro-portrait".to_owned()),
        };
        validate_request(&request(command.clone())).unwrap();
        let plan = plan_transaction(
            &command,
            &catalog,
            &state.profiles,
            Uuid::parse_str("aaaaaaaa-bbbb-5ccc-8ddd-eeeeeeeeeeee").unwrap(),
        )
        .unwrap();
        assert_eq!(plan.operations.len(), 3);
        assert!(matches!(
            plan.operations.as_slice(),
            [
                ConfigurationOperation::DeviceSet {
                    variant: ConfigurationVariant::Portrait,
                    frame_id,
                    ..
                },
                ConfigurationOperation::CustomizationSet {
                    variant: ConfigurationVariant::Portrait,
                    ..
                },
                ConfigurationOperation::CustomizationSet {
                    variant: ConfigurationVariant::Portrait,
                    ..
                }
            ] if frame_id == "iphone-16-pro-portrait"
        ));

        let empty = request(CliProfileCommand::CustomizationSet {
            target: ProfileSelector::Active,
            variant: ConfigurationVariant::Primary,
            changes: Vec::new(),
            frame_id: None,
        });
        assert_eq!(
            validate_request(&empty).unwrap_err().error.code,
            "invalid_customization_changes"
        );
        let unsupported = request(CliProfileCommand::CustomizationSet {
            target: ProfileSelector::Active,
            variant: ConfigurationVariant::Primary,
            changes: Vec::new(),
            frame_id: Some("custom-999x777-landscape".to_owned()),
        });
        assert_eq!(
            validate_request(&unsupported).unwrap_err().error.code,
            "unsupported_device_frame"
        );

        let fix = CliProfileCommand::CustomizationFix {
            profile: ProfileSelector::Active,
            variant: ConfigurationVariant::Landscape,
            target: Box::new(LayoutRepairTarget::Repair {
                repair: crate::draft_operation::LayoutRepairKind::MoveInsideSafeArea,
            }),
            canvas: Box::new(LayoutRepairCanvas::Size {
                width: 844.0,
                height: 390.0,
            }),
            include_locked: false,
        };
        validate_request(&request(fix.clone())).unwrap();
        let fix_plan = plan_transaction(
            &fix,
            &catalog,
            &state.profiles,
            Uuid::parse_str("acacacac-bbbb-5ccc-8ddd-eeeeeeeeeeee").unwrap(),
        )
        .unwrap();
        assert!(matches!(
            fix_plan.operations.as_slice(),
            [ConfigurationOperation::CustomizationFix {
                variant: ConfigurationVariant::Landscape,
                target,
                canvas,
                include_locked: false,
                ..
            }] if matches!(target.as_ref(), LayoutRepairTarget::Repair {
                repair: crate::draft_operation::LayoutRepairKind::MoveInsideSafeArea
            }) && matches!(canvas.as_ref(), LayoutRepairCanvas::Size {
                width: 844.0,
                height: 390.0
            })
        ));
        let invalid_fix = request(CliProfileCommand::CustomizationFix {
            profile: ProfileSelector::Active,
            variant: ConfigurationVariant::Primary,
            target: Box::new(LayoutRepairTarget::All {}),
            canvas: Box::new(LayoutRepairCanvas::Size {
                width: 239.0,
                height: 390.0,
            }),
            include_locked: true,
        });
        assert_eq!(
            validate_request(&invalid_fix).unwrap_err().error.code,
            "invalid_layout_repair"
        );

        let style = CliProfileCommand::StyleCreate {
            target: ProfileSelector::Active,
            style_id: "soul".to_owned(),
            name: "Soul".to_owned(),
            appearance: Box::new(StyleAppearance {
                fill_color: Some(ConfigurationRgbaColor {
                    red: 0.9,
                    green: 0.8,
                    blue: 0.7,
                    alpha: 1.0,
                }),
                ..StyleAppearance::default()
            }),
        };
        validate_request(&request(style.clone())).unwrap();
        let style_plan = plan_transaction(
            &style,
            &catalog,
            &state.profiles,
            Uuid::parse_str("bbbbbbbb-cccc-5ddd-8eee-ffffffffffff").unwrap(),
        )
        .unwrap();
        assert!(matches!(
            style_plan.operations.as_slice(),
            [ConfigurationOperation::StyleCreate {
                style_id,
                name,
                appearance,
                ..
            }] if style_id == "soul" && name == "Soul"
                && appearance.fill_color.is_some()
        ));
        let apply_plan = plan_transaction(
            &CliProfileCommand::StyleApply {
                target: ProfileSelector::Active,
                variant: ConfigurationVariant::Primary,
                style_id: "soul".to_owned(),
                element_id: "Right Stick".to_owned(),
            },
            &catalog,
            &state.profiles,
            Uuid::parse_str("cccccccc-dddd-5eee-8fff-000000000001").unwrap(),
        )
        .unwrap();
        assert!(matches!(
            apply_plan.operations.as_slice(),
            [ConfigurationOperation::StyleApply { element_id, .. }]
                if element_id == "00000000-0000-0000-0000-000000000701"
        ));
        let layer_plan = plan_transaction(
            &CliProfileCommand::LayerMove {
                target: ProfileSelector::Active,
                element_id: "Right Stick".to_owned(),
                destination: LayerMoveDestination::Before {
                    element_id: "Action 1".to_owned(),
                },
            },
            &catalog,
            &state.profiles,
            Uuid::parse_str("dddddddd-eeee-5fff-8000-000000000002").unwrap(),
        )
        .unwrap();
        assert!(matches!(
            layer_plan.operations.as_slice(),
            [ConfigurationOperation::LayerMove {
                element_id,
                destination: LayerMoveDestination::Before {
                    element_id: before
                },
                ..
            }] if element_id == "00000000-0000-0000-0000-000000000701"
                && before == "jump"
        ));

        state.profiles[0]["customization"]["designMetadata"] = serde_json::json!({
            "schemaVersion": 1,
            "groups": [{
                "id": "00000000-0000-0000-0000-000000000801",
                "name": "Actions",
                "children": [
                    {"kind": "builtin", "button": "jump"},
                    {"kind": "custom", "id": "00000000-0000-0000-0000-000000000701"}
                ],
                "isLocked": false,
                "isHidden": false
            }]
        });
        let group_invocation = Uuid::parse_str("eeeeeeee-ffff-5000-8111-000000000003").unwrap();
        let group_plan = plan_transaction(
            &CliProfileCommand::GroupDuplicate {
                target: ProfileSelector::Active,
                variant: ConfigurationVariant::Primary,
                group: "Actions".to_owned(),
                name: Some("Actions Copy".to_owned()),
                offset_x: 0.025,
                offset_y: 0.025,
            },
            &catalog,
            &state.profiles,
            group_invocation,
        )
        .unwrap();
        assert!(matches!(
            group_plan.operations.as_slice(),
            [ConfigurationOperation::GroupDuplicate {
                group_id,
                new_element_ids,
                ..
            }] if group_id == "00000000-0000-0000-0000-000000000801"
                && new_element_ids.len() == 2
                && new_element_ids[0]
                    == deterministic_uuid(group_invocation, "group.duplicate:new-element:0")
                        .hyphenated()
                        .to_string()
        ));

        let mut portrait_layers = state.profiles[0]["customization"].clone();
        portrait_layers["customButtons"][0]["label"] =
            serde_json::Value::String("Portrait Stick".to_owned());
        state.profiles[0]["portraitCustomization"] = portrait_layers;
        let layer_projection = execute_profile_transaction(
            &HostPaths::new(
                tempdir().unwrap().path().to_path_buf(),
                std::path::PathBuf::from("/unused"),
            ),
            &state,
            &request(CliProfileCommand::LayerList {
                target: ProfileSelector::Active,
                variant: ConfigurationVariant::Portrait,
            }),
            "test",
            |_, _, _, _, _| unreachable!(),
        );
        assert!(layer_projection.ok, "{:?}", layer_projection.error);
        let layer_projection = layer_projection.layers.unwrap();
        assert_eq!(layer_projection.variant, ConfigurationVariant::Portrait);
        let layers = layer_projection.layers;
        assert!(layers.len() <= 128);
        assert!(layers.iter().any(|layer| layer.stable_id == "builtin.jump"));
        assert!(layers.iter().any(|layer| layer.label == "Portrait Stick"));
        let encoded = serde_json::to_string(&layers).unwrap();
        assert!(!encoded.contains("keyCode"));
        assert!(!encoded.contains("outputBindings"));

        let group_projection = execute_profile_transaction(
            &HostPaths::new(
                tempdir().unwrap().path().to_path_buf(),
                std::path::PathBuf::from("/unused"),
            ),
            &state,
            &request(CliProfileCommand::GroupList {
                target: ProfileSelector::Active,
                variant: ConfigurationVariant::Primary,
            }),
            "test",
            |_, _, _, _, _| unreachable!(),
        );
        assert!(group_projection.ok, "{:?}", group_projection.error);
        let groups = group_projection.groups.unwrap();
        assert_eq!(groups.configuration_revision, state.configuration_revision);
        assert_eq!(groups.groups.len(), 1);
        assert_eq!(groups.groups[0].name, "Actions");
        assert_eq!(
            groups.groups[0].child_stable_ids,
            vec![
                "builtin.jump",
                "custom.00000000-0000-0000-0000-000000000701"
            ]
        );
        let encoded = serde_json::to_string(&groups).unwrap();
        assert!(!encoded.contains("customization"));
        assert!(!encoded.contains("keyCode"));
    }

    #[test]
    fn generation_and_template_plans_are_catalog_typed_and_deterministic() {
        let mut state = PersistentState::minimal("server").unwrap();
        state.profiles[0]["name"] = serde_json::json!("Soft White Pro");
        let catalog = catalog_from_state(&state).unwrap();
        let invocation = Uuid::parse_str("aaaaaaaa-bbbb-5ccc-8ddd-eeeeeeeeeeee").unwrap();

        let template = plan_transaction(
            &CliProfileCommand::TemplateInstall {
                template: ControllerTemplate::SoftWhite,
                name: None,
                select: true,
                make_default: false,
            },
            &catalog,
            &state.profiles,
            invocation,
        )
        .unwrap();
        assert_eq!(template.profile_names, vec!["Soft White Pro"]);
        assert!(matches!(
            template.operations.as_slice(),
            [ConfigurationOperation::TemplateInstall {
                template: ControllerTemplate::SoftWhite,
                template_revision: 1,
                destination: GeneratedProfileDestination::Replace { profile_id },
                new_element_ids,
                select: true,
                make_default: false,
                ..
            }] if profile_id == thumble_core::DEFAULT_PROFILE_ID
                && new_element_ids.len() == 15
                && new_element_ids.iter().collect::<BTreeSet<_>>().len() == 15
        ));

        let generated = plan_transaction(
            &CliProfileCommand::GenerationGenerate {
                select: false,
                make_default: true,
            },
            &catalog,
            &state.profiles,
            invocation,
        )
        .unwrap();
        assert_eq!(generated.profile_names, vec!["Hollow Knight"]);
        assert!(matches!(
            generated.operations.as_slice(),
            [ConfigurationOperation::GenerationGenerate {
                preset: GenerationPreset::HollowKnight,
                preset_revision: 1,
                destination: GeneratedProfileDestination::Create { new_profile_id },
                new_element_ids,
                select: false,
                make_default: true,
            }] if new_profile_id
                == &deterministic_uuid(invocation, "generation.generate:new-profile")
                    .hyphenated()
                    .to_string()
                && new_element_ids.len() == 4
        ));

        let replay_names = replay_profile_names(
            &CliProfileCommand::TemplateInstall {
                template: ControllerTemplate::Snes,
                name: Some("  Custom SNES  ".to_owned()),
                select: true,
                make_default: false,
            },
            &catalog,
            invocation,
        );
        assert_eq!(replay_names, vec!["Custom SNES"]);
    }

    #[test]
    fn offline_authority_is_revision_safe_noop_stable_and_idempotent() {
        let root = tempdir().unwrap();
        let paths = HostPaths::new(
            root.path().join("state"),
            root.path().join("state/control.sock"),
        );
        let state = PersistentState::minimal("server").unwrap();
        storage::save_atomic(&paths.state_file, &state).unwrap();
        let invocation = Uuid::parse_str("aaaaaaaa-bbbb-5ccc-8ddd-eeeeeeeeeeee").unwrap();
        let rename = CliProfileRequest {
            schema_version: CLI_PROFILE_SCHEMA_VERSION,
            invocation_id: Some(invocation),
            expected_configuration_revision: None,
            command: CliProfileCommand::Rename {
                target: ProfileSelector::Active,
                name: "Arcade".to_owned(),
            },
        };
        let first = execute_offline_authority(&paths, &rename);
        assert!(first.ok, "{:?}", first.error);
        assert_eq!(first.outcome.as_ref().unwrap().configuration_revision, 2);
        assert!(!first.outcome.as_ref().unwrap().idempotent_replay);
        let replay = execute_offline_authority(&paths, &rename);
        assert!(replay.ok, "{:?}", replay.error);
        assert!(replay.outcome.as_ref().unwrap().idempotent_replay);
        assert_eq!(
            storage::load(&paths.state_file)
                .unwrap()
                .configuration_revision,
            2
        );

        let conflict = CliProfileRequest {
            command: CliProfileCommand::Rename {
                target: ProfileSelector::Active,
                name: "Different".to_owned(),
            },
            ..rename.clone()
        };
        let conflict = execute_offline_authority(&paths, &conflict);
        assert!(!conflict.ok);
        assert_eq!(conflict.error.unwrap().code, "commit_id_conflict");

        let noop = CliProfileRequest {
            schema_version: CLI_PROFILE_SCHEMA_VERSION,
            invocation_id: Some(Uuid::parse_str("bbbbbbbb-cccc-5ddd-8eee-ffffffffffff").unwrap()),
            expected_configuration_revision: None,
            command: CliProfileCommand::Rename {
                target: ProfileSelector::Active,
                name: "Arcade".to_owned(),
            },
        };
        let noop = execute_offline_authority(&paths, &noop);
        assert!(noop.ok, "{:?}", noop.error);
        assert!(!noop.outcome.as_ref().unwrap().changed);
        assert_eq!(noop.outcome.as_ref().unwrap().configuration_revision, 2);
    }

    #[test]
    fn multi_move_plans_deterministic_order_and_one_save() {
        let mut state = PersistentState::minimal("server").unwrap();
        let base = state.profiles[0].clone();
        for (id, name) in [
            ("00000000-0000-0000-0000-000000000202", "B"),
            ("00000000-0000-0000-0000-000000000203", "C"),
            ("00000000-0000-0000-0000-000000000204", "D"),
        ] {
            let mut profile = base.clone();
            profile["id"] = serde_json::json!(id);
            profile["name"] = serde_json::json!(name);
            state.profiles.push(profile);
        }
        let catalog = catalog_from_state(&state).unwrap();
        let plan = plan_move(
            &[
                ProfileSelector::Name {
                    name: "B".to_owned(),
                },
                ProfileSelector::Name {
                    name: "C".to_owned(),
                },
            ],
            &ProfileMoveDestination::Index { index: 2 },
            &catalog,
        )
        .unwrap();
        let ids = plan
            .operations
            .iter()
            .map(|operation| match operation {
                ConfigurationOperation::ProfileMove { profile_id, index } => {
                    (profile_id.clone(), *index)
                }
                _ => unreachable!(),
            })
            .collect::<Vec<_>>();
        assert_eq!(ids.len(), 4);
        assert_eq!(ids[1].0, "00000000-0000-0000-0000-000000000204");
        assert_eq!(ids[1].1, 1);
    }
}
