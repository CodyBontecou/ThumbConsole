# Input Latency and Reliability Optimization

Date: 2026-07-10

## Why we did this

PocketPad already felt responsive in light use, but Hollow Knight exposed the weak spots. Rapid direction changes, overlapping touches, short taps, and Wi-Fi loss put much more pressure on the input path than clicking through the UI.

The goal was not to shave time off a synthetic benchmark. It was to make the full iPhone-to-Mac path predictable under real gameplay:

1. A release must never be overtaken by an older mirrored input.
2. A short tap must remain visible to the target game.
3. A lost UDP packet must recover without leaving a key held.
4. Normal input processing on the Mac should stay below 4 ms at p95.
5. The numbers must come from production code, on physical devices.

## The input path we measured

The hot path is:

```text
UIKit touch edge
  -> iOS input state and sequence assignment
  -> JSON or compact wire encoding
  -> authenticated UDP send
  -> Mac decode and generation check
  -> short reorder window
  -> physical press bookkeeping
  -> pulse sequencing
  -> CGEvent or virtual-controller injection
```

The same input is mirrored over WebSocket after the UDP send. UDP usually wins. The reliable copy covers packet loss and is discarded when the UDP copy has already been accepted.

Early measurements used `Date.currentMilliseconds` on both devices. That cannot measure one-way latency because the clocks are not synchronized. We replaced it with three Mac-side monotonic timings:

- decode time;
- reorder wait;
- receive-to-processed time.

A Mac-originated ping/pong supplies round-trip latency. `pocketpad status --json` reports rolling p50/p95/p99 values, and `pocketpad monitor --jsonl` records every accepted or rejected input decision.

## What changed

### 1. Input protocol v2

Protocol v1 packed button data into 14 bytes and overloaded a timestamp to carry a limited sequence and press identifier. Protocol v2 uses a fixed 32-byte compact button frame with explicit fields for:

- protocol version;
- 64-bit input generation;
- full sequence number;
- full physical press identifier.

Element, analog, pointer, and release messages carry the same ordering fields in JSON. The decoder still accepts legacy v1 frames.

The press identifier matters as much as the sequence. It lets the Mac distinguish an old release from a release for the touch that is currently holding the same control.

### 2. Ordered generations and release barriers

`release_all` used to bypass the sequenced input path. A delayed UDP or WebSocket copy could arrive after the release and press the key again.

Each connection now owns an input generation. Releasing all input advances that generation and retires the previous one. The Mac rejects frames from retired generations, and delayed reliable mirrors verify that they still belong to the current connection before sending.

This turned `release_all` into an ordering barrier instead of a best-effort side message.

### 3. Network-owned liveness

Heartbeat and stale-input checks moved off the main run loop. Both sides now use dispatch-source timers on their network queues and compare monotonic uptime values.

Physical testing found two less obvious races:

- A heartbeat could snapshot B as held, race with B-up, then send the stale down after the release.
- A global snapshot revision prevented that race but could also suppress refreshes for a long-held direction whenever an unrelated action button changed.

The final design validates each heartbeat press independently. A refresh is sent only if that exact press identifier is still active. Releasing B does not cancel the refresh for a held direction.

The iOS refresh interval is 250 ms. The Mac expires an unrefreshed physical hold after 1.75 seconds. Those values came from device logs: iOS sometimes coalesced nominal 500 ms timers to roughly 1.5 seconds during gameplay, which made the previous 850 ms timeout release legitimate holds.

### 4. Safe late-release recovery

The Mac waits up to 4 ms for a missing sequence before continuing. That keeps packet loss from blocking newer input for an entire frame, but physical logs showed reliable WebSocket copies arriving 15–102 ms after that deadline.

A late down remains unsafe and is rejected. A late up is different: if it names the exact press identifier that is still active, the Mac applies it as a release. It cannot release a newer touch with another identifier.

This recovered a dropped B-up in the final physical run without reopening the stale-down race.

### 5. One bounded reorder deadline

The reorder buffer now creates one deadline for a gap instead of waiting again for each buffered frame. It is capped at 512 messages. When the deadline expires, the Mac advances to the next available sequence and records the missing range.

The reliable mirror can still arrive later. At that point normal stale frames are logged and discarded, while the exact identified-up recovery described above remains available.

### 6. Minimum tap pulses

Some games do not observe a down/up pair that completes inside one input poll. Buttons and element inputs now share `InputPulseSequencer<Input>`:

- minimum visible hold: 22 ms;
- minimum gap between repeated taps: 18 ms.

The down edge remains immediate. Only an early up is deferred. Physical touch ownership stays reference-counted before the pulse stage, so overlapping touches cannot release each other.

### 7. Trailing analog delivery

Analog input is limited to one send every 16 ms per stick or trigger. The old throttle kept the leading value and dropped later values in the window, which could leave the Mac with an outdated position until the next heartbeat.

The transport now stores the newest pending value and sends it at the end of the throttle window. Neutral and final values bypass the wait and are mirrored reliably.

### 8. Mac hot-path caching

Element input used to normalize the complete keypad customization to resolve a label and binding for every edge. That work happened on the same serial queue responsible for decode, ordering, and injection.

The Mac now rebuilds a resolved `[KeypadElementInputID: ResolvedElementInput]` cache when the profile or bindings change. Gameplay lookup is constant-time and does not normalize the profile.

### 9. Honest telemetry

Accepted user edges contribute to rolling latency percentiles. Heartbeat refreshes, stale TCP mirrors, malformed messages, and rejected generations remain in the JSONL capture with a reason, but do not lower or inflate the reported percentiles.

Element sequence gaps now update the same runtime counter as compact button gaps. This matters because custom keypad profiles send element inputs rather than legacy button slots.

The latency simulator is still useful for deterministic regression tests, but its output is labeled as a model. It is not presented as device latency.

## Physical test loop

We did not get to the final behavior in one pass. Each fix was installed on an iPhone and tested with real Hollow Knight input.

| Run | Duration | Mac receive-to-processed p95 | What the log found |
|---|---:|---:|---|
| Initial production run | 11m 02s | 1.360 ms | A heartbeat reasserted B 63 µs after B-up; stale recovery released it 937 ms later. |
| Generation-safe heartbeat | 13m 03s | 2.308 ms | A global revision guard starved refresh for an unrelated 4.575-second direction hold. |
| Per-press heartbeat | 9m 50s | 2.845 ms | Four valid 0.886–1.180-second direction holds hit the old 850 ms timeout. |
| Final liveness run | 6m 31s | 2.081 ms | No stale holds or orphan edges. Six UDP frames were lost; one late B-up recovered through the reliable path. |

Final run details:

- 2,600 wire sequence numbers;
- 749 down edges and 749 up edges;
- no input left held at the end;
- no stale-generation drops;
- 8 ms round-trip latency at the final status sample;
- 0.469 ms receive-to-processed p50;
- 2.081 ms p95;
- 4.467 ms p99.

The p99 includes packet-loss recovery and was allowed to exceed 4 ms. The target for normal Mac-side processing was sub-4 ms p95.

The retained final capture from the test machine was:

```text
/tmp/pocketpad-capture-2026-07-10-physical-final-liveness.jsonl
```

Temporary captures are not committed to the repository.

## How to repeat the measurement

Build and run the current Mac and iOS apps, pair the phone, then clear and stream the capture:

```bash
pocketpad monitor --clear --jsonl --duration 600 > /tmp/pocketpad-gameplay.jsonl
```

After the gameplay run:

```bash
pocketpad status --json
```

Useful checks:

```bash
# Event and rejection counts
jq -r '.kind' /tmp/pocketpad-gameplay.jsonl | sort | uniq -c
jq -r 'select(.kind == "input_pipeline") | (.detail // "sample")' \
  /tmp/pocketpad-gameplay.jsonl | sort | uniq -c

# Safety recoveries should be rare and explainable
jq -c 'select(.source == "Stale hold timeout" or
              .source == "iPhone late release recovery" or
              .detail == "orphan_up")' \
  /tmp/pocketpad-gameplay.jsonl
```

A healthy run should end with empty `pressedButtons`, `pressedElementInputs`, and pointer-button state. Packet-loss counts do not need to be zero. What matters is that later input continues promptly and every active press eventually gets the correct release.

## Validation commands

```bash
xcodebuild test \
  -project PocketPad.xcodeproj \
  -scheme PocketPadCLI \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO

xcodebuild build \
  -project PocketPad.xcodeproj \
  -scheme PocketPadMac \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO

xcodebuild build \
  -project PocketPad.xcodeproj \
  -scheme PocketPadiOS \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO

python3 scripts/check-controller-stack-frames.py
```

The final validation had 43 passing CLI tests. Debug and release builds succeeded for macOS and iOS Simulator, and the largest controller stack frame remained 27,280 bytes against the 32,768-byte limit.

## Files involved

- `Sources/Shared/ControllerProtocol.swift`
- `Sources/Shared/ButtonPulseSequencer.swift`
- `Sources/Shared/PocketPadInputLatencySimulation.swift`
- `Sources/iOS/ControllerClient.swift`
- `Sources/Mac/MacControllerServer.swift`
- `Sources/Mac/MacContentView.swift`
- `Sources/CLI/PocketPadCLI.swift`
- `Tests/ButtonPulseSequencerSmokeTests.swift`
- `Tests/InputLatencySimulationSmokeTests.swift`

## What to preserve in future input work

- Treat releases as ordered state transitions, not cleanup messages.
- Use a physical press identifier before recovering an out-of-order release.
- Never recover a stale down.
- Keep liveness timers and state on the network queues.
- Validate timer behavior on a physical iPhone; configured cadence is not proof of delivered cadence.
- Keep rejected traffic in captures, but keep it out of latency percentiles.
- Measure with one clock. Cross-device wall-clock subtraction is not latency instrumentation.
- Test with a game that produces overlapping holds and rapid taps. A quiet synthetic loop will miss the races that matter.
