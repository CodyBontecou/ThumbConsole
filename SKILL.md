---
name: thumbconsole-keypad-generator
description: Generate, install, edit, export/import, and runtime-control ThumbConsole keypad profiles using the `thumbconsole` CLI. Use whenever a user asks for a ThumbConsole keypad, iPhone controller layout, game profile, keyboard-to-touch controls, shortcut pad setup, profile/template management, key binding changes, joystick/custom button layout changes, or Mac helper runtime actions such as status, pairing code/payload, accessibility, test tap, server restart, or release-all. For unknown games, research or infer controls, write an agent-provided JSON spec, dry-run it, and install it without asking the user unless they explicitly want custom controls.
---

# ThumbConsole CLI / Keypad Generator

Use this skill to configure ThumbConsole from the command line. ThumbConsole turns an iPhone into a programmable keypad/controller for a Mac. The CLI can now do both agent-friendly game profile generation and most saved-configuration/runtime actions exposed by the macOS app.

## Decision tree

- User names a game and wants a keypad/controller profile → generate or write a spec, dry-run, install.
- User wants an emulator/controller-style layout → use `template list` / `template install`.
- User wants to change shortcuts → use `binding` commands.
- User wants shape/color/joystick/layout changes → use `customization` or `element` commands.
- User wants to customize the iPhone control bar or one of its buttons → use `control-bar` commands.
- User wants backup/restore/share → use `profile export` / `profile import`.
- User wants pairing/status/server/accessibility/test/release-all → use runtime commands.

## Build or locate the CLI

From the ThumbConsole repo root:

```bash
xcodebuild -project ThumbConsole.xcodeproj \
  -scheme ThumbConsoleCLI \
  -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData \
  build

THUMBCONSOLE_CLI="$PWD/build/DerivedData/Build/Products/Debug/thumbconsole"
```

If `build/DerivedData/Build/Products/Debug/thumbconsole` already exists and is recent enough, reuse it.

## Generate a game profile

Try built-in game generation first:

```bash
"$THUMBCONSOLE_CLI" generate "Hollow Knight" --dry-run
"$THUMBCONSOLE_CLI" generate "Hollow Knight"
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
    "Generated from the agent's best guess. Adjust in ThumbConsole Mac if your in-game bindings differ."
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
"$THUMBCONSOLE_CLI" generate --spec /tmp/game-keypad.json --dry-run
"$THUMBCONSOLE_CLI" generate --spec /tmp/game-keypad.json
# or stdin
"$THUMBCONSOLE_CLI" generate --stdin < /tmp/game-keypad.json
```

By default, `generate` installs, selects, and marks the profile as default. If ThumbConsole Mac is running, it reloads and pushes the selected keypad to the paired iPhone.

Useful variants:

```bash
"$THUMBCONSOLE_CLI" generate --spec /tmp/game-keypad.json --no-default
"$THUMBCONSOLE_CLI" generate --spec /tmp/game-keypad.json --no-select
"$THUMBCONSOLE_CLI" install-spec /tmp/game-keypad.json
"$THUMBCONSOLE_CLI" generate --spec /tmp/game-keypad.json --json --dry-run
```

## Agent spec fields

Top-level fields:

| Field | Required | Purpose |
|---|---:|---|
| `gameName` | yes | Profile name shown in ThumbConsole. Aliases: `name`, `game`. |
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
| `button` | optional | Explicit ThumbConsole slot. Usually omit and let the CLI infer. |
| `centerX`, `centerY` | optional | Normalized position `0.0`–`1.0`. Aliases: `x`, `y`. |
| `widthScale`, `heightScale` | optional | Button size multipliers. Aliases: `width`, `height`. |
| `shape` | optional | `rounded_rectangle`, `rectangle`, `capsule`, `circle`, `ellipse`, `polygon`, `star`. |
| `accentStyle` | optional | `monochrome`, `blue`, `green`, `purple`, `pink`, `amber`. |
| `fill`, `fillHex`, `color`, `fillColor` | optional | Hex fill color like `#7C3AED`, or `fillColor` object. |
| `thumbFill`, `thumbColor`, `knobColor`, `joystickThumbFill`, `joystickKnobFill`, `joystickKnobColor` | optional | Hex color for a joystick's moving thumb/knob. |
| `styleID`, `visualStyle`, `pressedFill`, `stroke`, `strokeWidth`, `foreground`, `glow`, `glowRadius`, `opacity` | optional | Rich design styling fields for reusable/editor-quality appearances. |
| `icon`, `iconName`, `sfSymbol`, `iconText`, `hapticStyle` | optional | SF Symbol/text icon and per-control haptic style. |
| `cornerRadius` | optional | Rounded-rectangle corner radius. |
| `shadowStrength` | optional | Shadow multiplier `0`–`2`. |
| `isHidden` | optional | Hide this control. |
| `isLocationLocked` | optional | Prevent drag repositioning in the Mac editor. |
| `kind` / `controlKind` | optional | `button`, `joystick`, or `trackpad` for saved element/profile editing. Agent-generated key specs still require a keyboard `key`. |
| `trackpadSettings` | optional | Object with `sensitivity`, `scrollSensitivity`, `tapToClick`, `twoFingerScroll`, and `naturalScrolling` for trackpad components. |
| `sensitivity`, `cursorSensitivity`, `pointerSensitivity` | optional | Trackpad cursor sensitivity multiplier (`0.2`–`4.0` after normalization). Implies `kind: "trackpad"` if no kind is set. |
| `scrollSensitivity` | optional | Trackpad scroll sensitivity multiplier (`0.1`–`4.0` after normalization). |
| `tapToClick`, `twoFingerScroll`, `naturalScrolling` / `naturalScroll` | optional | Trackpad gesture toggles. |
| `joystickMapping` | optional | Object mapping joystick directions to ThumbConsole button slots. |
| `up`, `down`, `left`, `right` | optional | Direction aliases for joystick mappings; values are ThumbConsole slots, not keyboard keys. |

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
    { "label": "Move", "key": "W", "button": "custom1", "kind": "joystick", "up": "up", "down": "down", "left": "left", "right": "right", "fill": "#111827", "thumbFill": "#F8FAFC", "centerX": 0.22, "centerY": 0.64, "widthScale": 1.35, "heightScale": 1.35 },
    { "label": "Aim", "key": "I", "button": "custom2", "kind": "joystick", "up": "custom1", "down": "custom2", "left": "custom3", "right": "custom4", "fill": "#7C3AED", "thumbFill": "#FDE68A", "centerX": 0.78, "centerY": 0.64, "widthScale": 1.35, "heightScale": 1.35 },
    { "label": "Fire", "key": "Space", "button": "jump", "role": "primary", "fill": "#F59E0B", "shape": "circle" },
    { "label": "Pause", "key": "Escape", "button": "pause", "role": "system" }
  ]
}
```

### Trackpad sensitivity spec example

```json
{
  "gameName": "Remote Desktop Pad",
  "source": "Agent-provided layout",
  "confidence": "medium",
  "controls": [
    { "label": "Trackpad", "key": "Space", "kind": "trackpad", "sensitivity": 1.8, "scrollSensitivity": 1.1, "tapToClick": true, "twoFingerScroll": true, "naturalScrolling": false, "centerX": 0.50, "centerY": 0.58, "widthScale": 1.35 }
  ]
}
```

## Profile management

```bash
"$THUMBCONSOLE_CLI" profile list --ids
"$THUMBCONSOLE_CLI" profile show active --json
"$THUMBCONSOLE_CLI" profile create "My Setup" --blank
"$THUMBCONSOLE_CLI" profile create "SNES Setup" --template snes
"$THUMBCONSOLE_CLI" profile select "My Setup"
"$THUMBCONSOLE_CLI" profile default "My Setup"
"$THUMBCONSOLE_CLI" profile rename "My Setup" "Browser Shortcuts"
"$THUMBCONSOLE_CLI" profile duplicate "Browser Shortcuts" "Browser Copy"
"$THUMBCONSOLE_CLI" profile delete "Browser Copy"
"$THUMBCONSOLE_CLI" profile reset active
"$THUMBCONSOLE_CLI" profile export --all -o thumbconsole-profiles.json
"$THUMBCONSOLE_CLI" profile import thumbconsole-profiles.json
```

## Controller templates

Use these for emulator/controller-style layouts rather than game-specific key generation:

```bash
"$THUMBCONSOLE_CLI" template list
"$THUMBCONSOLE_CLI" template show snes
"$THUMBCONSOLE_CLI" template install snes --name "SNES" --default
```

Templates include NES, Super Nintendo, Nintendo 64, GameCube, Game Boy, Game Boy Advance, Genesis 6-Button, Sega Saturn, Dreamcast, Arcade Stick, PSP, PlayStation, and Xbox.

## Shortcut bindings

```bash
"$THUMBCONSOLE_CLI" binding list
"$THUMBCONSOLE_CLI" binding set jump Return
"$THUMBCONSOLE_CLI" binding set dash --key K --modifiers command
"$THUMBCONSOLE_CLI" binding set focus --sequence 'Control+B,H'
"$THUMBCONSOLE_CLI" binding reset jump
"$THUMBCONSOLE_CLI" binding clear custom1
"$THUMBCONSOLE_CLI" binding reset-all
```

Use `--profile PROFILE` on binding commands to target a non-active profile.

## Customization and elements

Setup-level customization:

```bash
"$THUMBCONSOLE_CLI" customization show --profile active
"$THUMBCONSOLE_CLI" customization set --appearance dark --device iphone-17-pro --background '#101014'
"$THUMBCONSOLE_CLI" customization set --background-gradient '#101014,#4338CA' --gradient-angle 45
"$THUMBCONSOLE_CLI" customization export -o customization.json
"$THUMBCONSOLE_CLI" customization import customization.json
"$THUMBCONSOLE_CLI" customization reset
```

Element-level controls:

```bash
"$THUMBCONSOLE_CLI" element list
"$THUMBCONSOLE_CLI" element add button --label Fire --maps-to custom1 --x 0.50 --y 0.80 --light-fill '#F59E0B' --dark-fill '#78350F'
"$THUMBCONSOLE_CLI" element add joystick --label "Right Stick" --fill '#111827' --thumb-fill '#F8FAFC' --up custom1 --down custom2 --left custom3 --right custom4
"$THUMBCONSOLE_CLI" element add trackpad --label Trackpad --x 0.50 --y 0.58 --width 1.25 --sensitivity 1.2 --scroll-sensitivity 0.85 --tap-to-click true
"$THUMBCONSOLE_CLI" element set jump --label A --light-fill '#7C3AED' --dark-fill '#C4B5FD' --shape circle --width 1.2 --height 1.2 --z-index 10
"$THUMBCONSOLE_CLI" element set "Right Stick" --thumb-fill '#22C55E'
"$THUMBCONSOLE_CLI" element set focus --icon sf:sparkles --haptic medium --stroke '#38BDF8' --pressed-fill '#0EA5E9' --glow '#0EA5E9' --glow-radius 12
"$THUMBCONSOLE_CLI" element set jump --lock
"$THUMBCONSOLE_CLI" element set pause --hide
"$THUMBCONSOLE_CLI" element reset jump
"$THUMBCONSOLE_CLI" element delete custom1
```

Appearance/design flags:

- `customization set --appearance system|light|dark` saves the selected setup's runtime appearance preference.
- `element set BUTTON --light-fill '#RRGGBB' --dark-fill '#RRGGBB'` saves separate button fills for both palettes.
- `--fill '#RRGGBB'` remains the shared/legacy fill for both palettes; `--clear-light-fill`, `--clear-dark-fill`, and `--clear-fill` remove custom colors.
- `style list|create|show|apply|detach|delete|export|import` manages reusable style tokens.
- `element set BUTTON --z-index -100...100` sets explicit stack order; `layer list|move|front|back|bring-forward|send-backward` still manages same-z tie order.
- `group list|create|ungroup|hide|show|lock|unlock` stores editor groups and can apply group visibility/lock to child controls.
- `asset import|list|remove` stores profile-local design assets for future icon/background workflows.

## iPhone control bar

Control-bar items keep their built-in actions, but their order, visibility, icon, size, fill, shape, corners, effects, and haptics can be customized per portrait/landscape variant:

```bash
"$THUMBCONSOLE_CLI" control-bar list --json
"$THUMBCONSOLE_CLI" control-bar set status,profiles,launch,spacer,edit,settings,home,connection
"$THUMBCONSOLE_CLI" control-bar move settings earlier
"$THUMBCONSOLE_CLI" control-bar item show settings --json
"$THUMBCONSOLE_CLI" control-bar item set settings --icon sf:slider.horizontal.3 --fill '#111827' --corner 12
"$THUMBCONSOLE_CLI" control-bar item set connection --width 1.25 --height 1.1 --haptic medium
"$THUMBCONSOLE_CLI" control-bar item reset settings
"$THUMBCONSOLE_CLI" control-bar reset
```

Use `--variant portrait|landscape` and `--profile PROFILE` as needed. A control-bar item's semantic action is fixed: styling `home`, for example, cannot turn it into a keyboard shortcut.

## Runtime Mac helper commands

ThumbConsole Mac must be running for most runtime commands. `app open` launches it first.

```bash
"$THUMBCONSOLE_CLI" app open
"$THUMBCONSOLE_CLI" status --json
"$THUMBCONSOLE_CLI" server start
"$THUMBCONSOLE_CLI" server stop
"$THUMBCONSOLE_CLI" server restart
"$THUMBCONSOLE_CLI" server addresses
"$THUMBCONSOLE_CLI" pairing code
"$THUMBCONSOLE_CLI" pairing payload
"$THUMBCONSOLE_CLI" pairing cancel
"$THUMBCONSOLE_CLI" accessibility status
"$THUMBCONSOLE_CLI" accessibility prompt
"$THUMBCONSOLE_CLI" accessibility open
"$THUMBCONSOLE_CLI" latency simulate --pattern hollow-knight --mode compare --log /tmp/thumbconsole-latency.json
"$THUMBCONSOLE_CLI" latency verify --max-ms 4 --p95-ms 4 --log /tmp/thumbconsole-latency-verify.json
"$THUMBCONSOLE_CLI" test tap jump
"$THUMBCONSOLE_CLI" test down left
"$THUMBCONSOLE_CLI" test up left
"$THUMBCONSOLE_CLI" release-all
```

Use `latency simulate` before UI automation when investigating controller lag. It is headless and emits per-edge touch-to-injection timings; supported patterns are `hollow-knight`, `same-button-burst`, `udp-recovery`, and `udp-recovery-burst`, with modes `current`, `legacy-main-actor`, or `compare`. Use `latency verify` as the pass/fail gate for whether the current input path is below the configured lag budget.

## Quality checklist before installing a game spec

- Movement keys are present unless the game does not use movement.
- At least one primary action exists for action games.
- Pause/menu is mapped when the game has one.
- Joystick direction aliases map to ThumbConsole slots, not keyboard keys.
- `confidence` honestly reflects certainty.
- `source` explains where the mapping came from.
- `--dry-run` lists the expected bindings and does not fail.

## User-facing summary

After installing, respond with a short summary:

```txt
Created and selected a ThumbConsole profile for Celeste.
Confidence: low — this is an agent best guess from common/default controls.

Bindings:
- Move: Arrow keys
- Jump: C
- Dash: X
- Climb: Z
- Pause: Esc

If your in-game bindings differ, I can update the profile from the CLI or you can edit it in ThumbConsole Mac's Keypad editor.
```

## Troubleshooting

- **No built-in game template**: create `--spec` JSON. Do not ask the app to invent a generic fallback.
- **Need a controller layout, not a game profile**: use `template install`.
- **Unsupported key**: change `key` to a supported key name, then rerun `--dry-run`.
- **Malformed JSON**: validate the file or rewrite it with strict JSON syntax.
- **Profile does not appear on iPhone**: make sure ThumbConsole Mac is running and the iPhone is paired; rerun the install command or restart ThumbConsole Mac.
- **Runtime status missing**: run `thumbconsole app open`, then `thumbconsole status` again.
- **Controls feel wrong in-game**: update the JSON/spec or use `binding set` / `element set` rather than asking the user to hand-edit everything.
