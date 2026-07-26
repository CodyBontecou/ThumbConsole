#!/usr/bin/env bash
set -euo pipefail

VIDEO_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$VIDEO_DIR"

npm install
npx tsc --noEmit
npm run preview
npm run render
npm run still
npm run still:customize

ffmpeg -y -hide_banner -loglevel error \
  -i renders/thumble-launch-4k.mp4 \
  -vf 'scale=1920:1080:flags=lanczos' \
  -c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p \
  -c:a aac -b:a 192k -movflags +faststart \
  renders/thumble-launch-1080p.mp4

ffprobe -v error \
  -show_entries stream=index,codec_name,codec_type,width,height,r_frame_rate,sample_rate,channels,duration:format=duration,size,bit_rate \
  -of json renders/thumble-launch-4k.mp4 \
  > renders/thumble-launch-4k.ffprobe.json

ffmpeg -y -hide_banner -loglevel error \
  -i renders/thumble-launch-4k.mp4 \
  -vf 'fps=1/3,scale=768:-1,tile=5x3' -frames:v 1 \
  renders/thumble-launch-contact.jpg

echo "Rendered: $VIDEO_DIR/renders/thumble-launch-4k.mp4"
