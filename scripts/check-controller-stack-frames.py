#!/usr/bin/env python3
"""Fail Debug builds when stack-sensitive ThumbConsole paths exceed their budgets."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

KIB = 1024
DEFAULT_CONTROLLER_MAX_BYTES = 32 * KIB
DEFAULT_MAC_MAX_BYTES = 48 * KIB
DEFAULT_IOS_RUNTIME_MAX_BYTES = 48 * KIB
CONTROLLER_OBJECT_NAMES = ("IOSContentView.o",)
MAC_RUNTIME_OBJECT_NAMES = (
    "GamepadCustomization.o",
    "ControllerProtocol.o",
    "MacControllerServer.o",
)
IOS_RUNTIME_OBJECT_NAMES = (
    "GamepadCustomization.o",
    "GamepadDesignSystem.o",
    "ControllerProtocol.o",
    "ControllerClient.o",
    "IOSLocalKeypadUX.o",
    "PocketPadSkin.o",
    "PocketPadSkinPackage.o",
    "PocketPadSkinResolver.o",
)


@dataclass(frozen=True)
class FunctionFrame:
    symbol: str
    stack_bytes: int


@dataclass(frozen=True)
class FrameEntry:
    frame: FunctionFrame
    name: str
    object_path: Path


@dataclass(frozen=True)
class CallPathBudget:
    name: str
    maximum_bytes: int
    groups: tuple[tuple[str, tuple[str, ...]], ...]


def parse_immediate(text: str) -> int:
    return int(text, 16 if text.lower().startswith("0x") else 10)


def arm64_stack_bytes(instructions: list[str]) -> int:
    """Return the fixed arm64 stack reservation visible in a function prologue."""
    total = 0
    constants: dict[str, int] = {}
    for instruction in instructions[:48]:
        preindexed = re.search(r"\[sp,\s*#-(0x[0-9a-fA-F]+|\d+)\]!", instruction)
        if preindexed:
            total += parse_immediate(preindexed.group(1))

        moved = re.search(r"\bmov\s+([wx]\d+),\s*#(0x[0-9a-fA-F]+|\d+)", instruction)
        if moved:
            constants[moved.group(1).replace("w", "x", 1)] = parse_immediate(moved.group(2))

        moved_keep = re.search(
            r"\bmovk\s+([wx]\d+),\s*#(0x[0-9a-fA-F]+|\d+)(?:,\s*lsl\s*#(\d+))?",
            instruction,
        )
        if moved_keep:
            register = moved_keep.group(1).replace("w", "x", 1)
            shift = int(moved_keep.group(3) or 0)
            mask = 0xFFFF << shift
            previous = constants.get(register, 0)
            constants[register] = (previous & ~mask) | (parse_immediate(moved_keep.group(2)) << shift)

        subtraction = re.search(
            r"\bsub\s+sp,\s*sp,\s*#(0x[0-9a-fA-F]+|\d+)(?:,\s*lsl\s*#(\d+))?",
            instruction,
        )
        if subtraction:
            amount = parse_immediate(subtraction.group(1))
            if subtraction.group(2):
                amount <<= int(subtraction.group(2))
            total += amount
            continue

        register_subtraction = re.search(r"\bsub\s+sp,\s*sp,\s*(x\d+)\b", instruction)
        if register_subtraction and register_subtraction.group(1) in constants:
            total += constants[register_subtraction.group(1)]
    return total


def x86_64_stack_bytes(instructions: list[str]) -> int:
    """Return the fixed x86_64 stack reservation visible in a function prologue."""
    total = 0
    for instruction in instructions[:48]:
        if re.search(r"\bpushq?\b", instruction):
            total += 8
        subtraction = re.search(r"\bsubq?\s+\$(0x[0-9a-fA-F]+|\d+),\s*%rsp", instruction)
        if subtraction:
            total += parse_immediate(subtraction.group(1))
    return total


def parse_disassembly(output: str) -> list[FunctionFrame]:
    frames: list[FunctionFrame] = []
    symbol: str | None = None
    instructions: list[str] = []

    def finish_function() -> None:
        if symbol is None:
            return
        frames.append(
            FunctionFrame(
                symbol=symbol,
                stack_bytes=max(arm64_stack_bytes(instructions), x86_64_stack_bytes(instructions)),
            )
        )

    for line in output.splitlines():
        label = re.match(r"(?:[0-9a-fA-F]+\s+<)?(_[^>]+)>?:$", line)
        if label:
            finish_function()
            symbol = label.group(1)
            instructions = []
        elif symbol is not None and re.match(r"\s*[0-9a-fA-F]+:", line):
            instructions.append(line)
    finish_function()
    return frames


def demangle(symbols: list[str]) -> list[str]:
    if not symbols:
        return []
    result = subprocess.run(
        ["xcrun", "swift-demangle"],
        input="\n".join(symbols) + "\n",
        text=True,
        capture_output=True,
        check=True,
    )
    return result.stdout.splitlines()


def is_controller_symbol(name: str) -> bool:
    return "ControllerPad" in name or (
        "GamepadFreeformControllerCanvas" in name
        and (".body.getter" in name or ".renderedControl(" in name)
    )


def is_shared_runtime_symbol(name: str) -> bool:
    if ".GamepadButtonCustomization.normalized.getter" in name:
        return True
    if ".GamepadCustomization." in name:
        return any(
            fragment in name
            for fragment in (
                ".init(from:",
                ".encode(to:",
                ".normalized.getter",
                ".normalizeInPlace",
                ".(decode",
                ".(encode",
                ".(normalize",
                ".(synchronized",
                ".(appendSynchronized",
                ".hasSamePresentation",
                ".(PresentationComparisonWorkspace",
                ".(ControlBarCustomizationNormalizationWorkspace",
            )
        )
    if ".GamepadConfigurationProfile." in name:
        return any(
            fragment in name
            for fragment in (
                ".init(from:",
                ".init(decoded:",
                ".encode(to:",
                ".normalized.getter",
                ".(decode",
                ".(normalize",
            )
        )
    if ".GamepadConfigurationProfilePersistence." in name:
        return ".normalizedState(" in name or "normalizedUniqueProfiles" in name
    if ".ControllerMessage." in name:
        return ".init(from:" in name or ".encode(to:" in name
    if ".ControllerWireCodec." in name:
        return ".encode(" in name or ".decode(" in name
    return False


def is_mac_runtime_symbol(name: str) -> bool:
    if is_shared_runtime_symbol(name):
        return True
    if ".MacControllerServer." not in name:
        return False
    return any(
        fragment in name
        for fragment in (
            "handleReceivedDataOnNetworkQueue",
            "handleReceivedDatagramDataOnNetworkQueue",
            "handleMessageOnNetworkQueue",
            "handleConnectionMessageOnNetworkQueue",
            "handleHelloOnNetworkQueue",
            "handleRealtimeInputMessageOnNetworkQueue",
            "handleProfileMessageOnNetworkQueue",
            "handleClientCustomizationOnNetworkQueue",
            "handleProfileOrientationMutationOnNetworkQueue",
            "handleSkinMessageOnNetworkQueue",
            "handlePairingRequestOnNetworkQueue",
            "acceptPairedClientOnNetworkQueue",
            "gamepadProfilesForClient",
            "sendGamepadCustomizationOnNetworkQueue",
            "sendGamepadProfileStateOnNetworkQueue",
            ".(send in ",
            ".(sendNowOnNetworkQueue",
        )
    )


def is_ios_runtime_symbol(name: str) -> bool:
    if is_shared_runtime_symbol(name):
        return True
    if ".GamepadControlVisualStyle." in name:
        return any(
            fragment in name
            for fragment in (".normalized.getter", ".isEmpty.getter", ".normalize")
        )
    if ".PocketPadSkinControlAppearance." in name:
        return any(
            fragment in name
            for fragment in (
                ".normalized.getter",
                ".normalize",
                ".isEmpty.getter",
                ".merged(over:",
                ".(MergeWorkspace",
            )
        )
    if ".PocketPadSkinAppearance." in name:
        return any(
            fragment in name
            for fragment in (
                ".normalized.getter",
                ".normalize",
                ".merged(over:",
                ".(MergeWorkspace",
            )
        )
    if ".PocketPadSkin." in name:
        return ".normalized.getter" in name or ".appearance(orientation:" in name
    if ".PocketPadSkinPackageValidator." in name:
        return any(
            fragment in name
            for fragment in (
                ".validate(",
                ".(ValidationWorkspace",
                ".referencedAssetIDs(",
                ".validateStyleReferences(",
            )
        )
    if ".PocketPadSkinPackageCodec." in name:
        return any(
            fragment in name
            for fragment in (
                ".encode(",
                ".decode(",
                ".(EncodingWorkspace",
                ".(DecodingWorkspace",
            )
        )
    if ".GamepadConfigurationProfile." in name and any(
        fragment in name
        for fragment in (".applySkin(", ".(SkinApplicationWorkspace", ".(SkinSlotApplicationWorkspace")
    ):
        return True
    if (
        ".PocketPadSkinResolver." in name
        or ".GamepadCustomization.applying(skinPackage:" in name
        or ".GamepadCustomization.resolvingAssetReferences" in name
    ):
        return any(
            fragment in name
            for fragment in (
                ".applying(package:",
                ".applying(skinPackage:",
                ".(applying in ",
                ".(SkinApplicationWorkspace",
                ".resolvingAssetReferences",
                ".resolveAssetReferencesInPlace",
                ".dehydratingAssets",
                ".dehydrateAssetReferencesInPlace",
            )
        )
    if ".ControllerClient." in name:
        return any(
            fragment in name
            for fragment in (
                "handleIncoming",
                "handlePairingMessage",
                "handleProfileStateMessage",
                "handleRuntimeMessage",
                "applyGamepadProfileStateFromMac",
                "installSyncedSkinPackages",
                "applyServerProfileMetadata",
                "IncomingProfileReconciliationWorkspace",
                "commitIncomingProfileState",
                "commitPendingKeypadEdits",
                "acknowledgeSyncedSkinSelections",
                "applyActiveCustomization",
                "applySkinToSelectedProfile",
            )
        )
    return ".PendingKeypadLayoutReconciler.reconcile(" in name


def scope_predicate(scope: str) -> Callable[[str], bool]:
    if scope == "controller":
        return is_controller_symbol
    if scope in ("network", "mac-network"):
        return is_mac_runtime_symbol
    return is_ios_runtime_symbol


def scope_object_names(scope: str) -> tuple[str, ...]:
    if scope == "controller":
        return CONTROLLER_OBJECT_NAMES
    if scope in ("network", "mac-network"):
        return MAC_RUNTIME_OBJECT_NAMES
    return IOS_RUNTIME_OBJECT_NAMES


def frame_limit(scope: str, name: str, override: int | None) -> int:
    if override is not None:
        return override
    if scope == "controller":
        return DEFAULT_CONTROLLER_MAX_BYTES
    if "GamepadConfigurationProfile.init(decoded:" in name:
        return 96 * KIB
    if scope in ("network", "mac-network"):
        return DEFAULT_MAC_MAX_BYTES
    if "IncomingProfileReconciliationWorkspace" in name and ".init(message:" in name:
        return 64 * KIB
    if ".PendingKeypadLayoutReconciler.reconcile(" in name:
        return 128 * KIB
    if "PocketPadSkinAppearance.(MergeWorkspace" in name:
        return 64 * KIB
    if ".PocketPadSkinPackageValidator.referencedAssetIDs(" in name:
        return 80 * KIB
    if ".PocketPadSkinPackageCodec." in name:
        return 64 * KIB
    if ".PocketPadSkinResolver.applying(package:" in name:
        return 64 * KIB
    if ".PocketPadSkinResolver.(applying in " in name:
        return 80 * KIB
    if "SkinApplicationWorkspace" in name or "SkinSlotApplicationWorkspace" in name:
        return 128 * KIB
    return DEFAULT_IOS_RUNTIME_MAX_BYTES


def required_sentinels(scope: str) -> tuple[tuple[str, tuple[str, ...]], ...]:
    if scope == "controller":
        return (("controller construction", ("ControllerPad",)),)
    shared = (
        ("wire message decode", ("ControllerMessage.init(from:",)),
        ("wire codec decode", ("ControllerWireCodec.decode",)),
        ("customization decode", ("GamepadCustomization.init(from:",)),
        ("profile decode", ("GamepadConfigurationProfile.init(from:",)),
        ("profile normalization", ("GamepadConfigurationProfile.normalized.getter",)),
        ("presentation comparison", ("GamepadCustomization.hasSamePresentation",)),
    )
    if scope in ("network", "mac-network"):
        return shared + (
            ("Mac receive", ("handleReceivedDataOnNetworkQueue",)),
            ("Mac routing", ("handleMessageOnNetworkQueue",)),
            ("Mac profile preparation", ("gamepadProfilesForClient",)),
            ("Mac deferred send", ("sendNowOnNetworkQueue",)),
        )
    return shared + (
        ("iOS receive", ("handleIncoming",)),
        ("iOS profile application", ("applyGamepadProfileStateFromMac",)),
        ("profile skin application", ("GamepadConfigurationProfile.applySkin",)),
        ("skin resolver", ("PocketPadSkinResolver.applying(package:",)),
        ("skin appearance selection", ("PocketPadSkin.appearance(orientation:",)),
        ("skin appearance normalization", ("PocketPadSkinAppearance.normalized.getter",)),
        ("skin control normalization", ("PocketPadSkinControlAppearance.normalized.getter",)),
        ("visual-style normalization", ("GamepadControlVisualStyle.normalized.getter",)),
        ("skin package validation", ("PocketPadSkinPackageValidator.validate(",)),
        ("skin package encoding", ("PocketPadSkinPackageCodec.encode(",)),
        ("skin package decoding", ("PocketPadSkinPackageCodec.decode(",)),
    )


def call_path_budgets(scope: str) -> tuple[CallPathBudget, ...]:
    if scope in ("network", "mac-network"):
        return (
            CallPathBudget(
                name="Mac profile decode",
                maximum_bytes=256 * KIB,
                groups=(
                    ("receive", ("handleReceivedDataOnNetworkQueue",)),
                    ("wire codec", ("ControllerWireCodec.decode",)),
                    ("message decoder", ("ControllerMessage.init(from:",)),
                    ("profile decoder", ("GamepadConfigurationProfile.init(from:",)),
                    ("profile field decoder", ("GamepadConfigurationProfile.(decode",)),
                    ("customization decoder", ("GamepadCustomization.init(from:",)),
                    ("customization normalized getter", ("GamepadCustomization.normalized.getter",)),
                    ("customization normalization coordinator", ("GamepadCustomization.normalizeInPlace",)),
                    ("customization normalization phase", ("GamepadCustomization.(normalize",)),
                    ("button normalization", ("GamepadButtonCustomization.normalized.getter",)),
                ),
            ),
            CallPathBudget(
                name="Mac profile encode",
                maximum_bytes=256 * KIB,
                groups=(
                    ("send", ("sendNowOnNetworkQueue",)),
                    ("wire codec", ("ControllerWireCodec.encode(_:",)),
                    ("message encoder", ("ControllerMessage.encode(to:",)),
                    ("profile encoder", ("GamepadConfigurationProfile.encode(to:",)),
                    ("customization encoder", ("GamepadCustomization.encode(to:",)),
                    ("customization encode phase", ("GamepadCustomization.(encode",)),
                    ("element synchronization phase", ("appendSynchronized",)),
                ),
            ),
        )
    if scope != "ios-runtime":
        return ()
    return (
        CallPathBudget(
            name="iOS profile decode",
            maximum_bytes=256 * KIB,
            groups=(
                ("incoming router", ("handleIncoming",)),
                ("wire codec", ("ControllerWireCodec.decode",)),
                ("message decoder", ("ControllerMessage.init(from:",)),
                ("profile decoder", ("GamepadConfigurationProfile.init(from:",)),
                ("profile field decoder", ("GamepadConfigurationProfile.(decode",)),
                ("customization decoder", ("GamepadCustomization.init(from:",)),
                ("customization normalized getter", ("GamepadCustomization.normalized.getter",)),
                ("normalization phase", ("GamepadCustomization.(normalize",)),
                ("button normalization", ("GamepadButtonCustomization.normalized.getter",)),
            ),
        ),
        CallPathBudget(
            name="physical iOS skin application",
            maximum_bytes=512 * KIB,
            groups=(
                ("UI entry", ("ControllerClient.applySkinToSelectedProfile",)),
                ("profile entry", ("GamepadConfigurationProfile.applySkin",)),
                ("profile orientation coordinator", ("GamepadConfigurationProfile.(SkinApplicationWorkspace", ".apply")),
                ("profile orientation preparation", ("GamepadConfigurationProfile.(SkinApplicationWorkspace", ".prepare")),
                ("profile slot phase", ("GamepadConfigurationProfile.(SkinSlotApplicationWorkspace", ".resolve")),
                ("customization resolver wrapper", ("GamepadCustomization.applying(skinPackage:",)),
                ("skin resolver entry", ("PocketPadSkinResolver.applying(package:",)),
                ("skin resolver coordinator", ("PocketPadSkinResolver.(SkinApplicationWorkspace", ".resolve()")),
                ("skin resolver phase", ("PocketPadSkinResolver.(SkinApplicationWorkspace", ".apply")),
                ("skin appearance selection", ("PocketPadSkin.appearance(orientation:",)),
                ("skin appearance merge", ("PocketPadSkinAppearance.merged(over:",)),
                ("skin appearance merge phase", ("PocketPadSkinAppearance.(MergeWorkspace",)),
                ("skin appearance normalization", ("PocketPadSkinAppearance.normalized.getter",)),
                ("skin control normalization", ("PocketPadSkinControlAppearance.normalized.getter",)),
                ("visual-style normalization", ("GamepadControlVisualStyle.normalized.getter",)),
                ("control appearance application", ("PocketPadSkinResolver.(applying in ",)),
            ),
        ),
    )


def inspect_object(path: Path, scope: str) -> list[tuple[FunctionFrame, str]]:
    symbol_result = subprocess.run(["nm", "-nm", str(path)], text=True, capture_output=True, check=True)
    symbols = [
        line.rsplit(maxsplit=1)[-1]
        for line in symbol_result.stdout.splitlines()
        if "(__TEXT,__text)" in line
        and (
            scope != "controller"
            or "Controller" in line
            or "GamepadFreeform" in line
        )
    ]
    names = demangle(symbols)
    if len(symbols) != len(names):
        raise RuntimeError("swift-demangle returned an unexpected symbol count")
    predicate = scope_predicate(scope)
    scoped_names = {symbol: name for symbol, name in zip(symbols, names) if predicate(name)}
    if not scoped_names:
        return []

    result = subprocess.run(
        [
            "xcrun",
            "llvm-objdump",
            "--disassemble",
            "--no-show-raw-insn",
            f"--disassemble-symbols={','.join(scoped_names)}",
            str(path),
        ],
        text=True,
        capture_output=True,
        check=True,
    )
    return [
        (frame, scoped_names[frame.symbol])
        for frame in parse_disassembly(result.stdout)
        if frame.symbol in scoped_names
    ]


def discover_objects(explicit_objects: list[Path], roots: list[Path], scope: str) -> list[Path]:
    discovered = list(explicit_objects)
    names = scope_object_names(scope)
    for root in roots:
        if root.is_file() and root.name in names:
            discovered.append(root)
        elif root.exists():
            for name in names:
                discovered.extend(root.rglob(name))
    return sorted({path.resolve() for path in discovered if path.exists()})


def matches_all(name: str, fragments: tuple[str, ...]) -> bool:
    return all(fragment in name for fragment in fragments)


def validate_required(entries: list[FrameEntry], scope: str) -> list[str]:
    missing = []
    for label, fragments in required_sentinels(scope):
        if not any(matches_all(entry.name, fragments) for entry in entries):
            missing.append(label)
    return missing


def validate_call_paths(entries: list[FrameEntry], scope: str) -> list[str]:
    errors: list[str] = []
    for path in call_path_budgets(scope):
        total = 0
        details: list[str] = []
        incomplete = False
        for label, fragments in path.groups:
            matches = [entry for entry in entries if matches_all(entry.name, fragments)]
            if not matches:
                errors.append(f"{path.name}: no symbol matched call-path group '{label}'")
                incomplete = True
                continue
            largest = max(matches, key=lambda entry: entry.frame.stack_bytes)
            total += largest.frame.stack_bytes
            details.append(f"{label}={largest.frame.stack_bytes}")
        if incomplete:
            continue
        if total > path.maximum_bytes:
            errors.append(
                f"{path.name}: {total} bytes exceeds {path.maximum_bytes} bytes "
                f"({', '.join(details)})"
            )
    return errors


def run_self_test() -> None:
    fixture = """
_$s12ThumbConsole17ControllerPadViewV4bodyQrvp:
       0: stp x28, x27, [sp, #-0x30]!
       4: stp x29, x30, [sp, #0x20]
       8: sub sp, sp, #0x48, lsl #12
       c: sub sp, sp, #0xf30
      10: ret
00000014 <_$s12ThumbConsole7CompareyyF>:
      14: str x28, [sp, #-0x30]!
      18: sub sp, sp, #0x5e, lsl #12
      1c: sub sp, sp, #0x300
      20: ret
_register:
      24: stp x29, x30, [sp, #-32]!
      28: mov x9, #0x3000
      2c: movk x9, #0x1, lsl #16
      30: sub sp, sp, x9
      34: ret
"""
    frames = parse_disassembly(fixture)
    assert frames == [
        FunctionFrame("_$s12ThumbConsole17ControllerPadViewV4bodyQrvp", 298_848),
        FunctionFrame("_$s12ThumbConsole7CompareyyF", 385_840),
        FunctionFrame("_register", 77_856),
    ], frames
    print("stack-frame parser self-test passed")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--object", action="append", default=[], type=Path)
    parser.add_argument("--object-root", action="append", default=[], type=Path)
    parser.add_argument(
        "--scope",
        choices=("controller", "network", "mac-network", "ios-runtime"),
        default="controller",
    )
    parser.add_argument("--max-bytes", type=int)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        run_self_test()
        return 0

    objects = discover_objects(args.object, args.object_root, args.scope)
    if not objects:
        print(
            f"error: no expected objects found for {args.scope}: {', '.join(scope_object_names(args.scope))}",
            file=sys.stderr,
        )
        return 2

    entries: list[FrameEntry] = []
    for object_path in objects:
        try:
            inspected = inspect_object(object_path, args.scope)
        except subprocess.CalledProcessError as error:
            print(error.stderr, file=sys.stderr)
            return error.returncode or 2
        entries.extend(FrameEntry(frame, name, object_path) for frame, name in inspected)

    if not entries:
        print(f"error: {args.scope} stack-frame check matched no scoped symbols", file=sys.stderr)
        return 2

    expected_objects = set(scope_object_names(args.scope))
    matched_objects = {entry.object_path.name for entry in entries}
    missing_objects = sorted(expected_objects - matched_objects)
    if missing_objects:
        print(
            f"error: {args.scope} stack-frame check matched no scoped symbols in {', '.join(missing_objects)}",
            file=sys.stderr,
        )
        return 2

    missing_sentinels = validate_required(entries, args.scope)
    if missing_sentinels:
        print(
            f"error: {args.scope} stack-frame check missed required symbol groups: {', '.join(missing_sentinels)}",
            file=sys.stderr,
        )
        return 2

    offenders = sorted(
        (
            (entry, frame_limit(args.scope, entry.name, args.max_bytes))
            for entry in entries
            if entry.frame.stack_bytes > frame_limit(args.scope, entry.name, args.max_bytes)
        ),
        key=lambda item: item[0].frame.stack_bytes,
        reverse=True,
    )
    path_errors = validate_call_paths(entries, args.scope)
    if offenders or path_errors:
        print(f"error: {args.scope} stack budget exceeded", file=sys.stderr)
        for entry, limit in offenders:
            print(
                f"  {entry.frame.stack_bytes:>7} bytes (limit {limit:>7})  {entry.name}\n"
                f"                 object: {entry.object_path}",
                file=sys.stderr,
            )
        for error in path_errors:
            print(f"  call path: {error}", file=sys.stderr)
        return 1

    largest = max(entries, key=lambda entry: entry.frame.stack_bytes)
    print(
        f"{args.scope} stack-frame check passed: {len(entries)} symbols, "
        f"largest {largest.frame.stack_bytes} bytes"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
