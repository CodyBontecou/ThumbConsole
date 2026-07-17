# Submit a skin to the ThumbConsole directory

The public directory is a reviewed static registry. It accepts appearance-only `.pocketpad` skin packages; it does not accept full keypad profiles, keyboard shortcuts, pointer actions, controller bindings, launch targets, scripts, or executable files.

## Before submitting

1. Choose a canonical artboard and create editable source with `thumbconsole skin scaffold`; keep original SVG under `sources/`.
2. Use a stable reverse-DNS identifier that you control and a semantic version such as `1.0.0`.
3. Include your creator name, a specific art-direction summary, a license, useful tags, and portrait/landscape light/dark previews.
4. Reference controls by semantic visual role instead of a profile UUID or label. Declare template revision compatibility when canvas artwork is layout-aligned.
5. Declare every runtime asset with its byte count, media type, and SHA-256. SVG stays in authoring source and is rasterized before packaging.
6. Author meaningful normal, pressed, active, and disabled states and verify them through the native renderer.
7. Confirm you have the right to distribute every visual asset. Do not submit copied console graphics, logos, trade dress, scripts, or executables.

```bash
thumbconsole skin compile ./my-skin -o ./my-skin/build/MySkin.pocketpad --clean --strict
thumbconsole skin validate ./my-skin/build/MySkin.pocketpad --strict
thumbconsole skin quality ./my-skin --strict
thumbconsole skin preview ./my-skin -o ./my-skin/reviews/contact-sheet.png \
  --all-variants --all-states --native-renderer --contact-sheet
```

## Submit

Open a [skin submission issue](https://github.com/CodyBontecou/PocketPad/issues/new?title=Skin%20submission%3A%20) with:

- the `.pocketpad` package or a stable download URL;
- a clean native-renderer preview and, for aligned/stateful skins, the all-variant/all-state contact sheet;
- the skin identifier, version, and canonical compatibility declaration;
- creator and license information;
- a one-paragraph description and suggested tags.

A maintainer will inspect and validate the package, review originality and the rendered state matrix, and request explicit human publication approval for the exact package hash. Only then may they add editorial catalog metadata, regenerate the directory, and verify the website. Automated agents may prepare evidence but cannot approve or publish a skin. Updating an existing skin requires the same identifier, a higher semantic version, and fresh approval.

## Maintainer workflow

After human approval is recorded for the final contact sheet and package SHA-256, add an entry to `Website/skins/catalog.source.json`. A source-backed skin belongs under `Website/skins/sources/<slug>`; first-party skins bundled by the app can use a `bundled` origin. Human-approved deterministic packages may use an `approved-package` origin and must pass the build script’s approval/hash check. Then run:

```bash
scripts/build-skin-directory.sh /path/to/thumbconsole
python3 scripts/verify-skin-directory.py
```

Generated packages and previews are versioned and tracked so Cloudflare Pages can serve them as immutable static files. Never hand-edit `Website/skins/catalog.json`.
