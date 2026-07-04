---
name: pocketpad-keypad-generator
description: Generate, install, edit, export/import, and runtime-control PocketPad keypad profiles using the `pocketpad` CLI. Use whenever a user asks for a PocketPad keypad, iPhone controller layout, game profile, keyboard-to-touch controls, shortcut pad setup, profile/template management, key binding changes, joystick/custom button layout changes, or Mac helper runtime actions such as status, pairing code/payload, accessibility, test tap, server restart, or release-all. For unknown games, research or infer controls, write an agent-provided JSON spec, dry-run it, and install it without asking the user unless they explicitly want custom controls.
---

# PocketPad CLI / Keypad Generator

Use this skill to configure PocketPad from the command line. PocketPad turns an iPhone into a programmable keypad/controller for a Mac. The CLI can now do both agent-friendly game profile generation and most saved-configuration/runtime actions exposed by the macOS app.

## Decision tree

- User names a game and wants a keypad/controller profile → generate or write a spec, dry-run, install.
- User wants an emulator/controller-style layout → use `template list` / `template install`.
- User wants to change shortcuts → use `binding` commands.
- User wants shape/color/joystick/layout changes → use `customization` or `element` commands.
- User wants backup/restore/share → use `profile export` / `profile import`.
- User wants pairing/status/server/accessibility/test/release-all → use runtime commands.

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

## Generate a game profile

Try built-in game generation first:

```bash
"$POCKETPAD_CLI" generate "Hollow Knight" --dry-run
"$POCKETPAD_CLI" generate "Hollow Knight"
```

If there is no built-in game template, the agent is the fallback: research or infer controls, write a JSON spec, dry-run, then install.

Research controls in this order when practical:

1. Local game config files or launcher settings.
2. Official docs, in-game manuals, or support pages.
3. Reputable community wiki/default-controls pages.
4. Common genre conventions plus the agent's best guess.

If uncertain, still create a playable spec, set `confidence` to `low`, and mention the caveat in `notes`.

### Minimal agent spec

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

Run:

```bash
"$POCKETPAD_CLI" generate --spec /tmp/game-keypad.json --dry-run
"$POCKETPAD_CLI" generate --spec /tmp/game-keypad.json
# or stdin
"$POCKETPAD_CLI" generate --stdin < /tmp/game-keypad.json
```

By default, `generate` installs, selects, and marks the profile as default. If PocketPad Mac is running, it reloads and pushes the selected keypad to the paired iPhone.

Useful variants:

```bash
"$POCKETPAD_CLI" generate --spec /tmp/game-keypad.json --no-default
"$POCKETPAD_CLI" generate --spec /tmp/game-keypad.json --no-select
"$POCKETPAD_CLI" install-spec /tmp/game-keypad.json
"$POCKETPAD_CLI" generate --spec /tmp/game-keypad.json --json --dry-run
```

## Agent spec fields

Top-level fields:

| Field | Required | Purpose |
|---|---:|---|
| `gameName` | yes | Profile name shown in PocketPad. Aliases: `name`, `game`. |
| `source` | recommended | Where controls came from, or why this is a best guess. |
| `confidence` | recommended | `high`, `medium`, or `low`. |
| `notes` | optional | Caveats or context. |
| `controls` | yes | Array of control objects. |

Control fields:

| Field | Required | Purpose |
|---|---:|---|
| `label` | yes | Visible text on the iPhone button. |
| `key` | yes | Mac key to inject. Still required for joystick specs. |
| `modifiers` | optional | Array of `command`, `shift`, `option`, `control`. |
| `role` | recommended | `movement`, `primary`, `secondary`, `utility`, `system`; helps placement/style. |
| `button` | optional | Explicit PocketPad slot. Usually omit and let the CLI infer. |
| `centerX`, `centerY` | optional | Normalized position `0.0`–`1.0`. Aliases: `x`, `y`. |
| `widthScale`, `heightScale` | optional | Button size multipliers. Aliases: `width`, `height`. |
| `shape` | optional | `rounded_rectangle`, `rectangle`, `capsule`, `circle`, `ellipse`, `polygon`, `star`. |
| `accentStyle` | optional | `monochrome`, `blue`, `green`, `purple`, `pink`, `amber`. |
| `fill`, `fillHex`, `color`, `fillColor` | optional | Hex fill color like `#7C3AED`, or `fillColor` object. |
| `cornerRadius` | optional | Rounded-rectangle corner radius. |
| `shadowStrength` | optional | Shadow multiplier `0`–`2`. |
| `isHidden` | optional | Hide this control. |
| `isLocationLocked` | optional | Prevent drag repositioning in the Mac editor. |
| `kind` / `controlKind` | optional | `button` or `joystick`. |
| `joystickMapping` | optional | Object mapping joystick directions to PocketPad button slots. |
| `up`, `down`, `left`, `right` | optional | Direction aliases for joystick mappings; values are PocketPad slots, not keyboard keys. |

Valid `button` slots:

```txt
up, down, left, right, jump, attack, dash, focus, map, pause,
custom1, custom2, custom3, custom4, custom5, custom6, custom7, custom8
```

Common supported key names:

```txt
A-Z, 0-9, LeftArrow, RightArrow, UpArrow, DownArrow,
Escape, Esc, Tab, Space, Spacebar, Return, Enter,
Delete, Backspace, ForwardDelete,
F1-F17, Home, End, Page Up, Page Down
```

### Styled joystick spec example

```json
{
  "gameName": "Twin Stick Example",
  "source": "Agent-provided layout",
  "confidence": "medium",
  "controls": [
    { "label": "Move", "key": "W", "button": "custom1", "kind": "joystick", "up": "up", "down": "down", "left": "left", "right": "right", "fill": "#111827", "centerX": 0.22, "centerY": 0.64, "widthScale": 1.35, "heightScale": 1.35 },
    { "label": "Aim", "key": "I", "button": "custom2", "kind": "joystick", "up": "custom1", "down": "custom2", "left": "custom3", "right": "custom4", "fill": "#7C3AED", "centerX": 0.78, "centerY": 0.64, "widthScale": 1.35, "heightScale": 1.35 },
    { "label": "Fire", "key": "Space", "button": "jump", "role": "primary", "fill": "#F59E0B", "shape": "circle" },
    { "label": "Pause", "key": "Escape", "button": "pause", "role": "system" }
  ]
}
```

## Profile management

```bash
"$POCKETPAD_CLI" profile list --ids
"$POCKETPAD_CLI" profile show active --json
"$POCKETPAD_CLI" profile create "My Setup" --blank
"$POCKETPAD_CLI" profile create "SNES Setup" --template snes
"$POCKETPAD_CLI" profile select "My Setup"
"$POCKETPAD_CLI" profile default "My Setup"
"$POCKETPAD_CLI" profile rename "My Setup" "Browser Shortcuts"
"$POCKETPAD_CLI" profile duplicate "Browser Shortcuts" "Browser Copy"
"$POCKETPAD_CLI" profile delete "Browser Copy"
"$POCKETPAD_CLI" profile reset active
"$POCKETPAD_CLI" profile export --all -o pocketpad-profiles.json
"$POCKETPAD_CLI" profile import pocketpad-profiles.json
```

## Controller templates

Use these for emulator/controller-style layouts rather than game-specific key generation:

```bash
"$POCKETPAD_CLI" template list
"$POCKETPAD_CLI" template show snes
"$POCKETPAD_CLI" template install snes --name "SNES" --default
```

Templates include NES, Super Nintendo, Nintendo 64, GameCube, Game Boy, Game Boy Advance, Genesis 6-Button, Sega Saturn, Dreamcast, Arcade Stick, PSP, PlayStation, and Xbox.

## Shortcut bindings

```bash
"$POCKETPAD_CLI" binding list
"$POCKETPAD_CLI" binding set jump Return
"$POCKETPAD_CLI" binding set dash --key K --modifiers command
"$POCKETPAD_CLI" binding set focus --sequence 'Control+B,H'
"$POCKETPAD_CLI" binding reset jump
"$POCKETPAD_CLI" binding clear custom1
"$POCKETPAD_CLI" binding reset-all
```

Use `--profile PROFILE` on binding commands to target a non-active profile.

## Customization and elements

Setup-level customization:

```bash
"$POCKETPAD_CLI" customization show --profile active
"$POCKETPAD_CLI" customization set --appearance dark --device iphone-17-pro --background '#101014'
"$POCKETPAD_CLI" customization set --background-gradient '#101014,#4338CA' --gradient-angle 45
"$POCKETPAD_CLI" customization export -o customization.json
"$POCKETPAD_CLI" customization import customization.json
"$POCKETPAD_CLI" customization reset
```

Element-level controls:

```bash
"$POCKETPAD_CLI" element list
"$POCKETPAD_CLI" element add button --label Fire --maps-to custom1 --x 0.50 --y 0.80 --light-fill '#F59E0B' --dark-fill '#78350F'
"$POCKETPAD_CLI" element add joystick --label "Right Stick" --up custom1 --down custom2 --left custom3 --right custom4
"$POCKETPAD_CLI" element set jump --label A --light-fill '#7C3AED' --dark-fill '#C4B5FD' --shape circle --width 1.2 --height 1.2
"$POCKETPAD_CLI" element set jump --lock
"$POCKETPAD_CLI" element set pause --hide
"$POCKETPAD_CLI" element reset jump
"$POCKETPAD_CLI" element delete custom1
```

Appearance flags:

- `customization set --appearance system|light|dark` saves the selected setup's runtime appearance preference.
- `element set BUTTON --light-fill '#RRGGBB' --dark-fill '#RRGGBB'` saves separate button fills for both palettes.
- `--fill '#RRGGBB'` remains the shared/legacy fill for both palettes; `--clear-light-fill`, `--clear-dark-fill`, and `--clear-fill` remove custom colors.

## Runtime Mac helper commands

PocketPad Mac must be running for most runtime commands. `app open` launches it first.

```bash
"$POCKETPAD_CLI" app open
"$POCKETPAD_CLI" status --json
"$POCKETPAD_CLI" server start
"$POCKETPAD_CLI" server stop
"$POCKETPAD_CLI" server restart
"$POCKETPAD_CLI" server addresses
"$POCKETPAD_CLI" pairing code
"$POCKETPAD_CLI" pairing payload
"$POCKETPAD_CLI" pairing cancel
"$POCKETPAD_CLI" accessibility status
"$POCKETPAD_CLI" accessibility prompt
"$POCKETPAD_CLI" accessibility open
"$POCKETPAD_CLI" latency simulate --pattern hollow-knight --mode compare --log /tmp/pocketpad-latency.json
"$POCKETPAD_CLI" latency verify --max-ms 4 --p95-ms 4 --log /tmp/pocketpad-latency-verify.json
"$POCKETPAD_CLI" test tap jump
"$POCKETPAD_CLI" test down left
"$POCKETPAD_CLI" test up left
"$POCKETPAD_CLI" release-all
```

Use `latency simulate` before UI automation when investigating controller lag. It is headless and emits per-edge touch-to-injection timings; supported patterns are `hollow-knight`, `same-button-burst`, `udp-recovery`, and `udp-recovery-burst`, with modes `current`, `legacy-main-actor`, or `compare`. Use `latency verify` as the pass/fail gate for whether the current input path is below the configured lag budget.

## Quality checklist before installing a game spec

- Movement keys are present unless the game does not use movement.
- At least one primary action exists for action games.
- Pause/menu is mapped when the game has one.
- Joystick direction aliases map to PocketPad slots, not keyboard keys.
- `confidence` honestly reflects certainty.
- `source` explains where the mapping came from.
- `--dry-run` lists the expected bindings and does not fail.

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

If your in-game bindings differ, I can update the profile from the CLI or you can edit it in PocketPad Mac's Keypad editor.
```

## Troubleshooting

- **No built-in game template**: create `--spec` JSON. Do not ask the app to invent a generic fallback.
- **Need a controller layout, not a game profile**: use `template install`.
- **Unsupported key**: change `key` to a supported key name, then rerun `--dry-run`.
- **Malformed JSON**: validate the file or rewrite it with strict JSON syntax.
- **Profile does not appear on iPhone**: make sure PocketPad Mac is running and the iPhone is paired; rerun the install command or restart PocketPad Mac.
- **Runtime status missing**: run `pocketpad app open`, then `pocketpad status` again.
- **Controls feel wrong in-game**: update the JSON/spec or use `binding set` / `element set` rather than asking the user to hand-edit everything.
