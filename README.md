# PocketPad

PocketPad is a local iPhone-as-controller prototype for macOS games. The iPhone pairs with a macOS SwiftUI helper over WebSocket, sends realtime button state transitions over an authenticated UDP fast path with WebSocket mirroring as fallback, and the helper injects Hollow Knight keyboard controls with Accessibility-approved `CGEvent` key down/up events.

## Targets

- `PocketPadMac` — macOS 14+ SwiftUI helper, WebSocket pairing/control server plus UDP realtime listener preferring port `8765` with automatic fallback if unavailable, CGEvent keyboard injection.
- `PocketPadiOS` — iOS 17+ landscape SwiftUI controller with multitouch virtual gamepad.

## Build

```bash
xcodegen generate
xcodebuild -project PocketPad.xcodeproj -scheme PocketPadMac -destination 'platform=macOS' build
xcodebuild -project PocketPad.xcodeproj -scheme PocketPadiOS -destination 'generic/platform=iOS Simulator' build
```

## Use

1. Run `PocketPadMac` on the Mac.
2. Grant Accessibility permission when prompted, then restart/refresh if needed.
3. Run `PocketPadiOS` on the iPhone and tap **Scan Mac QR Code** to connect instantly, or manually enter one of the displayed `ws://<mac-ip>:<port>` addresses and tap **Request Pairing**.
4. For manual pairing, enter the six-digit code shown in the Mac helper's secure pairing card.
5. Launch Hollow Knight through Steam and focus the game window.

## Controller key bindings

The Mac helper includes a **Controller Key Bindings** panel. Click **Record** next to any iPhone controller button, press a key on the Mac, and PocketPad will save that mapping automatically. Use **Default** for a single button or **Reset All** to restore the built-in Hollow Knight profile.

Built-in defaults are defined in `Sources/Mac/KeyMap.swift`:

- D-pad: arrow keys
- Jump: `Z`
- Attack: `X`
- Dash: `C`
- Focus/Cast: `A`
- Map: `Tab`
- Pause: `Esc`

## Safety behavior

- Only sends key events on state transitions.
- Button frames use a compact 14-byte binary payload. After pairing, iOS sends those frames over authenticated UDP for lower latency and mirrors them over WebSocket so packet loss still recovers through the reliable path.
- iOS and macOS WebSocket connections set TCP `noDelay` to avoid Nagle delays on small input packets.
- iOS uses a controller-area UIKit touch router with stable expanded non-overlapping hit targets, hands moving touches between adjacent buttons, sends every per-touch edge immediately before SwiftUI visual-state checks, stamps compact button frames with sequence diagnostics and per-press identifiers, and skips per-input send callbacks, live status publishes, and haptics while playing.
- macOS handles received button events on a user-interactive realtime queue, accepts the first authenticated UDP stream for the paired iPhone, silently drops stale mirrored frames, recovers transport-proven missing-up and missing-down edges, and posts key events before UI/debug updates.
- macOS throttles input debug/status publishing so UI work does not compete with key injection.
- During physical tap testing, the Mac debug panel shows missing transport frames, recovered duplicate-down edges, and ignored duplicate/orphan input edges separately.
- iOS sends a heartbeat every 500 ms.
- macOS releases all held keys after 1500 ms without heartbeat, but keeps the socket open so brief focus/game-launch stalls can recover.
- macOS keeps a latency-critical activity while the helper is running to avoid App Nap when the game is focused.
- macOS releases all held keys on client disconnect, server stop, or manual Release All.
- iOS sends best-effort `release_all` when disconnecting, becoming inactive, or backgrounding.
