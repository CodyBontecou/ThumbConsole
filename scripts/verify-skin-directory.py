#!/usr/bin/env python3
"""Verify the deployable Thumble web skin directory without third-party packages."""

from __future__ import annotations

import hashlib
import json
import re
import shutil
import stat
import struct
import subprocess
import sys
import zipfile
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "Website"
CATALOG_PATH = WEB / "skins" / "catalog.json"
IDENTIFIER = re.compile(r"^[a-z0-9]+(?:[.-][a-z0-9]+)+$")
SLUG = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
SHA256 = re.compile(r"^[a-f0-9]{64}$")


def fail(message: str) -> None:
    raise AssertionError(message)


def web_path(value: str, expected_prefix: str) -> Path:
    if not value.startswith(expected_prefix) or "\\" in value:
        fail(f"Unsafe catalog path: {value}")
    relative = PurePosixPath(value.removeprefix("/"))
    if any(part in {"", ".", ".."} for part in relative.parts):
        fail(f"Unsafe catalog path: {value}")
    return WEB.joinpath(*relative.parts)


def verify_png(path: Path, expected: dict[str, int]) -> None:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        fail(f"Not a PNG: {path}")
    width, height = struct.unpack(">II", data[16:24])
    if width != expected["width"] or height != expected["height"]:
        fail(f"PNG dimensions do not match catalog: {path}")
    if width < 1000 or height < 400:
        fail(f"Preview is too small for the directory: {path}")


def verify_package(path: Path, entry: dict) -> None:
    package_data = path.read_bytes()
    if len(package_data) != entry["packageByteCount"]:
        fail(f"Package byte count mismatch: {path}")
    digest = hashlib.sha256(package_data).hexdigest()
    if digest != entry["packageSHA256"]:
        fail(f"Package digest mismatch: {path}")

    with zipfile.ZipFile(path) as archive:
        names: set[str] = set()
        total_uncompressed = 0
        for info in archive.infolist():
            normalized = PurePosixPath(info.filename)
            if info.filename.startswith("/") or "\\" in info.filename:
                fail(f"Unsafe ZIP path in {path}: {info.filename}")
            if any(part in {"", ".", ".."} for part in normalized.parts):
                fail(f"Unsafe ZIP path in {path}: {info.filename}")
            if info.filename in names:
                fail(f"Duplicate ZIP entry in {path}: {info.filename}")
            names.add(info.filename)
            total_uncompressed += info.file_size
            unix_mode = info.external_attr >> 16
            if stat.S_ISLNK(unix_mode):
                fail(f"Symlink ZIP entry in {path}: {info.filename}")
        if total_uncompressed > 64 * 1024 * 1024:
            fail(f"Package exceeds directory expansion budget: {path}")
        if not {"manifest.json", "skin.json"}.issubset(names):
            fail(f"Package is missing manifest.json or skin.json: {path}")

        manifest = json.loads(archive.read("manifest.json"))
        if manifest["identifier"] != entry["identifier"]:
            fail(f"Manifest identifier mismatch: {path}")
        if manifest["version"] != entry["version"]:
            fail(f"Manifest version mismatch: {path}")
        if manifest["name"] != entry["name"]:
            fail(f"Manifest name mismatch: {path}")
        if manifest.get("kind") != "skin":
            fail(f"Directory accepts appearance-only skin packages: {path}")
        if manifest.get("profilePath"):
            fail(f"Executable profile content is not allowed: {path}")

        previews = manifest.get("previews", [])
        if not previews:
            fail(f"Package has no embedded preview: {path}")
        for preview in previews:
            payload = archive.read(preview["path"])
            if len(payload) != preview["byteCount"]:
                fail(f"Embedded preview byte count mismatch: {path}")
            if hashlib.sha256(payload).hexdigest() != preview["sha256"]:
                fail(f"Embedded preview digest mismatch: {path}")


def main() -> int:
    if not CATALOG_PATH.exists():
        fail("Website/skins/catalog.json is missing; run scripts/build-skin-directory.sh")
    catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    if catalog.get("schemaVersion") != 1:
        fail("Unsupported website skin catalog schema")
    skins = catalog.get("skins")
    if not isinstance(skins, list) or not skins:
        fail("Skin catalog must include at least one skin")

    slugs: set[str] = set()
    identifiers: set[str] = set()
    for entry in skins:
        slug = entry.get("slug", "")
        identifier = entry.get("identifier", "")
        if not SLUG.fullmatch(slug):
            fail(f"Invalid skin slug: {slug}")
        if not IDENTIFIER.fullmatch(identifier):
            fail(f"Invalid skin identifier: {identifier}")
        if slug in slugs or identifier in identifiers:
            fail(f"Duplicate skin identity: {slug} / {identifier}")
        slugs.add(slug)
        identifiers.add(identifier)
        if not SHA256.fullmatch(entry.get("packageSHA256", "")):
            fail(f"Invalid package SHA-256 for {slug}")
        if not entry.get("description") or not entry.get("summary"):
            fail(f"Skin lacks directory copy: {slug}")
        if not entry.get("palette") or not entry.get("modes"):
            fail(f"Skin lacks visual filters: {slug}")

        package = web_path(entry["downloadPath"], "/skins/packages/")
        preview = web_path(entry["previewPath"], "/skins/previews/")
        if not package.is_file() or not preview.is_file():
            fail(f"Catalog asset is missing for {slug}")
        verify_package(package, entry)
        verify_png(preview, entry["preview"])

    html = (WEB / "skins.html").read_text(encoding="utf-8")
    for marker in ('id="skin-directory"', 'id="skin-search"', 'id="skin-detail"', 'src="/skins.js"'):
        if marker not in html:
            fail(f"skins.html is missing required hook: {marker}")
    headers = (WEB / "_headers").read_text(encoding="utf-8")
    if "application/vnd.pocketpad.skin+zip" not in headers:
        fail("Website/_headers does not declare the .pocketpad media type")

    node = shutil.which("node")
    if node:
        subprocess.run([node, "--check", str(WEB / "skins.js")], check=True)
        subprocess.run([node, "--check", str(WEB / "script.js")], check=True)

    print(f"Verified {len(skins)} web skin packages, previews, catalog entries, and page assets.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, KeyError, ValueError, zipfile.BadZipFile) as error:
        print(f"Skin directory verification failed: {error}", file=sys.stderr)
        raise SystemExit(1)
