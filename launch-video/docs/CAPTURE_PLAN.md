# Capture plan

## Prerequisites

- Xcode 26+
- `tart`
- `baguette`
- `ffmpeg`
- A booted iPhone 17 Pro simulator
- The local ThumbConsole checkout mounted into the VM

## 1. Build ThumbConsole

```bash
launch-video/scripts/build-apps.sh
```

Outputs are placed in `launch-video/build/` and can be copied into the Tart VM or installed into Simulator.

## 2. Prepare Tart

The draft uses a copy-on-write clone named `pocketpad-capture`:

```bash
tart clone nanoclaw-capture pocketpad-capture
tart set pocketpad-capture --display 1920x1080px --no-display-refit
```

Run it with the repo and optional Hollow Knight install mounted read-only:

```bash
tart run --vnc-experimental \
  --dir="pocketpad:$PWD" \
  --dir="hollow-knight:$HOME/Library/Application Support/Steam/steamapps/common/Hollow Knight:ro" \
  pocketpad-capture
```

`--vnc-experimental` opens the VM through macOS Screen Sharing and allows a clean, deterministic window recording. The built Mac app and CLI were installed at:

- `/Applications/ThumbConsole Mac.app`
- `/usr/local/bin/thumbconsole`

The Steam Hollow Knight app was copied to `/Applications/Hollow Knight.app`. It still requires Steam to be authenticated before gameplay can launch.

## 3. Create and sync the demo profile

Inside the VM:

```bash
thumbconsole generate "Hollow Knight"
thumbconsole pairing payload
```

The recorded session used:

- VM address: `192.168.64.4`
- Port: `8765`
- Simulator: iPhone 17 Pro
- Bundle ID: `com.codybontecou.ThumbConsole.iOS`

Pair once in portrait if text entry is easier, then rotate to landscape:

```bash
baguette orientation --udid "$UDID" landscape-left
```

## 4. Capture iOS

The script assumes the app is already paired and showing the Hollow Knight profile:

```bash
launch-video/scripts/capture-ios-controller.sh actions
launch-video/scripts/capture-ios-controller.sh customize
```

Simulator records a portrait-oriented framebuffer even while the app is landscape. The script rotates the recording clockwise and normalizes it to 30 fps.

Important coordinate transform for this simulator/orientation:

```text
visual landscape point (X, Y)
→ baguette input point (x = Y, y = 872 - X)
with width=400 and height=872
```

## 5. Capture Tart Terminal

```bash
launch-video/scripts/capture-tart-cli.sh
```

The script:

1. Finds the Screen Sharing `Virtualization` window.
2. Prepares `vm-agent-demo.sh` inside the VM.
3. Records the Screen Sharing window for 12 seconds.
4. Runs the real CLI through Terminal.
5. Crops Screen Sharing chrome to the guest display.
6. Produces both a full 16:9 guest capture and a tighter terminal clip.

The Screen Sharing crop used by this VM/window is:

```text
3024×1701 at x=112, y=180 → 1920×1080
```

If Screen Sharing changes size, update the crop values in `capture-tart-cli.sh`.

## 6. Render and QA

```bash
cd launch-video
npm install
npm run preview
npm run render
```

Validate:

```bash
ffprobe renders/thumbconsole-launch-4k.mp4
ffmpeg -i renders/thumbconsole-launch-4k.mp4 -filter_complex ebur128=peak=true -f null -
```

Current master verification:

- 3840×2160
- 30 fps
- 45.0 seconds of video
- H.264 + AAC stereo
- Integrated music loudness: approximately -22.4 LUFS
- True peak: approximately -5.9 dBFS
