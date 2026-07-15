#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
VIDEO_DIR="$ROOT/launch-video"
VM=${VM:-pocketpad-capture}
RAW="$VIDEO_DIR/assets/captures/macos/mac-cli-tart-raw.mov"
FULL="$VIDEO_DIR/assets/captures/macos/mac-cli-tart-full.mp4"
OUT="$VIDEO_DIR/public/captures/mac-cli-tart.mp4"

mkdir -p "$(dirname "$RAW")" "$(dirname "$OUT")"

osascript -e 'tell application "Screen Sharing" to activate' >/dev/null 2>&1 || true
sleep 1
WINDOW_ID=$(swift "$VIDEO_DIR/scripts/find-screen-sharing-window.swift")

echo "Capturing Screen Sharing window $WINDOW_ID"

NO_COLOR=1 TERM=dumb timeout 20 tart exec "$VM" /bin/bash -c \
  'killall Terminal 2>/dev/null || true; cp "/Volumes/My Shared Files/pocketpad/launch-video/scripts/vm-agent-demo.sh" /tmp/pocketpad-agent-demo.sh; chmod +x /tmp/pocketpad-agent-demo.sh' \
  </dev/null >/tmp/pocketpad-cli-prep.log 2>&1

rm -f "$RAW" "$FULL" "$OUT"
screencapture -x -v -l"$WINDOW_ID" -V12 "$RAW" >/tmp/pocketpad-mac-record.log 2>&1 &
REC=$!
trap 'kill -INT "$REC" 2>/dev/null || true' EXIT
sleep 1

NO_COLOR=1 TERM=dumb timeout 30 tart exec "$VM" osascript \
  '/Volumes/My Shared Files/pocketpad/launch-video/scripts/vm-terminal-demo.applescript' \
  '/tmp/pocketpad-agent-demo.sh' \
  </dev/null >/tmp/pocketpad-cli-trigger.log 2>&1 || true

wait "$REC"
trap - EXIT

# Screen Sharing chrome -> exact 16:9 guest display.
ffmpeg -y -hide_banner -loglevel error -i "$RAW" \
  -vf 'crop=3024:1701:112:180,scale=1920:1080,fps=30' \
  -c:v libx264 -preset slow -crf 16 -pix_fmt yuv420p -an -movflags +faststart "$FULL"

# Tighter terminal treatment used by Remotion.
ffmpeg -y -hide_banner -loglevel error -i "$FULL" \
  -vf 'crop=1740:900:60:75,scale=2088:1080' \
  -c:v libx264 -preset slow -crf 16 -pix_fmt yuv420p -an -movflags +faststart "$OUT"

ffprobe -v error -show_entries stream=width,height,r_frame_rate,duration \
  -of default=noprint_wrappers=1 "$OUT"
