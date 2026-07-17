# Solar Sumi — Final Independent QA Report

- **Report version:** 2
- **QA date:** 2026-07-17
- **Source:** `docs/skins/examples/solar-sumi`
- **Canonical artboard:** `arcade-stick-v1` (`arcadeStick`, revision 1)
- **Final visual evidence:** `reviews/contact-sheet-4.png`
- **Evidence SHA-256:** `7dd3e83c868fdccbac0f9ca828f257f3322dfa6ae8da1ebb63f0b16213363b6e`
- **Latest independent critique:** `reviews/critique-4.md` — `visual-pass`, 0 open findings
- **CLI:** `/Users/codybontecou/Library/Developer/Xcode/DerivedData/ThumbConsole-bqyuqmkqyppmxqddlzshosycivju/Build/Products/Debug/thumbconsole`
- **CLI SHA-256:** `2370bb12d5df75e3f8888a9f1b84434acba052a8d5d5540a1f9cb5f16c585952`
- **Candidate package:** `build/solar-sumi-1.0.0.pocketpad`
- **Candidate package SHA-256:** `edbecde5b7085aff6c99d3ce671f61daba1a3db1b04bc3f0ef83b72301501947`
- **Verdict:** **qa-pass**

Solar Sumi passes the complete strict and deterministic QA contract. Two sequential isolated clean compiles are byte-for-byte identical; package validation and canonical source quality pass in strict mode with no warnings; unpack/repack is lossless; all declared hashes, dimensions, states, materials, safety boundaries, compatibility metadata, and preview requirements pass. A fresh sequential native-renderer generation is byte-for-byte identical to the exact sheet reviewed in `critique-4.md`.

This is an artifact-quality verdict only. It does not grant human approval and does not authorize publication, catalog changes, deployment, staging, commit, or push.

## Result summary

| Gate | Result | Evidence |
|---|---|---|
| Latest critic verdict | PASS | `reviews/critique-4.md` says `visual-pass`; 0 blockers, majors, or minors |
| Two sequential isolated clean strict compiles | PASS | Both exit 0 with `issues: []` and empty stderr |
| Byte-for-byte package determinism | PASS | `cmp` exit 0; both SHA-256 `edbecde5…1947` |
| Expected build output identity | PASS | Existing package is byte-identical to both isolated outputs |
| Strict package validation | PASS | Exit 0; zero errors and zero warnings |
| Strict canonical source quality | PASS | Exit 0; score 100; zero errors and zero warnings |
| Unpack/repack integrity | PASS | Repacked archive and unpacked trees are byte-identical |
| Declared resource integrity | PASS | Every byte count and SHA-256 matches; `skin.json` hash matches |
| Canonical compatibility | PASS | Exact `arcadeStick` revision 1; portrait and landscape accepted |
| Appearance-only/package safety | PASS | No profile, binding, mapping, launch, label/accessibility override, executable, or layout payload |
| SVG exclusion | PASS | Four editable SVGs remain in source; archive SVG count is zero |
| Dimensions and budgets | PASS | Four 2× canonical PNG assets and four matching previews; all limits have wide margin |
| State/material/contrast | PASS | 33 definitions contain distinct normal/pressed/active/disabled states; strict contrast gate passes |
| Native all-variant/all-state generation | PASS | Current CLI generated all 16 panels at 2176×1714 |
| Exact current-sheet regeneration | PASS | Regenerated output is byte-identical to `contact-sheet-4.png`, SHA `7dd3e83c…b6e` |
| Website preview readiness | PASS | Both orientations and appearances have high-resolution previews |
| Human gate | PENDING | `reviews/human-approval.json` remains pending and was not edited |

## Commands and exact outcomes

Commands used these paths:

```bash
CLI="/Users/codybontecou/Library/Developer/Xcode/DerivedData/ThumbConsole-bqyuqmkqyppmxqddlzshosycivju/Build/Products/Debug/thumbconsole"
SRC="/Users/codybontecou/projects/ThumbConsole/docs/skins/examples/solar-sumi"
QA="/tmp/solar-sumi-qa-final-v2"
PKG="$QA/compile-a/solar-sumi-1.0.0.pocketpad"
```

### 1. Sequential strict compilation and determinism

```bash
rm -rf "$QA"
mkdir -p "$QA/compile-a" "$QA/compile-b"

NO_COLOR=1 TERM=dumb timeout 180 "$CLI" skin compile "$SRC" \
  --build-directory "$QA/compile-a/work" \
  -o "$QA/compile-a/solar-sumi-1.0.0.pocketpad" \
  --clean --strict --json </dev/null

NO_COLOR=1 TERM=dumb timeout 180 "$CLI" skin compile "$SRC" \
  --build-directory "$QA/compile-b/work" \
  -o "$QA/compile-b/solar-sumi-1.0.0.pocketpad" \
  --clean --strict --json </dev/null

cmp -s "$QA/compile-a/solar-sumi-1.0.0.pocketpad" \
  "$QA/compile-b/solar-sumi-1.0.0.pocketpad"
cmp -s "$QA/compile-a/solar-sumi-1.0.0.pocketpad" \
  "$SRC/build/solar-sumi-1.0.0.pocketpad"
shasum -a 256 "$QA"/compile-{a,b}/solar-sumi-1.0.0.pocketpad \
  "$SRC/build/solar-sumi-1.0.0.pocketpad"
```

Outcomes:

- Compile A: exit `0`, `issues: []`, empty stderr.
- Compile B: exit `0`, `issues: []`, empty stderr.
- Isolated package comparison: exit `0`.
- Existing expected-output comparison: exit `0`.
- Each package is `708806` bytes.
- All three SHA-256 values are `edbecde5b7085aff6c99d3ce671f61daba1a3db1b04bc3f0ef83b72301501947`.

### 2. Strict package and source gates

```bash
NO_COLOR=1 TERM=dumb timeout 90 "$CLI" skin validate \
  "$PKG" --strict --json </dev/null

NO_COLOR=1 TERM=dumb timeout 90 "$CLI" skin quality "$SRC" \
  --artboard arcade-stick-v1 --strict --json </dev/null
```

Outcomes:

```json
{ "issues": [] }
```

```json
{
  "checkedArtboardID": "arcade-stick-v1",
  "issues": [],
  "score": 100
}
```

Both commands exited `0` with empty stderr. There were no warnings; any warning under either strict command would have failed QA.

### 3. Unpack/repack integrity

```bash
NO_COLOR=1 TERM=dumb timeout 90 "$CLI" skin unpack "$PKG" \
  -o "$QA/unpacked-a" </dev/null
NO_COLOR=1 TERM=dumb timeout 90 "$CLI" skin validate "$QA/unpacked-a" \
  --strict --json </dev/null
NO_COLOR=1 TERM=dumb timeout 90 "$CLI" skin pack "$QA/unpacked-a" \
  -o "$QA/repacked.pocketpad" </dev/null
NO_COLOR=1 TERM=dumb timeout 90 "$CLI" skin validate "$QA/repacked.pocketpad" \
  --strict --json </dev/null
NO_COLOR=1 TERM=dumb timeout 90 "$CLI" skin unpack "$QA/repacked.pocketpad" \
  -o "$QA/unpacked-repacked" </dev/null

cmp -s "$PKG" "$QA/repacked.pocketpad"
diff -qr "$QA/unpacked-a" "$QA/unpacked-repacked"
shasum -a 256 "$PKG" "$QA/repacked.pocketpad"
```

Every CLI command exited `0`; both strict validations returned `issues: []`. Archive `cmp` and tree `diff` exited `0`. Original and repacked archives are `708806` bytes and share SHA-256 `edbecde5b7085aff6c99d3ce671f61daba1a3db1b04bc3f0ef83b72301501947`.

### 4. Exact current-renderer evidence regeneration

```bash
NO_COLOR=1 TERM=dumb timeout 240 "$CLI" skin preview "$SRC" \
  -o "$QA/contact-sheet-qa.png" \
  --artboard arcade-stick-v1 \
  --all-variants --all-states --native-renderer \
  --contact-sheet --columns 4 </dev/null

cmp -s "$QA/contact-sheet-qa.png" "$SRC/reviews/contact-sheet-4.png"
shasum -a 256 "$QA/contact-sheet-qa.png" \
  "$SRC/reviews/contact-sheet-4.png"
sips -g pixelWidth -g pixelHeight -g format -g space \
  "$QA/contact-sheet-qa.png" "$SRC/reviews/contact-sheet-4.png"
```

Outcome:

- Preview exited `0` with empty stderr and reported `Rendered 16-panel native contact sheet`.
- Matrix: landscape/portrait × light/dark × normal/pressed/active/disabled = 16 panels.
- Both files are 2176×1714 RGB PNG and `469743` bytes.
- Exact file comparison: exit `0`.
- Both SHA-256 values: `7dd3e83c868fdccbac0f9ca828f257f3322dfa6ae8da1ebb63f0b16213363b6e`.
- This is the exact evidence reviewed by `reviews/critique-4.md`, whose verdict is `visual-pass`.

## Package, resource, and budget audit

The archive contains exactly ten regular `0644` files:

```text
manifest.json
skin.json
assets/canvas-landscape-dark.png
assets/canvas-landscape-light.png
assets/canvas-portrait-dark.png
assets/canvas-portrait-light.png
previews/canvas-landscape-dark.png
previews/canvas-landscape-light.png
previews/canvas-portrait-dark.png
previews/canvas-portrait-light.png
```

| Resource | Dimensions | Bytes | SHA-256 | Result |
|---|---:|---:|---|---|
| `assets/canvas-landscape-light.png` | 1748×804 | 95,929 | `edf959a817d88d7cdeed8775eb6a738cee83ff2982e6cff89c256e2090f3cc7f` | PASS |
| `assets/canvas-landscape-dark.png` | 1748×804 | 86,078 | `c2cbbde421561e269e0e3a82e1ff8cc22720648712cbf83e4d543556d8fffe81` | PASS |
| `assets/canvas-portrait-light.png` | 804×1748 | 107,586 | `a7d55beab45a158f786d3cc4fb44c277a7b2a410417db6131fd220bb83f3904c` | PASS |
| `assets/canvas-portrait-dark.png` | 804×1748 | 96,218 | `524db6725eb43a00afce2600126fe630b4f02d7f1541277ca8e8330f75fc93d9` | PASS |

Each corresponding preview has the same dimensions, byte count, and SHA-256 as its asset. Every raster is RGB PNG and exactly 2× the canonical 874×402 landscape or 402×874 portrait canvas.

- Declared and recalculated `skin.json` SHA-256: `4a471b4dfd78f3dfab0518a7d2a885caccb897cba332113c31023e3e4b79b4bb`.
- Manifest SHA-256: `d0d2ef1b16bdfd3beb09ffaecc0c095f89c14c8b84cf7ee97766f663d6a65d14`.
- Total asset bytes: `385811` (below 12 MiB warning and 24 MiB error thresholds).
- Total preview bytes: `385811` (below 8 MiB).
- Encoded archive: `708806` bytes (below 30 MiB publication and 40 MiB hard limits).
- Uncompressed content: `1019529` bytes (below 50 MiB).
- Largest entry: `244403` bytes (below 10 MiB).
- Entry count: `10` (below 256).
- Maximum compression ratio: `16.86:1` (below `200:1`).
- All timestamps are deterministic `1980-01-01 00:00:00`.
- No duplicate, encrypted, executable, symlink, undeclared, absolute, traversal, or unsafe-path entry exists.

## Appearance-only and SVG safety

- Manifest schema is `com.codybontecou.pocketpad.skin-package`, schema version 2, kind `skin`.
- `profilePath` and `profileSHA256` are absent.
- `skin.json` has only `base` and `variants` at top level.
- Base has zero built-in-button rules and seven semantic appearance assignments.
- No binding, keyboard mapping, mapped-button, profile, launch target, label/accessibility override, control-frame, or control-layout payload is present.
- Artwork is passive background raster media; native controls retain geometry, labels, state, hit testing, and accessibility.
- Four editable SVG sources remain under `sources/artwork/`; distributable SVG count is `0`.

Editable SVG hashes:

| Source | SHA-256 |
|---|---|
| `sources/artwork/landscape-dark.svg` | `4412ca6ccad109c8a4297026f17cb0993c53b871c26fba4eb8a5d5af0f18af49` |
| `sources/artwork/landscape-light.svg` | `76880d6d86b43d76fcc7b4b35b76728e5e6b20fb7a493514f34992f2fc80537d` |
| `sources/artwork/portrait-dark.svg` | `7442fa177e53f2cbaccfdc2fd06e9095514094fd9075c89c3ef9926642bbaa67` |
| `sources/artwork/portrait-light.svg` | `8251ab74e6f0a3c8c0b7d896b8c69745eb36486d01a915e33362d506f3d270cc` |

## Materials, states, contrast, and semantic roles

- 11 base, 11 explicit light, and 11 explicit dark styles: 33 definitions total.
- Every definition contains normal, pressed, active, and disabled.
- No pressed, active, or disabled definition is structurally identical to normal.
- Semantic assignments cover `joystick`, `primary_action`, `secondary_action`, `custom`, `menu`, `utility`, and `system`.
- All semantic pressed scales are `0.97`; active scales are `1.0`.
- All semantic active strokes are `3.25` px.
- Active-stroke-to-active-fill contrast is `3.10:1–7.91:1` across compiled base/light/dark semantic styles.
- Disabled legend/fill contrast is `5.82:1–8.64:1`; disabled states contain no cast shadows.
- Source material foreground/base contrast is `4.71:1–16.39:1`, above the strict evaluator's 4.5:1 no-warning threshold.
- Strict quality independently passed contrast, state completeness/distinction, roles, dimensions, variant coverage, alignment, safe areas, layer safety, and budgets with score 100 and no issues.
- `critique-4.md` visually passes legibility, state distinction, safe areas, semantic hierarchy, material craft, and originality on the exact regenerated sheet.

## Canonical compatibility and website readiness

Commands:

```bash
NO_COLOR=1 TERM=dumb timeout 30 "$CLI" skin artboard show \
  arcade-stick-v1 --json </dev/null
NO_COLOR=1 TERM=dumb timeout 60 "$CLI" skin inspect "$PKG" --json </dev/null
```

Compatibility results:

- Artboard ID `arcade-stick-v1`, template `arcadeStick`, revision 1.
- Package mode `template_aligned`; normalized template `arcadestick`; minimum and maximum revision both 1.
- Declared orientations: landscape and portrait.
- Required feature: `bitmap_control_states`.
- Required package roles are present; source additionally covers custom and system.
- Landscape canvas 874×402; safe rectangle `(0.045, 0.035)–(0.955, 0.965)`; zero non-system control-center violations.
- Portrait canvas 402×874; safe rectangle `(0.025, 0.055)–(0.975, 0.955)`; zero non-system control-center violations.
- Strict quality reports no compatibility, role, safe-area, alignment, aspect-ratio, or variant issue.

The four manifest previews cover landscape light/dark and portrait light/dark. Each is a validated high-resolution RGB PNG, matches its canonical aspect ratio, exceeds website minimum dimensions, has a verified declared hash, and remains within preview budgets. Website-preview readiness passes.

## Human gate, warnings, and verdict

`reviews/human-approval.json` remains pending:

```json
{
  "status": "pending",
  "approvedBy": null,
  "approvedAt": null,
  "reviewedContactSheet": null,
  "packageSHA256": null
}
```

Approval record SHA-256: `9cc91bd3e9162b95fbf751b35ff31af7048a23955f89b4daca4aebe78cf98ae7`. QA did not edit or infer approval.

- Strict compile warnings: **none**.
- Strict validation warnings: **none**.
- Strict quality warnings: **none**.
- Package/resource/safety warnings: **none**.
- Remaining QA warnings or failures: **none**.
- Human approval: **pending**.
- Publication authorization: **not granted**.

**Final verdict: `qa-pass`.**
