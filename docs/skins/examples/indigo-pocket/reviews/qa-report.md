# Indigo Pocket — Final Independent QA Report

- **Report version:** 1
- **QA date:** 2026-07-17
- **Source:** `docs/skins/examples/indigo-pocket`
- **Canonical artboard:** `showcase-controller-v1` (`snes`, revision 2)
- **Latest independent critique:** `reviews/critique-3.md` — `visual-pass`
- **CLI:** `/Users/codybontecou/Library/Developer/Xcode/DerivedData/ThumbConsole-bqyuqmkqyppmxqddlzshosycivju/Build/Products/Debug/thumbconsole`
- **CLI SHA-256:** `573bc237fe5a6d6c083850a8bb68cc59e5651deb0eaa2c58e95cb2753c41b542`
- **Verdict:** **qa-pass**

This QA pass is an artifact-quality verdict only. It does not grant human approval and does not authorize publication.

## Result summary

| Gate | Result | Evidence |
|---|---|---|
| Latest critic verdict | PASS | `reviews/critique-3.md` says `visual-pass`; no unresolved findings |
| Two isolated clean strict compiles | PASS | Both exited 0 with `"issues": []` |
| Byte-for-byte determinism | PASS | `cmp` exit 0; both packages have SHA-256 `72fdbb32d789cd3c13d32b79cc83d9a373eb9b7d4d663d9e1cab1c80ba3bb3d3` |
| Strict package validation | PASS | Exit 0; zero errors and zero warnings |
| Strict canonical quality | PASS | Exit 0; score 100; zero errors and zero warnings |
| Unpack/repack integrity | PASS | Original and repacked archives are byte-identical; unpacked trees are identical |
| Resource integrity | PASS | All declared byte counts and SHA-256 hashes match; `skin.json` hash matches |
| Dimensions and budgets | PASS | All raster dimensions match 2× canonical artboards; all budgets have wide margin |
| Native state matrix | PASS | 16 panels: 2 orientations × 2 appearances × 4 states |
| State materials and contrast | PASS | All 21 compiled base/light/dark material definitions have four distinct states; measured thresholds pass |
| Canonical compatibility | PASS | Exact SNES revision 2; portrait and landscape compatible; safe-area checks pass |
| Appearance-only safety | PASS | No profile, bindings, mappings, labels, launch targets, or control-layout payload |
| SVG exclusion | PASS | Four editable SVGs remain in source; zero SVG files are present in the archive |
| Website preview readiness | PASS | Four valid high-resolution preview descriptors cover both orientations and appearances |
| Human approval | APPROVED after QA | Cody Bontecou approved the exact final sheet and package hash at `2026-07-17T15:43:09Z` |

## Commands and exact outcomes

The command blocks below use:

```bash
CLI="$HOME/Library/Developer/Xcode/DerivedData/ThumbConsole-bqyuqmkqyppmxqddlzshosycivju/Build/Products/Debug/thumbconsole"
SRC="/Users/codybontecou/projects/ThumbConsole/docs/skins/examples/indigo-pocket"
QA="/tmp/indigo-pocket-qa"
PKG="$QA/compile-a/indigo-pocket-1.0.0.pocketpad"
```

### 1. Isolated clean compilation and determinism

```bash
rm -rf "$QA"
mkdir -p "$QA/compile-a" "$QA/compile-b"

NO_COLOR=1 TERM=dumb timeout 120 "$CLI" skin compile "$SRC" \
  --build-directory "$QA/compile-a/work" \
  -o "$QA/compile-a/indigo-pocket-1.0.0.pocketpad" \
  --clean --strict --json </dev/null

NO_COLOR=1 TERM=dumb timeout 120 "$CLI" skin compile "$SRC" \
  --build-directory "$QA/compile-b/work" \
  -o "$QA/compile-b/indigo-pocket-1.0.0.pocketpad" \
  --clean --strict --json </dev/null

cmp -s \
  "$QA/compile-a/indigo-pocket-1.0.0.pocketpad" \
  "$QA/compile-b/indigo-pocket-1.0.0.pocketpad"
shasum -a 256 \
  "$QA/compile-a/indigo-pocket-1.0.0.pocketpad" \
  "$QA/compile-b/indigo-pocket-1.0.0.pocketpad"
```

Outcome:

- Compile A: exit `0`, `issues: []`, no stderr.
- Compile B: exit `0`, `issues: []`, no stderr.
- `cmp`: exit `0`.
- Each package size: `260965` bytes.
- Compile A SHA-256: `72fdbb32d789cd3c13d32b79cc83d9a373eb9b7d4d663d9e1cab1c80ba3bb3d3`.
- Compile B SHA-256: `72fdbb32d789cd3c13d32b79cc83d9a373eb9b7d4d663d9e1cab1c80ba3bb3d3`.

### 2. Strict validation and quality

```bash
NO_COLOR=1 TERM=dumb timeout 60 "$CLI" skin validate "$PKG" --strict --json </dev/null

NO_COLOR=1 TERM=dumb timeout 60 "$CLI" skin quality "$SRC" \
  --artboard showcase-controller-v1 --strict --json </dev/null
```

Outcomes:

```json
{
  "issues": []
}
```

```json
{
  "checkedArtboardID": "showcase-controller-v1",
  "issues": [],
  "score": 100
}
```

Both strict commands exited `0`. There were no warnings; under this QA policy, any strict warning would have failed the release candidate.

### 3. Unpack, validate, repack, validate, and compare

```bash
NO_COLOR=1 TERM=dumb timeout 60 "$CLI" skin unpack "$PKG" \
  -o "$QA/unpacked-a" </dev/null
NO_COLOR=1 TERM=dumb timeout 60 "$CLI" skin validate "$QA/unpacked-a" \
  --strict --json </dev/null
NO_COLOR=1 TERM=dumb timeout 60 "$CLI" skin pack "$QA/unpacked-a" \
  -o "$QA/repacked.pocketpad" </dev/null
NO_COLOR=1 TERM=dumb timeout 60 "$CLI" skin validate "$QA/repacked.pocketpad" \
  --strict --json </dev/null
NO_COLOR=1 TERM=dumb timeout 60 "$CLI" skin unpack "$QA/repacked.pocketpad" \
  -o "$QA/unpacked-repacked" </dev/null

cmp -s "$PKG" "$QA/repacked.pocketpad"
diff -qr "$QA/unpacked-a" "$QA/unpacked-repacked"
shasum -a 256 "$PKG" "$QA/repacked.pocketpad"
```

Outcome:

- Every CLI command exited `0`.
- Both strict validations returned `issues: []`.
- Archive `cmp`: exit `0`.
- Recursive unpacked-tree `diff`: exit `0`, no differences.
- Repacked size: `260965` bytes.
- Repacked SHA-256: `72fdbb32d789cd3c13d32b79cc83d9a373eb9b7d4d663d9e1cab1c80ba3bb3d3`.

## Package and resource audit

Commands:

```bash
unzip -Z1 "$PKG" | sort
unzip -l "$PKG"
shasum -a 256 "$QA/unpacked-a/skin.json" "$QA/unpacked-a"/assets/*.png "$QA/unpacked-a"/previews/*.png
sips -g pixelWidth -g pixelHeight -g format -g space \
  "$QA/unpacked-a"/assets/*.png "$QA/unpacked-a"/previews/*.png
```

Declared and independently recalculated values:

| Resource | Dimensions | Bytes | SHA-256 | Result |
|---|---:|---:|---|---|
| `assets/canvas-landscape-light.png` | 1748×804 | 47,885 | `26b16b36035557e6098c3e6879adb7dd4132de08bb47bfdb4c105921c8fb760a` | PASS |
| `assets/canvas-landscape-dark.png` | 1748×804 | 47,615 | `1c50ff575b1178111950596d13764d5f404ba10da45056cd34b2a1e1857a1e07` | PASS |
| `assets/canvas-portrait-light.png` | 804×1748 | 56,595 | `60eae90d58fcac012e61ba2818eb613e606316b322653b2bca929b3b76da3791` | PASS |
| `assets/canvas-portrait-dark.png` | 804×1748 | 56,546 | `cc4a938844b899956968e8cc51bf74fcd49cf6e537abbd78dba57520660c4309` | PASS |

Each corresponding `previews/` PNG has the same dimensions, byte count, and SHA-256 as its declared asset counterpart. The preview descriptors cover landscape-light, landscape-dark, portrait-light, and portrait-dark.

- Declared `skin.json` SHA-256: `6306c5e34aa040ba1e4fe3b3538e4d4437e94d509449ed3f57afb18361d3ac48`.
- Recalculated `skin.json` SHA-256: `6306c5e34aa040ba1e4fe3b3538e4d4437e94d509449ed3f57afb18361d3ac48`.
- Total asset bytes: `208641` (below the 12 MiB warning and 24 MiB error thresholds).
- Total preview bytes: `208641` (below the 8 MiB limit).
- Encoded archive: `260965` bytes (below the 30 MiB publication and 40 MiB hard limits).
- Total uncompressed archive content: `570048` bytes (below the 50 MiB hard limit).
- Largest entry: `149246` bytes (below the 10 MiB per-entry limit).
- Entries: `10` (below the 256-entry limit).
- All package visual resources are valid PNG files at exactly 2× the canonical 874×402 landscape and 402×874 portrait artboards.

## Appearance-only and archive safety

The distributable archive contains exactly:

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

Safety findings:

- `manifest.kind` is `skin`; schema is `com.codybontecou.pocketpad.skin-package`, version 2.
- `profilePath` and `profileSHA256` are absent.
- `skin.json` has only `base` and `variants` top-level keys.
- No binding, keyboard mapping, mapped-button, profile, launch-target, label override, accessibility override, or control-layout payload is present.
- There are zero built-in-button rules and seven semantic appearance role rules.
- Artwork is supplied only as passive raster background fills; native controls continue to own geometry, hit testing, labels, state, and accessibility.
- No executables, symlinks, undeclared resources, traversal paths, or duplicate entries were found; strict decoding/validation passed.
- The four editable SVG files remain under `sources/artwork/` and are not shipped. Archive SVG count: `0`.

## Materials, states, and contrast

A structured JSON audit checked the base material library and both `styles-light` and `styles-dark` variants. Each contains seven material definitions:

- `shell-satin`
- `harbor-inset`
- `movement-elastomer`
- `action-lacquer`
- `utility-indigo`
- `shoulder-rail-key`
- `system-index-key`

All 21 base/light/dark definitions explicitly contain distinct `normal`, `pressed`, `active`, and `disabled` state objects. Semantic role assignments cover movement, primary action, secondary action, utility, menu, custom shoulders, and system chrome.

Measured WCAG contrast results:

- Normal legend/base range across source materials and both appearances: **8.96:1–16.55:1**; requirement: at least 7:1.
- Compiled disabled legend/fill range across both appearances: **9.71:1–16.72:1**; requirement: at least 3:1, with 4.5:1 preferred for small legends.
- Active violet/base-fill range across source materials: **3.33:1–6.26:1**; requirement: at least 3:1.

The strict quality evaluator independently confirmed state completeness, state distinction, source contrast, asset dimensions, variant coverage, safe areas, and layer safety with score 100 and no issues.

## Canonical SNES revision-2 compatibility and safe areas

Commands:

```bash
NO_COLOR=1 TERM=dumb timeout 30 "$CLI" skin artboard show \
  showcase-controller-v1 --json </dev/null
NO_COLOR=1 TERM=dumb timeout 30 "$CLI" skin inspect "$PKG" --json </dev/null
```

Compatibility result:

- Canonical artboard ID: `showcase-controller-v1`.
- Template: `snes`.
- Artboard revision: `2`.
- Package compatibility mode: `template_aligned`.
- Package template range: minimum revision `2`, maximum revision `2`.
- Declared orientations: `landscape`, `portrait`.
- Required rendering feature: `bitmap_control_states`.
- Required semantic roles are present.
- Landscape canonical profile: 874×402, 13 controls, safe rectangle `(0.045, 0.035)–(0.955, 0.965)`; zero non-system control-center violations.
- Portrait canonical profile: 402×874, 13 controls, safe rectangle `(0.025, 0.055)–(0.975, 0.955)`; zero non-system control-center violations.
- Strict quality reported no `canonical-template-incompatible`, `control-outside-safe-area`, role, alignment, aspect-ratio, or variant issue.

The package is intentionally exact-match compatible with SNES revision 2 in both orientations; revision 1 is outside its declared compatibility range.

## Native 16-panel contact sheet

Command:

```bash
NO_COLOR=1 TERM=dumb timeout 180 "$CLI" skin preview "$SRC" \
  -o "$QA/contact-sheet-qa.png" \
  --artboard showcase-controller-v1 \
  --orientation all --appearance all --state all --contact-sheet </dev/null

sips -g pixelWidth -g pixelHeight -g format -g space \
  "$QA/contact-sheet-qa.png" "$SRC/reviews/contact-sheet-3.png"
shasum -a 256 "$QA/contact-sheet-qa.png" "$SRC/reviews/contact-sheet-3.png"
cmp -s "$QA/contact-sheet-qa.png" "$SRC/reviews/contact-sheet-3.png"
```

Outcome:

- CLI output: `Rendered 16-panel native contact sheet`.
- Exit: `0`.
- Matrix: landscape/portrait × light/dark × normal/pressed/active/disabled = 16 panels.
- Dimensions: `2176×1714`, RGB PNG.
- Regenerated SHA-256: `dad64a866a4274a4f36c12ef1e1e76dce1750bdd6c5f7f29bf79c79e9a0830c8`.
- Preserved `reviews/contact-sheet-3.png` SHA-256: `dad64a866a4274a4f36c12ef1e1e76dce1750bdd6c5f7f29bf79c79e9a0830c8`.
- `cmp`: exit `0`; the regenerated sheet is byte-for-byte identical to the visual-pass evidence.
- Prior contact sheets and critique evidence were not modified.

## Human approval gate

At the time independent QA ran, `reviews/human-approval.json` remained pending and QA did not edit it. After reviewing `reviews/contact-sheet-3.png`, Cody Bontecou explicitly approved the exact evidence and package in Pi:

```json
{
  "status": "approved",
  "approvedBy": "Cody Bontecou",
  "approvedAt": "2026-07-17T15:43:09Z",
  "reviewedContactSheet": "reviews/contact-sheet-3.png",
  "packageSHA256": "72fdbb32d789cd3c13d32b79cc83d9a373eb9b7d4d663d9e1cab1c80ba3bb3d3"
}
```

Approved record SHA-256: `c8a59cc779ebbc25364a090776274cb656e1164d604342e77fb7b4472b3a8179`.

## Remaining warnings and verdict

- Strict-command warnings: **none**.
- QA warnings: **none**.
- Human approval: **granted** for the exact final contact sheet and package hash above.
- Publication authorization: **granted**.

**Final verdict: `qa-pass`.**
