# Asset manifest

## Final outputs

| File | Purpose |
| --- | --- |
| `renders/thumble-launch-4k.mp4` | 4K 30 fps master |
| `renders/thumble-launch-1080p.mp4` | Compressed 1080p share copy |
| `renders/thumble-launch-preview.mp4` | Lightweight review render |
| `renders/thumble-launch-poster.png` | Hero poster |
| `renders/thumble-launch-customize-poster.png` | Customization poster |
| `renders/thumble-launch-contact.jpg` | Final QA contact sheet |
| `renders/thumble-launch-4k.ffprobe.json` | Technical verification |
| `renders/thumble-launch-loudness.txt` | Audio loudness verification |
| `renders/SHA256SUMS.txt` | Checksums for the three MP4 deliverables |

## Remotion source

| File | Purpose |
| --- | --- |
| `src/ThumbleLaunch.tsx` | Timeline, copy, scenes, music |
| `src/components.tsx` | Grid, typography, phone frame, chips, media frames |
| `src/Root.tsx` | 3840×2160 / 30 fps / 45-second composition |
| `src/styles.css` | Geist font imports and global styles |
| `remotion.config.ts` | Render quality and concurrency |

## Processed media used by Remotion

| File | Source |
| --- | --- |
| `public/captures/mac-cli-tart.mp4` | Terminal inside the Tart VM, captured through Screen Sharing |
| `public/captures/mac-app-tart.mp4` | Thumble Mac helper inside the Tart VM |
| `public/captures/ios-controller-actions.mp4` | iPhone 17 Pro simulator button presses |
| `public/captures/ios-customization.mp4` | iPhone 17 Pro simulator drag/resize flow |
| `public/captures/ios-controller-clean.png` | Clean generated Hollow Knight controller |
| `public/captures/keypad-editor.png` | Existing real Thumble Mac editor screenshot |
| `public/brand/app-icon.png` | Thumble app icon |
| `public/brand/iphone-frame-landscape.png` | Reusable iPhone 17 Pro landscape frame artwork |
| `public/music/technotronic.ogg` | Attributed launch music |

## Raw/review assets

- `assets/captures/ios/*-raw.mov` — unprocessed portrait-framebuffer recordings
- `assets/captures/ios/*-contact.jpg` — iOS QA contact sheets
- `assets/captures/macos/*-raw.mov` — Screen Sharing window recordings
- `assets/captures/macos/*-full.mp4` — uncropped 16:9 Tart guest captures
- `assets/captures/macos/*-contact.jpg` — macOS QA contact sheets
- `assets/music/technotronic.ogg` — original music copy
- `renders/review/` — selected full-resolution scene frames and preview QA images

## Replacing media

Keep the same processed filenames to swap captures without changing TypeScript. Preferred formats:

- H.264 MP4, 30 fps, no audio for UI clips
- PNG for clean stills and logos
- OGG, WAV, or MP3 for music

The iOS clips are 2622×1206. The CLI clip is 2088×1080. The Mac helper clip is 1594×1080. Remotion scales these into reusable frames, so replacement media may use a different source resolution if its aspect ratio is similar.
