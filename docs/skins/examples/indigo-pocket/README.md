# Indigo Pocket

Reference-quality ThumbConsole skin workspace targeting `showcase-controller-v1` / SNES template revision 2.

Indigo Pocket is an original compact calibration instrument: a softened-octagonal indigo field case with orientation-specific movement and action harbors, a single violet calibration seam, warm ivory native legends, and upper-left lighting. The SVG artwork remains passive; ThumbConsole owns control geometry, labels, hit testing, state, bindings, and accessibility.

## Source hierarchy

- `skin-source.json` — identity, canonical contract, palette/material tokens, semantic assignments, and the 16-panel preview matrix.
- `sources/artwork/landscape-*.svg` — low field-case shell, shoulder rail, semantic harbors, utility bridge, seam, and restrained shell texture.
- `sources/artwork/portrait-*.svg` — recomposed tall shell, action and movement decks, structural shoulder spine, right waist bay, and short cross-axis seam.
- `reviews/` — art direction, three native contact-sheet passes, independent critique, QA evidence, and the human approval gate.
- `dist/indigo-pocket-1.0.0.pocketpad` — deterministic QA-passed reference package (SHA-256 `72fdbb32d789cd3c13d32b79cc83d9a373eb9b7d4d663d9e1cab1c80ba3bb3d3`).
- `build/` — generated package output; never edit by hand.

```bash
thumbconsole skin compile . -o build/indigo-pocket-1.0.0.pocketpad --clean --strict
thumbconsole skin validate build/indigo-pocket-1.0.0.pocketpad --strict
thumbconsole skin quality . --artboard showcase-controller-v1 --strict
thumbconsole skin preview . -o reviews/contact-sheet.png \
  --all-variants --all-states --native-renderer --contact-sheet
```

The final visual critique is `visual-pass`, independent QA is `qa-pass`, and Cody Bontecou approved the exact final contact sheet and package hash on 2026-07-17. Indigo Pocket is cleared for the reviewed public skin directory.
