# PocketPad

PocketPad turns an iPhone into a programmable shortcut keypad for your Mac. The iPhone pairs with a macOS SwiftUI helper over WebSocket, sends realtime button state transitions over an authenticated UDP fast path with WebSocket mirroring as fallback, and the helper injects keyboard shortcuts with Accessibility-approved `CGEvent` key down/up events.

It is no longer game-specific: use it for terminal workflows, tmux prefixes, Cursor shortcuts, window management, or any Mac app that responds to keyboard input.

## Targets

- `PocketPadMac` — macOS 14+ SwiftUI helper, WebSocket pairing/control server plus UDP realtime listener preferring port `8765` with automatic fallback if unavailable, CGEvent keyboard shortcut injection.
- `PocketPadiOS` — iOS 17+ SwiftUI programmable keypad with multitouch controls.

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
5. Focus the Mac app you want to control, such as Terminal, Cursor, or a browser.

## Keypad customization

Customize keypad setups from the macOS helper's **Keypad** section. The iOS app receives the Mac's saved setups during pairing, can switch between them from the in-controller **Keypad setup** menu, and can mark the current setup as the default. The macOS helper can also mark any setup as default from the Keypad editor.

## Shortcut bindings

The Mac helper includes a **Keypad Shortcuts** panel. Click **Record Shortcut** next to any iPhone button, then press a Mac key or shortcut. PocketPad records held modifiers, so pressing `Control+B` saves `⌃B`. The recording sheet also has quick modifier-only buttons for Control, Option, Shift, Command, plus a tmux prefix preset.

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
- iOS uses a keypad-area UIKit touch router with stable expanded non-overlapping hit targets, hands moving touches between adjacent buttons, sends every per-touch edge immediately before SwiftUI visual-state checks, stamps compact button frames with sequence diagnostics and per-press identifiers, and skips per-input send callbacks, live status publishes, and haptics during use.
- macOS handles received button events on a user-interactive realtime queue, accepts the first authenticated UDP stream for the paired iPhone, silently drops stale mirrored frames, recovers transport-proven missing-up and missing-down edges, and posts key events before UI/debug updates.
- macOS throttles input debug/status publishing so UI work does not compete with key injection.
- During physical tap testing, the Mac debug panel shows missing transport frames, recovered duplicate-down edges, and ignored duplicate/orphan input edges separately.
- iOS sends a heartbeat every 500 ms.
- macOS releases all held keys after 1500 ms without heartbeat, but keeps the socket open so brief focus/app-launch stalls can recover.
- macOS keeps a latency-critical activity while the helper is running to avoid App Nap when the target app is focused.
- macOS releases all held keys on client disconnect, server stop, or manual Release All.
- iOS sends best-effort `release_all` when disconnecting, becoming inactive, or backgrounding.
