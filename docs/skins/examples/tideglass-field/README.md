# Tideglass Field

Handcrafted Thumble skin workspace for `game-boy-v1` revision 1.

The four orientation/appearance SVGs build an original hydrographic plate from connected frosted tideglass shelves, hard-edged abyss wells, contour etching, coral datum notches, and three or fewer brass soundings. Landscape is a lateral transect; portrait is a separately drawn vertical sounding. Artwork remains passive while native controls own geometry, labels, bindings, accessibility, and normal/pressed/active/disabled rendering.

## Build and review

```bash
thumble skin compile . -o build/tideglass-field-1.0.0.pocketpad --clean --strict
thumble skin validate build/tideglass-field-1.0.0.pocketpad --strict
thumble skin quality . --artboard game-boy-v1 --strict
thumble skin preview . -o reviews/contact-sheet-5.png --all-variants --all-states --native-renderer --contact-sheet --columns 4
```

Final independent evidence is `reviews/contact-sheet-5.png`; `reviews/critique-5.md` is `visual-pass` and `reviews/qa-report.md` is `qa-pass`. Package SHA-256: `77927e956d14bd5cf6710c7dc2810da91ce577f290e7f5311d3b389f3e5e24ed`.

Editable sources are `skin-source.json` and `sources/artwork/*.svg`. Generated working output stays under `build/`; the exact approved package is `dist/tideglass-field-1.0.0.pocketpad`; review evidence stays under `reviews/`. Cody Bontecou approved the exact contact sheet and package hash in `reviews/human-approval.json` on 2026-07-17, and the package is published through the reviewed website directory.
