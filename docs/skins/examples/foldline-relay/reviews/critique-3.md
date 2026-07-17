# Foldline Relay — Independent Visual Critique 3

- **Evidence reviewed:** `reviews/contact-sheet-3.png`
- **Comparison evidence:** `reviews/contact-sheet-1.png`, `reviews/contact-sheet-2.png`, `reviews/critique-1.md`, and `reviews/critique-2.md`
- **Evidence dimensions:** 2176 × 1714 px
- **Inspection scales:** exact full-resolution PNG, source-pixel panel/control crops, and an exact 25% overview at 544 × 429 px
- **Art direction:** `reviews/art-direction.md`
- **Quality bar:** PocketPad visual quality bar
- **Verdict:** `revise`

Contact sheet 3 contains all 16 required native-renderer combinations. The stepped folio silhouette now survives the 25% view, the open brackets remain detectable, dark tiers and route hierarchy have not regressed, and the native faces no longer use the radial spotlight treatment seen in sheets 1–2. Disabled chroma and physical tab depression are also materially clearer. A visual pass is still blocked by three major findings: the landscape lower clearance remains below the explicit source-pixel target, `Command` remains below the required cap height, and active styling replaces secondary/utility role colors while retaining complete selection rings instead of discrete registration indices.

## Prior-finding audit

| Critique-2 finding | Pass-3 status | Evidence in contact sheet 3 |
|---|---|---|
| C1 — row-four landscape output reaches the lower boundary | **Unresolved — improved** | No face or circular contour is visibly cut now, but only the final source row is untouched in light pressed/disabled; normal/active generally leave two clean rows. The required three fully clean source rows are not present across all eight landscape panels. |
| C2 — generic keypad rather than ragged folio | **Resolved** | Three stepped shoulders remain visible across the landscape top edge; separate row fields and the notched Escape/Palette rail produce an uneven inner contour. Portrait retains its oblique crown and staggered right edge. These survive at 25%. |
| C3 — brackets disappear at overview scale | **Resolved** | Both registration positions survive as paired ticks at 25% in light and dark; at full resolution each remains an open L rather than a node, target, or fake control. |
| M1 — dark fold tiers collapse | **Remains resolved; no regression** | Canvas, lower field, raised plane, score edge, and stepped shoulder remain independently traceable in all eight dark panels at full resolution and 25%. |
| M2 — glossy/haloed tabs | **Resolved** | Normal faces are flat, edges are crisp, shadows are compact and lower-right, and pressed faces darken without the former bright-center vignette. |
| M3 — long-label size and clarity | **Unresolved** | `Prefix`, `Escape`, `Palette`, and `Return` now read reliably, but `Command` retains the same approximately four-source-pixel cap height seen in sheet 2. |
| I1 — disabled state remains too chromatic | **Resolved** | Blue, orange, and chartreuse become slate, muted clay, and gray-green; depth and edge treatment also flatten. Disabled is immediately separable from normal at 25% while role grouping remains understandable. |
| I2 — Escape active absent; other roles use full rings | **Unresolved — partly corrected** | Escape now has an unmistakable dense-ink active perimeter, and every role changes. Complete rings remain, however, and secondary/utility face colors are replaced rather than indexed. |
| I3 — pressed reads as illumination rather than depression | **Resolved for the tab stack; minor system-role residue** | Square and circular tabs now scale inward, darken uniformly, and lose most cast shadow. The isolated dark pressed system tag still sinks too close to the canvas value. |

## All-panel audit

| Panel group | Normal | Pressed | Active | Disabled |
|---|---|---|---|---|
| **Landscape · Light** | Ragged folio and route hierarchy survive; `Command` is undersized; bottom clearance remains tight. | Tabs read physically lower and matte; lower shadow reaches the penultimate source row; `Command` remains fragile. | Escape is finally distinct, but full rings and periwinkle secondary/utility faces disrupt role color; lower margin remains short. | Desaturation is clear and legends remain readable; lower shadow still leaves only one fully untouched row in the weakest case. |
| **Landscape · Dark** | Two paper tiers and score line survive; route remains subordinate; `Command` is still too small. | Depression works on the stack, but the isolated system tag nearly merges with the carbon canvas. | Indices are visible and crisp, but complete rings plus face-color replacement flatten the normal role hierarchy. | Disabled reads unavailable without losing the fold structure; no chromatic control competes with normal. |
| **Portrait · Light** | Independent crown, vertical route, brackets, and ragged right edge read at 25%; `Command` remains the micro-legend. | Matte depression replaces the former orb/vignette effect. | Escape is visible, but secondary stock and Palette chartreuse both become periwinkle under the active treatment. | Chroma, depth, and edge attenuation are distinct while all roles remain locatable. |
| **Portrait · Dark** | Dark tiering, long route, and negative space remain balanced. | Tab depression works; the top system tag is too faint at 25%. | Full rings carry more visual weight than the editorial index grammar, and active face replacement weakens the Palette terminal accent. | Role grouping remains readable and the system tag no longer disappears as it did in sheet 2. |

## Pass 1 — Composition

The cluster wins the first glance in both orientations at 25%, remains comfortably above the route's apparent area, and the large upper/right fields read as deliberate proofing space. Landscape is now a low stepped packet; portrait is a separately composed docket rather than a rotation. Route endpoints remain attached to the command side and system centerline, and the orange handoff remains a turn rather than a node. The dark tiers, route, negative space, and bracket placements show no regression.

### C1 — Lower clipping is gone, but the required landscape clearance is still not achieved

- **Severity:** major
- **Affected panels:** all eight landscape panels; tightest in Landscape · Light · Pressed and Landscape · Light · Disabled
- **Visible evidence:** The Palette curve and row-four rectangles now close before the canvas edge, so there is no flat crop. In each 492 × 226 embedded landscape render, however, light pressed/disabled shadow antialiasing remains on source row 224 and only row 225 is fully untouched. Normal/active generally leave rows 224–225 clean, while non-canvas output remains on row 223. At the 492:874 render scale, one to two clean rows represent only about 1.8–3.6 artboard px, below the 4 px minimum and the prior requirement for three clean source rows.
- **Likely cause:** The lower-right row-four shadow kernel was tightened enough to complete the contours but still extends one to two raster rows too far after native-renderer downsampling.
- **Concrete correction:** Constrain every row-four edge/shadow to produce **at least three consecutive untouched source rows** at the bottom of all eight landscape renders, equivalent to keeping output at or above the prior **y ≤ 397** artboard limit. The next sheet must show no row-four antialiasing on source row 223.

## Pass 2 — Material and craft

The material revision is visible rather than nominal: spotlight gradients are gone, interior faces remain nearly flat, the cut edges are crisp, and cast shadows sit lower-right instead of haloing all sides. The stepped light and graphite planes share one coherent upper-left light direction. No new seam, glow, fold contradiction, or texture blob is visible at full resolution. One label still misses the explicit craft bar.

### M3 — `Command` remains an undersized micro-legend

- **Severity:** major
- **Affected panels:** all 16 panels; strongest in both landscape appearances and in pressed/disabled states
- **Visible evidence:** `Command` is single-line and untruncated, but its dark cap strokes occupy only source rows 206–209 in the exact landscape normal render: approximately four source pixels, or about **7.1 artboard px** at the 492:874 scale. Portrait yields roughly the same 7–8 artboard-px result after scaling. It is visibly smaller than `Prefix` and loses stroke authority first in pressed and disabled panels. This is effectively unchanged from sheet 2 and remains below the required 9 px cap height.
- **Likely cause:** Native auto-fit still reduces the longest string to preserve existing horizontal padding instead of using a narrower label treatment at the required height.
- **Concrete correction:** Render `Command` at **≥9 artboard-px cap height** while retaining one line and **≥4 artboard px of clear space on both sides**. The next full-resolution sheet must show at least five cap-height source pixels in the landscape render and preserve ≥3:1 disabled contrast.

## Pass 3 — Interaction

Disabled now changes chroma, depth, and edge rather than opacity alone. Pressed square and circular tabs stay center-anchored, shrink without label shift, darken uniformly, and collapse their cast shadows; they read as physical depression instead of illumination. Active is unmistakable for every role, including Escape, but it achieves that distinction with the wrong material hierarchy.

### I2 — Active styling floods role faces and still reads as complete selection rings

- **Severity:** major
- **Affected panels:** all four active panels
- **Visible evidence:** Every active control carries a complete perimeter. Escape's dense ring is now visible at 25%, resolving its former absence, but the other cues remain focus/selection outlines rather than one editorial registration index. More seriously, secondary stock changes from beige to blue-gray and Palette changes from chartreuse to periwinkle. In Landscape · Light, representative face interiors move from approximately **(223, 209, 174) → (203, 212, 232)** for secondary and **(202, 238, 84) → (172, 188, 232)** for utility. The same replacement occurs in dark active. At 25%, this turns the bottom roles into one blue family and removes Palette's terminal chartreuse accent.
- **Likely cause:** The active ultramarine treatment is being applied as a face-wide material override plus a perimeter stroke, instead of only as the specified registration index over the normal role face.
- **Concrete correction:** Preserve the central face color of every active role to match its normal material, and confine the active cue to **one crisp 2 px, non-enclosing registration index**. Use chartreuse for movement/primary/system, ultramarine for secondary/utility, and dense ink for Escape. At 25%, every active role must remain distinguishable from normal while Palette stays chartreuse and Command/Prefix stay secondary stock.

### I3 — The dark pressed system tag nearly disappears

- **Severity:** minor
- **Affected panels:** Landscape · Dark · Pressed and Portrait · Dark · Pressed
- **Visible evidence:** The pressed tab stack retains complete silhouettes, but the isolated top tag becomes nearly the same value as the carbon canvas at 25%; only a faint blue edge locates it. This weakens the route's destination precisely in the pressed panel.
- **Likely cause:** Dense-ink pressed darkening exceeds the useful 8–12% range while the already restrained system edge is attenuated with the shadow.
- **Concrete correction:** Limit system-face pressed darkening to **8–12%** and retain one complete crisp cut edge. At 25%, the whole pill silhouette—not merely a fragment of its blue edge—must remain traceable while still reading lower than normal.

## Acceptance-criteria audit

| Criterion | Result | Reason |
|---|---|---|
| 1. All 16 combinations; independent portrait | Pass | All combinations are present, and portrait has its own crown, vertical route, bracket placement, and docket contour. |
| 2. Cluster-first hierarchy and ragged read at 25% | Pass | Stepped shoulders, separated row fields, and the notched circle rail survive before legends can be read; the cluster remains well above 3:1 apparent area versus the route. |
| 3. Alignment, clearance, no clipping/tangencies | Fail | Curves are no longer clipped, but landscape row-four output still leaves only one or two clean source rows rather than three/≥4 artboard px. |
| 4. Legend/index contrast | Partial | Disabled legends and active cues remain visible, including Escape, but active geometry and face replacement violate the intended index hierarchy. |
| 5. Long-label fit | Fail | All labels remain single-line, but `Command` is still approximately 7–8 artboard px high rather than ≥9. |
| 6. Four materially distinct native states | Fail | Pressed and disabled now pass visually; active remains a face-wide color replacement with complete rings. |
| 7. Lighting, texture, seams, fold logic | Pass | Matte faces, compact lower-right shadows, separate dark tiers, and fold edges are coherent; no glow, spotlight gradient, seam, or texture artifact is visible. |
| 8. Originality and prohibited motifs | Pass | No copied mark, proprietary glyph arrangement, hardware shell, port, vent, screw, or recognizable console/keyboard trade dress is visible. |

## Originality / trade-dress check

No trade-dress blocker is visible. The stepped Thumb Folio, oblique portrait crown, asymmetric Escape/Palette rail, single orange Relay Fold handoff, and open registration brackets form a distinct combination. There are no logos, model names, manufacturer glyphs, faux hardware details, or copied console/calculator silhouettes. The prior generic-keypad concern is now sufficiently answered by the surviving ragged silhouette and role-specific contour. Complete active rings are a generic software-selection convention and weaken the authored editorial language, but they do not create a copying concern.

## Optional taste notes — not defects

- Do not add ornament to the upper/right field. Its current negative-space balance is correct; the remaining issues are in native materials and lower clearance.
- A periwinkle active face could work in another visual system. Here it is a defect because it erases the explicitly assigned secondary-stock and chartreuse role identities, not because blue is inherently undesirable.

## Final verdict

**`revise`** — there are no blockers, but three unresolved major findings prevent `visual-pass`: landscape lower clearance, `Command` cap height, and active face/index behavior. The highest-priority corrections are (1) preserve role fills and replace active rings with discrete 2 px indices, (2) raise `Command` to the measured 9 px cap-height minimum, and (3) guarantee three clean source rows beneath every landscape row-four shadow.
