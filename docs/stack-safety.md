# Swift stack-safety policy

Thumble moves unusually rich keypad, profile, and skin values through SwiftUI, Codable, Network.framework, and file-backed stores. In unoptimized Debug builds, copying several large structs in one call chain can exhaust the 512 KiB stacks used by worker threads or the roughly 1 MiB iOS main-thread stack. A crash may surface in `___chkstk_darwin` or an innocent optional getter even when there is no recursion.

## Required gate

Run this before merging changes to shared models, codecs, profile synchronization, skins, or iOS startup:

```bash
./scripts/verify-stack-safety.sh
```

The gate:

1. requires an arm64 host and verifies both schemes resolve to `SWIFT_OPTIMIZATION_LEVEL = -Onone`;
2. self-tests the disassembly-based frame checker;
3. runs `StackSafetyRegressionTests` on deliberately constrained threads;
4. builds the macOS app in Debug so network call-path budgets run;
5. builds the iOS app in Debug so controller and iOS runtime frame budgets run.

The iOS checker budgets actual nested branches independently—persistence decode/encode, default startup, reconciliation outcomes, skin preparation, appearance selection, style merging, and control application. Sequential phases must not be added together as though they were simultaneously live; callers and callees that really overlap must not be omitted.

`.github/workflows/stack-safety.yml` runs the same script for pull requests and pushes to `main`.

Current Debug/arm64 inline budgets are intentionally close enough to detect accidental re-embedding while leaving useful model-growth room:

| Value | Current bytes | Budget |
|---|---:|---:|
| `GamepadCustomization` | 1,864 | 4,096 |
| `GamepadButtonCustomization` | 1,050 | 2,048 |
| `GamepadConfigurationProfile` | 216 | 512 |
| `ControllerMessage` | 2,465 | 4,096 |
| `ThumbleSkin` / `ThumbleSkinAppearance` | 464 / 456 | 1,024 each |
| `GamepadControlVisualStyle` | 8 | 256 |
| `GamepadStyleToken` | 48 | 256 |

The regression test prints the measured values, so CI logs reveal architecture or compiler layout changes.

## Design rules

- Keep frequently copied transport and aggregate values under the inline-size budgets in `StackSafetyRegressionTests`.
- Put large aggregate fields behind immutable boxes or copy-on-write storage. A copied struct must not share mutable state with its source. This applies to elements stored in arrays and dictionaries too; one large collection element can make optional lookup and equality frames unexpectedly expensive.
- Split normalization, Codable, validation, migration, and resolver pipelines into phase methods. Do not keep every intermediate value alive in one function.
- Use heap-backed workspace objects when multiple large values must survive across phases.
- Keep app and observable-object initializers shallow. Startup migrations still need constrained-stack tests even when moved off the main thread; dispatch worker stacks can be smaller.
- Add a constrained-stack regression for the complete operation, not only its leaf helpers.
- Treat the static frame checker as a supplement. Generic metadata-driven stack allocations are not always visible as fixed prologue reservations, so runtime tests are authoritative.

## Review warning signs

Review these patterns carefully when they involve `GamepadCustomization`, `GamepadConfigurationProfile`, `ControllerMessage`, `ThumbleSkin`, or similarly rich values:

```swift
var prepared = largeValue
let normalized = prepared.normalized
let encoded = try encoder.encode(normalized)
validate(normalized)
```

```swift
if largeOptional != nil { ... }
```

```swift
largeValues.map { $0.normalized }
```

They are not automatically wrong, but Debug builds may reserve scratch storage for several copies before executing the first line. Prefer boxed storage and phase boundaries.

Do not solve a recurring overflow only by increasing `Thread.stackSize` or changing queues. A bounded expanded-stack worker is acceptable around an isolated system Codable limitation, but core model copies and application logic must still pass the normal constrained-stack tests.
