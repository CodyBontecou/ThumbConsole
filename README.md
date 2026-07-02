# PocketPad

PocketPad is a local iPhone-as-controller prototype for macOS games. The iPhone sends WebSocket button state transitions to a macOS SwiftUI helper, and the helper injects Hollow Knight keyboard controls with Accessibility-approved `CGEvent` key down/up events.

## Targets

- `PocketPadMac` — macOS 14+ SwiftUI helper, WebSocket server on port `8765`, CGEvent keyboard injection.
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
3. Scan the displayed QR code from the iOS app, or manually enter the displayed `ws://<mac-ip>:8765` address and optional pairing code.
4. Run `PocketPadiOS` on the iPhone and tap **Scan Mac QR Code** to connect without typing the address.
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
- macOS maintains `pressedButtons` and ignores duplicate down/up events.
- iOS sends a heartbeat every 500 ms.
- macOS releases all held keys after 1500 ms without heartbeat, but keeps the socket open so brief focus/game-launch stalls can recover.
- macOS keeps a latency-critical activity while the helper is running to avoid App Nap when the game is focused.
- macOS releases all held keys on client disconnect, server stop, or manual Release All.
- iOS sends best-effort `release_all` when disconnecting, becoming inactive, or backgrounding.
