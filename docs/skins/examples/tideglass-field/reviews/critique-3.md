# Tideglass Field — Independent Visual Critique, Pass 3

**Evidence reviewed:** `reviews/contact-sheet-3.png` (2176 × 1714), inspected at full raster resolution and as an exact 25% Lanczos reduction (544 × 428).
**Comparison evidence:** `reviews/contact-sheet-1.png`, `reviews/contact-sheet-2.png`, `reviews/critique-1.md`, and `reviews/critique-2.md`.
**Criteria:** `reviews/art-direction.md` and the Thumble visual quality bar.
**Verdict:** **revise**

Pass 3 resolves the dark Disabled boundary failure and removes the portrait delta shoulder whiskers. The three-mass landscape, portrait hierarchy, legends, contours, and state geometry show no visible regression. The A/B Active treatment is materially improved and now separates from Normal at 25%, but its portrait raster still does not provide the required continuous 1.5–2 px, ≥3:1 perimeter. One prior major therefore remains unresolved; a visual pass is not available.

## Required audit summary

| Required audit | Pass-3 result | Exact rendered evidence |
|---|---|---|
| Dark Disabled boundaries are visible and ≥3:1 | **Resolved** | In Landscape · Dark · Disabled, a representative continuous movement edge is approximately `(91,121,119)` against well `(5,47,53)`, about **3.04:1**; stronger edge samples reach about 3.24:1. Portrait movement, utility, action, and system edge cores range from approximately **3.25:1 to 4.28:1** against the same well. Every Disabled control remains boxed at 25%, including the portrait rail. |
| A/B Active perimeter width and contrast | **Partial / fail** | Both landscape Active panels now carry a roughly two-pixel perimeter with representative light samples around `(207,151,142)` and `(191,128,121)` against face `(87,56,60)`, about **4.16:1** and **3.23:1**. In Portrait · Light · Active, however, the straight A edge reduces to one near-threshold core pixel around `(165–166,123–124,117)` plus an inner antialiased pixel around `(143,96,94)` against adjacent face `(82,53,58)`: approximately **2.96–2.98:1** and **2.07:1**. The side therefore is neither a continuous ≥3:1 band nor a solid 1.5–2 px index. |
| A/B Active thumbnail distinction | **Resolved visually** | At exact 25%, both portrait and landscape Active A/B are now distinguishable from Normal within two seconds. The distinction is carried by a pale perimeter and a substantial face lift; it no longer disappears as in pass 2. |
| Portrait delta shoulder whiskers | **Resolved** | Across all eight portrait panels, both neck-to-delta shoulder edges terminate at the filled silhouette. No line or shadow pixels project into empty canvas as they did in pass 2. |

## Prior-finding audit

| Pass-2 finding | Pass-3 status | Audit |
|---|---|---|
| **M-01** — Dark Disabled controls lose their material boundary | **Resolved** | The muted fills remain visibly unavailable, while continuous light edges now clear 3:1 in the rendered raster and survive the 25% sheet. Labels remain above 3:1 and the controls no longer reduce to floating legends. |
| **I-01** — A/B Active index is under-width and under-contrast | **Unresolved, improved** | Landscape width/contrast and all-orientation thumbnail distinction now pass. Portrait, especially Portrait · Light · Active, still falls just below 3:1 on its straight perimeter and has only one near-threshold core pixel plus antialiasing. |
| **M-05** — Portrait movement-delta shoulder artifacts | **Resolved** | The left and right whiskers are absent at full resolution in every portrait panel. |

No resolved pass-1 or pass-2 finding visibly regressed.

# Pass 1 — Composition

## Composition result: no defect

All eight landscape panels preserve the broad movement shelf, narrow central sampling bridge with lower terrace, and tapered action shelf as three connected but separate masses. Their overlaps and unequal ends remain legible at 25%, so the silhouette does not return to the single commercial-controller front plate rejected in pass 1. Movement and action grouping is immediate, while the central contour span reads as measured distance rather than vacant space.

Portrait remains independently composed. The upper action shard, centered system junction, alternately notched sounding neck, separate right-side tide-gauge rail, and broad lower movement delta retain the intended top/bottom counterweight in light and dark. The former shoulder-line removal does not flatten or disconnect the delta. Native centers stay inside their basins, outer artwork remains unclipped, and no new 4–8 px tangency is visible.

Focal hierarchy also holds: A/B first, movement mass second, utility bridge/rail third, and contour/datum detail last. Normal, Pressed, Active, and Disabled do not alter the silhouette or control geometry.

# Pass 2 — Material and craft

## Material result: no new defect

The edge and lighting system remains coherent at full resolution. Milky edges stay upper-left, dense edges and compact shadows stay lower-right, wells remain hard-edged rather than blurred, and no glow has been introduced to solve contrast. Light and dark still read as separately authored appearances.

The pass-3 Disabled edges are brighter but remain neutral and flat, so they preserve unavailable material rather than resembling coral Active indices. Movement, action, utility/menu, and system controls remain visible in both dark Disabled panels at 25%. A/B, arrows, system, Select, and Start legends remain centered, unwarped, and readable at full resolution; the small utility legends remain recognizable marks at 25%. The brighter Active A/B faces do not reduce legend contrast below the established 7:1 floor.

Contours remain subordinate and orientation-specific, with no visible moiré, concentric control echo, or crossing into control faces. Grain disappears at 25% as required. Coral datum marks and brass sounding points remain sparse, asymmetrical, and non-tappable. There is no full-canvas seam, stacked landscape halo, clipped contour, banding, stray path cap, or new raster artifact.

# Pass 3 — Interaction

## I-01 — Portrait A/B Active perimeter still misses the final-raster width/contrast requirement

- **Severity:** `major`
- **Affected panels:** Portrait · Light · Active and Portrait · Dark · Active; the contrast miss is clearest on light A/B. The four landscape Active A/B controls now pass this specific check.
- **Visible evidence:** At full resolution, the landscape perimeter has two useful pixels and clears 3:1, but the portrait's smaller presentation downsamples the same treatment to one near-threshold core plus a low-contrast inner antialias. On the straight light A edge, representative core-to-adjacent-face contrast is only **2.96–2.98:1** and the inner pixel is about **2.07:1**. The current authoring width therefore does not produce a continuous 1.5–2 px, ≥3:1 perimeter in the exact contact-sheet raster. At 25%, Active is now meaningfully distinguishable, but much of that distinction comes from an overdriven face lift: same-position rendered samples rise by roughly **26–29% luminance** from Normal to Active rather than the specified 6–8%.
- **Likely cause:** The current 3.5-unit action Active stroke maps to only about **1.36 px** in the 156 px-wide portrait artboard shown on the contact sheet, so antialiasing dilutes its straight sides. The stronger custom Active fill is compensating for the lost perimeter instead of letting the coral index carry the state.
- **Concrete correction:** Keep all native frames fixed, but increase the supported A/B Active stroke enough that the next final portrait raster contains a continuous two-pixel coral core whose straight sides each measure **≥3.1:1** against the adjacent face in light and dark. Then return the same-position A/B face luminance lift to **6–8%**. The exact 25% sheet must retain the present two-second Active/Normal distinction without relying on an oversized fill change.

### Interaction checks that pass

- No control frame, label, or center shifts between states.
- Pressed remains center-anchored, darker, saturated, and physically inset.
- Disabled remains flatter, muted, desaturated, and clearly distinct from Pressed in every orientation/appearance at 25%.
- Active movement, utility/menu, and system indices remain crisp, coral, visible, and non-glowing.
- Dark Disabled boundaries now remain visible without turning into coral or luminous edges.
- Native controls and legends remain unobscured by artwork.

# Originality and trade-dress check

**Pass.** Landscape continues to derive its silhouette from three asymmetric hydrographic shelf masses rather than a single hardware enclosure. Portrait remains an independently authored shard/neck/rail/delta composition. The bathymetric contours, coral datum notches, sounding points, palette, and legend treatment form a coherent original grammar.

No manufacturer mark, model typography, screen or bezel hierarchy, vent, speaker slot, screw pattern, compass rose, proprietary glyph, fake control, or recognizable commercial handheld outline is visible. The unresolved Active-raster issue is an interaction/craft defect, not an originality concern.

# Defects versus optional taste

The sole unresolved finding enforces explicit Active width, contrast, and fill-lift criteria. It is not a request for additional decoration. There are no optional taste changes in this pass; do not add glow, grain, contours, datum marks, or new silhouette detail to compensate.

# Final verdict

**`revise`**

Pass 3 has **no blockers, one unresolved major, and no new minor findings**. Dark Disabled boundaries and portrait shoulder artifacts are resolved, composition and craft remain stable, and Active A/B now works at thumbnail scale. A final visual pass still requires the portrait A/B perimeter itself—not an oversized face lift—to meet the 1.5–2 px and ≥3:1 final-raster requirement.

**Report path:** `docs/skins/examples/tideglass-field/reviews/critique-3.md`

## Three highest-priority findings

1. **I-01 (`major`, unresolved):** portrait A/B Active straight sides remain effectively one near-threshold pixel, measuring about 2.96–2.98:1 rather than a continuous 1.5–2 px, ≥3:1 perimeter.
2. **M-01 audit (`resolved`):** all dark Disabled controls now retain visible ≥3:1 edge cores and remain boxed at exact 25%.
3. **M-05 audit (`resolved`):** both portrait delta shoulder whiskers are removed in all appearances and states with no composition regression.
