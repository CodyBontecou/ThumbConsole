# Pale Cavern

Editable handcrafted PocketPad skin workspace targeting canonical artboard `showcase-controller-v1`, template `snes`, revision 2.

Pale Cavern is an original quiet mineral ecology: offset moonstone laminae, recessed semantic control wells, one restrained cold-spring cyan seam, and a sparse silt constellation. Landscape is a low overlapping two-lamina composition. Portrait is separately composed as upper and lower chambers joined by a narrow mineral bridge. Light and dark use separately authored limestone and subterranean material logic.

The SVG artwork is passive appearance only. Thumble retains native control geometry, hit testing, labels, bindings, interaction states, haptics, and accessibility. This workspace contains no executable mappings and must not alter installed profiles or user defaults.

## Source hierarchy

- `skin-source.json` — identity, palette/material/component tokens, semantic assignments, and all 16 preview requests.
- `sources/artwork/landscape-*.svg` — editable low offset-lamina compositions.
- `sources/artwork/portrait-*.svg` — editable descending two-chamber compositions.
- `reviews/` — approved art direction, versioned native contact sheets, independent critiques, QA evidence, and the human approval gate.
- `build/` — generated working package output; never edit by hand.

```bash
thumble skin compile . -o build/pale-cavern-1.0.0.pocketpad --clean --strict
thumble skin validate build/pale-cavern-1.0.0.pocketpad --strict
thumble skin quality . --artboard showcase-controller-v1 --strict
thumble skin preview . -o reviews/contact-sheet-1.png \
  --all-variants --all-states --native-renderer --contact-sheet --columns 4
```

Human approval is pending. This first design pass is not approved, installed, published, or cleared for catalog use.
