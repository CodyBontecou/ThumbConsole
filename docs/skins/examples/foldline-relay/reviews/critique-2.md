# Foldline Relay — Independent Visual Critique 2

- **Evidence reviewed:** `reviews/contact-sheet-2.png`
- **Comparison evidence:** `reviews/contact-sheet-1.png`, `reviews/critique-1.md`
- **Evidence dimensions:** 2176 × 1714 px
- **Inspection scales:** exact PNG at full resolution, source-pixel panel crops, and a 25% overview at 544 × 429 px
- **Art direction:** `reviews/art-direction.md`
- **Quality bar:** PocketPad visual quality bar
- **Verdict:** `revise`

Contact sheet 2 retains all 16 native-renderer combinations. Relative to pass 1, the raised landscape folio no longer runs to the lower boundary, portrait has gained an oblique crown fold, route endpoints now relate to the source cluster and system tag, and the dark fold planes separate at 25%. Those are real corrections. The sheet still cannot pass: row-four native shadows continue into the landscape crop, the folio/tab mass still resolves as a keypad at 25%, the controls remain digitally shaded rather than matte, long legends remain undersized or muddy, and disabled, active-Escape, and pressed behavior still miss the state contract.

## Prior-finding audit

| Prior finding | Pass-2 status | Evidence in contact sheet 2 |
|---|---|---|
| C1 — Landscape folio and bottom-row shadows cropped | **Unresolved — improved** | The passive fold plane now resolves to canvas above row four, but row-four face/shadow pixels still reach the final source row in normal, pressed, and active panels; the best disabled/normal cases leave only one contact-sheet pixel row of canvas. |
| C2 — Generic keypad rather than tab docket | **Unresolved — improved** | Added ledges and the portrait crown are visible at full size, but they collapse at 25%; the three regular columns over broad shared fields still dominate. |
| C3 — Detached Relay Fold / unexplained negative field | **Unresolved — improved; downgraded to minor** | Source and destination endpoints are now aligned and the open field reads intentionally. The registration brackets still disappear at 25%, so the measurement/fold grammar is incomplete at the required overview scale. |
| M1 — Dark fold tiers collapse | **Resolved** | Canvas, lower score field, and raised outer plane remain separately traceable in all eight dark panels and at 25%. |
| M2 — Glossy/haloed tabs instead of matte die cuts | **Unresolved** | Pressed secondary, orange, and chartreuse faces retain bright-center/dark-edge modeling; normal and active edges still carry broad soft shadow or perimeter bloom. |
| M3 — Long-label fit and contrast | **Unresolved** | `Command` remains a micro-legend, while pressed `Command`, `Prefix`, `Escape`, and `Palette` are degraded by face shading. The rendered evidence still does not demonstrate the specified 9 px cap height. |
| I1 — Disabled states too chromatic | **Unresolved** | Blue, orange, and chartreuse stay near normal saturation while depth is flattened; dark disabled action keys remain more salient than the system tag. |
| I2 — Escape active incomplete / other indices ring-like | **Unresolved** | Escape's dense edge is not distinct at 25%; other roles still gain complete perimeter outlines rather than discrete registration indices. |
| I3 — Pressed reads as illumination, not depression | **Unresolved** | Scale change is perceptible, but spotlight gradients and persistent halos remain the primary pressed cue. |

No prior finding visibly regressed. M1 is the only prior major finding fully resolved.

## All-panel audit

| Panel group | Normal | Pressed | Active | Disabled |
|---|---|---|---|---|
| **Landscape · Light** | Improved fold/route relationship; row-four shadows still meet the crop; regular matrix reading remains. | Bottom contact is strongest; radial shading muddies secondary and chromatic tabs. | Cluster is state-visible, but full rings dominate and Escape remains weak; bottom contact persists. | Depth flattens, but blue/orange/chartreuse remain available-looking; lower clearance is still below target. |
| **Landscape · Dark** | Two fold tiers now read; bottom clearance remains inadequate. | Dark tiers survive, but bright-center face modeling and cropped lower shadows remain. | Active rings are obvious; Escape is not meaningfully stronger than normal; bottom remains unresolved. | Fold tiers survive, but chromatic controls stay prominent while the system tag recedes. |
| **Portrait · Light** | Oblique crown and attached route improve orientation-specific composition; lower docket still reads rectangular/grid-like. | Long legends and circular tabs become muddy under glossy depression shading. | Most outlines register; Escape still relies on a normal-looking dark perimeter. | Role colors remain strong and `Command` is too small/soft for reliable scanning. |
| **Portrait · Dark** | Dark plane hierarchy is now authored and legible; tab stack remains too regular at 25%. | Fold hierarchy survives, but controls read illuminated rather than inset. | Rings carry more hierarchy than the folio; Escape remains the weak active role. | Action colors remain active-looking; system and long secondary legends are disproportionately subdued. |

## Pass 1 — Composition

### C1 — Native row-four shadows still terminate at the landscape boundary

- **Severity:** major
- **Affected panels:** all eight landscape panels; most visible in light/dark pressed and active, least visible in disabled
- **Visible evidence:** The raised folio itself now stops above row four, correcting half of the prior issue. The native `Command`, `Prefix`, and `Palette` footprint does not. In the 492 × 226 landscape render embedded in the exact sheet, non-canvas pixels from these controls occur on source row 225 in normal, pressed, and active. Disabled and dark-normal panels provide only one clean source row, approximately 1.8 artboard px after accounting for the 492:874 render ratio. Several circular Palette shadows end as a flat crop rather than a complete lower curve.
- **Likely cause:** The centered scale and lower-right shadow footprint still consume the canonical row-four clearance; lifting only the passive artwork did not resolve native-material overflow.
- **Concrete correction:** Keep all native centers fixed, but confine row-four shadow/edge output to **y ≤ 397 on the 402 px artboard**, leaving **at least 4 continuous artboard px of untouched canvas** in every state and appearance. In the next contact sheet this must produce **at least three fully clean source-pixel rows** beneath every row-four face and shadow, with no flattened circular edge.

### C2 — The new folio ledges do not survive as a ragged tab stack at 25%

- **Severity:** major
- **Affected panels:** all 16 panels
- **Visible evidence:** At full resolution, landscape now has stepped upper and inner edges and portrait has an oblique crown. At 25%, those changes merge into one horizontal cap in landscape and one rectangular lower docket in portrait. The equal native squares/circles still form three rigid columns over two large shared rectangles, so the first structural reading is “keypad on a mount,” not a stack of die-cut editorial tabs. The repeated narrow notches beside Right/Escape/Palette look like a stitched spine at full size but do not establish semantic grouping at thumbnail size.
- **Likely cause:** Most silhouette changes occur above or outside the controls, while the passive fields behind the role groups remain broad and continuous. The setbacks are too shallow or too closely stacked to alter the cluster's thumbnail contour.
- **Concrete correction:** Without moving native frames, make **at least three 10–16 artboard-px role-specific setbacks/ledges** survive around the movement, primary/secondary, and Escape/Palette groups. Separate the large shared fields enough that portrait and landscape each show an uneven inner/right contour at 25%. Success is a two-second 25% read of “ragged tab docket” before any legend is legible, while the cluster still outweighs the route by at least **3:1**.

### C3 — Route endpoints are corrected, but registration marks vanish at overview scale

- **Severity:** minor
- **Affected panels:** all 16 panels
- **Visible evidence:** The landscape route now leaves the folio beside Escape and meets the system centerline; the portrait route begins beside Palette and terminates below the system tag. The upper/right negative space now feels deliberate and remains calm. However, the open L marks reduce to isolated sub-pixel specks or disappear in the 25% sheet, so they do not reinforce the intended proofing/measurement vocabulary.
- **Likely cause:** Registration-gray contrast and 1× stroke coverage are too low after contact-sheet reduction, especially over light stock and the dark carbon ground.
- **Concrete correction:** Keep every bracket 10 px from controls and preserve the route's current weight, but tune each **6–10 px open L** so a complete pair remains identifiable at 25% in light and dark. Do not add nodes, circles, crosshairs, or more marks; route plus brackets must remain below **one-third of the cluster's apparent area**.

## Pass 2 — Material and craft

### M2 — Native tabs still use glossy spotlight modeling instead of matte paper craft

- **Severity:** major
- **Affected panels:** all 16 panels; strongest in all four pressed panels
- **Visible evidence:** Pressed Return/Tab show bright blue centers and dark borders; pressed Command/Prefix show light centers with a dark vignette; pressed Escape/Palette read as shaded beads. Normal movement tabs retain soft multi-side halos, and active outlines diffuse beyond a crisp cut edge. The apparent light changes by material and state instead of consistently arriving from 315°.
- **Likely cause:** Face gradient/gloss and blurred elevation remain stronger than the cut edge, ply, and compact lower-right contact shadow. Pressed is being communicated through radial tonal modeling rather than shadow collapse and inset edge logic.
- **Concrete correction:** Limit interior face variation outside fine tooth to **≤3% tonal variance**; use a crisp **1 px cut edge**, **1–2 px ply**, and a shadow confined to **2–3 px lower-right** with no visible upper-left halo. Pressed faces must darken uniformly **8–12%**, remain center-anchored at **0.96–0.97**, and reduce cast-shadow depth by **≥60%**. No radial or spotlight gradient may remain at 100%.

### M3 — Long legends remain below the demonstrated size/clarity bar

- **Severity:** major
- **Affected panels:** all 16 panels; strongest for `Command` in landscape and for `Command`, `Prefix`, `Escape`, and `Palette` in pressed/disabled panels
- **Visible evidence:** `Command` is still visibly smaller and lighter than neighboring labels. In the exact landscape render, its dark cap strokes occupy about four contact-sheet source pixels, roughly 7 artboard px at the 492:874 scale, so this sheet does not demonstrate the required 9 px cap height. Pressed gradients run through long words, while disabled `Command` and the dark-mode secondary legends lose effective stroke clarity. No hard ellipsis appears, but “present” is not the same as reliably legible.
- **Likely cause:** Auto-fit is shrinking the longest native string to preserve one line, and state-dependent shading reduces the already small glyph strokes.
- **Concrete correction:** At the unscaled artboard, render `Command`, `Palette`, `Escape`, `Return`, and `Prefix` single-line at **≥9 px cap height**, with **≥4 px clear space on both sides** and flat tone beneath the glyphs. Verify **≥4.5:1 normal** and **≥3:1 disabled** contrast in both appearances. The next exact sheet must allow every word to be read at 100% without enlargement.

## Pass 3 — Interaction

### I1 — Disabled chroma reduction is far short of the specified 55–70%

- **Severity:** major
- **Affected panels:** all four disabled panels
- **Visible evidence:** At 25%, disabled is still identified mainly by missing depth. Exact rendered dominant-face samples show only small HSV-saturation changes in light mode: ultramarine is approximately **0.74 → 0.70**, orange **0.77 → 0.73**, and chartreuse **0.65 → 0.62**. In dark mode, ultramarine and chartreuse saturation slightly increase even as value drops. The colored action keys therefore continue to solicit attention, while the disabled system tag nearly disappears.
- **Likely cause:** Disabled applies darkening/flattening but little true chroma reduction, with inconsistent attenuation across semantic materials.
- **Concrete correction:** Reduce role chroma by **55–70% from each normal face**, remove the fiber highlight, flatten the cast shadow, and replace role edges with one quiet neutral cut edge. Keep every disabled legend at **≥3:1**. At 25%, every disabled panel must be identifiable without its caption and no chromatic tab may compete with its normal counterpart.

### I2 — Escape active remains indistinct and the other active cues remain perimeter rings

- **Severity:** major
- **Affected panels:** all four active panels
- **Visible evidence:** Movement, primary, secondary, utility, and system roles gain obvious full outlines. Escape gains a dense perimeter that overlaps the same dark edge/lower-right shadow already present in normal. The difference can be found only under full-resolution side-by-side scrutiny and disappears at 25%. The complete outlines read as selection rings, not editorial registration indices.
- **Likely cause:** Escape's active color duplicates its normal edge/shadow family, and active geometry is a material-wide perimeter rather than a distinct index absent from normal.
- **Concrete correction:** Give every role one crisp **2 px registration index**, visibly absent in normal and with **≥3:1 face contrast**, while keeping active geometry at **0.99–1×**. For Escape, change the index's geometry or placement rather than only its dense-ink color. At 25%, Escape active must be as immediately distinguishable from Escape normal as movement active is from movement normal, without glow or a complete ring.

### I3 — Pressed state remains a vignette/illumination effect rather than a physical depression

- **Severity:** major
- **Affected panels:** all four pressed panels
- **Visible evidence:** Pressed controls are distinguishable from normal, and their centers generally remain fixed. The dominant cue is still center-to-edge shading: blue and stock faces brighten centrally, orange/chartreuse become orb-like, and broad shadows remain visible. The result suggests internal illumination or dimming rather than a die-cut tab entering its recess.
- **Likely cause:** The renderer's face gradient and halo persist after scaling, while the inset edge and shadow-collapse cues remain too weak.
- **Concrete correction:** Preserve centered **0.96–0.97 scale**, apply only uniform **8–12% darkening**, reduce cast shadow by **≥60%**, narrow the upper-left highlight, and add no more than a **1 px inner lower-right edge**. Side by side at 25%, pressed must read as lower elevation; at 100%, it must introduce no new gradient direction.

## Acceptance-criteria audit

| Criterion | Result | Reason |
|---|---|---|
| 1. All 16 combinations; independent portrait | Pass | All combinations are present, and portrait uses a distinct tall route and crown fold. |
| 2. Cluster-first hierarchy and ragged read at 25% | Partial | Cluster wins and exceeds route area, but the ragged tab/docket idea still collapses into a keypad mount. |
| 3. Alignment, clearance, no clipping/tangencies | Fail | Route endpoints are improved, but row-four native output still reaches the landscape crop. |
| 4. Legend/index contrast | Fail by rendered evidence | Escape lacks a 25%-visible active index; disabled and micro-legend clarity are not reliably demonstrated. |
| 5. Long-label fit | Fail | Full strings remain, but the evidence does not sustain the specified 9 px cap-height bar for `Command`. |
| 6. Four distinct native states | Fail | Disabled chroma, Escape active, and pressed depression remain unresolved. |
| 7. Lighting, texture, seams, fold logic | Fail | Dark fold tiers now pass, but native-face gradients/halos and clipped lower shadows violate the material bar. |
| 8. Originality and prohibited motifs | Pass | No copied mark, proprietary glyph arrangement, hardware shell, vent, port, screw, or recognizable console trade dress is visible. |

## Originality / trade-dress check

No trade-dress blocker is visible. The asymmetric scored folio, editorial route, open registration marks, and role-color sequence remain legally distinct from the prohibited console, calculator, keyboard, and stationery references. The new oblique portrait crown and stepped landscape planes strengthen the original Foldline vocabulary. The remaining keypad reading is a weakness of silhouette execution, not evidence of copying.

## Optional taste notes — not defects

- Do not fill the upper/right field. Contact sheet 2 shows that endpoint alignment, rather than added ornament, is enough to make the negative space intentional.
- The restrained one-orange-handoff route is appropriate; C3 asks only for bracket survival at 25%, not a brighter or more complex line.

## Final verdict

**`revise`** — there are no blockers and the dark fold hierarchy plus route relationship improved, but seven unresolved major findings prevent a visual pass. Prioritize complete landscape bottom clearance, a thumbnail-legible ragged folio, and replacement of glossy state shading with matte, materially distinct pressed/active/disabled behavior.
