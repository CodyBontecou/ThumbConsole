# PocketPad

PocketPad turns an iPhone into a programmable shortcut keypad for your Mac. The iPhone pairs with a macOS SwiftUI helper over WebSocket on a local network or Apple peer-to-peer path, sends realtime button state transitions over an authenticated UDP fast path with WebSocket mirroring as fallback, and the helper injects keyboard shortcuts with Accessibility-approved `CGEvent` key down/up events.

It is no longer game-specific: use it for terminal workflows, tmux prefixes, Cursor shortcuts, window management, or any Mac app that responds to keyboard input.

## Targets

- `PocketPadMac` — macOS 14+ SwiftUI helper, WebSocket pairing/control server plus UDP realtime listener preferring port `8765` with automatic fallback if unavailable, Bonjour Smart Connect advertising with peer-to-peer enabled, CGEvent keyboard shortcut injection.
- `PocketPadiOS` — iOS 17+ SwiftUI programmable keypad with multitouch controls and Smart Connect reconnects.
- `PocketPadCLI` — macOS command-line configuration and control tool for generating, editing, importing/exporting, selecting, and testing keypad profiles for the Mac helper.

## Build

```bash
xcodegen generate
xcodebuild -project PocketPad.xcodeproj -scheme PocketPadMac -destination 'platform=macOS' build
xcodebuild -project PocketPad.xcodeproj -scheme PocketPadiOS -destination 'generic/platform=iOS Simulator' build
xcodebuild -project PocketPad.xcodeproj -scheme PocketPadCLI -destination 'platform=macOS' build
```

## Distribution

PocketPad has first-pass release automation for both shipping channels:

```bash
# macOS direct download: Developer ID export, notarize, zip, upload to Cloudflare R2.
scripts/release/macos-cloudflare.sh --version 1.0.0 --build-number 1

# iOS beta: archive/export an IPA, upload it, and distribute to a TestFlight group.
scripts/release/ios-testflight.sh --app "$ASC_APP_ID" --group "Internal Testers"
```

Cloudflare Pages serves `/api/releases/latest-mac` and `/api/download-mac` from the `RELEASES` R2 binding. Create the bucket with `wrangler r2 bucket create pocketpad-releases`, then deploy the `Website` project after the binding exists. The macOS release script expects Wrangler auth plus either `asc` API-key notarization auth or notarization credentials via `NOTARYTOOL_KEYCHAIN_PROFILE` / `APPLE_ID`, `APP_SPECIFIC_PASSWORD`, and `ASC_TEAM_ID`.

The iOS script uses the `asc` CLI. Set `ASC_APP_ID` (or pass `--app`) and optionally `POCKETPAD_TESTFLIGHT_GROUP`; it resolves a remote-safe build number when App Store Connect is reachable.

## Use

1. Run `PocketPadMac` on the Mac.
2. Grant Accessibility permission when prompted, then restart/refresh if needed.
3. Run `PocketPadiOS` on the iPhone and tap **Scan Mac QR Code** to connect instantly, or manually enter one of the displayed `ws://<mac-ip>:<port>` addresses and tap **Request Pairing**. QR pairing can also discover the Mac over nearby peer-to-peer when there is no Wi‑Fi router.
4. For manual pairing, enter the six-digit code shown in the Mac helper's secure pairing card.
5. After the first successful pair, **Smart Connect** remembers this Mac, discovers it over Bonjour, and reconnects automatically when the iOS app opens or returns to foreground.
6. The iOS app also keeps the last synced keypads available for viewing and switching even when PocketPad Mac is not open.
7. Focus the Mac app you want to control, such as Terminal, Cursor, or a browser.

For airplane/offline use, turn on Airplane Mode if desired, then manually re-enable Wi‑Fi and Bluetooth. PocketPad can use Apple peer-to-peer discovery without internet or a router; if both radios are off, wireless control is not possible.

## Programmatic keypad generation

Build the CLI target and generate a game-specific profile from just a game name:

```bash
xcodebuild -project PocketPad.xcodeproj -scheme PocketPadCLI -destination 'platform=macOS' build
~/Library/Developer/Xcode/DerivedData/PocketPad-*/Build/Products/Debug/pocketpad generate "Hollow Knight"
```

`pocketpad generate` installs, selects, and marks the generated profile as default. If `PocketPadMac` is running, it reloads the profile store and pushes the selected keypad to the paired iPhone. Use `--dry-run` to preview without installing, `--json` to inspect the generated profile, and `pocketpad profile list` to view installed profiles.

The first built-in template is Hollow Knight, including aliases like “Hollow Night” from speech recognition. Unknown games intentionally do **not** use a deterministic fallback. Instead, the calling agent should make its own best guess and pass a JSON spec:

```bash
pocketpad generate --spec /tmp/celeste-keypad.json
# or
pocketpad generate --stdin < /tmp/celeste-keypad.json
```

Example agent spec:

```json
{
  "gameName": "Celeste",
  "source": "Agent best guess from default keyboard controls",
  "confidence": "low",
  "controls": [
    { "label": "Left", "key": "LeftArrow", "role": "movement" },
    { "label": "Right", "key": "RightArrow", "role": "movement" },
    { "label": "Up", "key": "UpArrow", "role": "movement" },
    { "label": "Down", "key": "DownArrow", "role": "movement" },
    { "label": "Jump", "key": "C", "role": "primary" },
    { "label": "Dash", "key": "X", "role": "primary" },
    { "label": "Climb", "key": "Z", "role": "secondary" },
    { "label": "Pause", "key": "Escape", "role": "system" }
  ]
}
```

## CLI configuration parity

The CLI can perform the same saved-configuration work as the macOS **Keypad** editor:

```bash
pocketpad profile list --ids
pocketpad template list
pocketpad template install snes --name "SNES Browser Controls" --default
pocketpad profile attach-app "SNES Browser Controls" --path /Applications/OpenEmu.app
pocketpad profile launch "SNES Browser Controls"
pocketpad profile export --all -o pocketpad-profiles.json
pocketpad profile import pocketpad-profiles.json
pocketpad binding set focus --sequence 'Control+B,H'
pocketpad output mode keyboard   # or controller/custom per setup
pocketpad customization set --appearance dark --device iphone-17-pro --background '#101014'
pocketpad customization set --background-gradient '#101014,#4338CA' --gradient-angle 45
pocketpad element add joystick --label "Right Stick" --fill '#111827' --thumb-fill '#F8FAFC' --up custom1 --down custom2 --left custom3 --right custom4
pocketpad element add joystick --label Nub --thumbstick --target right-stick --no-digital-directions --x 0.5 --y 0.58
pocketpad element set jump --label A --light-fill '#7C3AED' --dark-fill '#C4B5FD' --shape circle --width 1.2 --height 1.2 --z-index 10
pocketpad element set "Right Stick" --thumb-fill '#22C55E'
pocketpad style create Soul --fill '#F8FAFC' --stroke '#38BDF8' --pressed-fill '#0EA5E9' --glow '#0EA5E9' --glow-radius 12 --icon sf:sparkles --haptic medium --haptic-pattern double --haptic-intensity 75%
pocketpad style apply soul focus
pocketpad layer front focus
pocketpad group create Actions jump attack dash focus
pocketpad asset import ./orb.png --role icon --name SoulOrb
```

When PocketPad Mac is running, CLI profile/customization/binding changes are pushed to the app via distributed notifications and then synced to the paired iPhone. Runtime commands are also available:

```bash
pocketpad app open
pocketpad status --json
pocketpad server restart
pocketpad pairing payload
pocketpad accessibility status
pocketpad latency simulate --pattern hollow-knight --mode compare --log /tmp/pocketpad-latency.json
pocketpad latency verify --max-ms 4 --p95-ms 4 --log /tmp/pocketpad-latency-verify.json
pocketpad test tap jump
pocketpad release-all
```

`pocketpad latency simulate` is a synthetic replay model for agent debugging, not an end-to-end device benchmark. It runs Hollow-Knight-style bursts, same-button mash bursts, and UDP recovery cases through the wire codec and sequence-buffer assumptions, then writes modeled per-edge timing. `pocketpad latency verify` validates those model assumptions. For production measurements, use `pocketpad monitor`: `input_pipeline` events report same-clock Mac decode, reorder wait, and receive-to-processed timing, while `pocketpad status` reports rolling p50/p95/p99 pipeline latency and round-trip latency.

## Virtual gamepad output

PocketPad can map keypad controls to system-visible virtual gamepad buttons, analog sticks, and triggers while keeping keyboard and pointer output available. Each keypad setup has an output mode: `keyboard` keeps the virtual controller off, `controller` applies the default Xbox-style virtual controller map, and `custom` uses per-button mixed bindings. Configure the mode and mappings in the macOS Keypad editor or with the CLI:

```bash
pocketpad output mode controller
pocketpad output mode keyboard --profile "SNES Browser Controls"
pocketpad output set jump --keyboard Space --gamepad south
pocketpad output set attack --gamepad west
pocketpad element add joystick --target left-stick --no-digital-directions
pocketpad element add trigger --target left --orientation horizontal --sensitivity 1.2
```

On macOS, the virtual controller is created with `IOHIDUserDevice` and requires the Apple-granted `com.apple.developer.hid.virtual.device` signing entitlement. If the Mac app is not signed with that entitlement, keyboard/pointer output continues to work, but macOS Game Controller settings and games will show no controller. `pocketpad status` reports the virtual gamepad availability and the entitlement error when creation is denied.

## Keypad customization

Customize keypad setups from the macOS helper's **Keypad** section or with the CLI. The iOS app receives the Mac's saved setups during pairing, can switch between them from the in-controller **Keypad setup** menu, and can mark the current setup as the default. The macOS helper can also mark any setup as default from the Keypad editor. On iPhone, open the in-controller **Keypad setup** menu and choose **Export Keypads as JSON** to save the synced setups locally with Files.

PocketPad uses its own versioned JSON envelope because there is no broadly adopted interchange format for these multitouch keypad layouts. The current schema is `com.codybontecou.pocketpad.keypad-configuration` version `1`; it stores `profiles`, `activeProfileID`, and `defaultProfileID`. The CLI exports the same envelope and may include macOS-only `profileKeyBindings` so backups preserve shortcut mappings too.

Each setup stores its own keypad-level preferences. Select a setup in the Keypad editor to show the right-side keypad inspector, where you can choose the device canvas, attach a Mac application with the native file browser, set custom device dimensions, change the iPhone background fill, and toggle System/Light/Dark view modes while editing. Attached applications sync with the setup, including the selected app icon; when the iPhone is connected, the top bar shows that app icon as a button that asks the Mac helper to launch or refocus the pre-approved app. Use **Saved Mode** to choose whether that setup follows the device, always uses light mode, or always uses dark mode; per-button light and dark fills and keypad background fills are saved separately with the setup. The same settings are scriptable with `pocketpad customization set --appearance light|dark|system --device iphone-17-pro --background '#101014'`, `pocketpad customization set --background-gradient '#101014,#4338CA'`, `pocketpad element set BUTTON --light-fill '#RRGGBB' --dark-fill '#RRGGBB'`, and `pocketpad profile attach-app PROFILE --path /Applications/App.app`.

Layouts can include up to two virtual joysticks via **Layout tools → Add Joystick**. New joysticks default to **Digital directions**, so the first joystick's up/down/left/right directions use the normal arrow-key shortcut slots in keyboard mode. Each joystick maps its directions to normal PocketPad shortcut slots, so you can also build shooter-style dual-stick layouts while still using the existing keyboard-binding recorder. In the joystick inspector, **Look → Thumbstick** turns the control into a compact center nub: touches must start on the small ball, then can drag through the larger invisible range without stealing taps from neighboring face buttons. The CLI equivalent is `pocketpad element add joystick --thumbstick --target right-stick --no-digital-directions`. Select a joystick and edit **Fill → Thumbstick** to recolor the moving thumb separately from the joystick base; the CLI equivalent is `pocketpad element set "Right Stick" --thumb-fill '#22C55E'` (or light/dark variants such as `--light-thumb-fill`).

The Keypad editor now has a foundational design layer: a z-indexed component list, grid/snap preferences saved in the profile, reusable style tokens, per-control icons/haptics, copy/paste style, basic alignment/distribution, and style-aware preview rendering. Per-control z-index values run from -100 (back) to 100 (front). Per-control haptics include style, pattern/rhythm, intensity, sharpness, and duration; iPhone haptics are still device-wide, so these distinguish controls by feel rather than screen location. The same data is scriptable with `pocketpad style`, `pocketpad layer`, `pocketpad group`, `pocketpad asset`, and richer `pocketpad element set` options such as `--z-index`, `--style`, `--icon`, `--haptic`, `--haptic-pattern`, `--haptic-intensity`, `--stroke`, `--glow`, and `--pressed-fill`.

Layouts can also include a trackpad component via **Layout tools → Add Trackpad** or `pocketpad element add trackpad`. The trackpad sends relative cursor movement to the Mac, supports tap-to-click, two-finger right click, two-finger scroll, natural-scroll inversion, and per-component cursor/scroll sensitivity. Pointer events use the paired realtime channel and the macOS helper injects them with Accessibility-approved `CGEvent` mouse and scroll events.

### iPhone device frames

The Keypad editor can preview layouts inside every iPhone display class PocketPad supports on iOS 17+, from iPhone XS/XR and SE 2/3 through the iPhone 17 family. The editor uses a vector device frame plus the real logical screen size for each model, so keypad placement matches the phone display instead of relying on a single bundled PNG.

When an iPhone connects, it sends its device metrics to the Mac helper. If you have not manually chosen a frame, the editor auto-selects the connected phone's matching canvas. Each setup can now save separate portrait and landscape designs; changing the canvas orientation in the editor edits that orientation's variant, and the iPhone swaps variants automatically as it rotates. You can switch frames manually from the keypad inspector, the canvas device menu, or the CLI:

```bash
pocketpad device list
pocketpad device show
pocketpad device set iphone-17-pro --orientation landscape
pocketpad device set iphone-17-pro --orientation portrait --variant portrait
pocketpad device set custom --size 844x390
pocketpad customization set --light-background '#FFFFFF' --dark-background '#050505'
pocketpad customization set --background-tile dots --tile-foreground '#FFFFFF' --tile-background '#111111'
pocketpad element nudge jump right --step 10 --canvas iphone-17-pro-landscape
```

## Shortcut bindings

The Mac helper shows a shortcut field in the Keypad editor's **Element** inspector. Click the field for the selected button/shape, press one or more Mac keystrokes, then pause; the shortcut saves automatically. PocketPad records held modifiers, so pressing `Control+B` saves `⌃B`; pressing `Control+B`, releasing it, then pressing `H` saves `⌃B H` for Herdr/tmux-style prefix bindings. Modifier-only shortcuts save when you press and release the modifier key.

Starter defaults are defined in `Sources/Mac/KeyMap.swift`:

- Navigation pad: arrow keys
- Action 1: Return
- Action 2: Tab
- Action 3: `⌘K`
- Action 4: `⌃B` (tmux prefix)
- Utility 1: `⇧⌘P`
- Utility 2: Esc

Use **Default** for a single button or **Reset All** to restore the starter keypad profile.

## Safety behavior

- Only sends key events on state transitions.
- Button frames use a compact 14-byte binary payload. After pairing, iOS sends those frames over authenticated UDP for lower latency and mirrors them over WebSocket so packet loss still recovers through the reliable path.
- iOS and macOS WebSocket connections set TCP `noDelay` to avoid Nagle delays on small input packets.
- iOS uses a keypad-area UIKit touch router with stable expanded non-overlapping hit targets, hands moving touches between adjacent buttons and joysticks, sends every per-touch edge immediately before SwiftUI visual-state checks, stamps compact button frames with sequence diagnostics and per-press identifiers, supports optional per-control Core Haptics/impact feedback, and skips per-input send callbacks and live status publishes during use.
- macOS handles received button events on a user-interactive realtime queue, accepts the first authenticated UDP stream for the paired iPhone, silently drops stale mirrored frames, recovers transport-proven missing-up and missing-down edges, and posts key events before UI/debug updates.
- macOS throttles input debug/status publishing so UI work does not compete with key injection.
- During physical tap testing, the Mac debug panel shows missing transport frames, recovered duplicate-down edges, and ignored duplicate/orphan input edges separately.
- iOS sends a heartbeat every 500 ms.
- Smart Connect stores a trusted reconnect token after successful pairing, advertises the Mac as `_pocketpad._tcp` on the local network with peer-to-peer discovery enabled, and avoids reusing stale six-digit pairing codes.
- macOS releases all held keys after 1500 ms without heartbeat, but keeps the socket open so brief focus/app-launch stalls can recover.
- macOS keeps a latency-critical activity while the helper is running to avoid App Nap when the target app is focused.
- macOS releases all held keys on client disconnect, server stop, or manual Release All.
- iOS sends best-effort `release_all` when disconnecting, becoming inactive, or backgrounding.
