#!/usr/bin/env python3
"""Fail a Debug build when controller SwiftUI construction frames grow too large."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

DEFAULT_MAX_BYTES = 32 * 1024
SCOPED_TYPE_NAMES = ("ControllerPad",)
FREEFORM_TYPE_NAME = "GamepadFreeformControllerCanvas"


@dataclass(frozen=True)
class FunctionFrame:
    symbol: str
    stack_bytes: int


def parse_immediate(text: str) -> int:
    return int(text, 16 if text.lower().startswith("0x") else 10)


def arm64_stack_bytes(instructions: list[str]) -> int:
    """Return static stack reserved in an arm64 function prologue."""
    total = 0
    for instruction in instructions[:32]:
        preindexed = re.search(r"\[sp,\s*#-(0x[0-9a-fA-F]+|\d+)\]!", instruction)
        if preindexed:
            total += parse_immediate(preindexed.group(1))

        subtraction = re.search(
            r"\bsub\s+sp,\s*sp,\s*#(0x[0-9a-fA-F]+|\d+)(?:,\s*lsl\s*#(\d+))?",
            instruction,
        )
        if subtraction:
            amount = parse_immediate(subtraction.group(1))
            if subtraction.group(2):
                amount <<= int(subtraction.group(2))
            total += amount
    return total


def x86_64_stack_bytes(instructions: list[str]) -> int:
    """Return static stack reserved in an x86_64 function prologue."""
    total = 0
    for instruction in instructions[:32]:
        if re.search(r"\bpushq?\b", instruction):
            total += 8
        subtraction = re.search(
            r"\bsubq?\s+\$(0x[0-9a-fA-F]+|\d+),\s*%rsp",
            instruction,
        )
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
        stack_bytes = max(
            arm64_stack_bytes(instructions),
            x86_64_stack_bytes(instructions),
        )
        frames.append(FunctionFrame(symbol=symbol, stack_bytes=stack_bytes))

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


def is_scoped_controller_symbol(name: str) -> bool:
    if any(type_name in name for type_name in SCOPED_TYPE_NAMES):
        return True
    return FREEFORM_TYPE_NAME in name and (
        ".body.getter" in name or ".renderedControl(" in name
    )


def inspect_object(path: Path) -> list[tuple[FunctionFrame, str]]:
    symbol_result = subprocess.run(
        ["nm", "-nm", str(path)],
        text=True,
        capture_output=True,
        check=True,
    )
    candidate_symbols = [
        line.rsplit(maxsplit=1)[-1]
        for line in symbol_result.stdout.splitlines()
        if "(__TEXT,__text)" in line
        and ("Controller" in line or "GamepadFreeform" in line)
    ]
    candidate_names = demangle(candidate_symbols)
    if len(candidate_symbols) != len(candidate_names):
        raise RuntimeError("swift-demangle returned an unexpected symbol count")
    scoped_names = {
        symbol: name
        for symbol, name in zip(candidate_symbols, candidate_names)
        if is_scoped_controller_symbol(name)
    }
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
    frames = parse_disassembly(result.stdout)
    return [
        (frame, scoped_names[frame.symbol])
        for frame in frames
        if frame.symbol in scoped_names
    ]


def discover_objects(explicit_objects: list[Path], roots: list[Path]) -> list[Path]:
    discovered = list(explicit_objects)
    for root in roots:
        if root.is_file() and root.name == "IOSContentView.o":
            discovered.append(root)
        elif root.exists():
            discovered.extend(root.rglob("IOSContentView.o"))
    return sorted({path.resolve() for path in discovered if path.exists()})


def run_self_test() -> None:
    fixture = """
_$s12ThumbConsole17ControllerPadViewV4bodyQrvp:
       0: stp x28, x27, [sp, #-0x30]!
       4: stp x29, x30, [sp, #0x20]
       8: sub sp, sp, #0x14, lsl #12
       c: sub sp, sp, #0x620
      10: ret
_direct:
      14: sub sp, sp, #0x70
      18: ret
"""
    frames = parse_disassembly(fixture)
    assert frames == [
        FunctionFrame("_$s12ThumbConsole17ControllerPadViewV4bodyQrvp", 0x14650),
        FunctionFrame("_direct", 0x70),
    ], frames
    print("controller stack-frame parser self-test passed")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--object", action="append", default=[], type=Path)
    parser.add_argument("--object-root", action="append", default=[], type=Path)
    parser.add_argument("--max-bytes", type=int, default=DEFAULT_MAX_BYTES)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        run_self_test()
        return 0

    objects = discover_objects(args.object, args.object_root)
    if not objects:
        print("error: no IOSContentView.o found for controller stack-frame check", file=sys.stderr)
        return 2

    scoped: list[tuple[FunctionFrame, str, Path]] = []
    for object_path in objects:
        try:
            inspected = inspect_object(object_path)
        except subprocess.CalledProcessError as error:
            print(error.stderr, file=sys.stderr)
            return error.returncode or 2
        for frame, name in inspected:
            if is_scoped_controller_symbol(name):
                scoped.append((frame, name, object_path))

    if not scoped:
        print("error: controller stack-frame check matched no scoped symbols", file=sys.stderr)
        return 2

    offenders = sorted(
        (entry for entry in scoped if entry[0].stack_bytes > args.max_bytes),
        key=lambda entry: entry[0].stack_bytes,
        reverse=True,
    )
    if offenders:
        print(
            f"error: controller stack-frame budget exceeded ({args.max_bytes} bytes maximum)",
            file=sys.stderr,
        )
        for frame, name, object_path in offenders:
            print(
                f"  {frame.stack_bytes:>7} bytes  {name}\n"
                f"                 object: {object_path}",
                file=sys.stderr,
            )
        return 1

    largest = max(scoped, key=lambda entry: entry[0].stack_bytes)
    print(
        f"controller stack-frame check passed: {len(scoped)} symbols, "
        f"largest {largest[0].stack_bytes} bytes (limit {args.max_bytes})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
