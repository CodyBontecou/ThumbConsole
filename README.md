# PocketPad

PocketPad turns an iPhone into a programmable shortcut keypad for your Mac. The iPhone pairs with a macOS SwiftUI helper over WebSocket, sends realtime button state transitions over an authenticated UDP fast path with WebSocket mirroring as fallback, and the helper injects keyboard shortcuts with Accessibility-approved `CGEvent` key down/up events.

It is no longer game-specific: use it for terminal workflows, tmux prefixes, Cursor shortcuts, window management, or any Mac app that responds to keyboard input.

## Targets

- `PocketPadMac` — macOS 14+ SwiftUI helper, WebSocket pairing/control server plus UDP realtime listener preferring port `8765` with automatic fallback if unavailable, Bonjour Smart Connect advertising, CGEvent keyboard shortcut injection.
- `PocketPadiOS` — iOS 17+ SwiftUI programmable keypad with multitouch controls and Smart Connect reconnects.
- `PocketPadCLI` — macOS command-line configuration and control tool for generating, editing, importing/exporting, selecting, and testing keypad profiles for the Mac helper.

## Build

```bash
xcodegen generate
xcodebuild -project PocketPad.xcodeproj -scheme PocketPadMac -destination 'platform=macOS' build
xcodebuild -project PocketPad.xcodeproj -scheme PocketPadiOS -destination 'generic/platform=iOS Simulator' build
xcodebuild -project PocketPad.xcodeproj -scheme PocketPadCLI -destination 'platform=macOS' build
```

## Use

1. Run `PocketPadMac` on the Mac.
2. Grant Accessibility permission when prompted, then restart/refresh if needed.
3. Run `PocketPadiOS` on the iPhone and tap **Scan Mac QR Code** to connect instantly, or manually enter one of the displayed `ws://<mac-ip>:<port>` addresses and tap **Request Pairing**.
4. For manual pairing, enter the six-digit code shown in the Mac helper's secure pairing card.
5. After the first successful pair, **Smart Connect** remembers this Mac, discovers it over Bonjour, and reconnects automatically when the iOS app opens or returns to foreground.
6. The iOS app also keeps the last synced keypads available for viewing and switching even when PocketPad Mac is not open.
7. Focus the Mac app you want to control, such as Terminal, Cursor, or a browser.

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
pocketpad profile export --all -o pocketpad-profiles.json
pocketpad profile import pocketpad-profiles.json
pocketpad binding set focus --sequence 'Control+B,H'
pocketpad output mode keyboard   # or controller/custom per setup
pocketpad customization set --appearance dark --device iphone-17-pro --background '#101014'
pocketpad customization set --background-gradient '#101014,#4338CA' --gradient-angle 45
pocketpad element add joystick --label "Right Stick" --fill '#111827' --thumb-fill '#F8FAFC' --up custom1 --down custom2 --left custom3 --right custom4
pocketpad element set jump --label A --light-fill '#7C3AED' --dark-fill '#C4B5FD' --shape circle --width 1.2 --height 1.2
pocketpad element set "Right Stick" --thumb-fill '#22C55E'
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

`pocketpad latency simulate` is a headless replay harness for agent debugging. It runs Hollow-Knight-style bursts, same-button mash bursts, UDP recovery, or UDP recovery-burst cases through the compact button wire format and Mac sequence buffering model, then prints touch-to-injection latency and can write a per-edge JSON report. `pocketpad latency verify` runs every current-path pattern and exits nonzero if the configured max or p95 latency budget is exceeded.

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

Each setup stores its own keypad-level preferences. Select a setup in the Keypad editor to show the right-side keypad inspector, where you can choose the device canvas, set custom device dimensions, change the iPhone background fill, and toggle System/Light/Dark view modes while editing. Use **Saved Mode** to choose whether that setup follows the device, always uses light mode, or always uses dark mode; per-button light and dark fills and keypad background fills are saved separately with the setup. The same settings are scriptable with `pocketpad customization set --appearance light|dark|system --device iphone-17-pro --background '#101014'`, `pocketpad customization set --background-gradient '#101014,#4338CA'`, and `pocketpad element set BUTTON --light-fill '#RRGGBB' --dark-fill '#RRGGBB'`.

Layouts can include up to two virtual joysticks via **Layout tools → Add Joystick**. Each joystick maps its up/down/left/right directions to normal PocketPad shortcut slots, so you can build shooter-style dual-stick layouts while still using the existing keyboard-binding recorder. Select a joystick and edit **Fill → Thumbstick** to recolor the moving thumb separately from the joystick base; the CLI equivalent is `pocketpad element set "Right Stick" --thumb-fill '#22C55E'` (or light/dark variants such as `--light-thumb-fill`).

Layouts can also include a trackpad component via **Layout tools → Add Trackpad** or `pocketpad element add trackpad`. The trackpad sends relative cursor movement to the Mac, supports tap-to-click, two-finger right click, two-finger scroll, natural-scroll inversion, and per-component cursor/scroll sensitivity. Pointer events use the paired realtime channel and the macOS helper injects them with Accessibility-approved `CGEvent` mouse and scroll events.

### iPhone device frames

The Keypad editor can preview layouts inside every iPhone display class PocketPad supports on iOS 17+, from iPhone XS/XR and SE 2/3 through the iPhone 17 family. The editor uses a vector device frame plus the real logical screen size for each model, so keypad placement matches the phone display instead of relying on a single bundled PNG.

When an iPhone connects, it sends its device metrics to the Mac helper. If you have not manually chosen a frame, the editor auto-selects the connected phone's matching canvas. You can switch frames manually from the keypad inspector, the canvas device menu, or the CLI:

```bash
pocketpad device list
pocketpad device show
pocketpad device set iphone-17-pro --orientation landscape
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
- iOS uses a keypad-area UIKit touch router with stable expanded non-overlapping hit targets, hands moving touches between adjacent buttons and joysticks, sends every per-touch edge immediately before SwiftUI visual-state checks, stamps compact button frames with sequence diagnostics and per-press identifiers, supports optional lightweight press haptics, and skips per-input send callbacks and live status publishes during use.
- macOS handles received button events on a user-interactive realtime queue, accepts the first authenticated UDP stream for the paired iPhone, silently drops stale mirrored frames, recovers transport-proven missing-up and missing-down edges, and posts key events before UI/debug updates.
- macOS throttles input debug/status publishing so UI work does not compete with key injection.
- During physical tap testing, the Mac debug panel shows missing transport frames, recovered duplicate-down edges, and ignored duplicate/orphan input edges separately.
- iOS sends a heartbeat every 500 ms.
- Smart Connect stores a trusted reconnect token after successful pairing, advertises the Mac as `_pocketpad._tcp` on the local network, and avoids reusing stale six-digit pairing codes.
- macOS releases all held keys after 1500 ms without heartbeat, but keeps the socket open so brief focus/app-launch stalls can recover.
- macOS keeps a latency-critical activity while the helper is running to avoid App Nap when the target app is focused.
- macOS releases all held keys on client disconnect, server stop, or manual Release All.
- iOS sends best-effort `release_all` when disconnecting, becoming inactive, or backgrounding.
