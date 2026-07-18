# Pale Cavern — Design Pass 3

- Stage: narrowly bounded corrective pass after `critique-2.md`
- Canonical artboard: `showcase-controller-v1`, revision 2
- Package identity: `com.codybontecou.pale-cavern` `1.0.0`
- Human approval: pending

## Scope and preserved evidence

Only the action-well opening and system cue in the two portrait SVGs were changed. `skin-source.json`, all palette/material/state tokens, native controls, both landscape SVGs, the bridge, utility shelf/gap, custom ledges, laminae, flecks, and all profile/default/catalog content were left unchanged.

The prior review evidence remains byte-for-byte unchanged:

| Preserved file | SHA-256 |
|---|---|
| `reviews/contact-sheet-1.png` | `cea87ee3b9cf485e1c214c9952075d7406c309a9393d880e56052a8d019c40cb` |
| `reviews/contact-sheet-2.png` | `2e2752cb2bb1bc789f22975ae06437f7b51517b608493f21e927fda7545771b5` |
| `reviews/critique-1.md` | `9b8125dd0c0a2e6ee5986216a50e70752b07195dceb43f64e70f77d7987ea1ca` |
| `reviews/critique-2.md` | `fa7bf73035dc862d4762c3f3b266961eb819d8ad839a0ef60080b6bde214d8ec` |

Additional unchanged-scope hashes:

| Preserved file | SHA-256 |
|---|---|
| `skin-source.json` | `856887b3478fe4735d919c3b646fd0b3d727c3414ce57c4ccaedd0e49f363064` |
| `sources/artwork/landscape-light.svg` | `d278fa6e9199a6ad0765848c1e49e6068dc9be407e7bd4416cb4e335d8c91c07` |
| `sources/artwork/landscape-dark.svg` | `04dbbf558ab2e9cce31e4bed7f78d4c9d1cd67ca23089c1720fabaa280f891f1` |
| `reviews/human-approval.json` | `9cc91bd3e9162b95fbf751b35ff31af7048a23955f89b4daca4aebe78cf98ae7` |

## Sole correction implemented

The canonical portrait frames remain unchanged:

- Y: `x = 197.784–244.416`, `y = 195.184–241.816`.
- System: `x = 171–231`, `y = 257.680–301.680`.
- Clear native-frame gap: `15.864 px`, from `y = 241.816` to `257.680`.

In both `portrait-light.svg` and `portrait-dark.svg`:

1. The action-well fill was opened through its lower center instead of retaining the prior closed bottom. Its opening uses outer legs at `x = 158` and `x = 255`, outside the requested central `x = 159–243` corridor. The lower-right passive edge now terminates at `x = 255`, which is `10.584 px` right of the Y frame and `24 px` right of the system frame.
2. The opening returns beneath the native Y through a restrained 10 px curved throat at `y <= 241.816`; no action-well fill transition or stroke enters the open frame gap.
3. The closed 84 × 68 px system landing, its fill, top highlight, and lower-right shadow were removed. The replacement is a fill-free open-top U aperture with centerline sides at `x = 159` and `x = 243` and bottom at `y = 314`.
4. Aperture centerline clearances from the system frame are `12 px` left, `12 px` right, and `12.320 px` below. With the 1 px stroke footprint included, the nearest painted-edge clearances are `11.5 px`, `11.5 px`, and `11.820 px`. Its nearest point to the Y frame remains the full `15.864 px` vertical frame gap.
5. The central `x = 159–243`, `y = 241.816–257.680` corridor now contains one uninterrupted underlying chamber-ground field. It contains no passive stroke, fill transition, occlusion edge, or shadow. The native system control remains unmodified and receives no baked state treatment.

## Verification outcomes

Using `/Users/codybontecou/projects/ThumbConsole/build/AgentDerivedData-hollow-skin-cli/Build/Products/Debug/thumbconsole`:

- Clean source compile: passed.
- Strict package validation: `valid with no warnings`.
- Strict source quality against `showcase-controller-v1`: `publication-ready`, score `100/100`, `0` errors, `0` warnings.
- Determinism: two clean temporary compiles and the workspace package were byte-for-byte identical.
- Native preview: rendered all 16 orientation × appearance × state panels at 4 columns.
- Full-resolution inspection: completed at `2176 × 1714 px`; the portrait Light and Dark panels retain fixed native frames and show continuous ground between Y and system, with no closed system tab.
- 25% inspection: completed at `544 × 429 px`; action and movement remain primary, the system cue stays subordinate, and no rounded tab reads as attached to the action well.

## Output evidence

| Output | Dimensions / size | SHA-256 |
|---|---:|---|
| `build/pale-cavern-1.0.0.pocketpad` | 658,390 bytes | `10b498ca7c549847d4c32d3aea8248f7a102ab9dc307c051a86e1c536cdbdd5b` |
| `reviews/contact-sheet-3.png` | 2176 × 1714 px | `bab8e455fe7cb75f0b3c34a78e120892483e7dad34f792609057b04cd65ac691` |
| `sources/artwork/portrait-light.svg` | 6,344 bytes | `ece59c519eda73311e50eeae7f35dbd5c945f0e5649a861bc182cb907e62a76a` |
| `sources/artwork/portrait-dark.svg` | 6,340 bytes | `708381d3fffedc0783117831c82156b8f5a688ca09809184903087d75c35aeef` |

## Remaining risks

1. This is designer inspection, not an independent `visual-pass`; the exact `contact-sheet-3.png` still requires the next critic review.
2. The open action throat deliberately disappears beneath the native Y frame at the canonical boundary. A critic should confirm at exact panel pixels that renderer antialiasing and the native shadow preserve the intended uninterrupted ground reading without introducing a visible near-tangency.
3. The 1 px fill-free system aperture is intentionally quiet and shares the lower chamber-edge region. A critic should confirm that it remains legible enough to group the system role while staying visually subordinate at 25%.

No distribution directory, install/apply action, profile/default/catalog/Website change, publication, staging, commit, push, or approval action was performed. `reviews/human-approval.json` remains pending.
