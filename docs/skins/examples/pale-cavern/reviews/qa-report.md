# Pale Cavern 1.0.0 — Final Strict Publication-Readiness QA

- **QA date:** 2026-07-17
- **Source root:** `/Users/codybontecou/projects/ThumbConsole/docs/skins/examples/pale-cavern`
- **Candidate package:** `build/pale-cavern-1.0.0.pocketpad`
- **Candidate package SHA-256:** `10b498ca7c549847d4c32d3aea8248f7a102ab9dc307c051a86e1c536cdbdd5b`
- **Final review sheet:** `reviews/contact-sheet-3.png`
- **Final review sheet SHA-256:** `bab8e455fe7cb75f0b3c34a78e120892483e7dad34f792609057b04cd65ac691`
- **Strict-command warnings:** **0**
- **QA defects:** **0**
- **Verdict:** **`qa-pass`**

`qa-pass` means this exact package and contact sheet passed the technical release gate. It is not human approval and does not authorize publication, installation, catalog changes, staging, commit, or push.

## 1. Gate and evidence audit

QA began only after reading the project skin-author workflow, quality bar, art direction, all three critique reports, source JSON, every original SVG, and the pending human gate.

Required evidence is present:

| Evidence | Result |
|---|---|
| `skin-source.json` | Pass — editable source schema v1 |
| Four original SVG files | Pass — complete light/dark × landscape/portrait inventory |
| `build/pale-cavern-1.0.0.pocketpad` | Pass — exact candidate present |
| `reviews/art-direction.md` | Pass — canonical artboard explicitly declared as `showcase-controller-v1`, revision 2 |
| `reviews/contact-sheet-3.png` | Pass — exact expected hash, 2176 × 1714 |
| `reviews/critique-1.md` | Pass — preserved |
| `reviews/critique-2.md` | Pass — preserved |
| `reviews/critique-3.md` | Pass — latest verdict is exactly `visual-pass`; 0 blockers, 0 majors, 0 minors |
| Minimum two independent critiques | Pass — 3 versioned critiques exist |
| `reviews/human-approval.json` | Pass — still `pending`; approval fields remain null |

Evidence hashes:

| File | SHA-256 |
|---|---|
| `skin-source.json` | `856887b3478fe4735d919c3b646fd0b3d727c3414ce57c4ccaedd0e49f363064` |
| `reviews/art-direction.md` | `ed970e33d38a8f0198cd873c05d99261cff6945f865e13f1748fcf1199ca2709` |
| `reviews/critique-1.md` | `9b8125dd0c0a2e6ee5986216a50e70752b07195dceb43f64e70f77d7987ea1ca` |
| `reviews/critique-2.md` | `fa7bf73035dc862d4762c3f3b266961eb819d8ad839a0ef60080b6bde214d8ec` |
| `reviews/critique-3.md` | `b3b4ccccfc3722dca19e3725693dedc2a5c50e8b0a2901d5d6cb17d2bfdd9694` |
| `reviews/human-approval.json` | `9cc91bd3e9162b95fbf751b35ff31af7048a23955f89b4daca4aebe78cf98ae7` |

Evidence commands and outcomes:

```bash
ROOT='/Users/codybontecou/projects/ThumbConsole/docs/skins/examples/pale-cavern'
shasum -a 256 \
  "$ROOT/build/pale-cavern-1.0.0.pocketpad" \
  "$ROOT/reviews/contact-sheet-3.png" \
  "$ROOT/skin-source.json" \
  "$ROOT/sources/artwork/"*.svg
sips -g pixelWidth -g pixelHeight "$ROOT/reviews/contact-sheet-3.png"
```

Outcome: hashes matched the nominated candidate evidence; the sheet is 2176 × 1714. The final critique records and the native rerender both establish **16 panels**.

```bash
python3 -c 'import json; p="/Users/codybontecou/projects/ThumbConsole/docs/skins/examples/pale-cavern/reviews/human-approval.json"; d=json.load(open(p)); assert d["status"]=="pending" and d["approvedBy"] is None and d["approvedAt"] is None and d["reviewedContactSheet"] is None and d["packageSHA256"] is None; print("PASS")'
```

Outcome: pass. No approval record was created or changed by QA.

## 2. Source schema and SVG authoring safety

`skin-source.json` passed compilation and the structural audit with:

- schema `com.codybontecou.pocketpad.skin-source`, schema version `1`;
- identifier `com.codybontecou.pale-cavern`, version `1.0.0`;
- artboard `showcase-controller-v1`;
- both orientations: `landscape`, `portrait`;
- both appearances: `light`, `dark`;
- all 16 orientation × appearance × state preview declarations;
- all seven canonical semantic assignments: `movement`, `primary_action`, `secondary_action`, `custom`, `utility`, `menu`, and `system`;
- no binding, profile, key-code, keyboard, gamepad, command, executable, or hit-region payload keys.

Editable SVG inventory:

| Source | SHA-256 | Bytes | Artboard | XML elements | Result |
|---|---|---:|---:|---:|---|
| `sources/artwork/landscape-dark.svg` | `04dbbf558ab2e9cce31e4bed7f78d4c9d1cd67ca23089c1720fabaa280f891f1` | 5,088 | 874 × 402 | 47 | Pass |
| `sources/artwork/landscape-light.svg` | `d278fa6e9199a6ad0765848c1e49e6068dc9be407e7bd4416cb4e335d8c91c07` | 5,092 | 874 × 402 | 47 | Pass |
| `sources/artwork/portrait-dark.svg` | `708381d3fffedc0783117831c82156b8f5a688ca09809184903087d75c35aeef` | 6,340 | 402 × 874 | 55 | Pass |
| `sources/artwork/portrait-light.svg` | `ece59c519eda73311e50eeae7f35dbd5c945f0e5649a861bc182cb907e62a76a` | 6,344 | 402 × 874 | 55 | Pass |

Each is a regular, non-symlink file with a matching `viewBox`. XML parsing succeeded. The sanitization audit found no scripts, event handlers, entities/DOCTYPE, `foreignObject`, embedded executable content, external/data/file/JavaScript references, traversal, bindings, key codes, baked control labels, hit regions, or state feedback. `sourceAssets` contains exactly these four safe relative SVG paths and declares PNG output only at 2× dimensions: 1748 × 804 landscape and 804 × 1748 portrait.

Audit command:

```bash
python3 /tmp/pale-cavern-final-qa-audit.py
```

Outcome: `PASS: source/SVG/package/path/hash/raster/state/compatibility safety audit found zero defects and zero warnings`.

## 3. Canonical compatibility

Command:

```bash
CLI='/Users/codybontecou/projects/ThumbConsole/build/AgentDerivedData-hollow-skin-cli/Build/Products/Debug/thumbconsole'
NO_COLOR=1 TERM=dumb timeout 15 "$CLI" skin artboard show showcase-controller-v1 --json </dev/null
```

Outcome: the canonical contract reports:

- artboard ID `showcase-controller-v1`;
- revision `2`;
- template ID `snes`;
- landscape `874 × 402` and portrait `402 × 874` variants;
- expected roles `custom`, `menu`, `movement`, `primary_action`, `secondary_action`, `system`, `utility`;
- safe-area insets for both canonical variants.

The compiled manifest is `template_aligned`, supports both orientations, constrains template compatibility to `snes` minimum revision `2` and maximum revision `2`, and declares the required `bitmap_control_states` feature. The source artboard ID, package tag, strict quality result, compiled canvas variants, and exact native render jointly bind this package to `showcase-controller-v1` revision 2.

Compatibility result: **pass** for portrait and landscape, light and dark, and normal/pressed/active/disabled. Canonical frames and safe areas remain unchanged; strict source and package quality produced no clearance, clipping, tangency, contrast, semantic-role, or compatibility warnings.

## 4. Clean deterministic compilation

Commands:

```bash
ROOT='/Users/codybontecou/projects/ThumbConsole/docs/skins/examples/pale-cavern'
CLI='/Users/codybontecou/projects/ThumbConsole/build/AgentDerivedData-hollow-skin-cli/Build/Products/Debug/thumbconsole'
A='/tmp/pale-cavern-final-qa-20260717-a'
B='/tmp/pale-cavern-final-qa-20260717-b'
rm -rf "$A" "$B"
mkdir -p "$A" "$B"
NO_COLOR=1 TERM=dumb timeout 120 "$CLI" skin compile "$ROOT" \
  --build-directory "$A/build" \
  -o "$A/pale-cavern-1.0.0.pocketpad" --clean --json </dev/null
NO_COLOR=1 TERM=dumb timeout 120 "$CLI" skin compile "$ROOT" \
  --build-directory "$B/build" \
  -o "$B/pale-cavern-1.0.0.pocketpad" --clean --json </dev/null
shasum -a 256 \
  "$A/pale-cavern-1.0.0.pocketpad" \
  "$B/pale-cavern-1.0.0.pocketpad" \
  "$ROOT/build/pale-cavern-1.0.0.pocketpad"
cmp "$A/pale-cavern-1.0.0.pocketpad" "$B/pale-cavern-1.0.0.pocketpad"
cmp "$A/pale-cavern-1.0.0.pocketpad" "$ROOT/build/pale-cavern-1.0.0.pocketpad"
cmp "$B/pale-cavern-1.0.0.pocketpad" "$ROOT/build/pale-cavern-1.0.0.pocketpad"
```

Outcomes:

- Compile A: exit 0; JSON `issues` was empty.
- Compile B: exit 0; JSON `issues` was empty.
- A SHA-256: `10b498ca7c549847d4c32d3aea8248f7a102ab9dc307c051a86e1c536cdbdd5b`.
- B SHA-256: `10b498ca7c549847d4c32d3aea8248f7a102ab9dc307c051a86e1c536cdbdd5b`.
- Workspace package SHA-256: `10b498ca7c549847d4c32d3aea8248f7a102ab9dc307c051a86e1c536cdbdd5b`.
- All three packages are 658,390 bytes.
- `cmp` A ↔ B: pass, byte-for-byte identical.
- `cmp` A ↔ workspace: pass, byte-for-byte identical.
- `cmp` B ↔ workspace: pass, byte-for-byte identical.

Determinism result: **pass**.

## 5. Strict validation and quality

Commands:

```bash
NO_COLOR=1 TERM=dumb timeout 60 "$CLI" skin validate \
  "$ROOT/build/pale-cavern-1.0.0.pocketpad" --strict --json </dev/null

NO_COLOR=1 TERM=dumb timeout 60 "$CLI" skin quality "$ROOT" \
  --artboard showcase-controller-v1 --strict --json </dev/null

NO_COLOR=1 TERM=dumb timeout 60 "$CLI" skin quality \
  "$ROOT/build/pale-cavern-1.0.0.pocketpad" \
  --artboard showcase-controller-v1 --strict --json </dev/null
```

Outcomes:

| Check | Exit | Issues/warnings | Score | Result |
|---|---:|---:|---:|---|
| Candidate `skin validate --strict` | 0 | 0 | n/a | Pass |
| Source `skin quality --strict` against `showcase-controller-v1` | 0 | 0 | 100 | Pass |
| Package `skin quality --strict` against `showcase-controller-v1` | 0 | 0 | 100 | Pass |

There were no strict warnings. Image budgets, source/output dimensions, semantic assignments, required materials/states, contrast, safe-area alignment, and package compatibility passed the CLI's strict checks.

The compiled skin contains nine style definitions in base plus light/dark resolved libraries, for 27 audited style occurrences. Every occurrence contains `normal`, `pressed`, `active`, and `disabled`. The seven semantic role rules remain present. The latest independent `visual-pass` records minimum legend contrast of 8.49:1 normal, 7.53:1 pressed, 7.37:1 active, and 4.42:1 disabled; the QA rerender is byte-identical to that reviewed evidence.

## 6. Package inventory, path safety, raster media, and integrity

ZIP commands:

```bash
PKG="$ROOT/build/pale-cavern-1.0.0.pocketpad"
unzip -Z1 "$PKG"
unzip -t "$PKG"
```

Outcome: archive integrity passed with no compressed-data errors. Exact archive inventory:

```text
manifest.json
skin.json
assets/canvas-landscape-light.png
assets/canvas-landscape-dark.png
assets/canvas-portrait-light.png
assets/canvas-portrait-dark.png
previews/canvas-landscape-light.png
previews/canvas-landscape-dark.png
previews/canvas-portrait-light.png
previews/canvas-portrait-dark.png
```

Path and payload audit passed:

- exactly 10 entries, no duplicates;
- all paths are safe relative POSIX paths;
- no absolute paths, `..`, backslashes, symlinks, or traversal;
- only JSON and validated PNG media are shipped;
- no SVG authoring source is in the distributable archive;
- no script, executable, profile, binding, mapping, key-code, command, install, or apply payload exists;
- `skin.json` SHA-256 matches manifest declaration: `4ee224dc4dd8f5b823095ce5270759037a5b42ba43d3cab0c23a543f921b5b3e` (183,440 bytes).

Declared asset and preview integrity:

| Raster | SHA-256 | Bytes | Dimensions |
|---|---|---:|---:|
| landscape light | `d71ba224912ae955507bc1c56e95774a09936746ce8a2a754c95c3318244019a` | 82,600 | 1748 × 804 |
| landscape dark | `d65d5c0f85f41132227071048f5ed5305f847ad468765e0eb421135309794698` | 78,864 | 1748 × 804 |
| portrait light | `20a0707aedb03c32bf0f7c335d9e01591f695d9f765eb89b00af8e90bdf521bf` | 107,381 | 804 × 1748 |
| portrait dark | `e234ec0d058714f43b6fef813882f01269c9187c6e3f1b2020f6e561669b3d5a` | 101,678 | 804 × 1748 |

All actual hashes, byte counts, PNG signatures, and IHDR dimensions match the manifest. The four `previews/` files exactly duplicate the corresponding validated asset bytes, cover both orientations and both appearances, and are ready as package/website preview inputs. This QA did not copy them into the Website or public catalog.

Unpack/repack commands:

```bash
DIR='/tmp/pale-cavern-final-qa-20260717-unpacked'
REPACK='/tmp/pale-cavern-final-qa-20260717-repacked.pocketpad'
rm -rf "$DIR" "$REPACK"
NO_COLOR=1 TERM=dumb timeout 60 "$CLI" skin unpack "$PKG" -o "$DIR" </dev/null
NO_COLOR=1 TERM=dumb timeout 60 "$CLI" skin pack "$DIR" -o "$REPACK" </dev/null
shasum -a 256 "$PKG" "$REPACK"
cmp "$PKG" "$REPACK"
NO_COLOR=1 TERM=dumb timeout 60 "$CLI" skin validate "$REPACK" --strict --json </dev/null
```

Outcomes:

- unpack: pass;
- repack: pass;
- repack SHA-256: `10b498ca7c549847d4c32d3aea8248f7a102ab9dc307c051a86e1c536cdbdd5b`;
- original ↔ repack `cmp`: pass, byte-for-byte identical;
- repack strict validation: exit 0, 0 issues/warnings.

## 7. Native all-variant/all-state rerender

Command:

```bash
OUT='/tmp/pale-cavern-final-qa-20260717-contact-sheet.png'
rm -f "$OUT"
NO_COLOR=1 TERM=dumb timeout 180 "$CLI" skin preview "$PKG" \
  -o "$OUT" \
  --artboard showcase-controller-v1 \
  --all-variants --all-states \
  --native-renderer --contact-sheet --columns 4 </dev/null
shasum -a 256 "$OUT" "$ROOT/reviews/contact-sheet-3.png"
sips -g pixelWidth -g pixelHeight "$OUT" "$ROOT/reviews/contact-sheet-3.png"
cmp "$OUT" "$ROOT/reviews/contact-sheet-3.png"
```

Outcomes:

- native renderer: `Rendered 16-panel native contact sheet`;
- QA output dimensions: 2176 × 1714;
- QA output bytes: 356,880;
- QA output SHA-256: `bab8e455fe7cb75f0b3c34a78e120892483e7dad34f792609057b04cd65ac691`;
- contact-sheet-3 SHA-256: `bab8e455fe7cb75f0b3c34a78e120892483e7dad34f792609057b04cd65ac691`;
- `cmp`: pass, byte-for-byte identical.

The exact rerender covers landscape/portrait, light/dark, and normal/pressed/active/disabled. QA inspection confirms the reviewed sheet retains all native controls and legends, stable geometry, distinct states, authored light/dark appearances, readable contrast, safe-area composition, no clipping/seams/raster artifacts, and passive artwork subordinate to native interaction. Because the QA rerender is byte-identical to `contact-sheet-3.png`, the latest independent `visual-pass` applies to the exact QA output rather than a merely similar render.

## 8. Appearance-only and publication-boundary audit

The source and package are appearance-only:

- raster backgrounds plus native visual styles and semantic role assignments;
- no executable profile or control binding payload;
- no key mappings, keyboard/gamepad actions, hit testing, install command, apply command, or profile mutation data;
- no SVG in the package;
- no public catalog or Website entry for `Pale Cavern`, `pale-cavern`, or `com.codybontecou.pale-cavern`.

Search command:

```bash
grep -RniE 'Pale Cavern|pale-cavern|com\.codybontecou\.pale-cavern' \
  /Users/codybontecou/projects/ThumbConsole/Website
```

Outcome: no matches. The repository already contains unrelated Website working-tree changes and unrelated skin artifacts; this QA did not alter those files. No Pale Cavern distribution or catalog artifact was created. All QA compile, unpack, repack, and rerender products remain under `/tmp` only.

## 9. Environment

- macOS 26.5 (`25F71`), arm64.
- CLI path: `/Users/codybontecou/projects/ThumbConsole/build/AgentDerivedData-hollow-skin-cli/Build/Products/Debug/thumbconsole`.
- CLI SHA-256: `91bd0c5c8300ed90b887b92959cd59157d2cf6cf906241642e7d7f40a5d0119b`.
- CLI size: 50,844,272 bytes.
- Native renderer was available; no fallback renderer was used.
- Commands were run non-interactively with `NO_COLOR=1 TERM=dumb`, stdin closed, and hard timeouts.
- No environmental limitation reduced test coverage.

## 10. Remaining warnings and human gate

- **Strict warnings:** none.
- **Remaining QA warnings:** none.
- **Human approval:** `pending`.
- `approvedBy`, `approvedAt`, `reviewedContactSheet`, and `packageSHA256` remain null in `reviews/human-approval.json`.
- QA did not modify the human approval record.

## Final verdict

**`qa-pass`**

Every required strict check completed without warning. Two clean builds are byte-identical to each other and to the nominated workspace package. Unpack/repack is byte-identical. All declared hashes and raster dimensions match. The native 16-panel rerender is byte-identical to the final independently visual-passed contact sheet. Compatibility, state coverage, safe areas, contrast, semantics, package safety, and preview readiness pass.

Publication remains blocked on explicit human approval of this exact pair:

- package SHA-256 `10b498ca7c549847d4c32d3aea8248f7a102ab9dc307c051a86e1c536cdbdd5b`;
- contact-sheet SHA-256 `bab8e455fe7cb75f0b3c34a78e120892483e7dad34f792609057b04cd65ac691`.
