#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
VIDEO_DIR="$ROOT/launch-video"
UDID=${UDID:-0335EECF-93B3-4F95-9D5E-DC339BC055DB}

cd "$ROOT"

xcodebuild -project ThumbConsole.xcodeproj -scheme ThumbConsoleMac \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$VIDEO_DIR/build/MacDerivedData" \
  CODE_SIGNING_ALLOWED=NO build

xcodebuild -project ThumbConsole.xcodeproj -scheme ThumbConsoleCLI \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$VIDEO_DIR/build/CLIDerivedData" \
  CODE_SIGNING_ALLOWED=NO build

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b

xcodebuild -project ThumbConsole.xcodeproj -scheme ThumbConsoleiOS \
  -configuration Debug -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$VIDEO_DIR/build/iOSDerivedData" \
  CODE_SIGNING_ALLOWED=NO build

xcrun simctl install "$UDID" \
  "$VIDEO_DIR/build/iOSDerivedData/Build/Products/Debug-iphonesimulator/ThumbConsole.app"

printf '\nBuilt Mac app, CLI, and iOS Simulator app.\n'
