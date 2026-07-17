# Handcrafted skin workflow

## 1. Choose the contract

Inspect canonical artboards before drawing:

```bash
thumbconsole skin artboard list
thumbconsole skin artboard show showcase-controller-v1 --json
thumbconsole skin artboard export showcase-controller-v1 -o /tmp/showcase-profile.json
```

An artboard is a geometry contract: canvas dimensions, safe areas, semantic control roles, and normalized frames. A template-aligned skin may still apply semantic materials to another layout, but aligned canvas artwork is hidden when compatibility is degraded or incompatible.

## 2. Scaffold editable source

```bash
thumbconsole skin scaffold "Name" \
  --identifier com.creator.name \
  --artboard showcase-controller-v1 \
  -o Website/skins/sources/name
```

Expected source tree:

```text
skin-source.json
sources/artwork/*.svg
sources/icons/*.svg
reviews/README.md
reviews/human-approval.json
build/                       # generated, ignored
```

SVG is authoring input only. The sanitizer rejects scripts, external URLs, entities, event handlers, pathological complexity, traversal, and symlinks. Compilation rasterizes visual media to package-safe PNG.

## 3. Direct before designing

The art director inspects portrait and landscape separately and writes:

- concept and originality boundary;
- silhouette/focal hierarchy;
- light/dark palette and contrast targets;
- material/edge/lighting/texture rules;
- native state behavior;
- measurable acceptance criteria.

Do not accept a brief that is only a list of adjectives.

## 4. Execute as components

Use named palette, material, component, and semantic assignment tokens. Prefer a small coherent system over many unrelated effects.

A complete composition normally includes:

- canvas ground;
- controller shell with consistent edge logic;
- movement and action wells aligned to artboard roles;
- distinct action, movement, shoulder, and utility materials;
- deliberate legends and icon treatment;
- one lighting direction;
- restrained texture at the correct physical scale;
- orientation-aware spacing and negative space.

Artwork remains passive. Native controls render state and preserve accessibility. When derived states are not visually distinct enough, use the source schema's optional pressed/active/disabled fills, boundaries, shadow scales, and light/dark joystick puck colors; never paint state feedback into SVG.

## 5. Compile and inspect

```bash
thumbconsole skin compile SOURCE -o SOURCE/build/name.pocketpad --clean
thumbconsole skin validate SOURCE/build/name.pocketpad --strict
thumbconsole skin quality SOURCE --strict
thumbconsole skin preview SOURCE \
  -o SOURCE/reviews/contact-sheet-1.png \
  --all-variants --all-states --native-renderer --contact-sheet
```

The package compiler is deterministic. Native review snapshots use the real SwiftUI renderer and are review evidence, not inputs to package hashing.

## 6. Critique loop

Run the critic on the exact rendered file. The parent reads the report and turns accepted findings into a bounded designer task with paths and measurable outcomes. Preserve evidence:

```text
reviews/contact-sheet-1.png
reviews/critique-1.md
reviews/contact-sheet-2.png
reviews/critique-2.md
...
```

Minimum: two critique passes. Continue until the latest verdict is `visual-pass`; do not average away a blocker.

## 7. Strict QA

QA recompiles twice to separate directories and compares package hashes, then validates, quality-checks, unpacks, and rerenders. Any strict warning fails QA.

Recommended determinism check:

```bash
thumbconsole skin compile SOURCE --build-directory /tmp/skin-a -o /tmp/a.pocketpad --clean
thumbconsole skin compile SOURCE --build-directory /tmp/skin-b -o /tmp/b.pocketpad --clean
cmp /tmp/a.pocketpad /tmp/b.pocketpad
shasum -a 256 /tmp/a.pocketpad
```

## 8. Human approval

The human reviews the final contact sheet and package hash. Agents must leave the approval record pending until the user explicitly approves that exact evidence. Human approval is separate from QA and separate from publication.

After approval, an ordinary repository workflow may update the static directory, but this skill itself never does so.