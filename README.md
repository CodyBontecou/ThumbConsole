# ThumbConsole

ThumbConsole turns an iPhone into a programmable shortcut keypad for your Mac. The iPhone pairs with a macOS SwiftUI helper over WebSocket on a local network or Apple peer-to-peer path, sends realtime button state transitions over an authenticated UDP fast path with WebSocket mirroring as fallback, and the helper injects keyboard shortcuts with Accessibility-approved `CGEvent` key down/up events.

It is no longer game-specific: use it for terminal workflows, tmux prefixes, Cursor shortcuts, window management, or any Mac app that responds to keyboard input.

## Targets

- `ThumbConsoleMac` — macOS 14+ SwiftUI helper, WebSocket pairing/control server plus UDP realtime listener preferring port `8765` with automatic fallback if unavailable, Bonjour Smart Connect advertising with peer-to-peer enabled, CGEvent keyboard shortcut injection.
- `ThumbConsoleiOS` — iOS 17+ SwiftUI programmable keypad with multitouch controls and Smart Connect reconnects.
- `ThumbConsoleCLI` — macOS command-line configuration and control tool for generating, editing, importing/exporting, selecting, and testing keypad profiles for the Mac helper.

For upgrade compatibility, the existing app bundle identifiers, `_pocketpad._tcp` Bonjour service, pairing payload type, defaults keys, and keypad export schema remain unchanged internally. Existing scripts can keep using the legacy `pocketpad` CLI executable while migrating to `thumbconsole`.

## Build

```bash
xcodegen generate
xcodebuild -project ThumbConsole.xcodeproj -scheme ThumbConsoleMac -destination 'platform=macOS' build
xcodebuild -project ThumbConsole.xcodeproj -scheme ThumbConsoleiOS -destination 'generic/platform=iOS Simulator' build
xcodebuild -project ThumbConsole.xcodeproj -scheme ThumbConsoleCLI -destination 'platform=macOS' build
```

## Distribution

ThumbConsole has first-pass release automation for both shipping channels:

```bash
# macOS direct download: Developer ID export, notarize, zip, upload to Cloudflare R2.
scripts/release/macos-cloudflare.sh --version 1.0.0 --build-number 1

# iOS beta: archive/export an IPA, upload it, and distribute to a TestFlight group.
scripts/release/ios-testflight.sh --app "$ASC_APP_ID" --group "Internal Testers"
```

Cloudflare Pages serves `/api/releases/latest-mac` and `/api/download-mac` from the `RELEASES` R2 binding. Create the bucket with `wrangler r2 bucket create pocketpad-releases`, then deploy the `Website` project after the binding exists. The macOS release script expects Wrangler auth plus either `asc` API-key notarization auth or notarization credentials via `NOTARYTOOL_KEYCHAIN_PROFILE` / `APPLE_ID`, `APP_SPECIFIC_PASSWORD`, and `ASC_TEAM_ID`.

The iOS script uses the `asc` CLI. Set `ASC_APP_ID` (or pass `--app`) and optionally `THUMBCONSOLE_TESTFLIGHT_GROUP`; it resolves a remote-safe build number when App Store Connect is reachable.

## Use

1. Run `ThumbConsoleMac` on the Mac.
2. Grant Accessibility permission when prompted, then restart/refresh if needed.
3. Run `ThumbConsoleiOS` on the iPhone and tap **Scan Mac QR Code** to connect instantly, or manually enter one of the displayed `ws://<mac-ip>:<port>` addresses and tap **Request Pairing**. QR pairing can also discover the Mac over nearby peer-to-peer when there is no Wi‑Fi router.
4. For manual pairing, enter the six-digit code shown in the Mac helper's secure pairing card.
5. After the first successful pair, **Smart Connect** remembers this Mac, discovers it over Bonjour, and reconnects automatically when the iOS app opens or returns to foreground.
6. The iOS app also keeps the last synced keypads available for viewing and switching even when ThumbConsole Mac is not open.
7. Focus the Mac app you want to control, such as Terminal, Cursor, or a browser.

For airplane/offline use, turn on Airplane Mode if desired, then manually re-enable Wi‑Fi and Bluetooth. ThumbConsole can use Apple peer-to-peer discovery without internet or a router; if both radios are off, wireless control is not possible.

## Programmatic keypad generation

Build the CLI target and generate a game-specific profile from just a game name:

```bash
xcodebuild -project ThumbConsole.xcodeproj -scheme ThumbConsoleCLI -destination 'platform=macOS' build
~/Library/Developer/Xcode/DerivedData/ThumbConsole-*/Build/Products/Debug/thumbconsole generate "Hollow Knight"
```

`thumbconsole generate` installs, selects, and marks the generated profile as default. If `ThumbConsoleMac` is running, it reloads the profile store and pushes the selected keypad to the paired iPhone. Use `--dry-run` to preview without installing, `--json` to inspect the generated profile, and `thumbconsole profile list` to view installed profiles. The CLI build also produces a legacy `pocketpad` executable so existing scripts continue to work during the rename.

The first built-in template is Hollow Knight, including aliases like “Hollow Night” from speech recognition. Unknown games intentionally do **not** use a deterministic fallback. Instead, the calling agent should make its own best guess and pass a JSON spec:

```bash
thumbconsole generate --spec /tmp/celeste-keypad.json
# or
thumbconsole generate --stdin < /tmp/celeste-keypad.json
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
thumbconsole profile list --ids
thumbconsole template list
thumbconsole template install snes --name "SNES Browser Controls" --default
thumbconsole profile attach-app "SNES Browser Controls" --path /Applications/OpenEmu.app
thumbconsole profile launch "SNES Browser Controls"
thumbconsole profile export --all -o thumbconsole-profiles.json
thumbconsole profile import thumbconsole-profiles.json
thumbconsole binding set focus --sequence 'Control+B,H'
thumbconsole output mode keyboard   # or controller/custom per setup
thumbconsole customization set --appearance dark --device iphone-17-pro --background '#101014'
thumbconsole customization set --background-gradient '#101014,#4338CA' --gradient-angle 45
thumbconsole orientation get --profile "SNES Browser Controls"
thumbconsole orientation set landscape --profile "SNES Browser Controls"
thumbconsole element add joystick --label "Right Stick" --fill '#111827' --thumb-fill '#F8FAFC' --up custom1 --down custom2 --left custom3 --right custom4
thumbconsole element add joystick --label Nub --thumbstick --target right-stick --no-digital-directions --x 0.5 --y 0.58
thumbconsole element set jump --label A --light-fill '#7C3AED' --dark-fill '#C4B5FD' --shape circle --width 1.2 --height 1.2 --z-index 10
thumbconsole element set "Right Stick" --thumb-fill '#22C55E'
thumbconsole style create Soul --fill '#F8FAFC' --stroke '#38BDF8' --pressed-fill '#0EA5E9' --glow '#0EA5E9' --glow-radius 12 --icon sf:sparkles --haptic medium --haptic-pattern double --haptic-intensity 75%
thumbconsole style apply soul focus
thumbconsole layer front focus
thumbconsole group create Actions jump attack dash focus
thumbconsole asset import ./orb.png --role icon --name SoulOrb
```

When ThumbConsole Mac is running, CLI profile/customization/binding changes are pushed to the app via distributed notifications and then synced to the paired iPhone. Runtime commands are also available:

```bash
thumbconsole app open
thumbconsole status --json
thumbconsole server restart
thumbconsole pairing payload
thumbconsole accessibility status
thumbconsole latency simulate --pattern hollow-knight --mode compare --log /tmp/thumbconsole-latency.json
thumbconsole latency verify --max-ms 4 --p95-ms 4 --log /tmp/thumbconsole-latency-verify.json
thumbconsole test tap jump
thumbconsole release-all
```

`thumbconsole latency simulate` is a synthetic replay model for agent debugging, not an end-to-end device benchmark. It runs Hollow-Knight-style bursts, same-button mash bursts, and UDP recovery cases through the wire codec and sequence-buffer assumptions, then writes modeled per-edge timing. `thumbconsole latency verify` validates those model assumptions. For production measurements, use `thumbconsole monitor`: `input_pipeline` events report same-clock Mac decode, reorder wait, input processing, binding lookup, output injection, post-injection, deferred-output, and receive-to-processed timing. `thumbconsole status` reports rolling pipeline and output-stage percentiles plus round-trip latency.

See [Input Latency and Reliability Optimization](docs/development-logs/2026-07-10-input-latency-and-reliability-optimization.md) for the protocol, queueing, recovery, and physical-device test work behind these measurements.

## Virtual gamepad output

ThumbConsole can map keypad controls to system-visible virtual gamepad buttons, analog sticks, and triggers while keeping keyboard and pointer output available. Each keypad setup has an output mode: `keyboard` keeps the virtual controller off, `controller` applies the default Xbox-style virtual controller map, and `custom` uses per-button mixed bindings. Configure the mode and mappings in the macOS Keypad editor or with the CLI:

```bash
thumbconsole output mode controller
thumbconsole output mode keyboard --profile "SNES Browser Controls"
thumbconsole output set jump --keyboard Space --gamepad south
thumbconsole output set attack --gamepad west
thumbconsole element add joystick --target left-stick --no-digital-directions
thumbconsole element add trigger --target left --orientation horizontal --sensitivity 1.2
```

On macOS, the virtual controller is created with `IOHIDUserDevice` and requires the Apple-granted `com.apple.developer.hid.virtual.device` signing entitlement. If the Mac app is not signed with that entitlement, keyboard/pointer output continues to work, but macOS Game Controller settings and games will show no controller. `thumbconsole status` reports the virtual gamepad availability and the entitlement error when creation is denied.

## Keypad customization

Customize keypad setups from the macOS helper's **Keypad** section or with the CLI. The iOS app receives the Mac's saved setups during pairing, can switch between them from the in-controller **Keypad setup** menu, and can mark the current setup as the default. The macOS helper can also mark any setup as default from the Keypad editor. To create a JSON backup on Mac, use the **Export** menu above the setup list and choose **Export Current Setup…** or **Export All Setups…**. Restore a full backup, individual profile, generated profile, or raw customization from the adjacent **Import** menu; imports can replace matching setups or create new copies. On iPhone, open the in-controller **Keypad setup** menu and choose **Export Keypads as JSON** to save the synced setups locally with Files.

ThumbConsole uses its own versioned JSON envelope because there is no broadly adopted interchange format for these multitouch keypad layouts. The current schema is `com.codybontecou.pocketpad.keypad-configuration` version `3`; it stores `profiles`, `activeProfileID`, and `defaultProfileID`. Mac app and CLI exports use the same envelope and may include macOS-only `profileKeyBindings` and `profileOutputBindings` so backups preserve shortcut and controller mappings too.

Each setup stores its own keypad-level preferences. Select a setup in the Keypad editor to show the right-side keypad inspector, where you can choose the device canvas, set **iPhone Rotation** to Follow Device, Lock Portrait, or Lock Landscape, attach a Mac application with the native file browser, set custom device dimensions, change the iPhone background fill, and toggle System/Light/Dark view modes while editing. Attached applications sync with the setup, including the selected app icon; when the iPhone is connected, the top bar shows that app icon as a button that asks the Mac helper to launch or refocus the pre-approved app. Use **Saved Mode** to choose whether that setup follows the device, always uses light mode, or always uses dark mode; per-button light and dark fills and keypad background fills are saved separately with the setup. The same settings are scriptable with `thumbconsole orientation get|set`, `thumbconsole customization set --appearance light|dark|system --device iphone-17-pro --background '#101014'`, `thumbconsole customization set --background-gradient '#101014,#4338CA'`, `thumbconsole element set BUTTON --light-fill '#RRGGBB' --dark-fill '#RRGGBB'`, and `thumbconsole profile attach-app PROFILE --path /Applications/App.app`.

Layouts can include up to two virtual joysticks via **Add Control → Add Joystick**. New joysticks default to **Digital directions**, so the first joystick's up/down/left/right directions use the normal arrow-key shortcut slots in keyboard mode. Each joystick maps its directions to normal ThumbConsole shortcut slots, so you can also build shooter-style dual-stick layouts while still using the existing keyboard-binding recorder. In the joystick inspector, **Look → Thumbstick** turns the control into a compact center nub: touches must start on the small ball, then can drag through the larger invisible range without stealing taps from neighboring face buttons. The CLI equivalent is `thumbconsole element add joystick --thumbstick --target right-stick --no-digital-directions`. Select a joystick and edit **Fill → Thumbstick** to recolor the moving thumb separately from the joystick base; the CLI equivalent is `thumbconsole element set "Right Stick" --thumb-fill '#22C55E'` (or light/dark variants such as `--light-thumb-fill`).

The Keypad editor has a persistent command bar for Edit/Test mode, named control creation, undo/redo, orientation workflows, layout health, live save/delivery status, and explicit zoom controls; setup switching moves into the command bar whenever the Setups list is hidden. The left sidebar provides searchable **Setups** and **Layers** views with rename, duplicate, lock, visibility, grouping, and stack actions, and automatically follows the active setup. Use **Focus Canvas** (`⌥⌘0`) to temporarily hide both sidebars. The task-first inspector opens **Action & Label** and **Position & Size** first; switch to **Advanced** for reusable styles, haptics, corners, and effects. Pressing a control in Test mode sends its real configured output, while presses received from the paired iPhone are mirrored on the Mac canvas.

The layout-health menu surfaces the same overlap, touch-target, edge, displacement, and canvas-usage checks available through `thumbconsole layout validate`. Selecting an issue zooms to the affected controls and opens an on-canvas repair banner for minimum touch targets, safe-area placement, overlap separation, or automatic arrangement; the same repairs are available through `thumbconsole layout fix`. Portrait and landscape variants can be copied, automatically arranged, or compared side by side. Keyboard editing includes marquee selection, `⌘A`, `⌘D`, grouping, nudging, explicit Fit and Zoom to Selection controls, zoom shortcuts, and a `⌘/` reference sheet. Equivalent saved-layout operations are available from the CLI, including `thumbconsole element duplicate`, `thumbconsole element align`, `thumbconsole element distribute`, `thumbconsole group rename`, `thumbconsole group duplicate`, and `thumbconsole orientation copy|arrange`.

The design layer also supports grid/snap preferences, reusable style tokens, per-control icons/haptics, copy/paste style, alignment/distribution, and style-aware preview rendering. Open **Keypad Resources** from the advanced appearance inspector to create, rename, update, import, export, and delete named styles or manage embedded assets. Per-control z-index values run from -100 to 100. Per-control haptics include style, pattern/rhythm, intensity, sharpness, and duration; iPhone haptics are device-wide, so these distinguish controls by feel rather than screen location. The same data is scriptable with `thumbconsole style`, `thumbconsole layer`, `thumbconsole group`, `thumbconsole asset`, and richer `thumbconsole element set` options such as `--z-index`, `--style`, `--icon`, `--haptic`, `--haptic-pattern`, `--haptic-intensity`, `--stroke`, `--glow`, and `--pressed-fill`.

On iPhone, the scrollable **Keypad settings** sheet includes a device-wide haptic intensity and test, optional secondary binding glyphs, immersive mode, the profile rotation preference, and thumb-placement calibration, including at accessibility Dynamic Type sizes. Calibration records left/right reach traces for the current profile, display, and orientation, scores reach and touch-target quality, and offers explicit, undoable layout suggestions. **Practice Mode** keeps controls, pressed visuals, and haptics active while centrally suppressing every keyboard, controller, trigger, and pointer output path. Saved keypads remain clearly offline until Practice Mode or reconnection is chosen. Home opens connection details and iPhone settings without dropping a live Mac session; the connection page then offers explicit Return to Keypad and Disconnect actions. On-device layout edits support Undo/Cancel and accessible move, resize, rotate, and delete actions; offline final edits are retained against the trusted Mac identity and uploaded after reconnect instead of being overwritten by the first server snapshot.

Layouts can also include a trackpad component via **Add Control → Add Trackpad** or `thumbconsole element add trackpad`. The trackpad sends relative cursor movement to the Mac, supports tap-to-click, two-finger right click, two-finger scroll, natural-scroll inversion, and per-component cursor/scroll sensitivity. Pointer events use the paired realtime channel and the macOS helper injects them with Accessibility-approved `CGEvent` mouse and scroll events.

### iPhone device frames

The Keypad editor can preview layouts inside every iPhone display class ThumbConsole supports on iOS 17+, from iPhone XS/XR and SE 2/3 through the iPhone 17 family. The editor uses a vector device frame plus the real logical screen size for each model, so keypad placement matches the phone display instead of relying on a single bundled PNG.

When an iPhone connects, it sends its device metrics to the Mac helper. If you have not manually chosen a frame, the editor auto-selects the connected phone's matching canvas. Each setup can now save separate portrait and landscape designs; changing the canvas orientation in the editor edits that orientation's variant, and the iPhone swaps variants automatically as it rotates. You can switch frames manually from the keypad inspector, the canvas device menu, or the CLI:

```bash
thumbconsole device list
thumbconsole device show
thumbconsole device set iphone-17-pro --orientation landscape
thumbconsole device set iphone-17-pro --orientation portrait --variant portrait
thumbconsole device set custom --size 844x390
thumbconsole customization set --light-background '#FFFFFF' --dark-background '#050505'
thumbconsole customization set --background-tile dots --tile-foreground '#FFFFFF' --tile-background '#111111'
thumbconsole element nudge jump right --step 10 --canvas iphone-17-pro-landscape
```

## Shortcut bindings

The Mac helper shows a shortcut field in the Keypad editor's **Action & Label** inspector. Click the field for the selected button/shape, press one or more Mac keystrokes, then pause; the shortcut saves automatically. ThumbConsole records held modifiers, so pressing `Control+B` saves `⌃B`; pressing `Control+B`, releasing it, then pressing `H` saves `⌃B H` for Herdr/tmux-style prefix bindings. Modifier-only shortcuts save when you press and release the modifier key. Friendly control labels remain independent from these bindings: Mac publishes compact and VoiceOver-friendly presentation metadata per profile/orientation, while iPhone can render the compact binding as a smaller optional subtitle. Inspect the same resolved metadata with `thumbconsole binding display [--profile PROFILE] [--json]`, or remove only a friendly override with `thumbconsole element set CONTROL --clear-label`.

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
- Protocol v2 button frames use a fixed 32-byte binary payload with an input generation, full sequence number, and physical press identifier; legacy 14-byte v1 frames remain decodable. After pairing, iOS sends input over authenticated UDP and mirrors it over WebSocket for packet-loss recovery.
- The Mac advertises the `gamepad_profile_orientation_preference_mutation` capability before iOS enables rotation changes. A capable iPhone sends the dedicated profile-scoped mutation message only after that advertisement, and the Mac broadcasts the complete authoritative profile state afterward. Older peers ignore the optional capability/profile field; a new iPhone connected to an old Mac leaves the setting disabled and does not send the new message type.
- iOS and macOS WebSocket connections set TCP `noDelay` to avoid Nagle delays on small input packets.
- iOS uses a keypad-area UIKit touch router with stable expanded non-overlapping hit targets, hands moving touches between adjacent buttons and joysticks, sends every per-touch edge immediately before SwiftUI visual-state checks, stamps compact button frames with sequence diagnostics and per-press identifiers, supports optional per-control Core Haptics/impact feedback, and skips per-input send callbacks and live status publishes during use.
- macOS handles received input on a user-interactive realtime queue, accepts the first authenticated UDP stream for the paired iPhone, drops stale mirrored frames, recovers transport-proven missing edges, and safely applies a late up only when its physical press identifier still matches the active hold.
- macOS throttles input debug/status publishing so UI work does not compete with key injection.
- During physical tap testing, the Mac debug panel shows missing transport frames, recovered duplicate-down edges, and ignored duplicate/orphan input edges separately.
- iOS schedules heartbeat and active-press refreshes every 250 ms on its network queue; the Mac validates each refreshed physical press independently.
- Smart Connect stores a trusted reconnect token after successful pairing, advertises the Mac as `_pocketpad._tcp` on the local network with peer-to-peer discovery enabled, and avoids reusing stale six-digit pairing codes.
- The Mac keeps one authoritative iPhone session: a reconnect from the same trusted installation may replace its stale socket, while a different iPhone is rejected without evicting the active keypad or starting a reconnect loop.
- macOS releases all held keys after 1500 ms without any client activity, keeps the socket open so brief stalls can recover, and expires an individually unrefreshed physical hold after 1750 ms.
- macOS keeps a latency-critical activity while the helper is running to avoid App Nap when the target app is focused.
- macOS releases all held keys on client disconnect, server stop, or manual Release All.
- iOS sends best-effort `release_all` when disconnecting, becoming inactive, or backgrounding.
