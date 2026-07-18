# Pale Cavern — Design Pass 2

- Stage: bounded corrective designer pass after `critique-1.md`
- Canonical artboard: `showcase-controller-v1`, revision 2
- Package identity: `com.codybontecou.pale-cavern` `1.0.0`
- Human approval: pending

## Evidence preserved

- `reviews/contact-sheet-1.png` was not changed; SHA-256 remains `cea87ee3b9cf485e1c214c9952075d7406c309a9393d880e56052a8d019c40cb`.
- `reviews/critique-1.md` was not changed; SHA-256 remains `9b8125dd0c0a2e6ee5986216a50e70752b07195dceb43f64e70f77d7987ea1ca`.

## Accepted corrections implemented

### Portrait composition and landings

- Replaced the broad portrait spine in both appearance SVGs with a curved bridge whose measured maximum solid horizontal run is 86 px over the unobscured y = 344–587 run.
- The measured bridge center shifts 12 px between the first and last unobscured sampled rows and ranges farther laterally through the curve. It overlaps the upper and lower chamber construction by approximately 14–16 px.
- Preserved 13–16 px between the bridge and utility shelf and 13 px between the system landing and bridge.
- Rebuilt both custom roles as independent 114 × 56 px raised ledges with radius 18 px, 11.7–13 px native-frame clearance, and a restrained 4 px lower-right contact shadow.
- Replaced the portrait square system mount with one 84 × 68 px neutral rounded landing, radius 18 px, with approximately 12 px clearance from its native frame.
- Kept the central cavern air unfilled; no particles, labels, glow, or texture were added there. Portrait flecks were reduced to four low-contrast authored marks.

### Landscape geometry and mineral laminae

- Replaced the landscape system square with an 80 × 64 px neutral rounded landing, radius 18 px, with approximately 10 px native-frame clearance.
- Brought movement, action, utility, and portrait chamber well corners into the 18–20 px internal-radius family.
- Expanded the landscape shell edge so both movement and action wells now have 13 px between well and shell boundaries; the former approximately 5 px right-side pinch is removed.
- Strengthened one lamina overlap per orientation with a continuous 2 px occlusion edge and a 4 px lower-right contact shadow. Each authored edge exceeds 30% of its plate span and remains visible in the 25% review.
- Reduced surface flecks to six in landscape and four in portrait. All are 1–3 px authored marks with low composited contrast; no noise, bloom, additional cyan, motifs, or hardware detail was introduced.

### Native state materials

- Retained authored Pressed luminance shifts of 11.1–12.7% and `pressedShadowScale` 0.4 for every semantic role.
- Reduced `pressedInnerShadowScale` from 0.72 to 0.14, collapsing the generated inner treatment to an approximately 1 px lower-right cue. Full-resolution and 25% inspection no longer shows a radial bright-center/halo model; Pressed reads through uniform tone and collapsed elevation.
- Preserved the 2 px active boundary and tint. Dark primary and secondary action boundaries now use `#2E777B` against their existing active faces, measuring 3.68:1 and 3.29:1 local contrast respectively; the short state index remains `#72D4CF`.
- Retuned every Disabled fill to 0% HSV saturation. Face-to-well contrast reduction is 39.3–49.4% across all roles and appearances, and source legend-to-face contrast is 4.42:1–7.64:1. Quiet neutral 1 px boundaries preserve countable faces and Normal grouping order without cyan, raised highlight, or shadows.

## Verification outcomes

Using `/Users/codybontecou/projects/ThumbConsole/build/AgentDerivedData-hollow-skin-cli/Build/Products/Debug/thumbconsole`:

- Clean source compile: passed.
- Strict package validation: `valid with no warnings`.
- Strict source quality against `showcase-controller-v1`: `publication-ready`, 100/100, 0 errors, 0 warnings.
- Determinism: two clean temporary compiles and the workspace package are byte-for-byte identical.
- Native preview: 16 panels, all variants and states, 4 columns.
- Full-size inspection: completed at 2176 × 1714 px.
- 25% inspection: completed at 544 × 429 px.

## Output evidence

- Package: `build/pale-cavern-1.0.0.pocketpad`
- Package SHA-256: `54b5343f622541a994934eb35e36ad91cf2cec9521b0ca8cd1cf039003d311f4`
- Contact sheet: `reviews/contact-sheet-2.png`
- Contact-sheet dimensions: 2176 × 1714 px
- Contact-sheet SHA-256: `2e2752cb2bb1bc789f22975ae06437f7b51517b608493f21e927fda7545771b5`

## Remaining known risks for critique 2

1. The canonical portrait action envelope ends near y = 242 while the system frame begins near y = 258, leaving only approximately 16 px between native frames. A 10–14 px action-well clearance, a 10–14 px system-landing clearance, and 12 px of passive ground between both boundaries cannot all coexist vertically. This pass prioritizes the exact system-landing clearance, a single rounded passive boundary, and a 13 px bridge gap; the action well and system landing remain visually close at their top/bottom junction. Critique 2 should explicitly judge whether the resulting detachment is sufficient under the fixed canonical geometry.
2. Source schema v1 exposes `pressedInnerShadowScale` but no Pressed-only highlight or bevel override. The native compiler retains its fixed 4% Pressed highlight while this pass reduces the supported inner-shadow token to 0.14. The rendered full-size and 25% evidence no longer shows the prior radial halo, but a stricter per-pixel interior-variation requirement would need a future schema token rather than SVG state artwork or a compiler change in this bounded pass.

No distribution output, profile installation/application, catalog or Website change, publication, staging, commit, push, or approval action was performed. `reviews/human-approval.json` remains pending.
