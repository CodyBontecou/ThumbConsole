#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Archive PocketPadiOS, export an IPA, upload it to App Store Connect, and optionally distribute to TestFlight.

Usage:
  scripts/release/ios-testflight.sh [options]

Options:
  --app <app-id-or-bundle-id>  App Store Connect app ID, bundle ID, or exact app name.
  --group <group-id-or-name>   TestFlight beta group ID/name to distribute to.
  --version <version>          Marketing version to stamp into the archive.
  --build-number <number>      Build number to stamp into the archive.
  --notes <text>               What to Test notes.
  --notes-file <path>          Read What to Test notes from a file.
  --uses-non-exempt-encryption <true|false>
                                Export-compliance value to set after upload. Default: false.
  --notify                     Notify TestFlight testers after distribution.
  --upload-only                Upload and wait for processing, but do not distribute to groups.
  --skip-upload                Build/export the IPA locally, but do not contact App Store Connect.
  --skip-xcodegen              Do not regenerate PocketPad.xcodeproj from project.yml.
  -h, --help                   Show this help.

Environment defaults:
  ASC_APP_ID or POCKETPAD_IOS_ASC_APP_ID
  POCKETPAD_TESTFLIGHT_GROUP
  POCKETPAD_IOS_VERSION
  POCKETPAD_IOS_BUILD_NUMBER
  POCKETPAD_USES_NON_EXEMPT_ENCRYPTION=false
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

log() {
  printf '\n==> %s\n' "$*"
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

APP_ID="${POCKETPAD_IOS_ASC_APP_ID:-${ASC_APP_ID:-}}"
GROUP="${POCKETPAD_TESTFLIGHT_GROUP:-}"
VERSION="${POCKETPAD_IOS_VERSION:-}"
BUILD_NUMBER="${POCKETPAD_IOS_BUILD_NUMBER:-${POCKETPAD_BUILD_NUMBER:-}}"
TEST_NOTES="${POCKETPAD_TESTFLIGHT_NOTES:-}"
NOTES_FILE=""
USES_NON_EXEMPT_ENCRYPTION="${POCKETPAD_USES_NON_EXEMPT_ENCRYPTION:-false}"
NOTIFY=0
UPLOAD_ONLY=0
SKIP_UPLOAD=0
SKIP_XCODEGEN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      APP_ID="${2:-}"; shift 2 ;;
    --group)
      GROUP="${2:-}"; shift 2 ;;
    --version)
      VERSION="${2:-}"; shift 2 ;;
    --build-number)
      BUILD_NUMBER="${2:-}"; shift 2 ;;
    --notes)
      TEST_NOTES="${2:-}"; shift 2 ;;
    --notes-file)
      NOTES_FILE="${2:-}"; shift 2 ;;
    --uses-non-exempt-encryption)
      USES_NON_EXEMPT_ENCRYPTION="${2:-}"; shift 2 ;;
    --notify)
      NOTIFY=1; shift ;;
    --upload-only)
      UPLOAD_ONLY=1; shift ;;
    --skip-upload)
      SKIP_UPLOAD=1; shift ;;
    --skip-xcodegen)
      SKIP_XCODEGEN=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      die "unknown option: $1" ;;
  esac
done

PROJECT="${POCKETPAD_XCODE_PROJECT:-PocketPad.xcodeproj}"
SCHEME="${POCKETPAD_IOS_SCHEME:-PocketPadiOS}"
CONFIGURATION="${CONFIGURATION:-Release}"
TEAM_ID="${POCKETPAD_DEVELOPMENT_TEAM:-67KC823C9A}"
EXPORT_OPTIONS="${POCKETPAD_IOS_EXPORT_OPTIONS:-Config/ExportOptions/iOS-TestFlight.plist}"
ARTIFACT_ROOT="${POCKETPAD_RELEASE_DIR:-.release}"

[[ -d "$PROJECT" ]] || die "missing Xcode project: $PROJECT"
[[ -f "$EXPORT_OPTIONS" ]] || die "missing export options plist: $EXPORT_OPTIONS"
command -v xcodebuild >/dev/null || die "xcodebuild not found"
command -v asc >/dev/null || die "asc CLI not found; install/configure asc before releasing"
command -v python3 >/dev/null || die "python3 not found"

if [[ $SKIP_XCODEGEN -eq 0 && -f project.yml ]]; then
  if command -v xcodegen >/dev/null; then
    log "Regenerating Xcode project"
    xcodegen generate
  else
    echo "warning: xcodegen not found; using existing $PROJECT" >&2
  fi
fi

xcode_setting() {
  local key="$1"
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIGURATION" -showBuildSettings 2>/dev/null \
    | awk -F= -v key="$key" '
      $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
        value=$2
        sub(/^[[:space:]]+/, "", value)
        sub(/[[:space:]]+$/, "", value)
        print value
        exit
      }'
}

if [[ -z "$VERSION" ]]; then
  VERSION="$(xcode_setting MARKETING_VERSION)"
fi
if [[ -z "$VERSION" ]]; then
  VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/iOS/Info.plist 2>/dev/null || true)"
fi
[[ -n "$VERSION" ]] || die "could not determine version; pass --version"

parse_next_build_number() {
  python3 -c '
import json
import re
import sys
text = sys.stdin.read()
try:
    data = json.loads(text)
except Exception:
    match = re.search(r"\b\d+\b", text)
    if match:
        print(match.group(0))
        raise SystemExit(0)
    raise SystemExit(1)

candidates = [data]
if isinstance(data, dict):
    for key in ("data", "result", "build", "latest"):
        value = data.get(key)
        if isinstance(value, dict):
            candidates.append(value)
        elif isinstance(value, list):
            candidates.extend(value)
elif isinstance(data, list):
    candidates.extend(data)
for item in candidates:
    if not isinstance(item, dict):
        continue
    for key in ("nextBuildNumber", "next_build_number", "buildNumber", "build_number", "number", "value"):
        value = item.get(key)
        if value is not None:
            print(str(value))
            raise SystemExit(0)
match = re.search(r"\b\d+\b", text)
if match:
    print(match.group(0))
    raise SystemExit(0)
raise SystemExit(1)
'
}

parse_build_id() {
  python3 -c '
import json
import re
import sys
text = sys.stdin.read()
objects = []
for line in text.splitlines():
    line = line.strip()
    if not line or not (line.startswith("{") or line.startswith("[")):
        continue
    try:
        objects.append(json.loads(line))
    except Exception:
        pass
try:
    objects.append(json.loads(text))
except Exception:
    pass
for data in reversed(objects):
    candidates = [data]
    if isinstance(data, dict):
        for key in ("data", "result", "build"):
            value = data.get(key)
            if isinstance(value, dict):
                candidates.append(value)
            elif isinstance(value, list):
                candidates.extend(value)
    elif isinstance(data, list):
        candidates.extend(data)
    for item in candidates:
        if isinstance(item, dict) and item.get("type") == "builds" and item.get("id"):
            print(item["id"])
            raise SystemExit(0)
        if isinstance(item, dict) and item.get("buildId"):
            print(item["buildId"])
            raise SystemExit(0)
match = re.search(r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}", text)
if match:
    print(match.group(0))
    raise SystemExit(0)
raise SystemExit(1)
'
}

if [[ -z "$BUILD_NUMBER" && -n "$APP_ID" && $SKIP_UPLOAD -eq 0 ]]; then
  log "Resolving next safe App Store Connect build number"
  next_build_json="$(asc builds next-build-number \
    --app "$APP_ID" \
    --version "$VERSION" \
    --platform IOS \
    --output json)"
  BUILD_NUMBER="$(printf '%s' "$next_build_json" | parse_next_build_number)" || die "could not parse next build number from asc output: $next_build_json"
fi

if [[ -z "$BUILD_NUMBER" ]]; then
  BUILD_NUMBER="$(xcode_setting CURRENT_PROJECT_VERSION)"
fi
if [[ -z "$BUILD_NUMBER" ]]; then
  BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' Resources/iOS/Info.plist 2>/dev/null || true)"
fi
[[ -n "$BUILD_NUMBER" ]] || BUILD_NUMBER="$(date -u +%Y%m%d%H%M)"

if [[ -n "$NOTES_FILE" ]]; then
  [[ -f "$NOTES_FILE" ]] || die "notes file not found: $NOTES_FILE"
  TEST_NOTES="$(cat "$NOTES_FILE")"
fi

case "$USES_NON_EXEMPT_ENCRYPTION" in
  true|false|"") ;;
  *) die "--uses-non-exempt-encryption must be true or false" ;;
esac

safe_version="$(python3 - <<'PY' "$VERSION-$BUILD_NUMBER"
import re, sys
print(re.sub(r'[^A-Za-z0-9._-]+', '-', sys.argv[1]).strip('-'))
PY
)"
release_dir="$ARTIFACT_ROOT/ios/$safe_version"
archive_path="$release_dir/PocketPadiOS.xcarchive"
ipa_path="$release_dir/PocketPadiOS-$safe_version.ipa"

rm -rf "$release_dir"
mkdir -p "$release_dir"

log "Archiving $SCHEME $VERSION ($BUILD_NUMBER)"
asc xcode archive \
  --project "$PROJECT" \
  --scheme "$SCHEME" \
  --configuration "$CONFIGURATION" \
  --clean \
  --overwrite \
  --archive-path "$archive_path" \
  --xcodebuild-flag=-destination \
  --xcodebuild-flag=generic/platform=iOS \
  --xcodebuild-flag=DEVELOPMENT_TEAM="$TEAM_ID" \
  --xcodebuild-flag=MARKETING_VERSION="$VERSION" \
  --xcodebuild-flag=CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  --output json

log "Exporting App Store Connect IPA"
asc xcode export \
  --archive-path "$archive_path" \
  --export-options "$EXPORT_OPTIONS" \
  --ipa-path "$ipa_path" \
  --overwrite \
  --xcodebuild-flag=-allowProvisioningUpdates \
  --output json

uploaded_build_id=""

if [[ $SKIP_UPLOAD -eq 1 ]]; then
  echo "warning: skipping App Store Connect upload" >&2
elif [[ -z "$APP_ID" ]]; then
  echo "warning: no ASC app configured; set ASC_APP_ID/POCKETPAD_IOS_ASC_APP_ID or pass --app to upload" >&2
else
  log "Uploading IPA to App Store Connect"
  upload_output="$({ asc builds upload \
    --app "$APP_ID" \
    --ipa "$ipa_path" \
    --version "$VERSION" \
    --build-number "$BUILD_NUMBER" \
    --wait \
    --output json; } 2>&1)" || {
      printf '%s\n' "$upload_output" >&2
      exit 1
    }
  printf '%s\n' "$upload_output"

  uploaded_build_id="$(printf '%s' "$upload_output" | parse_build_id)" || die "could not parse uploaded build ID from asc output"

  if [[ -n "$USES_NON_EXEMPT_ENCRYPTION" ]]; then
    log "Setting export compliance: usesNonExemptEncryption=$USES_NON_EXEMPT_ENCRYPTION"
    asc builds update \
      --build-id "$uploaded_build_id" \
      --uses-non-exempt-encryption="$USES_NON_EXEMPT_ENCRYPTION" \
      --output json
  fi

  if [[ -n "$TEST_NOTES" ]]; then
    log "Setting TestFlight What to Test notes"
    if asc builds test-notes view --build-id "$uploaded_build_id" --locale en-US --output json >/dev/null 2>&1; then
      asc builds test-notes update \
        --build-id "$uploaded_build_id" \
        --locale en-US \
        --whats-new "$TEST_NOTES" \
        --output json
    else
      asc builds test-notes create \
        --build-id "$uploaded_build_id" \
        --locale en-US \
        --whats-new "$TEST_NOTES" \
        --output json
    fi
  fi

  if [[ $UPLOAD_ONLY -eq 0 && -n "$GROUP" ]]; then
    log "Adding build to TestFlight group: $GROUP"
    asc builds add-groups \
      --build-id "$uploaded_build_id" \
      --group "$GROUP" \
      --output json
  fi
fi

if [[ $NOTIFY -eq 1 ]]; then
  echo "warning: --notify is currently handled by App Store Connect group notification settings" >&2
fi

log "Done"
echo "ipa:     $ipa_path"
echo "version: $VERSION ($BUILD_NUMBER)"
if [[ -n "$uploaded_build_id" ]]; then
  echo "build:   $uploaded_build_id"
fi
