# QA report: Tideglass Field

**Report version:** 1.0
**Date:** 2026-07-17
**Verdict:** `qa-pass`

QA passed for the exact package and visual evidence identified below. This verdict does not grant human approval and does not authorize publication.

## Evidence and toolchain

- Source: `docs/skins/examples/tideglass-field`
- Canonical artboard: `game-boy-v1`, template `gameBoy`, revision 1
- Expected package: `docs/skins/examples/tideglass-field/build/tideglass-field-1.0.0.pocketpad`
- Package SHA-256: `77927e956d14bd5cf6710c7dc2810da91ce577f290e7f5311d3b389f3e5e24ed`
- Package size: 927,147 bytes
- Accepted native sheet: `reviews/contact-sheet-5.png`
- Accepted native sheet PNG SHA-256: `5c3754ec7c4095730b29e0db871d80f82217a483cc20f42618871f268ddc08ce`
- Accepted native sheet dimensions: 2176 × 1714
- Latest critique: `reviews/critique-5.md`; confirmed verdict `visual-pass`, with no blocker, major, or minor findings
- CLI: `/Users/codybontecou/Library/Developer/Xcode/DerivedData/ThumbConsole-bqyuqmkqyppmxqddlzshosycivju/Build/Products/Debug/thumbconsole`
- CLI SHA-256: `2370bb12d5df75e3f8888a9f1b84434acba052a8d5d5540a1f9cb5f16c585952`
- CLI size/mtime: 50,846,272 bytes; 2026-07-17T15:01:20Z

## Commands and outcomes

The following variables abbreviate the exact absolute paths used below:

```bash
CLI=/Users/codybontecou/Library/Developer/Xcode/DerivedData/ThumbConsole-bqyuqmkqyppmxqddlzshosycivju/Build/Products/Debug/thumbconsole
SRC=/Users/codybontecou/projects/ThumbConsole/docs/skins/examples/tideglass-field
PKG_A=/tmp/tideglass-field-qa-a/tideglass-field-1.0.0.pocketpad
PKG_B=/tmp/tideglass-field-qa-b/tideglass-field-1.0.0.pocketpad
EXPECTED="$SRC/build/tideglass-field-1.0.0.pocketpad"
```

| Check | Exact command | Outcome |
|---|---|---|
| Isolated strict compile A | `timeout 180 "$CLI" skin compile "$SRC" --build-directory /tmp/tideglass-field-qa-a/build -o "$PKG_A" --clean --strict </dev/null` | **PASS**; exit 0, no warnings |
| Isolated strict compile B | `timeout 180 "$CLI" skin compile "$SRC" --build-directory /tmp/tideglass-field-qa-b/build -o "$PKG_B" --clean --strict </dev/null` | **PASS**; exit 0, no warnings |
| Deterministic package bytes | `cmp "$PKG_A" "$PKG_B"` | **PASS**; byte-for-byte identical |
| Deterministic hashes | `shasum -a 256 "$PKG_A" "$PKG_B"` | **PASS**; both `77927e956d14bd5cf6710c7dc2810da91ce577f290e7f5311d3b389f3e5e24ed` |
| Strict package validation | `timeout 60 "$CLI" skin validate "$PKG_A" --strict --json </dev/null` | **PASS**; `issues: []` |
| Strict source quality | `timeout 180 "$CLI" skin quality "$SRC" --artboard game-boy-v1 --strict --json </dev/null` | **PASS**; score 100, `issues: []`, checked artboard `game-boy-v1` |
| Unpack | `timeout 60 "$CLI" skin unpack "$PKG_A" -o /tmp/tideglass-field-qa-unpacked </dev/null` | **PASS** |
| Strict unpacked-directory validation | `timeout 60 "$CLI" skin validate /tmp/tideglass-field-qa-unpacked --strict --json </dev/null` | **PASS**; `issues: []` |
| Repack | `timeout 60 "$CLI" skin pack /tmp/tideglass-field-qa-unpacked -o /tmp/tideglass-field-qa-repacked.pocketpad </dev/null` | **PASS** |
| Repack integrity | `cmp "$PKG_A" /tmp/tideglass-field-qa-repacked.pocketpad` | **PASS**; byte-for-byte identical; repack SHA-256 is the package SHA above |
| Native 16-panel sheet regeneration | `timeout 240 "$CLI" skin preview "$SRC" -o /tmp/tideglass-field-qa-contact-sheet-2.png --artboard game-boy-v1 --all-variants --all-states --native-renderer --contact-sheet --columns 4 </dev/null` | **PASS**; 16 panels rendered |
| Exact accepted-sheet comparison | `cmp /tmp/tideglass-field-qa-contact-sheet-2.png "$SRC/reviews/contact-sheet-5.png"` | **PASS**; byte-for-byte identical; both SHA-256 `5c3754ec7c4095730b29e0db871d80f82217a483cc20f42618871f268ddc08ce` |
| Install expected output | `cp "$PKG_A" "$EXPECTED" && cmp "$PKG_A" "$EXPECTED" && shasum -a 256 "$EXPECTED"` | **PASS**; expected output is the verified package |

### Native renderer reproducibility observation

The first native-sheet invocation produced a lossless PNG with SHA-256 `48c331a84d990b2639a43b698d8ca4c82a55920096968048c5e7c87df1c0a5d7`. It differed from the accepted sheet at 811 of 3,729,664 pixels, with only 1–2 channel-value units of antialiasing variance and no alpha differences. A clean second invocation using the same command and current CLI reproduced `contact-sheet-5.png` exactly at the PNG-byte level. The required exact comparison therefore passes. This observation is not a strict-validator warning and does not affect package determinism.

## Unpack, manifest, and resource integrity

The archive unpacked to exactly these allowed payload classes:

- `manifest.json`
- `skin.json`
- four `assets/*.png`
- four `previews/*.png`

There was no `profile.json`, executable payload, unexpected archive entry, symlink, SVG, script, or external resource. `manifest.kind` is `skin`; `profilePath` and `profileSHA256` are absent. `skin.json` contains semantic appearance rules and empty button-rule arrays, with no `mappedButton`, keyboard, keycode, profile, or binding payload. Native geometry, labels, hit testing, bindings, and accessibility therefore remain outside the package.

All declared byte counts and SHA-256 values matched extracted bytes:

| Declared resource | Bytes | SHA-256 | Result |
|---|---:|---|---|
| `assets/canvas-landscape-light.png` | 117,082 | `aa424a57da724e39416f5995bfa31c41cb37a356eb3e5b3a40cf484cd574a3b6` | PASS |
| `assets/canvas-landscape-dark.png` | 112,934 | `2b1c2b0fb4d5b0d9a4bf294f8ff979f9b6d364e5c4e882eeb4c83ff9a5bbcf67` | PASS |
| `assets/canvas-portrait-light.png` | 135,044 | `31c3867630dc7d75cf5199eaf650b895f5d180c7ed4b493095371480d3482624` | PASS |
| `assets/canvas-portrait-dark.png` | 127,960 | `7787047937e8ff5ded8a8775ad48f6840d7fd8ace3b4286ca647c2cb139e2dbe` | PASS |
| Corresponding four `previews/*.png` | same as asset | same as asset | PASS |
| `skin.json` | 337,254 | `d464435317012e76ecc1a81bada0a9d58765e97cf278a8680a81df038d69af9e` | PASS |

## Compatibility, safe areas, and semantic roles

**PASS.** Strict quality evaluated both committed canonical variants and emitted no `canonical-template-incompatible`, safe-area, role, alignment, aspect, or variant issue.

- Manifest mode: `template_aligned`
- Template: `gameboy`, minimum revision 1, maximum revision 1; this is the package form of `game-boy-v1` revision 1
- Landscape canonical profile: 874 × 402, aspect 2.1741; declared and evaluated compatible
- Portrait canonical profile: 402 × 874, aspect 0.4600; declared and evaluated compatible
- Declared aspect range: 0.4–2.5; both profiles are inside it
- Declared orientations: landscape and portrait
- Canonical/source semantic coverage: movement, primary action, utility, menu, and system
- Manifest-required interactive roles: movement, primary action, utility, and menu
- Required renderer feature: `bitmap_control_states`; supported
- All non-system canonical control centers passed the canonical safe-area evaluator. The art-direction exceptions near nominal safe limits remain preserved by the canonical profile and introduce no strict issue.

## Dimensions and budgets

**PASS.** All visual resources decode as RGBA PNG and match the committed artboard aspect at 2×:

- Landscape light/dark assets and previews: 1748 × 804
- Portrait light/dark assets and previews: 804 × 1748
- Asset bytes: 493,020 total, below the 12 MiB warning and 24 MiB failure budgets
- Preview bytes: 493,020 total, below the 8 MiB budget
- Package bytes: 927,147, below the 30 MiB budget
- Each preview exceeds the directory-readiness minimum of 300 px on its short edge and 640 px on its long edge
- No axis exceeds 8192 px

## Materials, states, contrast, and orientation-specific styling

**PASS.** The compiled skin contains seven materials in each style variant, and every material has Normal, Pressed, Active, and Disabled definitions. The five semantic assignments are:

- movement → `movement-elastomer`
- primary action → `action-resin`
- utility → `utility-key`
- menu → `menu-key`
- system → `system-junction`

State and orientation checks:

- All pressed states compile at center-anchored scale 0.97.
- Disabled semantic controls use explicit fill, foreground, stroke, 3 px stroke width, 0.98 opacity, and no normal-state-equivalent definition.
- Action Active stroke is orientation-specific: 4.5 source units in landscape and 7.0 in portrait, in both light and dark variants.
- The source declares all 16 orientation × appearance × state review combinations; the native renderer regenerated all 16.
- Light and dark canvas artwork is separately authored for both orientations, not rotated or stretched.

Computed source-token contrast minima across the five semantic control materials:

- Normal legend contrast: 9.03:1 minimum
- Disabled legend contrast: 4.98:1 minimum
- Active index against active/control fill: 3.71:1 minimum
- Disabled edge against the immediate abyss well: 3.93:1 minimum

These exceed the written 7:1 normal-legend target, 3:1 disabled-legend floor, 3:1 active-index floor, and 3:1 control-boundary floor. `critique-5.md` independently confirms the final native raster's two-pixel Active A/B index, 6.74% light and 7.19% dark action-face lift, state distinction, consistent upper-left lighting/lower-right depth, no glow, and no remaining visual defects.

## Artwork and package safety

**PASS.** Editable SVG sources remain in the workspace and were sanitized/rasterized during both strict compiles. The distributable archive contains zero SVG files and only validated PNG media. Source artwork has four orientation/appearance-specific SVGs with canonical 874 × 402 or 402 × 874 view boxes. No source script, event handler, entity, JavaScript URI, or external image/link reference was found; the only URL text is the standard SVG namespace declaration.

Artwork is passive canvas support. The package carries no profile or executable binding data, and its semantic role rules only select native appearance materials. The final visual-pass confirms controls and labels stay legible, safe, unobscured, and semantically native.

## Website preview readiness

**PASS.** The manifest declares a complete four-preview matrix: landscape light/dark and portrait light/dark. Every preview decodes, has a matching descriptor/hash/byte count, matches its corresponding validated canvas raster, has canonical aspect and high-resolution dimensions, and stays within preview budgets. The 2176 × 1714 accepted contact sheet is ready as review evidence but is not embedded in the package.

## Remaining warnings

None from either strict compile, strict package validation, strict unpacked-directory validation, or strict source quality. The one low-order first-render variance is recorded above as an operational observation; the required clean regeneration exactly matched the accepted PNG.

## Human approval status

`reviews/human-approval.json` remains present and `pending`:

- `approvedBy`: null
- `approvedAt`: null
- `reviewedContactSheet`: null
- `packageSHA256`: null

No approval was created or inferred. QA pass is not publication approval. No catalog, publication, deployment, staging, commit, or push action was performed.
