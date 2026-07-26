#!/usr/bin/env bash
set -euo pipefail

MODE=${1:-}
if [[ "$MODE" != "actions" && "$MODE" != "customize" ]]; then
  echo "Usage: $0 actions|customize" >&2
  exit 64
fi

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
VIDEO_DIR="$ROOT/launch-video"
UDID=${UDID:-0335EECF-93B3-4F95-9D5E-DC339BC055DB}
if [[ "$MODE" == "actions" ]]; then
  BASENAME="ios-controller-actions"
else
  BASENAME="ios-customization"
fi
RAW="$VIDEO_DIR/assets/captures/ios/${BASENAME}-raw.mov"
OUT="$VIDEO_DIR/public/captures/${BASENAME}.mp4"

mkdir -p "$(dirname "$RAW")" "$(dirname "$OUT")"
baguette orientation --udid "$UDID" landscape-left
xcrun simctl launch --terminate-running-process "$UDID" com.codybontecou.PocketPad.iOS >/dev/null
sleep 2

rm -f "$RAW" "$OUT"
xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$RAW" >/tmp/pocketpad-ios-record.log 2>&1 &
REC=$!
trap 'kill -INT "$REC" 2>/dev/null || true' EXIT
sleep 1

if [[ "$MODE" == "actions" ]]; then
  (
    echo '{"type":"touch1-down","x":260,"y":223,"width":400,"height":872}'; sleep 0.50
    echo '{"type":"touch1-up","x":260,"y":223,"width":400,"height":872}'; sleep 0.45
    echo '{"type":"touch1-down","x":185,"y":148,"width":400,"height":872}'; sleep 0.55
    echo '{"type":"touch1-up","x":185,"y":148,"width":400,"height":872}'; sleep 0.45
    echo '{"type":"touch1-down","x":260,"y":72,"width":400,"height":872}'; sleep 0.45
    echo '{"type":"touch1-up","x":260,"y":72,"width":400,"height":872}'; sleep 0.35
    echo '{"type":"touch1-down","x":330,"y":148,"width":400,"height":872}'; sleep 0.55
    echo '{"type":"touch1-up","x":330,"y":148,"width":400,"height":872}'; sleep 0.50
    echo '{"type":"touch1-down","x":260,"y":800,"width":400,"height":872}'; sleep 0.55
    echo '{"type":"touch1-up","x":260,"y":800,"width":400,"height":872}'; sleep 0.50
  ) | NO_COLOR=1 TERM=dumb timeout 20 baguette input --udid "$UDID"
else
  # Unlock the in-controller editor.
  NO_COLOR=1 TERM=dumb timeout 20 baguette tap --udid "$UDID" \
    --x 27 --y 299 --width 400 --height 872 </dev/null
  sleep 0.8

  # Move the Soul control.
  (
    echo '{"type":"touch1-down","x":185,"y":149,"width":400,"height":872}'; sleep 0.35
    echo '{"type":"touch1-move","x":193,"y":170,"width":400,"height":872}'; sleep 0.09
    echo '{"type":"touch1-move","x":201,"y":195,"width":400,"height":872}'; sleep 0.09
    echo '{"type":"touch1-move","x":210,"y":222,"width":400,"height":872}'; sleep 0.09
    echo '{"type":"touch1-move","x":218,"y":250,"width":400,"height":872}'; sleep 0.09
    echo '{"type":"touch1-up","x":218,"y":250,"width":400,"height":872}'
  ) | NO_COLOR=1 TERM=dumb timeout 20 baguette input --udid "$UDID"
  sleep 1

  # Enlarge from the selected control's lower-right handle.
  (
    echo '{"type":"touch1-down","x":262,"y":206,"width":400,"height":872}'; sleep 0.25
    echo '{"type":"touch1-move","x":272,"y":195,"width":400,"height":872}'; sleep 0.08
    echo '{"type":"touch1-move","x":284,"y":181,"width":400,"height":872}'; sleep 0.08
    echo '{"type":"touch1-move","x":295,"y":168,"width":400,"height":872}'; sleep 0.08
    echo '{"type":"touch1-up","x":300,"y":162,"width":400,"height":872}'
  ) | NO_COLOR=1 TERM=dumb timeout 20 baguette input --udid "$UDID"
  sleep 1.2
fi

kill -INT "$REC" 2>/dev/null || true
wait "$REC" 2>/dev/null || true
trap - EXIT

ffmpeg -y -hide_banner -loglevel error -i "$RAW" \
  -vf 'transpose=1,fps=30' \
  -c:v libx264 -preset slow -crf 16 -pix_fmt yuv420p -an -movflags +faststart "$OUT"

ffprobe -v error -show_entries stream=width,height,r_frame_rate,duration \
  -of default=noprint_wrappers=1 "$OUT"
