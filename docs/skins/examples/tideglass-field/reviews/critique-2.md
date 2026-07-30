# Tideglass Field — Independent Visual Critique, Pass 2

**Evidence reviewed:** `reviews/contact-sheet-2.png` (2176 × 1714), inspected at exact contact-sheet resolution and as a 544 × 428 Lanczos reduction (25%).
**Comparison evidence:** `reviews/contact-sheet-1.png` and `reviews/critique-1.md`.
**Criteria:** `reviews/art-direction.md` and the Thumble visual quality bar.
**Verdict:** **revise**

The landscape blocker is resolved: the movement shelf, central sampling bridge, and action shelf remain three separate masses at 25%, so the composition no longer collapses into one commercial controller front plate. Legends and disabled-state semantics are also substantially corrected. Two prior major findings remain incomplete, however: dark Disabled controls lose their boundaries, and the new A/B active perimeter is too thin and too low-contrast in the exact raster. A smaller portrait shoulder artifact also remains.

## Required-target test summary

| Required test | Result | Exact rendered evidence |
|---|---|---|
| Three landscape shelf masses eliminate the blocker | **Pass** | Broad left shelf, lighter central contour bridge/lower terrace, and tapered right shelf remain visibly separate in all eight landscape panels and at 25%. The silhouette no longer reads as one enclosing rectangular body. |
| Dark control boundaries survive | **Partial / fail** | Normal, Pressed, and Active controls now retain readable edge structure at 25%. Dark Disabled faces and edges still merge into `well_abyss`, especially movement, utility/menu/system, and the portrait rail. |
| A/B active index reads | **Partial / fail** | A coral perimeter now exists at 100%, but it rasterizes mostly as a one-pixel antialiased edge and becomes only a slight red shift on portrait A/B at 25%. Its measured contrast remains below 3:1. |
| Seams and halos are gone | **Partial / fail** | The former full-width/full-height canvas seams and landscape stacked-edge halos are gone. Thin shoulder lines still project into empty canvas from both sides of the portrait movement-delta junction. |
| Legends hold | **Pass** | A/B, arrows, system, Start, and Select remain centered and readable at full resolution. Representative normal action contrast is about 10.4:1 light and 10.9:1 dark; utility is about 9.7:1 light and 11.6:1 dark. Disabled legends also remain well above 3:1. |
| Disabled differs from Pressed | **Pass** | Pressed retains a dark, inset, saturated material; Disabled is flatter, muted, and visibly desaturated. They can be sorted in every orientation/appearance at 25% without using panel titles. |

## Prior-finding audit

| Prior finding | Pass-2 status | Audit |
|---|---|---|
| **C-01** — Landscape silhouette reads as commercial controller trade dress | **Resolved** | Three overlapping shelf masses, unequal end treatment, the lower sampling terrace, and visible center/right overlap seams survive thumbnail reduction. The prior single-front-plate reading is gone. |
| **M-01** — Dark semantic tiers do not preserve a 3:1 control boundary | **Unresolved, improved** | Normal/Pressed/Active edges are materially stronger and remain perceptible at 25%. Dark Disabled controls still fall below 3:1 and often reduce to legends on the well. Because the prior finding covered Disabled too, it is not closed. |
| **M-02** — Normal legends miss 7:1 | **Resolved** | The broad pale face highlight has been removed and the faces beneath legends are darker. Measured normal legend contrast now clears 7:1 in both appearances, including A/B and utility keys. |
| **M-03** — Orientation-wide canvas lines | **Resolved** | No horizontal line traverses empty landscape canvas and no vertical line traverses empty portrait canvas in pass 2. |
| **M-04** — Stacked landscape edge halos | **Resolved** | Landscape shelf/well transitions now read as separate depth tiers rather than three- or four-line halos. No halo survives at 25%. |
| **I-01** — Active A/B lacks the coral perimeter index | **Unresolved, improved** | The perimeter has been added, but its exact rendered width and contrast do not meet the 1.5–2 px / 3:1 target and it weakens excessively at 25%, particularly in portrait. |
| **I-02** — Disabled collides with Pressed | **Resolved** | Disabled is now materially flatter and less saturated than Pressed in all four orientation/appearance comparisons. |

No prior finding visibly regressed.

# Pass 1 — Composition

## Composition result: no new composition defect

All eight landscape panels now read as a lateral transect rather than a single controller shell. The left movement mass is broad, the center bridge is visibly lighter and carries the utility terrace, and the right action mass has its own taper and overlap. These differences remain visible when the complete sheet is reduced to 25%. Movement and action groups are identifiable within two seconds, and the centered contours make the span read as surveyed distance rather than unused space.

Portrait remains separately authored: upper action shard, narrow alternately notched neck, detached right-side utility rail, and broad lower movement delta retain their hierarchy in light and dark. There is no clipping, control drift, or accidental rotation/stretch relationship between orientations.

The trade-dress blocker is therefore closed; do not rejoin the landscape masses into one outer slab in a correction pass.

# Pass 2 — Material and craft

## M-01 — Dark Disabled controls still lose their material boundary

- **Severity:** `major`
- **Affected panels:** Landscape · Dark · Disabled and Portrait · Dark · Disabled; movement, A/B, utility/menu, and system faces are all affected, with movement and the portrait utility rail clearest.
- **Visible evidence:** Normal/Pressed/Active dark controls now have enough edge structure to survive 25%, but Disabled button boxes recede toward floating legends. On a representative dark Disabled movement key, the well is approximately `(5,47,53)`, the face approximately `(7,52,58)` (**1.07:1**), and continuous edge samples range approximately `(46,91,92)` to `(62,108,107)` (**1.89:1–2.43:1**). The action face is similarly close to its well. These rendered values remain below the required 3:1 boundary even though the labels themselves are legible.
- **Likely cause:** Disabled flattening and edge softening are both being composited toward the same dark well. The compiler's lack of per-state fill/saturation fields does not change the visible result; the available disabled edge treatment is carrying too little luminance after native rendering/downsampling.
- **Concrete correction:** Preserve the current muted Disabled faces, but give every Disabled control a continuous solid edge that measures **≥3:1** against `well_abyss` in the final contact-sheet raster. Use an available stroke/edge token rather than glow or unsupported fill fields. At 25%, every dark Disabled movement key, A/B key, system key, and portrait Start/Select key must remain visibly boxed rather than reading as a floating legend.

## M-05 — Portrait movement-delta shoulders emit line artifacts into the canvas

- **Severity:** `minor`
- **Affected panels:** all eight portrait panels; clearest in Portrait · Dark · Normal, Pressed, Active, and Disabled.
- **Visible evidence:** At the neck-to-lower-delta junction, a thin horizontal/diagonal line projects beyond the filled silhouette on both the left and right. It is especially visible against the dark canvas and reads as a path cap, shadow whisker, or unclipped edge—not a contour, datum tick, or contact shadow following the shell. The former orientation-wide seams are gone, but these local protrusions mean the 100% artifact check is not yet clean.
- **Likely cause:** The delta's upper edge or shadow stroke extends past the polygon endpoints and is not clipped to the filled shelf.
- **Concrete correction:** Clip the delta edge/shadow to the shelf silhouette or use endpoint geometry that terminates flush. In the next exact native-renderer sheet, **zero pixels** of either shoulder edge may project into empty canvas beyond the filled polygon; retain only the compact lower-right contact shadow within 4 px.

### Material checks that pass

- The full-bleed landscape and portrait seam lines from pass 1 are absent.
- Landscape well, shelf, and contact-shadow edges no longer form pale/dark stacked halos at 25%.
- Light and dark appearances retain separate authored shelf values rather than simple global dimming.
- Contours remain subordinate, do not cross control faces, and do not form moiré at 25%.
- Coral datum ticks and brass points remain sparse and do not read as fake controls or screws.
- Normal and Disabled legends are centered, unwarped, and comfortably above their required contrast floors.

# Pass 3 — Interaction

## I-01 — The A/B active index is present but remains under-width and under-contrast

- **Severity:** `major`
- **Affected panels:** Landscape · Light · Active; Landscape · Dark · Active; Portrait · Light · Active; Portrait · Dark · Active.
- **Visible evidence:** Both A and B now gain a coral perimeter without geometry shift, so this is a real improvement. In the exact sheet, however, most straight sections collapse to a single antialiased pixel. Typical perimeter samples are approximately `(152,71,67)` and the brightest samples about `(177,84,74)` against adjacent faces around `(75–78,49–55)`, yielding only about **1.8:1–2.5:1**, below the required 3:1. At 25%, landscape Active is detectable as a weak red shift, while portrait Active A/B remains too close to Normal for the intended focal active hierarchy.
- **Likely cause:** The active stroke is too thin before contact-sheet downsampling and/or is rendered with partial opacity, so the specified coral is blended heavily into the burgundy face. There is no compensating active fill lift in the exact raster; the compiler's absent per-state fill fields make a robust perimeter more important, not optional.
- **Concrete correction:** Using the supported active stroke/edge controls, produce an **opaque 1.5–2 px perimeter in the final native-renderer raster** around both A and B with **≥3:1** contrast against every adjacent face pixel. If necessary, increase source stroke width to survive downsampling while keeping native frames fixed. At exact 25%, both portrait and landscape Active A/B must be distinguishable from Normal within two seconds without relying on other active controls.

### Interaction checks that pass

- No control frame or legend shifts between Normal, Pressed, Active, and Disabled.
- Pressed remains center-anchored and reads darker/inset rather than displaced.
- Disabled is now clearly distinct from Pressed across movement, action, utility/menu, and system roles in all four orientation/appearance comparisons.
- Active movement, utility/menu, and system indices are visible, non-glowing, and stronger than Normal.
- Native controls remain unobscured and retain their semantic labels.

# Originality and trade-dress check

**Pass.** The landscape's three asymmetrical shelf masses now govern the silhouette, so the canonical left-direction/right-action placement no longer sits inside a copied or generic single hardware enclosure. Portrait remains an independently composed upper shard, sounding neck, rail, and lower delta. The palette, bathymetric contour grammar, coral datum notches, sounding points, and native legend system remain original to this direction.

No manufacturer mark, model typography, screen/bezel hierarchy, vent, speaker slot, screw pattern, compass rose, proprietary glyph, fake control, or recognizable commercial handheld outline is visible. The remaining defects are contrast and raster-craft defects, not originality violations.

# Defects versus optional taste

The two major findings enforce explicit 3:1 boundary/index requirements and meaningful state visibility. The minor finding is a visible raster/path artifact forbidden by the acceptance criteria. There are no optional taste requests in this pass. Do not add glow, grain, extra contours, or more datum marks to compensate for these defects.

# Final verdict

**`revise`**

Pass 2 closes the landscape blocker, legend failure, broad canvas seams, landscape halos, and Pressed/Disabled collision. A visual pass is still unavailable while Dark · Disabled boundaries remain below 3:1 and the A/B active index remains below its required rendered width and contrast. Remove the portrait delta shoulder whiskers in the same correction pass.

## Three highest-priority findings

1. **M-01 (`major`):** restore a measured ≥3:1 continuous boundary to every dark Disabled control.
2. **I-01 (`major`):** make the rendered A/B active perimeter opaque, 1.5–2 px, and ≥3:1 in both orientations and appearances.
3. **M-05 (`minor`):** clip both portrait delta shoulder lines so no edge pixels project into empty canvas.
