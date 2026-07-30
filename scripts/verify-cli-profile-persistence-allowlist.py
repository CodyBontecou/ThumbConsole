#!/usr/bin/env python3
"""Fail CI when direct Swift profile-store persistence expands silently."""

from __future__ import annotations

import collections
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Sources/CLI/ThumbleCLI.swift"
EXPECTED = {
    "install": (1, 1),
    "profile": (1, 0),  # artifact-only `profile show`
    "createProfile": (1, 1),
    "exportProfiles": (1, 0),
    "importProfiles": (1, 1),
    "attachApplicationToProfile": (1, 1),
    "detachApplicationFromProfile": (1, 1),
    "launchAttachedApplication": (1, 0),
    "skin": (3, 2),
    "renderSkinPreview": (1, 0),
    "customization": (2, 0),
    "validateLayout": (1, 0),
    "previewLayout": (1, 0),
    "mutateCustomization": (1, 1),
    "mutateProfileResources": (1, 1),
    "style": (1, 0),
    "asset": (3, 0),
    "nudgeElement": (1, 1),
}

function = "<top-level>"
actual: dict[str, list[int]] = collections.defaultdict(lambda: [0, 0])
for line in SOURCE.read_text(encoding="utf-8").splitlines():
    match = re.match(r"\s*private static func\s+([A-Za-z0-9_]+)", line)
    if match:
        function = match.group(1)
    for index, symbol in enumerate(("loadStore", "persistStore")):
        if re.search(rf"\b{symbol}\s*\(", line) and not re.match(
            rf"\s*private static func {symbol}", line
        ):
            actual[function][index] += 1

normalized = {name: tuple(counts) for name, counts in actual.items()}
if normalized != EXPECTED:
    print("Direct loadStore/persistStore allowlist changed.", file=sys.stderr)
    print(f"Expected: {EXPECTED}", file=sys.stderr)
    print(f"Actual:   {normalized}", file=sys.stderr)
    print(
        "Migrate the call or explicitly review and update this narrow allowlist.",
        file=sys.stderr,
    )
    raise SystemExit(1)

profile_block = SOURCE.read_text(encoding="utf-8").split("private static func moveProfiles", 1)[0]
for command in ("select", "set-default", "rename", "duplicate", "delete", "reset"):
    if f'"{command}"' not in profile_block:
        print(f"Missing migrated profile command routing: {command}", file=sys.stderr)
        raise SystemExit(1)

for function_name in ("generate", "template"):
    function_block = SOURCE.read_text(encoding="utf-8").split(
        f"private static func {function_name}", 1
    )[1].split("private static func", 1)[0]
    if "generationGenerate" not in function_block and "templateInstall" not in function_block:
        print(f"Missing Rust-authoritative {function_name} install routing", file=sys.stderr)
        raise SystemExit(1)
    if function_name == "template" and ("loadStore(" in function_block or "persistStore(" in function_block):
        print("Migrated template install routing still uses direct persistence", file=sys.stderr)
        raise SystemExit(1)

orientation_block = SOURCE.read_text(encoding="utf-8").split(
    "private static func orientation", 1
)[1].split("private static func parseProfileLayoutVariant", 1)[0]
for forbidden in ("loadStore(", "persistStore("):
    if forbidden in orientation_block:
        print(f"Migrated orientation routing still uses {forbidden}", file=sys.stderr)
        raise SystemExit(1)
for command in ("orientationGet", "orientationSet", "orientationCopy"):
    if command not in orientation_block:
        print(f"Missing Rust-authoritative orientation routing: {command}", file=sys.stderr)
        raise SystemExit(1)

binding_output_block = SOURCE.read_text(encoding="utf-8").split(
    "// MARK: - Bindings", 1
)[1].split("// MARK: - Customization", 1)[0]
for forbidden in ("loadStore(", "persistStore("):
    if forbidden in binding_output_block:
        print(f"Migrated binding/output routing still uses {forbidden}", file=sys.stderr)
        raise SystemExit(1)
for command in (
    "bindingList", "bindingDisplay", "bindingSet", "bindingClear", "bindingReset",
    "bindingResetAll", "outputList", "outputModeGet", "outputMode", "outputSet",
    "outputReset", "outputResetAll",
):
    if command not in binding_output_block:
        print(f"Missing Rust-authoritative binding/output routing: {command}", file=sys.stderr)
        raise SystemExit(1)

control_bar_block = SOURCE.read_text(encoding="utf-8").split(
    "private static func controlBar(arguments:", 1
)[1].split("private static func controlBarItem(arguments:", 1)[0]
for forbidden in ("loadStore(", "persistStore(", "mutateCustomization("):
    if forbidden in control_bar_block:
        print(f"Migrated control-bar collection routing still uses {forbidden}", file=sys.stderr)
        raise SystemExit(1)
for command in (
    "controlBarList", "controlBarSet", "controlBarAdd", "controlBarRemove",
    "controlBarMove", "controlBarReset",
):
    if command not in control_bar_block:
        print(f"Missing Rust-authoritative control-bar routing: {command}", file=sys.stderr)
        raise SystemExit(1)

control_bar_item_block = SOURCE.read_text(encoding="utf-8").split(
    "private static func controlBarItem(arguments:", 1
)[1].split("private static func parseControlBarItems", 1)[0]
for forbidden in ("loadStore(", "persistStore(", "mutateCustomization("):
    if forbidden in control_bar_item_block:
        print(f"Migrated control-bar item routing still uses {forbidden}", file=sys.stderr)
        raise SystemExit(1)
for command in ("controlBarItemShow", "controlBarItemSet", "controlBarItemReset"):
    if command not in control_bar_item_block:
        print(f"Missing Rust-authoritative control-bar item routing: {command}", file=sys.stderr)
        raise SystemExit(1)

customization_block = SOURCE.read_text(encoding="utf-8").split(
    "private static func customization(arguments:", 1
)[1].split("private static func setCustomization(", 1)[0]
layer_block = SOURCE.read_text(encoding="utf-8").split(
    "private static func layer(arguments:", 1
)[1].split("private static func group(arguments:", 1)[0]
for command in ("layerList", "layerMove", "layerForward", "layerBackward", "layerFront", "layerBack"):
    if command not in layer_block and "mutateLayerThroughAuthority" not in layer_block:
        print(f"Missing Rust-authoritative layer routing: {command}", file=sys.stderr)
        raise SystemExit(1)
for forbidden in ("loadStore(", "persistStore(", "mutateCustomization("):
    if forbidden in layer_block:
        print(f"Migrated layer routing still uses {forbidden}", file=sys.stderr)
        raise SystemExit(1)

style_block = SOURCE.read_text(encoding="utf-8").split(
    "private static func style(arguments:", 1
)[1].split("private static func layer(arguments:", 1)[0]
for command in ("styleList", "styleShow", "styleCreate", "styleRename", "styleApply", "styleDetach", "styleDelete"):
    if command not in style_block:
        print(f"Missing Rust-authoritative style routing: {command}", file=sys.stderr)
        raise SystemExit(1)

customization_set_block = SOURCE.read_text(encoding="utf-8").split(
    "private static func setCustomization(", 1
)[1].split("private static func setCustomizationUsingLegacyStore", 1)[0]
for forbidden in ("loadStore(", "persistStore(", "mutateCustomization("):
    if forbidden in customization_set_block:
        print(f"Safe customization routing still uses {forbidden}", file=sys.stderr)
        raise SystemExit(1)
if "customizationSet" not in customization_set_block:
    print("Missing Rust-authoritative customization set routing", file=sys.stderr)
    raise SystemExit(1)

theme_block = SOURCE.read_text(encoding="utf-8").split(
    "private static func theme(arguments:", 1
)[1].split("private static func resolveThemePreset", 1)[0]
if "requireExplicitUnmigratedProfileAccess" not in theme_block:
    print("Unmigrated theme writes must fail closed under Rust authority", file=sys.stderr)
    raise SystemExit(1)

repair_block = SOURCE.read_text(encoding="utf-8").split(
    "private static func repairLayout(", 1
)[1].split("private static func parseLayoutRepairKind", 1)[0]
if "customizationFix" not in repair_block:
    print("Missing Rust-authoritative customization repair routing", file=sys.stderr)
    raise SystemExit(1)
if "requireExplicitUnmigratedProfileAccess" not in repair_block:
    print("Issue-specific legacy repairs must fail closed under Rust authority", file=sys.stderr)
    raise SystemExit(1)

element_block = SOURCE.read_text(encoding="utf-8").split(
    "private static func element(arguments:", 1
)[1].split("private static func duplicateElements", 1)[0]
if "layerList" not in element_block or "loadStore(" in element_block:
    print("Element list must use the sanitized Rust projection", file=sys.stderr)
    raise SystemExit(1)
for function_name in (
    "duplicateElements", "alignElements", "distributeElements", "addElement",
    "setElement", "nudgeElement", "deleteElement", "resetElement",
):
    function_block = SOURCE.read_text(encoding="utf-8").split(
        f"private static func {function_name}", 1
    )[1].split("private static func", 1)[0]
    if "requireExplicitUnmigratedProfileAccess" not in function_block:
        print(f"Unmigrated {function_name} write must fail closed", file=sys.stderr)
        raise SystemExit(1)

device_block = SOURCE.read_text(encoding="utf-8").split(
    "private static func device(arguments:", 1
)[1].split("private static func resolveDeviceFrame", 1)[0]
for forbidden in ("loadStore(", "persistStore(", "mutateCustomization(", "UserDefaults.standard"):
    if forbidden in device_block:
        print(f"Migrated device routing still uses {forbidden}", file=sys.stderr)
        raise SystemExit(1)
for command in ("deviceGet", "deviceSet"):
    if command not in device_block:
        print(f"Missing Rust-authoritative device routing: {command}", file=sys.stderr)
        raise SystemExit(1)

print("CLI direct profile/orientation/binding/output/customization/style/layer/group/control-bar/device persistence allowlist passed.")
