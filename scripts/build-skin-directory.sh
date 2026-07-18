#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

binary="${1:-}"
if [[ "$binary" == "--binary" ]]; then
  binary="${2:-}"
fi
if [[ -z "$binary" ]]; then
  binary="$(find "${HOME}/Library/Developer/Xcode/DerivedData" /tmp -path '*/Build/Products/Debug/thumbconsole' -type f -perm -111 2>/dev/null | head -1 || true)"
fi
if [[ -z "$binary" || ! -x "$binary" ]]; then
  echo "usage: $0 [--binary] /path/to/thumbconsole" >&2
  exit 2
fi

output_root="$repo_root/Website/skins"
packages_root="$output_root/packages"
previews_root="$output_root/previews"
temporary="$(mktemp -d "${TMPDIR:-/tmp}/thumbconsole-skin-directory.XXXXXX")"
trap 'rm -rf "$temporary"' EXIT

rm -rf "$packages_root" "$previews_root"
mkdir -p "$packages_root" "$previews_root"

manifest_value() {
  python3 - "$1" "$2" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    value = json.load(handle)
for component in sys.argv[2].split("."):
    value = value[component]
print(value)
PY
}

attach_preview() {
  local source_directory="$1"
  local preview_file="$2"
  local scheme="$3"
  local preview_name="directory-landscape-${scheme}.png"
  mkdir -p "$source_directory/previews"
  cp "$preview_file" "$source_directory/previews/$preview_name"
  python3 - "$source_directory/manifest.json" "$source_directory/previews/$preview_name" "$preview_name" "$scheme" <<'PY'
import hashlib, json, os, sys
manifest_path, preview_path, preview_name, scheme = sys.argv[1:]
with open(manifest_path, encoding="utf-8") as handle:
    manifest = json.load(handle)
with open(preview_path, "rb") as handle:
    data = handle.read()
manifest["previews"] = [{
    "id": f"directory-landscape-{scheme}",
    "path": f"previews/{preview_name}",
    "orientation": "landscape",
    "colorScheme": scheme,
    "byteCount": len(data),
    "sha256": hashlib.sha256(data).hexdigest(),
}]
with open(manifest_path, "w", encoding="utf-8") as handle:
    json.dump(manifest, handle, indent=2, ensure_ascii=False)
    handle.write("\n")
PY
}

finish_package() {
  local slug="$1"
  local source_directory="$2"
  local scheme="$3"
  local bootstrap="$temporary/${slug}-bootstrap.pocketpad"
  local raw_preview="$temporary/${slug}.png"

  "$binary" skin pack "$source_directory" -o "$bootstrap"
  "$binary" skin render "$bootstrap" --appearance "$scheme" --clean -o "$raw_preview"
  attach_preview "$source_directory" "$raw_preview" "$scheme"

  local version
  version="$(manifest_value "$source_directory/manifest.json" version)"
  local package_file="$packages_root/${slug}-${version}.pocketpad"
  local preview_file="$previews_root/${slug}-${version}.png"
  cp "$raw_preview" "$preview_file"
  "$binary" skin pack "$source_directory" -o "$package_file"
  "$binary" skin validate "$package_file" --strict
}

build_bundled() {
  local slug="$1"
  local identifier="$2"
  local scheme="$3"
  local bootstrap="$temporary/${slug}-bundled.pocketpad"
  local source_directory="$temporary/${slug}-source"
  "$binary" skin export "$identifier" -o "$bootstrap"
  "$binary" skin unpack "$bootstrap" -o "$source_directory"
  finish_package "$slug" "$source_directory" "$scheme"
}

build_source() {
  local slug="$1"
  local source_directory="$2"
  local scheme="$3"
  local staged_source="$temporary/${slug}-source"
  mkdir -p "$staged_source"
  cp -R "$source_directory/." "$staged_source/"
  rm -rf "$staged_source/previews"
  python3 - "$staged_source/manifest.json" <<'PY'
import json, sys
path = sys.argv[1]
with open(path, encoding="utf-8") as handle:
    manifest = json.load(handle)
manifest["previews"] = []
with open(path, "w", encoding="utf-8") as handle:
    json.dump(manifest, handle, indent=2, ensure_ascii=False)
    handle.write("\n")
PY
  finish_package "$slug" "$staged_source" "$scheme"
}

build_approved_package() {
  local slug="$1"
  local approved_package="$2"
  local scheme="$3"
  local artboard="$4"
  local approval_file="$5"
  local version
  version="$(python3 - "$approved_package" "$approval_file" <<'PY'
import hashlib, json, sys, zipfile
from pathlib import Path

package_path, approval_path = map(Path, sys.argv[1:])
approval = json.loads(approval_path.read_text(encoding="utf-8"))
if approval.get("status") != "approved" or not approval.get("approvedBy") or not approval.get("approvedAt"):
    raise SystemExit("Approved package publication requires explicit reviewer and timestamp")
actual_hash = hashlib.sha256(package_path.read_bytes()).hexdigest()
if approval.get("packageSHA256") != actual_hash:
    raise SystemExit("Approved package SHA-256 does not match publication candidate")
workspace_root = approval_path.parent.parent
reviewed_sheet = workspace_root / approval.get("reviewedContactSheet", "")
if not reviewed_sheet.is_file():
    raise SystemExit("Approved contact sheet is missing")
with zipfile.ZipFile(package_path) as archive:
    print(json.loads(archive.read("manifest.json"))["version"])
PY
)"
  local package_digest
  package_digest="$(shasum -a 256 "$approved_package" | awk '{print $1}')"
  local package_file="$packages_root/${slug}-${version}-${package_digest:0:12}.pocketpad"
  local preview_file="$previews_root/${slug}-${version}.png"
  local light_preview_file="$previews_root/${slug}-${version}-light.png"

  # Preserve the exact human-approved package bytes and render discovery media
  # independently through the native app renderer.
  cp "$approved_package" "$package_file"
  "$binary" skin validate "$package_file" --strict
  "$binary" skin quality "$package_file" --artboard "$artboard" --strict
  "$binary" skin preview "$package_file" \
    --artboard "$artboard" --orientation landscape --appearance "$scheme" --state normal \
    --native-renderer --render-scale 2 -o "$preview_file"
  "$binary" skin preview "$package_file" \
    --artboard "$artboard" --orientation landscape --appearance light --state normal \
    --native-renderer --render-scale 2 -o "$light_preview_file"
}

build_approved_package \
  "indigo-pocket" \
  "$repo_root/docs/skins/examples/indigo-pocket/dist/indigo-pocket-1.0.0.pocketpad" \
  "dark" \
  "showcase-controller-v1" \
  "$repo_root/docs/skins/examples/indigo-pocket/reviews/human-approval.json"

build_approved_package \
  "solar-sumi" \
  "$repo_root/docs/skins/examples/solar-sumi/dist/solar-sumi-1.0.0.pocketpad" \
  "dark" \
  "arcade-stick-v1" \
  "$repo_root/docs/skins/examples/solar-sumi/reviews/human-approval.json"

build_approved_package \
  "tideglass-field" \
  "$repo_root/docs/skins/examples/tideglass-field/dist/tideglass-field-1.0.0.pocketpad" \
  "dark" \
  "game-boy-v1" \
  "$repo_root/docs/skins/examples/tideglass-field/reviews/human-approval.json"

build_approved_package \
  "foldline-relay" \
  "$repo_root/docs/skins/examples/foldline-relay/dist/foldline-relay-1.0.0.pocketpad" \
  "dark" \
  "productivity-one-handed-left-v1" \
  "$repo_root/docs/skins/examples/foldline-relay/reviews/human-approval.json"

python3 - "$output_root/catalog.source.json" "$output_root/catalog.json" "$packages_root" "$previews_root" <<'PY'
import hashlib, json, struct, sys, zipfile
from pathlib import Path

source_path, output_path, packages_path, previews_path = map(Path, sys.argv[1:])
source = json.loads(source_path.read_text(encoding="utf-8"))
result = {
    "schemaVersion": source["schemaVersion"],
    "updatedAt": source.get("updatedAt", "2026-07-16"),
    "skins": [],
}

for editorial in source["skins"]:
    slug = editorial["slug"]
    matches = sorted(packages_path.glob(f"{slug}-*.pocketpad"))
    if len(matches) != 1:
        raise SystemExit(f"Expected one generated package for {slug}, found {len(matches)}")
    package_path = matches[0]
    package_data = package_path.read_bytes()
    with zipfile.ZipFile(package_path) as archive:
        manifest = json.loads(archive.read("manifest.json"))
    if manifest["identifier"] != editorial["identifier"]:
        raise SystemExit(f"Catalog identifier mismatch for {slug}")

    preview_path = previews_path / f"{slug}-{manifest['version']}.png"
    preview_data = preview_path.read_bytes()
    if preview_data[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit(f"Preview is not PNG for {slug}")
    width, height = struct.unpack(">II", preview_data[16:24])

    entry = {key: value for key, value in editorial.items() if key != "origin"}
    entry.update({
        "name": manifest["name"],
        "version": manifest["version"],
        "author": manifest["author"],
        "summary": manifest.get("summary", ""),
        "license": manifest.get("license", ""),
        "homepage": manifest.get("homepage"),
        "minimumAppVersion": manifest.get("minimumAppVersion"),
        "tags": manifest.get("tags", []),
        "downloadPath": f"/skins/packages/{package_path.name}",
        "previewPath": f"/skins/previews/{preview_path.name}",
        "packageByteCount": len(package_data),
        "packageSHA256": hashlib.sha256(package_data).hexdigest(),
        "preview": {"width": width, "height": height},
    })
    result["skins"].append(entry)

output_path.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
PY

python3 scripts/verify-skin-directory.py
printf '\nBuilt %s skin packages in %s\n' "$(find "$packages_root" -name '*.pocketpad' | wc -l | tr -d ' ')" "$output_root"
