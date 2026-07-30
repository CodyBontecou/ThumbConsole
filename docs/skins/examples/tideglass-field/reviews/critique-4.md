# Tideglass Field — Independent Visual Critique, Pass 4

**Evidence reviewed:** `reviews/contact-sheet-4.png` (2176 × 1714), inspected at full raster resolution and as an exact 25% Lanczos reduction (544 × 428).
**Comparison evidence:** `reviews/contact-sheet-1.png` through `reviews/contact-sheet-3.png` and `reviews/critique-1.md` through `reviews/critique-3.md`.
**Criteria:** `reviews/art-direction.md` and the Thumble visual quality bar.
**Verdict:** **revise**

Pass 4 restores the required A/B face lift and keeps Active distinct at 25%. Portrait A now has a continuous two-pixel, ≥3.1:1 straight-side perimeter in both appearances. Portrait B does not: its leading side still contains one strong core pixel followed by a second pixel below 3.1:1. The wider treatment also creates a three-pixel full-contrast trailing edge on landscape A/B, regressing the prescribed 1.5–2 px index weight. The sole pass-3 major therefore remains unresolved, and a visual pass is not available.

## Required pass-4 audit

| Required audit | Pass-4 result | Exact rendered evidence |
|---|---|---|
| Portrait A two-pixel straight sides in Light Active | **Pass** | Over the 21 px straight run, the two left-side pixels remain **3.744–4.080:1** and **3.121–3.722:1** against the flat active face; the two right-side pixels remain **3.561–3.885:1** and **3.680–3.920:1**. |
| Portrait A two-pixel straight sides in Dark Active | **Pass** | Over the 21 px straight run, the left pair remains **4.277–4.662:1** and **3.556–4.255:1**; the right pair remains **4.021–4.462:1** and **4.224–4.482:1**. |
| Portrait B two-pixel straight sides in Light Active | **Fail** | The trailing side passes, with two cores at **4.337–4.397:1** and **3.277–3.332:1**. Across the full 19 px leading straight run, however, the outer core is **4.314–4.378:1** while the adjacent inner pixel is only **2.228–2.260:1**. Only one pixel clears 3.1:1. |
| Portrait B two-pixel straight sides in Dark Active | **Fail** | The trailing side passes at **5.005–5.060:1** and **3.368–3.751:1**. Across the 20 px leading straight run, the outer core is **4.975–5.130:1**, but the adjacent inner pixel is only **2.455–2.844:1**. Again, only one pixel clears 3.1:1. |
| A/B Active face lift remains 6–8% | **Pass** | Repeated unobstructed same-position face samples move from `(77,50,55)` to `(79,52,57)` in light, a **6.74%** relative-luminance lift, and from `(69,46,50)` to `(73,47,52)` in dark, a **7.19%** lift. The pass-3 26–29% over-lift is gone. |
| Active remains distinct at exact 25% | **Pass** | In the 544 × 428 reduction, portrait and landscape A/B Active remain distinguishable from Normal within two seconds. The perimeter now carries the distinction; the corrected face lift does not need to overdrive the state. |
| No regression elsewhere | **Partial / fail** | All Normal, Pressed, and Disabled panels are pixel-identical to pass 3. Of 12,361 pass-3-to-pass-4 changed pixels, 12,345 belong to the eight A/B components in the four Active panels; the other 16 are isolated, visually inert antialias pixels. Composition and non-action states do not regress. The landscape A/B trailing perimeter does regress from two to three full-contrast pixels, detailed below. |

## Prior-finding audit

| Prior finding | Pass-4 status | Audit |
|---|---|---|
| **I-01** — Portrait A/B Active perimeter width/contrast and face lift | **Unresolved, narrowed** | Portrait A passes in both appearances; portrait B's leading side remains one full-contrast pixel plus one sub-threshold pixel. The face lift and exact-25% distinction now pass. |
| **M-01** — Dark Disabled boundaries | **Resolved, unchanged** | Both Disabled panels are pixel-identical to pass 3. Controls remain boxed, unavailable, and legible at 25%. |
| **M-05** — Portrait delta shoulder whiskers | **Resolved, unchanged** | All portrait non-Active panels are pixel-identical, and the Active silhouette shows no returning shoulder projection. |
| **C-01 / M-02 / M-03 / M-04 / I-02** | **Resolved, unchanged** | Three landscape shelf masses, legend contrast, seam removal, edge simplification, and Pressed/Disabled separation remain intact. |

# Pass 1 — Composition

## Composition result: no defect

Landscape still reads as three connected hydrographic masses: broad movement shelf, narrow sampling bridge/lower terrace, and tapered action shelf. Their overlaps and unequal ends survive 25% reduction and do not return to the pass-1 commercial front-plate silhouette.

Portrait remains separately composed as an upper action shard, centered system junction, alternating sounding neck, right tide-gauge rail, and lower movement delta. The A/B stroke change does not move native frames, alter the silhouette, disturb negative space, or change the intended action-first hierarchy. There is no clipping, accidental tangency, or state-dependent layout shift.

# Pass 2 — Material and craft

The shell, wells, contours, grain, datum marks, and sounding points are unchanged and retain coherent upper-left lighting with compact lower-right depth. Legends remain centered and readable; no glow, seam, whisker, banding, contour crossing, or new raster artifact is visible.

The Active A/B edge is not yet uniformly crafted. Portrait B's leading side is visibly softer than its trailing side at 100%, while landscape A/B gain an overweight trailing side. This is part of I-01 rather than an optional request for more decoration.

# Pass 3 — Interaction

## I-01 — A/B Active perimeter remains scale- and alignment-dependent

- **Severity:** `major`
- **Affected panels:** Portrait · Light · Active and Portrait · Dark · Active, specifically B's leading straight side; Landscape · Light · Active and Landscape · Dark · Active, specifically the trailing straight sides of both A and B.
- **Visible evidence:** Portrait A now holds two continuous ≥3.1:1 pixels on both straight sides. Portrait B does not. Its leading side carries one strong pixel, but the second stays at only **2.228–2.260:1** in light and **2.455–2.844:1** in dark throughout the straight run. In landscape, the correction expands the A trailing edge to three adjacent core pixels measuring approximately **3.67:1, 3.49:1, and 5.44:1** in light and **4.17:1, 4.00:1, and 6.33:1** in dark. B similarly reaches **3.28:1, 3.79:1, and 4.86:1** in light and **3.66:1, 4.36:1, and 5.67:1** in dark. That exceeds the prescribed 1.5–2 px index and gives the landscape action controls a heavier trailing rim than other Active controls.
- **Likely cause:** The current uniform 5.5-unit A/B Active stroke lands on different final-raster subpixel phases for portrait A and B. B's leading edge loses its second core during downsampling, while the same source width maps to three full-contrast pixels on the larger landscape presentation.
- **Concrete correction:** Keep all frames and the current A/B face colors fixed, but make the supported Active stroke width/alignment scale-aware. In the next exact sheet, every row of portrait B's straight leading run must contain **two adjacent pixels each ≥3.1:1** in light and dark, while every landscape A/B straight side contains **no more than two** full-contrast core pixels. Preserve portrait A's present passing edges, the **6–8%** face lift, and the current two-second Active/Normal distinction at exact 25%.

### Interaction checks that pass

- Active A/B face lift is back inside 6–8% in both appearances.
- Active A/B remains meaningfully distinct from Normal at exact 25%.
- Pressed remains darker, center-anchored, and inset; Disabled remains flatter, muted, and clearly unavailable.
- No frame, center, or legend shifts between states.
- Movement, utility/menu, and system Active indices remain visible, crisp, and non-glowing.
- Dark Disabled controls remain legible and materially bounded.

# Originality and trade-dress check

**Pass.** Landscape remains an asymmetric three-shelf hydrographic transect, and portrait remains an independently authored shard/neck/rail/delta composition. The bathymetric contours, sparse coral datum marks, oxidized-brass sounding points, palette, and native legend system remain an original visual grammar.

No manufacturer mark, model typography, screen/bezel hierarchy, vent, speaker slot, screw pattern, compass rose, proprietary glyph, fake control, or recognizable commercial handheld outline is visible. The remaining defect is a native-state raster/craft issue, not an originality issue.

# Defects versus optional taste

I-01 enforces the written two-pixel, ≥3.1:1 Active perimeter and 1.5–2 px index-weight requirements. It is not a request for extra decoration. There are no taste-only changes: do not add glow, grain, contours, datum marks, or silhouette detail to compensate.

# Final verdict

**`revise`**

Pass 4 has **no blockers, one unresolved major, and no separate minor findings**. Portrait A, face lift, thumbnail distinction, and all previously resolved defects pass. Portrait B still lacks a continuous two-pixel ≥3.1:1 leading edge, and landscape A/B now carry a three-pixel trailing edge. A `visual-pass` is therefore not justified.

**Report path:** `docs/skins/examples/tideglass-field/reviews/critique-4.md`

## Three highest-priority findings

1. **I-01 (`major`, unresolved):** portrait B's leading Active side has only one ≥3.1:1 core pixel in both light and dark; the second remains 2.228–2.844:1.
2. **Regression within I-01:** landscape A/B trailing Active sides now render three full-contrast core pixels instead of the prescribed maximum of two.
3. **Resolved and must be preserved:** A/B face lift is 6.74% light / 7.19% dark, portrait A passes its two-pixel perimeter audit, and Active remains distinct at exact 25%.
