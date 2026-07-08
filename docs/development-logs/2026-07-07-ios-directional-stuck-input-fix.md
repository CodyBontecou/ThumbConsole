# iOS Directional Stuck Input Fix

Date: 2026-07-07

## Symptom

The iOS controller could leave a directional input held after the user stopped touching the button. Example: hold Left/Right, release, and the character keeps auto-running on the Mac/game side.

This can also show up as:

- D-pad direction stuck down
- Joystick digital direction stuck down
- Analog stick not returning to neutral
- Trigger/element input staying active after a view/layout change

## Root Cause Pattern

PocketPad depends on balanced touch down/up edges from the iOS capture views. If UIKit/SwiftUI misses or cancels a release path during view teardown, app backgrounding, layout/profile changes, or touch routing changes, the Mac can keep the last physical hold active.

Before this fix, stale-hold recovery existed on the Mac side, but the timeout was long enough that a dropped release felt like an obvious stuck direction.

## Fix Summary

### iOS capture safety

File: `Sources/iOS/TouchCaptureView.swift`

- Added `UIViewRepresentable.dismantleUIView` hooks for touch, joystick, trigger, and trackpad capture views.
- Added a shared `ControllerTouchReleaseWatchdog` timer.
- The watchdog sweeps active capture views and releases touches whose UIKit touch phase ended/cancelled or whose `UITouch.window`/owner window disappeared.
- Joystick capture now tracks the current vector so the UI and analog output can reliably reset to neutral.

### Client state cleanup

File: `Sources/iOS/ControllerClient.swift`

- Release edges now clear local active-input bookkeeping even if the socket is disconnected or the send fails.
- This prevents a previously released input from being re-sent by heartbeat recovery after reconnect/send failure.

### Mac stale-hold recovery

File: `Sources/Mac/MacControllerServer.swift`

- Reduced physical stale-hold timeout from `1.6s` to `850ms`.
- Added stale analog stick/trigger tracking and neutral reset.
- This gives a server-side fallback if an iOS release packet is still lost.

### Simulation update

File: `Sources/Shared/PocketPadInputLatencySimulation.swift`

- Updated held-direction heartbeat recovery simulation to the new `850ms` stale timeout.

## Validation Run

Commands used:

```bash
xcodebuild -project PocketPad.xcodeproj -scheme PocketPadiOS -destination 'generic/platform=iOS Simulator' -derivedDataPath build/AgentDerivedData-direction-stuck build
xcodebuild -project PocketPad.xcodeproj -scheme PocketPadMac -destination 'platform=macOS' -derivedDataPath build/AgentDerivedData-direction-stuck-mac build
xcodebuild -project PocketPad.xcodeproj -scheme PocketPadCLI -destination 'platform=macOS' -derivedDataPath build/AgentDerivedData-direction-stuck-tests test
```

Results:

- iOS build succeeded
- macOS build succeeded
- CLI smoke tests passed: 28/28

## If This Happens Again

Check these first:

1. Confirm every new iOS capture/control type has a teardown path that emits releases.
2. Confirm release edges update local active state even when disconnected or send fails.
3. Confirm Mac-side stale hold tracking covers the output type involved:
   - keyboard buttons
   - element inputs
   - virtual gamepad buttons
   - analog sticks
   - analog triggers
4. Check whether heartbeat re-sync is reasserting an input that the iOS side already visually released.
5. Search logs for:
   - `stale_hold_timeout`
   - `recovered_button_edge`
   - `recovered_element_input_edge`
   - `recovered_gamepad_analog`

## Development Note

For future input work, treat iOS touch capture as edge-sensitive and failure-prone. Any new control should have both:

- an immediate release path from UIKit touch end/cancel, and
- a watchdog/server fallback for missed release edges.
