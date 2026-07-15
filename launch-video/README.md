# ThumbConsole launch video

A 45-second, text-led launch film built with Remotion, real iOS Simulator footage, and macOS footage captured from the `pocketpad-capture` Tart VM.

## Deliverables

- **4K master:** `renders/thumbconsole-launch-4k.mp4`
- **1080p share copy:** `renders/thumbconsole-launch-1080p.mp4`
- **Quick preview:** `renders/thumbconsole-launch-preview.mp4`
- **Hero poster:** `renders/thumbconsole-launch-poster.png`
- **Customization poster:** `renders/thumbconsole-launch-customize-poster.png`
- **Final contact sheet:** `renders/thumbconsole-launch-contact.jpg`
- **Editable composition:** `src/ThumbConsoleLaunch.tsx`
- **Reusable components:** `src/components.tsx`
- **Processed source clips:** `public/captures/`
- **Raw source recordings/contact sheets:** `assets/captures/`

The 4K master is also copied to `~/Downloads/ThumbConsole-Launch-4K.mp4`.

## Output specification

- 3840×2160
- 16:9
- 30 fps
- 45 seconds
- H.264 video / AAC stereo audio
- Geist Sans + Geist Mono

## Run it

```bash
cd launch-video
npm install
npm run studio   # interactive Remotion editor
npm run preview  # 960×540 review render
npm run render   # 3840×2160 master
npm run still    # poster frame
```

## Story

| Time | Section | Copy |
| --- | --- | --- |
| 0:00–0:05 | Hook | Turn your iPhone into a custom gaming controller. |
| 0:05–0:13 | Generate | Ask once. Start with a complete layout. |
| 0:13–0:20 | Build | Every control starts with intent. |
| 0:19–0:28 | Play | Built for multitouch. Tuned for the game. |
| 0:27–0:36 | Customize | Move it. Resize it. Make it yours. |
| 0:35–0:41 | Sync | Designed on Mac. Synced to iPhone. |
| 0:40–0:45 | Close | ThumbConsole / Build yours / Coming soon |

Scene starts overlap intentionally for short Vercel-style crossfades. Edit copy, durations, and sequence starts near the bottom of `src/ThumbConsoleLaunch.tsx`.

## Capture sources

### iOS Simulator

- Device: iPhone 17 Pro, iOS 26.3
- Orientation: landscape-left
- Bundle ID: `com.codybontecou.ThumbConsole.iOS`
- Processed clips:
  - `public/captures/ios-controller-actions.mp4`
  - `public/captures/ios-customization.mp4`
- Clean still: `public/captures/ios-controller-clean.png`

The phone was paired with the Mac helper at `ws://192.168.64.4:8765`. The Hollow Knight profile came from the real command:

```bash
thumbconsole generate "Hollow Knight"
```

### Tart macOS VM

- VM: `pocketpad-capture`
- Display: 1920×1080
- Guest account: `admin`
- Connection: Tart experimental VNC opened in macOS Screen Sharing
- Processed clips:
  - `public/captures/mac-cli-tart.mp4`
  - `public/captures/mac-app-tart.mp4`

The terminal sequence executes the real ThumbConsole CLI and then presents a concise, staged summary so it remains readable on video.

## Hollow Knight note

The locally owned Steam install was copied into the disposable Tart VM at `/Applications/Hollow Knight.app`. The game itself requires the Steam client to be running and authenticated, so this draft uses ThumbConsole’s built-in Hollow Knight profile rather than game footage. No game bundle or copyrighted game art is included in this directory. To add gameplay later, sign into Steam inside the VM, record a gameplay clip, and place it under `public/captures/`.

## Music

“Technotronic” by Eric Matyas, downloaded from OpenGameArt. Free to use with attribution. See `docs/MUSIC_LICENSE.md`.

## Useful files

- `docs/STORYBOARD.md` — copy and timing
- `docs/CAPTURE_PLAN.md` — full simulator/Tart workflow
- `docs/ASSET_MANIFEST.md` — asset inventory and replacement points
- `scripts/vm-agent-demo.sh` — terminal performance
- `scripts/vm-terminal-demo.applescript` — Terminal window setup
- `scripts/capture-ios-controller.sh` — repeatable iOS action/customization capture
- `scripts/capture-tart-cli.sh` — repeatable Tart/Screen Sharing capture
- `scripts/build-apps.sh` — rebuild all three ThumbConsole targets
