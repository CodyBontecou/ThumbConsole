# Tideglass Field — Independent Visual Critique, Pass 1

**Evidence reviewed:** `reviews/contact-sheet-1.png` (2176 × 1714), inspected at exact contact-sheet resolution and at an exact 25% reduction (544 × 428).
**Criteria:** `reviews/art-direction.md` and the Thumble visual quality bar.
**Verdict:** **reject**

The sheet contains all 16 required panels, and portrait is separately composed rather than rotated or stretched. The work nevertheless has one blocker and four major findings. Most importantly, the landscape artwork collapses at 25% into a conventional game-controller front plate rather than the specified three-shelf hydrographic transect. Dark control tiers, normal legend contrast, primary-action active feedback, and disabled-state semantics also miss explicit acceptance criteria.

## Panel coverage

| Panels | 100% inspection | 25% inspection |
|---|---|---|
| Landscape · Light · Normal / Pressed / Active / Disabled | Controls remain centered and unclipped. The single outer slab, stacked utility edges, low normal A/B legend contrast, missing active A/B index, and pressed/disabled collision are visible. | Movement and action groups remain identifiable, but the whole composition reads as a conventional controller face. Active A/B does not separate from normal. |
| Landscape · Dark · Normal / Pressed / Active / Disabled | The same composition defects remain; movement, utility, and system faces merge into their wells. A full-width canvas line is visible beneath the shell. | Movement faces reduce largely to floating arrow legends. Utility keys and non-active boundaries recede. |
| Portrait · Light · Normal / Pressed / Active / Disabled | The upper shard, alternating neck notches, right rail, and lower delta are separately authored and connected. Utility legends are weak; active A/B and disabled semantics fail as above. | Upper action and lower movement groups remain identifiable. The intended left negative space remains calm rather than looking like a crop. |
| Portrait · Dark · Normal / Pressed / Active / Disabled | Dark-tier merging is strongest in movement and the right utility rail. A full-height canvas line is visible left of the silhouette. | The silhouette survives, but movement faces and utility keys lose material definition; pressed and disabled remain too similar. |

# Pass 1 — Composition

## C-01 — The landscape silhouette reads as commercial controller trade dress

- **Severity:** `blocker`
- **Affected panels:** all eight landscape panels; clearest in Landscape · Light · Normal and all four landscape panels at 25%.
- **Visible evidence:** A single long, nearly rectangular teal body encloses a cross-arranged movement cluster on the left, diagonal A/B controls on the right, a low Select/Start pair, and a centered top protrusion. The movement and action areas read as dark wells cut into one front plate. The narrow center bridge is only a small lower tab; it does not establish three visibly overlapping shelves. At 25%, contour detail drops away and the result is the familiar directional-left/actions-right controller face the originality boundary explicitly warns against. Unequal chamfers and the shallow top notch are too slight to overturn that reading.
- **Likely cause:** One base shell polygon is carrying the entire landscape composition, while role separation is delegated to inset wells. The bathymetric shelves therefore behave as decoration inside a hardware enclosure rather than as the primary silhouette logic.
- **Concrete correction:** Keep all native frames fixed, but make the broad movement shelf, offset sampling bridge, and tapered action shelf visibly overlap as three connected masses. Preserve the straight upper datum edge, while giving the center bridge a clearly visible 12–20 px lower terrace and depth overlap, and make the action end taper and end chamfers materially unequal. At exact 25% scale, three shelf masses must remain visible and the artwork must no longer read as one rectangular controller body.

### Portrait continuity and empty-space check

No separate portrait composition defect is issued in this pass. All eight portrait panels show a continuous upper shard → alternately notched neck → lower delta, with a distinct right rail and intentional left-side negative space. The portrait is not a crop or rotation. Its lower delta is somewhat hardware-like, but the present blocker is the much stronger landscape front-plate reading; avoid making the portrait more bilaterally regular while correcting the family silhouette.

# Pass 2 — Material and craft

## M-01 — Dark semantic tiers do not preserve a 3:1 control boundary

- **Severity:** `major`
- **Affected panels:** all eight dark panels, especially Landscape/Portrait · Dark · Normal, Pressed, and Disabled; movement, utility/menu, and system materials are most affected.
- **Visible evidence:** In dark normal, movement faces nearly disappear into the movement well and read as arrows floating on one dark field. The portrait Start/Select rail also loses key-face definition. Representative rendered pixels from the exact sheet are approximately `(18,66,71)` for a movement face against `(5,47,53)` for its well, about **1.29:1**; the visible edge sample is only about **1.76:1**. A utility face sample is about **1.53:1** against its well. These are visibly and measurably below the required 3:1 boundary. Active coral outlines temporarily rescue some controls, but normal, pressed, and disabled do not have a stable material boundary.
- **Likely cause:** `movement_fill`, `utility_fill`, and `well_abyss` are too close in luminance, and the single-pixel teal edge is being asked to provide separation without enough contrast or thickness.
- **Concrete correction:** Establish either fill-to-well contrast or a continuous solid 2 px edge of at least **3:1** around every movement, utility/menu, and system face in dark appearance. Do not use glow. Re-render and verify that each face remains visible at 25%, including the portrait rail and disabled movement controls.

## M-02 — Normal legends miss the 7:1 target; the utility rail is not robustly legible

- **Severity:** `major`
- **Affected panels:** all four Normal panels and all four Active panels, because Active retains the same bright face treatment; primary-action and utility/menu controls in both orientations and appearances.
- **Visible evidence:** The broad light rose highlight behind A/B makes the foam legends look soft rather than engraved. Representative normal action pixels range around `(159,111,108)` to `(143,96,94)`, yielding only about **3.7–4.8:1** against the specified foam legend, not 7:1. Dark normal action samples are still only about **4.1–5.1:1**. The upper portion of the utility key treatment is similarly near **3.9–5.0:1**. At full sheet resolution, Start/Select are already soft; at 25%, they collapse to marks rather than readable native labels, especially on the portrait rail.
- **Likely cause:** The face highlight covers too much of each small key and raises the local luminance directly beneath the legend. Downscaling then blends the thin native text with that bright face.
- **Concrete correction:** Darken the normal action and utility face under every glyph and shorten the upper-left highlight so every rendered legend location measures **≥7:1** in light and dark. Preserve native labels and frames. Active’s 6–8% lift must not reduce legend contrast below 7:1. Confirm Start and Select remain readable in the full-resolution sheet and recognizable at 25%.

## M-03 — Orientation-wide canvas lines look like raster seams

- **Severity:** `minor`
- **Affected panels:** all 16 panels; most visible in all four dark landscape panels and all four dark portrait panels.
- **Visible evidence:** A one-pixel horizontal line spans the entire landscape canvas roughly 20 contact-sheet pixels below the shell. Portrait has a comparable full-height vertical line left of the silhouette. Neither line terminates at a shelf, contour junction, sounding point, or datum mark. In dark appearance they read as tiling or export seams on an otherwise matte canvas.
- **Likely cause:** A full-artboard guide/axis or an artwork boundary stroke has survived export, or a background layer edge is being rasterized as a line.
- **Concrete correction:** Remove the full-bleed lines and render a uniform matte canvas. If they are intentional survey datums, constrain them to a shelf and the established 8–14 px datum grammar. At 100% and 25%, no line may traverse empty canvas from edge to edge.

## M-04 — Stacked edge strokes create small halos around landscape shelves

- **Severity:** `minor`
- **Affected panels:** all eight landscape panels, most obvious beneath the Select/Start bridge and beside the movement/action wells.
- **Visible evidence:** The utility bridge has three to four parallel lower-edge lines at full resolution. Movement and action boundaries also combine a dark well edge, pale neighboring line, and nearby contour into doubled rails. The contour fields themselves stay at roughly seven paths in landscape and five through the portrait neck, with no moiré at 25%; the defect is the edge stack where shelf, well, and shadow strokes accumulate.
- **Likely cause:** Overlapping shelf outlines, well strokes, and contact shadows are all rendered at the same boundary instead of resolving into one depth transition.
- **Concrete correction:** Reduce each boundary to one 1–1.5 px upper-left milk edge, one 1.5–2 px lower-right dense edge, and at most one contact shadow ending within 4 px. Remove duplicate same-tier strokes. At 100%, the utility bridge must show one readable inset/raised transition; at 25%, no pale or dark halo may remain.

# Pass 3 — Interaction

## I-01 — Active A/B lacks the required coral perimeter index

- **Severity:** `major`
- **Affected panels:** Landscape · Light · Active; Landscape · Dark · Active; Portrait · Light · Active; Portrait · Dark · Active.
- **Visible evidence:** Normal and Active A/B faces are visually near-identical at full resolution and indistinguishable at 25%. Movement, system, and utility controls gain a clear coral perimeter, but the focal primary-action controls do not. This inverts the intended active hierarchy. The nominal coral against the bright rendered action face is also only about **2.4:1** in representative pixels, below the required 3:1.
- **Likely cause:** The primary-action active stroke is omitted, buried under the normal pale edge/highlight, or composited in a color too close to the lifted rose face.
- **Concrete correction:** Render a continuous, crisp **1.5–2 px** `signal_coral` perimeter index on both A and B, with **≥3:1** contrast against every adjacent action-face value, and apply the specified **6–8%** active fill lift while retaining ≥7:1 legend contrast. At 25%, a viewer must distinguish Active A/B from Normal within two seconds without relying on other controls.

## I-02 — Disabled behaves like a flatter pressed state instead of unavailable material

- **Severity:** `major`
- **Affected panels:** all four Disabled panels compared with their corresponding Pressed panels; strongest on A/B and on dark movement, utility/menu, and system controls.
- **Visible evidence:** Disabled A/B remains a saturated burgundy face; it is flatter and darker, but it is not visibly desaturated by 55–70%. At 25%, Pressed and Disabled produce nearly the same dark-control pattern. In dark movement and utility, weak boundaries compound the collision: both states reduce to legends on a low-contrast well. The sheet therefore does not provide four meaningful states side by side.
- **Likely cause:** Disabled appears to use a darker/flattened fill or opacity change rather than its own saturation, edge, highlight, and shadow treatment. Pressed and disabled are converging on the same dark endpoint.
- **Concrete correction:** Reduce disabled saturation by **55–70%**, remove specular and cast shadow, soften the edge, and retain **48–58%** material weight with **≥3:1** legend contrast. Keep Pressed saturated and physically inset, with its 0.97 center-anchored scale and inner lower-right edge. In a 25% four-state strip, a reviewer must be able to sort Pressed from Disabled for movement, action, utility/menu, and system without using the panel titles.

### Interaction checks that pass

- No visible control-frame or legend-position shift occurs between states.
- Pressed generally reads as a center-anchored depression rather than a displaced control.
- Active movement, system, and utility controls use a crisp non-glowing coral perimeter.
- Native controls and labels remain unobscured by contours or artwork.

# Originality and trade-dress check

No manufacturer logo, model text, screen bezel, vent, speaker slots, screw pattern, compass rose, fake control, or proprietary glyph is visible. Coral ticks and brass points remain sparse and do not read as fasteners. The portrait artwork is orientation-specific.

The check nevertheless **fails** because the landscape outer body and canonical control grouping combine into a recognizable generic commercial controller/front-plate silhouette. Changing color and adding hydrographic contours does not make that silhouette legally or visually distinct. C-01 must be resolved before a later pass can clear originality.

# Defects versus optional taste

All findings above are tied to the written acceptance criteria or a visible artifact. There are no taste-only requests in this pass. Do not add more grain, glow, contour paths, or decorative marks as a substitute for correcting silhouette, contrast, and state behavior.

# Final verdict

**`reject`**

A new contact sheet is required after C-01 and all major findings are corrected. A visual pass is not possible while the landscape trade-dress blocker remains, normal legend and dark boundary contrast miss their thresholds, Active A/B lacks a meaningful index, and Disabled collides with Pressed.
