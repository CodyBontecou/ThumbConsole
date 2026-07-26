# Foldline Relay

Editable handcrafted PocketPad skin workspace targeting `productivity-one-handed-left-v1`, template `productivityOneHandedLeft` revision 1.

Foldline Relay treats the canvas as an editorial dispatch sheet. Its asymmetric Thumb Folio supports the canonical lower-left native controls while one lightweight Relay Fold and open registration brackets organize the negative field. Landscape is a low packet; portrait is a separately composed tall docket. The SVGs are passive artwork only—Thumble retains control geometry, labels, hit testing, state, bindings, haptics, and accessibility.

## Sources

- `skin-source.json` — identity, palette/material/component tokens, role assignments, and all 16 preview requests.
- `sources/artwork/landscape-*.svg` — light/dark low dispatch packet compositions.
- `sources/artwork/portrait-*.svg` — light/dark tall docket compositions.
- `reviews/` — art direction, versioned native contact sheets, QA, and human approval.
- `build/` — generated working output; do not edit by hand.
- `dist/foldline-relay-1.0.0.pocketpad` — exact human-approved package.

```bash
thumble skin compile . -o build/foldline-relay-1.0.0.pocketpad --clean --strict
thumble skin validate build/foldline-relay-1.0.0.pocketpad --strict
thumble skin quality . --artboard productivity-one-handed-left-v1 --strict
thumble skin preview . -o reviews/contact-sheet-4.png \
  --all-variants --all-states --native-renderer --contact-sheet --columns 4
```

Final independent evidence is `reviews/contact-sheet-4.png`; `reviews/critique-4.md` is `visual-pass` and `reviews/qa-report.md` is `qa-pass`. Package SHA-256: `d04c121e9b0a4ac9a7f99ff61e13b9e6eb0798373b290b672c49bff877c7deaf`.

Cody Bontecou approved the exact contact sheet and package SHA-256 in `reviews/human-approval.json` on 2026-07-17; the package is published through the reviewed website directory.
