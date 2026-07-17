# AGENTS.md

## macOS app and CLI parity

Any functionality added to or changed in the macOS app must also be reflected in the CLI. The `thumbconsole` CLI should be able to do everything the macOS app can do, so changes under `Sources/Mac` should be reviewed for corresponding updates under `Sources/CLI`.

## Handcrafted skin authoring

When creating, redesigning, critiquing, or preparing a community PocketPad skin, load and follow the project `pocketpad-skin-author` skill. Use the separate art-director, designer, visual-critic, and QA agents in sequence. Preserve editable SVG source and native-renderer review evidence. Never publish a skin or mark human approval without the user's explicit approval of the exact contact sheet and package hash.
