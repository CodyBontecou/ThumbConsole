# Foldline Relay — Final Independent QA Report v2

- **Skin:** Foldline Relay `1.0.0`
- **Identifier:** `com.codybontecou.pocketpad.foldline-relay`
- **Workspace:** `docs/skins/examples/foldline-relay`
- **Canonical artboard:** `productivity-one-handed-left-v1`, revision `1`
- **Reviewed visual evidence:** `reviews/contact-sheet-4.png`
- **Visual-evidence SHA-256:** `98ed63a2c398adb10afa41843ddf750c9f2023f3a1df761dee8cdd99bb190a77`
- **Latest critique:** `reviews/critique-4.md`
- **Latest critic verdict confirmed:** `visual-pass`
- **QA date:** 2026-07-17
- **Verdict:** `qa-pass`

All QA operations, including three native contact-sheet renders, were run sequentially. Both isolated strict compilations were byte-identical. All three fresh 16-panel native contact sheets were byte-identical to one another and to `reviews/contact-sheet-4.png` at the required SHA-256. Both strict validators returned no issues or warnings. Package integrity, compatibility, safety, image, budget, material, state, contrast, and website-preview checks passed.

This QA pass does not authorize approval or publication. `reviews/human-approval.json` remains pending. No source, approval, catalog, publication, deployment, staging, commit, or push action was performed.

## Tool under test

```text
CLI: /Users/codybontecou/Library/Developer/Xcode/DerivedData/ThumbConsole-bqyuqmkqyppmxqddlzshosycivju/Build/Products/Debug/thumbconsole
CLI SHA-256: 2370bb12d5df75e3f8888a9f1b84434acba052a8d5d5540a1f9cb5f16c585952
CLI size: 50,846,272 bytes
CLI modified: 2026-07-17T15:01:20-0400
```

Common variables used below:

```bash
ROOT='/Users/codybontecou/projects/ThumbConsole/docs/skins/examples/foldline-relay'
CLI='/Users/codybontecou/Library/Developer/Xcode/DerivedData/ThumbConsole-bqyuqmkqyppmxqddlzshosycivju/Build/Products/Debug/thumbconsole'
```

## Results summary

| Gate | Result | Evidence |
|---|---|---|
| Art direction and all four critiques | PASS | All reports read; latest `critique-4.md` verdict is `visual-pass`. |
| Isolated strict compile A | PASS | Exit 0; no warnings. |
| Isolated strict compile B | PASS | Exit 0; no warnings. |
| Compile byte determinism | PASS | A and B `cmp` exit 0; both SHA-256 `d04c…deaf`. |
| Expected package output | PASS | Existing `build/foldline-relay-1.0.0.pocketpad` is byte-identical to both isolated outputs. |
| Package strict validation | PASS | Exit 0; JSON `issues: []`. |
| Source strict quality | PASS | Exit 0; score 100; JSON `issues: []`; checked intended artboard. |
| Sequential native regeneration | PASS | Three fresh 16-panel sheets, each exact SHA-256 `98ed…a77`. |
| Exact current-sheet comparison | PASS | All three fresh outputs are byte-identical to `contact-sheet-4.png`. |
| Unpack/repack integrity | PASS | Both commands exit 0; repacked archive is byte-identical. |
| Declared hashes and byte counts | PASS | `skin.json`, four assets, and four previews match all declarations. |
| Portrait/landscape compatibility | PASS | Both canonical variants pass revision, aspect, roles, and safe areas. |
| Appearance-only safety | PASS | Skin only; no bindings/profile/executable payload; no SVG in archive. |
| Dimensions and budgets | PASS | Raster dimensions match declarations; all package/publication limits pass. |
| States/materials/contrast | PASS | Six roles have explicit light/dark state materials; measured minima pass. |
| Native state evidence | PASS | All 16 orientation/appearance/state combinations rendered natively. |
| Website preview readiness | PASS | Four PNG previews cover portrait/landscape and light/dark at 2× canonical size. |
| Human approval gate | PASS (pending) | Approval remains pending and unapproved. |

## 1. Deterministic isolated double compile

Commands were run one after the other, never concurrently:

```bash
rm -rf /tmp/foldline-relay-final-qa-a
mkdir -p /tmp/foldline-relay-final-qa-a
NO_COLOR=1 TERM=dumb timeout 120 "$CLI" skin compile "$ROOT" \
  --build-directory /tmp/foldline-relay-final-qa-a/build \
  -o /tmp/foldline-relay-final-qa-a/foldline-relay-1.0.0.pocketpad \
  --clean --strict </dev/null

rm -rf /tmp/foldline-relay-final-qa-b
mkdir -p /tmp/foldline-relay-final-qa-b
NO_COLOR=1 TERM=dumb timeout 120 "$CLI" skin compile "$ROOT" \
  --build-directory /tmp/foldline-relay-final-qa-b/build \
  -o /tmp/foldline-relay-final-qa-b/foldline-relay-1.0.0.pocketpad \
  --clean --strict </dev/null

cmp -s \
  /tmp/foldline-relay-final-qa-a/foldline-relay-1.0.0.pocketpad \
  /tmp/foldline-relay-final-qa-b/foldline-relay-1.0.0.pocketpad
cmp -s \
  /tmp/foldline-relay-final-qa-a/foldline-relay-1.0.0.pocketpad \
  "$ROOT/build/foldline-relay-1.0.0.pocketpad"
shasum -a 256 \
  /tmp/foldline-relay-final-qa-a/foldline-relay-1.0.0.pocketpad \
  /tmp/foldline-relay-final-qa-b/foldline-relay-1.0.0.pocketpad \
  "$ROOT/build/foldline-relay-1.0.0.pocketpad"
```

Outcomes:

- Both strict compile commands: exit `0`, no warnings.
- A versus B `cmp`: exit `0`.
- A versus expected package `cmp`: exit `0`.
- All three package SHA-256 values:

```text
d04c121e9b0a4ac9a7f99ff61e13b9e6eb0798373b290b672c49bff877c7deaf
```

- Package size: `254,583` bytes.
- Source SHA-256: `e198d331ae85458c3f0cae15b2829c3427df79e6a95b6673552a0760640ddff2`.

## 2. Strict validation and strict canonical quality

Commands:

```bash
NO_COLOR=1 TERM=dumb timeout 60 "$CLI" skin validate \
  /tmp/foldline-relay-final-qa-a/foldline-relay-1.0.0.pocketpad \
  --strict --json </dev/null

NO_COLOR=1 TERM=dumb timeout 120 "$CLI" skin quality "$ROOT" \
  --artboard productivity-one-handed-left-v1 \
  --strict --json </dev/null
```

Outcomes:

```json
{ "issues": [] }
```

```json
{
  "checkedArtboardID": "productivity-one-handed-left-v1",
  "issues": [],
  "score": 100
}
```

Both commands exited `0`. There were zero strict warnings. Under this QA contract, any warning from either strict command would have failed the gate.

## 3. Exact sequential native contact-sheet regeneration

The following command was run three separate times, sequentially, with output suffixes `1`, `2`, and `3`:

```bash
NO_COLOR=1 TERM=dumb timeout 180 "$CLI" skin preview "$ROOT" \
  -o /tmp/foldline-relay-contact-sheet-final-qa-N.png \
  --artboard productivity-one-handed-left-v1 \
  --all-variants --all-states --native-renderer \
  --contact-sheet --columns 4 </dev/null
```

Comparisons:

```bash
cmp -s "$ROOT/reviews/contact-sheet-4.png" \
  /tmp/foldline-relay-contact-sheet-final-qa-1.png
cmp -s "$ROOT/reviews/contact-sheet-4.png" \
  /tmp/foldline-relay-contact-sheet-final-qa-2.png
cmp -s "$ROOT/reviews/contact-sheet-4.png" \
  /tmp/foldline-relay-contact-sheet-final-qa-3.png
cmp -s /tmp/foldline-relay-contact-sheet-final-qa-1.png \
  /tmp/foldline-relay-contact-sheet-final-qa-2.png
cmp -s /tmp/foldline-relay-contact-sheet-final-qa-2.png \
  /tmp/foldline-relay-contact-sheet-final-qa-3.png
shasum -a 256 "$ROOT/reviews/contact-sheet-4.png" \
  /tmp/foldline-relay-contact-sheet-final-qa-{1,2,3}.png
```

Outcomes:

- All three preview commands: exit `0`, no warnings.
- Each command reported a `16-panel native contact sheet`.
- Every `cmp`: exit `0`.
- All four files are `2176 × 1714`, 8-bit RGB PNGs.
- Expected and actual SHA-256 for every file:

```text
98ed63a2c398adb10afa41843ddf750c9f2023f3a1df761dee8cdd99bb190a77
```

The exact current visual-pass evidence regenerated successfully. The earlier concurrent-render variance did not reproduce under the required sequential execution.

## 4. Unpack/repack and archive integrity

Commands:

```bash
rm -rf /tmp/foldline-relay-final-qa-unpacked
rm -f /tmp/foldline-relay-final-qa-repacked.pocketpad
NO_COLOR=1 TERM=dumb timeout 60 "$CLI" skin unpack \
  /tmp/foldline-relay-final-qa-a/foldline-relay-1.0.0.pocketpad \
  -o /tmp/foldline-relay-final-qa-unpacked --force </dev/null
NO_COLOR=1 TERM=dumb timeout 60 "$CLI" skin pack \
  /tmp/foldline-relay-final-qa-unpacked \
  -o /tmp/foldline-relay-final-qa-repacked.pocketpad </dev/null
cmp -s \
  /tmp/foldline-relay-final-qa-a/foldline-relay-1.0.0.pocketpad \
  /tmp/foldline-relay-final-qa-repacked.pocketpad
shasum -a 256 \
  /tmp/foldline-relay-final-qa-a/foldline-relay-1.0.0.pocketpad \
  /tmp/foldline-relay-final-qa-repacked.pocketpad
unzip -t /tmp/foldline-relay-final-qa-a/foldline-relay-1.0.0.pocketpad
```

Outcomes:

- Unpack exit `0`; repack exit `0`; no warnings.
- Original versus repacked `cmp`: exit `0`.
- Both archive hashes: `d04c121e9b0a4ac9a7f99ff61e13b9e6eb0798373b290b672c49bff877c7deaf`.
- ZIP test: all 10 entries `OK`; no compressed-data error.
- Archive timestamps: deterministic `1980-01-01 00:00`.
- `manifest.json` SHA-256: `f6c399e92b0cfdfa41ac71b79483a802d0038e88551fcd1c78e47af4805272ba`.
- `skin.json` declared and actual SHA-256: `c0807f65adf11e05dad662e0ad70d93f19e8d093d08d4ffe30f4bda023b94be6`.

### Declared resource integrity

| Resource | Dimensions | Bytes | Declared/actual SHA-256 |
|---|---:|---:|---|
| `assets/canvas-landscape-light.png` | 1748 × 804 | 55,571 | `9da5061b4db1cf521b63076c3e56246e15b014e618a9bfefec6641da24ff2d0b` |
| `assets/canvas-landscape-dark.png` | 1748 × 804 | 58,861 | `86dce97c31d0d88c1236280e2bc5d699be07dd8f127729f0bf549acce5b99bdb` |
| `assets/canvas-portrait-light.png` | 804 × 1748 | 49,917 | `5a1c8793e585547b6618eac093670f80a701dcd7d9610decce0b5ea98bb5f235` |
| `assets/canvas-portrait-dark.png` | 804 × 1748 | 48,441 | `c9ab0d888954024a496d2b28ef18adb0659dc828c87a017b90f0351d1b705421` |

The corresponding four `previews/` files have identical dimensions, byte counts, and hashes. Every manifest declaration matched the actual file.

## 5. Compatibility, safe areas, image budgets, and website readiness

Canonical command:

```bash
NO_COLOR=1 TERM=dumb timeout 30 "$CLI" skin artboard show \
  productivity-one-handed-left-v1 --json </dev/null \
  > /tmp/foldline-relay-artboard.json
```

Structured audit command, after staging the current isolated package and unpacked output at the audit script's fixed temporary paths:

```bash
rm -rf /tmp/foldline-relay-qa-a /tmp/foldline-relay-unpacked
mkdir -p /tmp/foldline-relay-qa-a
cp /tmp/foldline-relay-final-qa-a/foldline-relay-1.0.0.pocketpad \
  /tmp/foldline-relay-qa-a/foldline-relay-1.0.0.pocketpad
cp -R /tmp/foldline-relay-final-qa-unpacked /tmp/foldline-relay-unpacked
python3 /tmp/foldline_relay_qa_audit.py
```

Result: `AUDIT_RESULT=PASS failures=0`.

Compatibility findings:

- Manifest compatibility mode: `template_aligned`.
- Template: `productivityonehandedleft`, revision range `1...1`.
- Canonical artboard: `productivity-one-handed-left-v1`, template `productivityOneHandedLeft`, revision `1`.
- Landscape aspect `2.174129` and portrait aspect `0.459954` are within the declared `0.4...2.5` range.
- Both portrait and landscape are declared.
- Canonical profiles contain all required semantic roles.
- Every non-system control center is within its orientation's canonical safe area.
- Strict quality independently reported no compatibility, alignment, role, or safe-area issue.

Budget findings:

| Budget | Actual | Limit | Result |
|---|---:|---:|---|
| Assets | 212,790 bytes | 12 MiB warning / 24 MiB error | PASS |
| Previews | 212,790 bytes | 8 MiB | PASS |
| Encoded archive | 254,583 bytes | 30 MiB publication / 40 MiB codec | PASS |
| Total uncompressed | 612,317 bytes | 50 MiB | PASS |
| Entries | 10 | 256 | PASS |
| Largest entry | 183,152 bytes | 10 MiB | PASS |

All four package previews are readable PNGs at 2× canonical dimensions and cover portrait/landscape plus light/dark. They are ready as website preview inputs; this check did not publish or copy them into a public catalog.

## 6. Appearance-only safety and SVG exclusion

Archive enumeration, ZIP metadata inspection, and recursive JSON-key inspection found:

- `manifest.kind` is `skin`.
- No `profilePath`, `profileSHA256`, `profile.json`, or `bindings.json` exists.
- No binding, keyboard, gamepad, mapped-button, output, keycode, sequence, haptic, or executable payload exists in the skin package.
- No symlink, absolute path, traversal path, executable, script, or unlisted file exists.
- The archive contains only `manifest.json`, `skin.json`, four PNG assets, and four PNG previews.
- No `.svg` is present in the distributable `.pocketpad` archive.
- Editable SVG remains only under `sources/artwork/`.

Editable SVG SHA-256 values:

```text
0c8da3873b62e7e0c1cc746fdb32fe557404dff9fe9b423abc3af5bbf2887be5  landscape-dark.svg
ea96346bb8360984be9363cbc217a9b92d0ba1b9f8ea190a2798548445a34edf  landscape-light.svg
0c8ab63727c23a056d3d8750d7575d9c95407098558177180cbf901051d87dd9  portrait-dark.svg
cce9ce0a796f91a0ab40644f12b1541b08a612c7265717920c3547d6d10791a7  portrait-light.svg
```

## 7. Semantic roles, state materials, contrast, and safe-area evidence

All six assigned semantic roles—movement, primary action, secondary action, utility, menu, and system—have explicit light/dark pressed, active, and disabled values in source and compiled normal/pressed/active/disabled styles.

Measured assigned-role minima:

| Check | Minimum measured | Required | Result |
|---|---:|---:|---|
| Normal legend contrast | 5.28:1 | 4.5:1 | PASS |
| Disabled legend contrast | 3.85:1 | 3:1 | PASS |
| Active-index contrast | 4.14:1 | 3:1 | PASS |

Additional state findings:

- Pressed scale is `0.965` for every semantic material.
- Pressed fills and reduced/removed shadows are explicit.
- Active fills equal corresponding normal role fills in light and dark.
- Active enclosing stroke width is `0` for every role.
- Active index thickness is `2.5` px.
- Native active-index geometry is capped at `18.00` px in portrait and landscape, so it remains short and non-enclosing.
- Disabled states use explicit fills, foregrounds, neutral strokes, stroke width `1.2`, full opacity, and flattened shadows; disabled is not opacity-only.
- Strict quality reported no missing or indistinguishable state issue.
- The exact regenerated native sheet and `critique-4.md` confirm all four states in both appearances and orientations, label legibility, short active indices, dark pressed-system contour, contrast, safe-area use, and landscape lower clearance.

## 8. Human gate

`reviews/human-approval.json` exists and remains pending:

```text
status: pending
approvedBy: null
approvedAt: null
reviewedContactSheet: null
packageSHA256: null
```

No approval was created, changed, or inferred. Human approval remains a separate gate tied to explicit review of the exact contact sheet and package hash.

## Remaining warnings

- **Strict package-validator warnings:** none.
- **Strict quality warnings:** none.
- **Compile warnings:** none.
- **Native preview warnings:** none.
- **Integrity, compatibility, safety, budget, state, contrast, or website-preview warnings:** none.
- **QA blockers:** none.

## Final verdict

**`qa-pass`** — the package compiles deterministically, passes both strict gates without warnings, unpacks and repacks byte-identically, satisfies declared hashes and safety boundaries, supports the intended revision-1 portrait and landscape canonical profiles, and regenerates the exact current 16-panel native visual evidence three times sequentially at SHA-256 `98ed63a2c398adb10afa41843ddf750c9f2023f3a1df761dee8cdd99bb190a77`.

This verdict is QA only. It is not human approval and does not authorize publication.
