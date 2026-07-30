# Pale Cavern — Independent Visual Critique 1

- **Evidence reviewed:** `reviews/contact-sheet-1.png`
- **Verified SHA-256:** `cea87ee3b9cf485e1c214c9952075d7406c309a9393d880e56052a8d019c40cb`
- **Evidence dimensions:** 2176 × 1714 px
- **Panel count:** 16 — portrait and landscape, light and dark, normal, pressed, active, and disabled
- **Inspection scales:** exact PNG at full resolution, source-pixel panel crops, and a 25% overview at 544 × 429 px
- **Criteria:** `reviews/art-direction.md` and the Thumble visual quality bar
- **Verdict:** `revise`

All 16 native-renderer combinations are present, native frames stay fixed between states, labels remain readable at full sheet resolution, and no prohibited game, character, logo, or hardware motif is visible. Portrait is genuinely recomposed rather than rotated. The result is not ready for a visual pass: the portrait bridge replaces the requested cavern air with a broad blank spine, custom/system landings create cramped hardware-like compound contours, the mineral-lamina idea becomes a generic flat controller deck at thumbnail size, pressed controls look radially shaded rather than physically depressed, dark active action boundaries disappear into their tint, and disabled face contrast is compressed beyond the specified range.

## Panel coverage

| Panel | Full-resolution and 25% observation |
|---|---|
| Landscape · Light · Normal | Movement and action read first, but broad rounded wells and uniform planes make the shell feel like a flat controller palette. The square system mount and tight double contour at the action well’s right edge are visible. |
| Landscape · Light · Pressed | State is distinguishable, but faces develop a bright-center/dark-perimeter model rather than a directional matte depression. Square system mount and right-edge contour remain. |
| Landscape · Light · Active | Cyan indices are clear on all roles and do not overpower the controls. The passive artwork still reads flat, and the system mount becomes a square-plus-circle compound contour. |
| Landscape · Light · Disabled | Labels remain readable, but movement, utility/menu, and system faces flatten almost into their wells; role depth becomes uneven relative to the still-prominent pale action group. |
| Landscape · Dark · Normal | Separate dark appearance is evident. The upper and lower shell planes survive at full size but weaken at 25%; native controls provide more material identity than the shell. |
| Landscape · Dark · Pressed | Pressed shading is symmetrical and halo-like, especially on movement and action faces, conflicting with the upper-left light direction. |
| Landscape · Dark · Active | Movement, custom, utility/menu, and system indices are clear. The pale-cyan primary/secondary action fills absorb their cyan perimeter, so the focal action roles rely mainly on tint. |
| Landscape · Dark · Disabled | Movement and compact-role face boundaries become very weak at 25%; action faces remain much more materially present than other disabled roles. |
| Portrait · Light · Normal | Orientation-specific upper/lower chambers are present, but the approximately 163 px-wide blank bridge reads as a missing central panel. The utility shelf sits in a 7 px near-gap, while fused R/L and system landings resemble hardware tabs. |
| Portrait · Light · Pressed | The same underfilled central spine and fused landings remain; pressed faces add radial center lighting rather than a clean inset edge. |
| Portrait · Light · Active | Active indices are clear, but they amplify the stacked contours around the square system tab and nearly full-width custom rail mounts. |
| Portrait · Light · Disabled | The bridge remains visually unresolved. Movement, custom, utility/menu, and system faces lose too much separation from their wells even though legends remain legible. |
| Portrait · Dark · Normal | The broad bridge becomes a nearly featureless navy column. Upper pale action faces dominate lower movement at 25%, so the requested chamber balance is weak. |
| Portrait · Dark · Pressed | Radial pressed shading persists; the blank spine and tiny bridge-to-utility gap are especially evident against the dark canvas. |
| Portrait · Dark · Active | Most indices survive, but primary/secondary action perimeters merge with pale-cyan active faces. The system circle reads as a cyan ring inside a square plug. |
| Portrait · Dark · Disabled | Lower movement and right-side compact roles reduce toward legends on a dark field, while the upper action cluster remains materially conspicuous. |

# Pass 1 — Composition

## C-01 — The portrait bridge fills the cavern air with an under-composed blank spine

- **Severity:** `major`
- **Affected panels:** all eight portrait panels; strongest in Portrait · Light/Dark · Normal and the 25% overview
- **Visible evidence:** The bridge occupies approximately x = 118–281, or about **163 px / 41% of the 402 px canvas**, and continues for roughly y = 304–606. Its sides are nearly vertical for most of that run, so it reads as a broad empty rectangular neck rather than a narrow, softly curved mineral connection. The system landing is fused to the action well and overlaps the bridge instead of sitting in open cavern air. The bridge’s right edge approaches the utility shelf at x = 288, leaving a **7 px gap**—inside the explicitly rejected 4–8 px tangency range. At 25%, the upper and lower chambers look joined by a missing or unpopulated panel; in dark mode, the brighter upper actions also outweigh the lower movement group.
- **Likely cause:** The bridge is being used as a large central bounding mass, while the system landing is appended below the action well and the utility shelf is positioned just outside the bridge contour. Width, overlap, and role grouping are doing layout work rather than expressing the requested open-air composition.
- **Concrete correction:** Reduce the bridge’s maximum width to **96 px or less**, introduce at least **12 px of lateral curvature/offset** over its run, and retain deliberate 12–20 px overlaps behind the chamber laminae. Keep **at least 12 px** between the bridge edge and utility shelf. Detach the system landing from both the action well and bridge so the system frame has **at least 12 px of visibly continuous cavern ground** around its landing. In the next 25% overview, the two chambers must remain related without a broad central slab, and movement/action must read as balanced primary masses.

## C-02 — Custom and system landings form cramped, hardware-like compound contours

- **Severity:** `major`
- **Affected panels:** all 16 panels; custom-rail defect is specific to all eight portrait panels, while the system-landing defect affects both orientations
- **Visible evidence:** In portrait, the R and L custom controls nearly fill straight rectangular appendages that are fused directly into the action and movement wells. Their right ends terminate at the main well junction instead of reading as separate subdued ledges. In landscape, the circular system control sits inside a hard-cornered **84 × 67 px** square mount that straddles the raised lamina; in portrait it sits in a hard-cornered **96 × 62 px** tab fused below the action well and over the bridge. Normal already shows stacked square/round boundaries, and Active adds another cyan contour. These shapes look like ports, plugs, or diagnostic mounting plates rather than separate mineral ledges and a neutral aperture. They also fall outside the specified 14–22 px internal-radius family.
- **Likely cause:** The portrait SVG combines custom and system landing geometry into the same path as the main recessed wells, while both landscape and portrait system landings use zero-radius rectangles. Native control outlines and passive artwork outlines therefore accumulate at the same locations.
- **Concrete correction:** Make each custom role a visually independent **raised** ledge with a **14–22 px radius**, **10–14 px clearance** from the native frame, and no shared recessed-well contour within 10 px of the frame. Replace both square system mounts with one neutral rounded aperture landing in the same 14–22 px radius family, preserving 10–14 px native-frame clearance and eliminating overlap with a lamina occlusion edge or bridge. At full resolution, each role must have no more than one passive artwork boundary outside its native boundary; at 25%, custom rails must read as separate secondary ledges and the system role must recede.

## C-03 — The landscape hierarchy is readable, but the shell idea loses to generic well geometry

- **Severity:** `major`
- **Affected panels:** all eight landscape panels; also weakens family consistency in all eight portrait panels
- **Visible evidence:** At 25%, movement and action are correctly the first two regions, but the artwork reduces to one long rounded deck, two large rounded rectangular wells, two shoulder bars, a center square, and a hairline. The irregular top/bottom arcs and silt marks disappear before the conventional control-deck structure does. At full resolution, most plate surfaces are uniform fills; the intended 2 px occlusion plus 4 px contact shadow is not strong enough to make the overlapping laminae the defining material event. Native button bevels carry more visible craft than the shell. The work is more authored than a literal token swap, but it does **not yet feel genuinely handcrafted or strongly evocative of mineral laminae**; it still reads primarily as a generic flat controller in a cave palette.
- **Likely cause:** Fine silhouette irregularity and very faint motes are being asked to establish the concept, while oversized, regular well shapes and low-amplitude plate edges dominate the downscaled composition.
- **Concrete correction:** Preserve the restrained palette, but make one lamina overlap per orientation a continuous **2 px occlusion edge plus a 4 px lower-right contact shadow** across at least **30% of the plate span**, and keep it visible at 25%. Bring internal well corners into the **14–22 px family** and add only **4–8 authored 1–3 px surface flecks per orientation** at no more than 6% local contrast; do not add global noise, glow, or more cyan. The next 25% overview must show two countable overlapping plate masses before the seam or motes are inspected.

# Pass 2 — Material and craft

## M-01 — Pressed controls look radially lit instead of physically depressed

- **Severity:** `major`
- **Affected panels:** all four Pressed panels; most obvious on movement and primary/secondary action faces
- **Visible evidence:** Pressed faces have bright centers and dark shading around multiple sides. The shading reads as a soft dimple, spotlight, or glossy inset rather than a matte face moving closer to its well. The perimeter darkening is substantially symmetrical, so it does not agree with the declared upper-left 35° light direction. Legends stay centered and the state is distinguishable, but the physical/material explanation is wrong.
- **Likely cause:** Native depth/highlight compositing remains too strong after the outer shadow is reduced, producing a center-to-edge gradient instead of a uniform luminance shift and compact lower-right inner edge.
- **Concrete correction:** Keep the existing 10–14% luminance change and 35–45% shadow scale, but suppress the upper-left face highlight in Pressed, limit interior face variation away from the edge to **3% or less**, and use only one **1 px lower-right inner edge**. No pressed face may show a radial bright center at full resolution; at 25%, Pressed must remain distinct through uniform tone and collapsed elevation rather than a halo.

## M-02 — The landscape action well creates a 5 px parallel-edge pinch against the shell

- **Severity:** `minor`
- **Affected panels:** all eight landscape panels, along the far-right action well
- **Visible evidence:** The action well ends near x = 851 while the outer shell ends near x = 856, leaving about **5 px** between two long rounded boundaries. This produces a dense double/triple rail on the right edge, unlike the movement side’s roughly 13 px breathing room. It is visible in every landscape state and becomes darkest in Dark · Normal/Disabled.
- **Likely cause:** The well was expanded to preserve clearance around the far-right canonical action frame without correspondingly adapting the outer lamina silhouette.
- **Concrete correction:** Preserve the canonical native frame and its required 10–14 px well clearance, but establish **at least 10 px** between the action-well edge and outer shell edge, or merge them into one intentional boundary with no parallel 4–8 px corridor. The next full-resolution sheet must show the same edge density on left and right.

# Pass 3 — Interaction

## I-01 — Dark active primary/secondary boundaries disappear into their cyan-tinted faces

- **Severity:** `major`
- **Affected panels:** Landscape · Dark · Active and Portrait · Dark · Active; primary and secondary action roles
- **Visible evidence:** Movement, custom, utility/menu, and system controls gain a clearly readable cyan perimeter. The pale action faces instead become pale cyan and their perimeter is difficult to isolate from the fill at full resolution; at 25%, the action group reads as tint-only. Source-token inspection explains the visible collision: `#72D4CF` against the dark active primary fill `#C9DED3` is approximately **1.24:1**, and against the secondary fill `#B6D4CC` approximately **1.10:1**. The required 2 px state boundary is therefore not a meaningful independent cue on the two focal action roles.
- **Likely cause:** The dark active fill is too close in hue and luminance to the active cyan index, with no separating keyline or placement change.
- **Concrete correction:** Retain a continuous **2 px cyan boundary** and the controlled face tint, but give the boundary **at least 3:1 local contrast** against its adjacent face or isolate it with a crisp 1 px dark separator while keeping the cyan edge adjacent to the dark well. At 25%, primary and secondary Active must be distinguishable from Normal from their own boundary-plus-tint treatment, not only because other roles are active.

## I-02 — Disabled face-to-well compression is too severe and uneven across roles

- **Severity:** `major`
- **Affected panels:** all four Disabled panels; strongest on light movement/custom/utility/menu/system and dark movement/custom/utility/menu/system roles
- **Visible evidence:** Disabled labels remain readable, cyan is removed from native controls, and the state is visibly unavailable. However, at 25% many non-action faces collapse almost entirely into their wells, while the pale action faces remain discrete blocks. This weakens grouping and produces a large role-to-role hierarchy change that is not present in Normal. Source values are consistent with what is visible: measured as reduction of face/well contrast excess (`contrast ratio − 1`) against the specified wells, the disabled fills compress by roughly **57–82%**, rather than the requested 35–50%; dark utility is also about **10.5% HSV saturation**, just above the ≤10% cap.
- **Likely cause:** Disabled fills were pushed too close to the well color in an effort to make unavailability obvious, especially in light appearance, without preserving a stable neutral face boundary.
- **Concrete correction:** Retune every role to **35–50% face-to-well contrast reduction**, **≤10% saturation**, and **≥3:1 legend contrast**. Preserve a quiet neutral edge so movement, custom, utility/menu, and system faces remain countable at 25%, while keeping them clearly flatter and less available than Pressed. The four disabled panels must retain the same role grouping order as Normal without restoring cyan or raised highlights.

## Interaction checks that pass

- Native frames and legend baselines do not visibly shift between states.
- The source luminance changes for Pressed are approximately 11–13%, and pressed shadow scales are 0.4, inside the numerical art-direction targets; M-01 concerns the visible shading model, not state magnitude.
- Light Active boundaries are clear, and dark movement/custom/utility/menu/system Active boundaries are clear.
- Native legends remain readable at full sheet resolution; source foreground/face combinations exceed the stated normal, pressed/active, and disabled contrast thresholds.
- Disabled does not collide with Pressed: the two states are distinguishable side by side, although Disabled over-compresses several role faces.

# Acceptance-criteria audit

| Criterion | Result | Reason |
|---|---|---|
| 1. Contract alignment, clearance, tangencies, clipping | **Fail** | Main action/movement wells appear centered and no native frame shifts or clipping are visible, but portrait bridge/utility leaves a 7 px near-tangency, the landscape action-well/shell corridor is about 5 px, and custom/system landing contours are cramped or fused. Seams and motes remain clear of native frames. |
| 2. Orientation authorship and unornamented space | **Partial** | Portrait is independently authored and both orientations retain ample unornamented surface, but portrait does not preserve cavern air around the system role and its bridge is broad rather than narrow/softly curved. |
| 3. Immediate hierarchy | **Partial** | Movement and action are the first two regions in landscape. In portrait, upper pale actions materially outweigh lower movement at 25%, while the broad bridge reads as an unresolved empty panel. |
| 4. Appearance authorship and contrast | **Pass with interaction caveat** | Light is warm/flatter and dark is subterranean rather than inverted; full-resolution legends remain readable and source contrast tokens clear their thresholds. Dark action Active boundary contrast fails under criterion 5. |
| 5. State separation | **Fail** | No geometry drift is visible and the numeric pressed shift/shadow targets are present, but pressed shading is materially incorrect, dark action Active loses its independent 2 px index, and Disabled compression exceeds the 35–50% target. |
| 6. Restraint | **Pass** | Cyan is visibly well below 6%; source has 9 landscape motes and 8 portrait marks, all 1–3 px-scale; there is no logo, decorative text, full-panel glow, noise, glass, HUD, or particle field. |
| 7. Material consistency | **Fail** | Pressed halos break the lighting logic; zero-radius/fused landings break the internal radius family; close parallel edges and weak occlusion hierarchy prevent a consistent mineral construction. No standalone raster seam or clipped shell was found. |
| 8. Originality and native-control boundary | **Pass legally; weak in craft** | All 16 native combinations are present; no fake controls or artwork-baked labels are visible; no prohibited motifs or copied trade dress are apparent. The generic controller-deck reading is an originality-strength/craft issue, not evidence of infringement. |

# Originality / trade-dress check

No Hollow Knight title, logo, character, mask, horn, weapon, glyph, map symbol, architecture, or recognizable fan-art motif is visible. There are no literal insects, wings, faces, skulls, crests, emblems, manufacturer marks, vents, screws, ports, speaker patterns, model text, or proprietary hardware color blocking. The soft asymmetric lamina paths, cold seam, and sparse motes are legally distinct from a named console or controller.

The legal check therefore passes. The visual originality bar is weaker: at 25%, the landscape’s rounded deck and regular wells are generic enough that the Pale Cavern signatures become secondary. C-03 is a craft and identity defect, not a claim that the work copies protected trade dress.

# Defects versus optional taste

All findings above tie to visible evidence and the written acceptance criteria. The following are **not** requested fixes:

- Do not fill the portrait center with extra motes, labels, glow, or texture. The correction is more open ground and a narrower, authored bridge—not more decoration.
- Do not increase cyan coverage or add bloom. Current restraint is appropriate.
- The warm limestone and subterranean navy palette relationship is authored and should remain.
- The irregular outer arcs should not be converted into handles, wings, points, or a familiar gamepad silhouette.

# Final verdict

**`revise`** — no blocker or trade-dress violation was found, but six unresolved major findings prevent a visual pass. Highest priority is to rebuild the portrait bridge/system-air composition, separate and round the custom/system landings, and correct the shell/material hierarchy so Pale Cavern reads as overlapping mineral laminae rather than a generic flat controller deck. After those geometry changes, correct pressed shading, dark action Active boundaries, and Disabled contrast compression before rendering `contact-sheet-2.png`.
