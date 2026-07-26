# Solar Sumi

Handcrafted PocketPad skin source workspace for `arcade-stick-v1` revision 1.

Solar Sumi combines an asymmetric Offset Fiber Deck, one absorbed Carbon Current, and sparse gold Solar Register marks. Landscape carries the eye left-to-right from the joystick island into the action field; portrait is separately composed to rise from the lower joystick pool through a single fork into two action ranks. Light and dark artwork are authored independently. Artwork remains passive: Thumble owns control frames, labels, hit testing, bindings, state rendering, and accessibility.

## Source hierarchy

- `skin-source.json` — identity, canonical compatibility, palette/material/component tokens, semantic assignments, and all 16 preview requests.
- `sources/artwork/landscape-{light,dark}.svg` — horizontal deck, Carbon Current, native-control gutters, and horizontal Solar Register.
- `sources/artwork/portrait-{light,dark}.svg` — vertical deck recomposition, lower carbon pool, one fork, and vertical Solar Register.
- `reviews/` — approved art direction, versioned native-renderer evidence, QA, and human approval.
- `build/solar-sumi-1.0.0.pocketpad` — generated working package; never edit by hand.
- `dist/solar-sumi-1.0.0.pocketpad` — exact QA-passed package awaiting human approval.

```bash
thumble skin compile . -o build/solar-sumi-1.0.0.pocketpad --clean --strict
thumble skin validate build/solar-sumi-1.0.0.pocketpad --strict
thumble skin quality . --artboard arcade-stick-v1 --strict
thumble skin preview . -o reviews/contact-sheet-4.png \
  --all-variants --all-states --native-renderer --contact-sheet --columns 4
```

Final independent evidence is `reviews/contact-sheet-4.png`; `reviews/critique-4.md` is `visual-pass` and `reviews/qa-report.md` is `qa-pass`. Package SHA-256: `edbecde5b7085aff6c99d3ce671f61daba1a3db1b04bc3f0ef83b72301501947`.

Cody Bontecou approved the exact contact sheet and package hash in `reviews/human-approval.json` on 2026-07-17; the package is published through the reviewed website directory.
