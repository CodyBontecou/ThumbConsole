---
name: pocketpad-keypad-generator
description: Generate and install PocketPad keypad profiles from a game name using the PocketPad CLI. Use this whenever a user asks for a PocketPad keypad, game controller layout, iPhone keypad, game profile, keyboard-to-touch controls, or agent-driven controls for a game. For known games, use built-in CLI templates. For unknown games, the agent should research or infer controls, create an agent-provided JSON spec, and install it; do not ask the user for controls unless they explicitly want a custom layout.
---

# PocketPad Keypad Generator

Use this skill to create a playable PocketPad profile for a game with minimal user input. The ideal user experience is: they name a game, the agent figures out reasonable controls, and PocketPad Mac receives a selected keypad profile that syncs to the iPhone.

## Core workflow

1. Build or locate the `pocketpad` CLI.
2. Try the built-in generator for the game name.
3. If no built-in template exists, research or infer the default keyboard controls.
4. Write an agent-provided keypad JSON spec.
5. Dry-run the spec to catch invalid keys or malformed JSON.
6. Install the profile.
7. Summarize the resulting bindings and confidence to the user.

The CLI intentionally avoids deterministic generic fallbacks for unknown games. The agent is the fallback because it can use context, local files, web knowledge, and judgment.

## Build or locate the CLI

From the PocketPad repo root:

```bash
xcodebuild -project PocketPad.xcodeproj \
  -scheme PocketPadCLI \
  -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData \
  build

POCKETPAD_CLI="$PWD/build/DerivedData/Build/Products/Debug/pocketpad"
```

If `build/DerivedData/Build/Products/Debug/pocketpad` already exists and is recent enough, reuse it.

## Try built-in templates first

```bash
"$POCKETPAD_CLI" generate "Hollow Knight" --dry-run
"$POCKETPAD_CLI" generate "Hollow Knight"
```

Built-in templates can handle aliases, for example speech-recognition variants like “Hollow Night”. The non-dry-run command installs, selects, and marks the profile as default. If PocketPad Mac is running, it reloads and pushes the selected keypad to the paired iPhone.

If the CLI says there is no built-in template, continue with an agent-provided spec.

## Create an agent-provided spec for unknown games

Research controls in this order when practical:

1. Local game config files or launcher settings.
2. Official docs, in-game manuals, or support pages.
3. Reputable community wiki/default-controls pages.
4. Common genre conventions plus the agent's best guess.

If uncertain, still create a playable spec, set `confidence` to `low`, and mention the caveat in `notes`.

Write JSON like this:

```json
{
  "gameName": "Celeste",
  "source": "Agent best guess from common/default keyboard controls",
  "confidence": "low",
  "notes": [
    "Generated from the agent's best guess. Adjust in PocketPad Mac if your in-game bindings differ."
  ],
  "controls": [
    { "label": "Left", "key": "LeftArrow", "role": "movement" },
    { "label": "Right", "key": "RightArrow", "role": "movement" },
    { "label": "Up", "key": "UpArrow", "role": "movement" },
    { "label": "Down", "key": "DownArrow", "role": "movement" },
    { "label": "Jump", "key": "C", "role": "primary" },
    { "label": "Dash", "key": "X", "role": "primary" },
    { "label": "Climb", "key": "Z", "role": "secondary" },
    { "label": "Pause", "key": "Escape", "role": "system" }
  ]
}
```

Then run:

```bash
"$POCKETPAD_CLI" generate --spec /tmp/game-keypad.json --dry-run
"$POCKETPAD_CLI" generate --spec /tmp/game-keypad.json
```

You can also use stdin:

```bash
"$POCKETPAD_CLI" generate --stdin < /tmp/game-keypad.json
```

## Spec fields

Top-level fields:

| Field | Required | Purpose |
|---|---:|---|
| `gameName` | yes | Profile name shown in PocketPad. |
| `source` | recommended | Where the controls came from, or why this is a best guess. |
| `confidence` | recommended | `high`, `medium`, or `low`. |
| `notes` | optional | Caveats or context for the user. |
| `controls` | yes | Array of control objects. |

Control fields:

| Field | Required | Purpose |
|---|---:|---|
| `label` | yes | Visible text on the iPhone button. |
| `key` | yes | Mac key to inject. |
| `role` | recommended | Helps the CLI place and style the button. |
| `button` | optional | Explicit PocketPad slot. Usually omit and let the CLI infer. |
| `modifiers` | optional | Array of `command`, `shift`, `option`, `control`. |
| `centerX`, `centerY` | optional | Normalized layout position from `0.0` to `1.0`. |
| `widthScale`, `heightScale` | optional | Button size multiplier. |
| `shape` | optional | Visual shape. |

## Roles

Use roles because they let the CLI generate a reasonable layout:

- `movement`: d-pad / arrow cluster
- `primary`: large right-thumb actions such as jump, attack, dash, shoot
- `secondary`: smaller action buttons such as cast, climb, interact, special
- `utility`: map, inventory, journal, item wheel
- `system`: pause, menu, escape

## Valid button slots

Use explicit `button` only when needed:

```txt
up, down, left, right, jump, attack, dash, focus, map, pause,
custom1, custom2, custom3, custom4, custom5, custom6, custom7, custom8
```

The CLI can infer slots from labels like “Jump”, “Attack”, “Dash”, “Map”, and “Pause”. Extra controls go into custom slots.

## Key names

Common supported key names:

```txt
A-Z, 0-9, LeftArrow, RightArrow, UpArrow, DownArrow,
Escape, Esc, Tab, Space, Spacebar, Return, Enter,
Delete, Backspace, ForwardDelete,
F1-F17, Home, End, Page Up, Page Down
```

Modifiers example:

```json
{ "label": "Console", "key": "P", "modifiers": ["command", "shift"], "role": "utility" }
```

## Install behavior

Default install behavior:

```bash
"$POCKETPAD_CLI" generate --spec /tmp/game-keypad.json
```

This installs the profile, selects it, and marks it as default.

Useful variants:

```bash
"$POCKETPAD_CLI" generate --spec /tmp/game-keypad.json --no-default
"$POCKETPAD_CLI" generate --spec /tmp/game-keypad.json --no-select
"$POCKETPAD_CLI" install-spec /tmp/game-keypad.json
"$POCKETPAD_CLI" profile list
```

## Quality checklist before installing

Before running the final install command, check:

- Movement keys are present unless the game does not use movement.
- At least one primary action exists for action games.
- Pause/menu is mapped when the game has one.
- `confidence` honestly reflects certainty.
- `source` explains where the mapping came from.
- The dry-run output lists the expected bindings.

## User-facing summary

After installing, respond with a short summary:

```txt
Created and selected a PocketPad profile for Celeste.
Confidence: low — this is an agent best guess from common/default controls.

Bindings:
- Move: Arrow keys
- Jump: C
- Dash: X
- Climb: Z
- Pause: Esc

If your in-game bindings differ, adjust them in PocketPad Mac's Keypad editor.
```

## Troubleshooting

- **No built-in template**: create `--spec` JSON. Do not ask the app to invent a generic fallback.
- **Unsupported key**: change `key` to a supported key name, then rerun `--dry-run`.
- **Malformed JSON**: validate the file or rewrite it with strict JSON syntax.
- **Profile does not appear on iPhone**: make sure PocketPad Mac is running and the iPhone is paired; rerun the install command or restart PocketPad Mac.
- **Controls feel wrong in-game**: tell the user the profile is editable in PocketPad Mac, and update the JSON/install again if they provide corrections.
