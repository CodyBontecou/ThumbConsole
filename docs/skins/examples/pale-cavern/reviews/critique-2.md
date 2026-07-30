# Pale Cavern — Independent Visual Critique 2

- **Evidence reviewed:** `reviews/contact-sheet-2.png`
- **Verified contact-sheet SHA-256:** `2e2752cb2bb1bc789f22975ae06437f7b51517b608493f21e927fda7545771b5`
- **Verified evidence dimensions:** 2176 × 1714 px
- **Panel count:** 16 — portrait and landscape, light and dark, normal, pressed, active, and disabled
- **Verified package SHA-256:** `54b5343f622541a994934eb35e36ad91cf2cec9521b0ca8cd1cf039003d311f4`
- **Inspection scales:** exact PNG at full resolution; nearest-neighbor enlargements of the flattened panel pixels; and a 25% overview at 544 × 429 px
- **Criteria:** `reviews/art-direction.md`, every correction in `reviews/critique-1.md`, and the Thumble visual quality bar
- **Verdict:** `revise`

The revision resolves the broad portrait spine, custom-ledge construction, generic flat-deck reading, landscape right-edge pinch, radial Pressed shading, dark Active action-boundary collision, and over-compressed Disabled materials. The apparent shoulder-length and control-shape inconsistencies in the 25% overview are downsampling effects: inspection of the exact panel pixels finds the same native frames and legend baselines in all states, with no missing, clipped, or malformed native control.

One major portrait defect remains. The action well and system landing overlap inside the fixed 15.864 px gap between the Y and system native frames. This is a real source-geometry collision, not thumbnail interpolation. It keeps the system role attached to the upper action chamber, leaves no cavern ground between their passive boundaries, and creates two forbidden 4–8 px near-tangencies to native frames. Because this fails the explicit contract-alignment and system-air criteria, the sheet cannot receive `visual-pass`.

## Panel coverage

| Panel | Full-resolution and 25% observation |
|---|---|
| Landscape · Light · Normal | Movement and action read first. Two overlapping lamina masses now survive at 25%; custom and system roles remain secondary. Left/right well-to-shell spacing is balanced. |
| Landscape · Light · Pressed | Faces read as uniformly lowered rather than radially lit. Shadows collapse without a frame or legend shift. |
| Landscape · Light · Active | Cyan boundaries and short indices are distinct on every role, including the pale action faces. Geometry remains fixed. |
| Landscape · Light · Disabled | All faces and legends remain countable; role grouping follows Normal without cyan or raised highlights. |
| Landscape · Dark · Normal | The raised upper lamina, lower plate, wells, and seam remain separately readable. The authored dark material logic is not an inversion of Light. |
| Landscape · Dark · Pressed | The prior center-bright halo is absent. Pressed remains distinct through uniform tone and reduced elevation. |
| Landscape · Dark · Active | Deep-cyan primary/secondary boundaries remain visible against the tinted pale faces, while the brighter short indices remain separate cues. |
| Landscape · Dark · Disabled | Movement, custom, compact, and system faces remain present at 25%; the pale action family stays the intended first action cue without erasing other roles. |
| Portrait · Light · Normal | The 86 px maximum bridge and broad lateral cavern air compose clearly. The portrait system landing is visibly attached beneath the action well at the Y/system junction. |
| Portrait · Light · Pressed | Pressed treatment is physically coherent and fixed in place. The same action/system passive-boundary collision remains. |
| Portrait · Light · Active | All native active contours are intact. Added state edges make the stacked Y/action-well/system-landing/system-control junction easiest to see. |
| Portrait · Light · Disabled | Controls remain countable and unavailable. The action/system passive geometry still has no separating cavern ground. |
| Portrait · Dark · Normal | Upper and lower chambers remain the first two regions, with a genuinely narrow curved bridge. The action/system attachment is quieter than in Light but still visible at exact pixels. |
| Portrait · Dark · Pressed | No radial halo or layout drift is present. The system landing remains fused to the upper chamber construction. |
| Portrait · Dark · Active | Dark Active boundaries survive on all roles. The system circle still reads inside a rounded tab attached to the action well rather than in open cavern air. |
| Portrait · Dark · Disabled | Legends and role grouping survive. The source-confirmed action/system collision remains despite reduced state contrast. |

# Pass 1 — Composition

## C2-01 — Portrait action and system passive geometry still collide in the fixed frame gap

- **Severity:** `major`
- **Affected panels:** all eight portrait panels; clearest in Portrait · Light · Normal/Active and Portrait · Dark · Active, directly between the Y action control and circular system control
- **Visible evidence:** The canonical Y frame ends at **y = 241.816**, and the system frame begins at **y = 257.680**, leaving **15.864 px** between native frames. The revised action well ends at **y = 254**, while the rounded system landing begins at **y = 246**. The passive shapes therefore overlap by **8 px**. The system-landing top edge sits only **4.184 px below the Y frame**, and the action-well bottom edge sits only **3.680 px above the system frame**. At exact sheet pixels these boundaries merge into a compact stacked junction; in Active, the native system boundary adds another contour. There is no continuous cavern ground between the action well and system landing, so the system still reads as a chin/tab attached to the upper chamber rather than a quiet aperture in open air. The measurements confirm that the effect is not thumbnail interpolation.
- **Likely cause:** The revision correctly preserved approximately 12 px clearance around the system frame, but used a closed 84 × 68 px landing inside a frame-to-frame gap too small to support closed action and system wells plus ground. The closed action-well bottom and closed system-landing top were allowed to overlap instead of treating the canonical 15.864 px corridor as a special open-boundary case.
- **Concrete correction:** In the central **x = 159–243** corridor, remove both the closed action-well bottom segment and the closed system-landing top segment; do not place any passive stroke, fill transition, occlusion edge, or shadow in the **y = 241.816–257.680** native-frame gap. Recompose the system cue as an open-top side/bottom aperture, or another neutral partial landing, whose surviving boundaries remain **10–14 px** from the system frame and at least **10 px** from every action frame. Preserve the native frames. In the next exact-pixel sheet, there must be one uninterrupted cavern-ground reading between Y and system, no 4–8 px passive-edge tangency to either frame, and no closed rounded tab attached to the action well at 25%.

## Composition checks that pass

- The portrait bridge is now narrow and authored: source geometry has an 86 px maximum solid run, lateral curvature/offset, and approximately 14–16 px chamber overlap. It no longer reads as a blank rectangular spine.
- The bridge-to-utility separation is 13–16 px and visibly intentional. The center remains cavern air rather than being filled with extra texture or glow.
- Upper and lower portrait chambers remain distinct, and the action and movement regions are the first two readable masses at 25%.
- Portrait custom roles are now independent 114 × 56 px raised ledges with 18 px radii and clear rounded ends. Exact-pixel review confirms that their apparent state-to-state length changes at thumbnail scale are interpolation, not geometry drift.
- Landscape movement and action wells have approximately 13 px to the outer shell on both sides; the former 5 px right-edge pinch is gone.
- The strengthened lamina overlap remains visible at 25%, so the landscape now reads as two offset plate masses rather than only a generic rounded control deck.
- Both orientations retain intentional unornamented space above the required 24% landscape and 28% portrait thresholds by visible inspection.

# Pass 2 — Material and craft

No new material defect was found outside the compound action/system geometry documented in C2-01.

- The declared upper-left lighting direction is coherent across shell highlights, lower-right boundaries, contact shadows, wells, and native controls.
- One continuous 2 px occlusion edge plus a 4 px lower-right contact shadow is readable per orientation without becoming an extra glow or HUD line.
- Internal well and landing radii are in the 18–20 px family; the square system mounts from pass 1 are gone.
- Pressed faces no longer show a radial bright center. Their interiors read uniformly shifted, with collapsed elevation and only a restrained edge cue.
- Six landscape flecks and four portrait flecks remain sparse, irregular, and subordinate. No raster artifact, clipped shell edge, accidental canvas seam, full-surface noise, or excessive bloom is visible.
- Light uses warm limestone ground, pale raised planes, and flatter shadows; Dark uses subterranean blue-black, deeper wells, and restrained cool edges. Both appearances are separately authored.

# Pass 3 — Interaction

No state-geometry, clipping, disappearance, or legend defect was found.

- Exact-pixel inspection covers all **208 native control instances** across the 16 panels. All 13 native frames per panel remain present; all **192 visible legends** remain correctly formed and on the same baselines. Shadows and active indices change visual footprint, but the canonical frames do not move.
- Pressed luminance shifts remain approximately 11–13%, `pressedShadowScale` is 0.4, and the rendered halo defect from pass 1 is gone. Pressed is distinct from both Normal and Disabled at 25%.
- Dark Active primary and secondary boundaries are visibly independent of their face tint. Source colors independently measure approximately **3.68:1** and **3.29:1** local boundary-to-face contrast, respectively, and the brighter cyan short index remains a separate cue.
- Disabled fills independently measure **0% HSV saturation**. Face-to-well contrast-excess reduction is **46.6–49.4% in Light** and **39.3–43.3% in Dark**, inside the required 35–50% interval. All Disabled faces remain countable at 25%.
- Independent source-token contrast checks give minimum legend contrast of **8.49:1 Normal**, **7.53:1 Pressed**, **7.37:1 Active**, and **4.42:1 Disabled**. These exceed the stated thresholds.
- Cyan remains visibly below the 6% cap and is used as an orientation/state accent rather than ambient neon.

# Critique-1 correction audit

| Critique-1 finding | Result | Evidence in revision |
|---|---|---|
| C-01 broad portrait spine / missing cavern air | **Resolved except system detachment** | Bridge is 86 px maximum, curved, offset, and leaves broad air; utility gap is 13–16 px. The requested detached system landing remains unresolved under C2-01. |
| C-02 cramped custom/system compound contours | **Partially resolved** | Both custom ledges and the landscape system landing are independently rounded and visually subordinate. The portrait system remains compounded with the action well. |
| C-03 generic flat shell hierarchy | **Resolved** | Continuous lamina overlap and contact shadow survive at 25%; two plate masses are countable in both orientations. |
| M-01 radial Pressed shading | **Resolved** | Pressed interiors are uniform and elevation collapses without halo lighting. |
| M-02 landscape right-edge pinch | **Resolved** | Movement and action sides each retain approximately 13 px well-to-shell spacing. |
| I-01 dark Active action boundary loss | **Resolved** | Deep-cyan boundaries retain more than 3:1 local contrast and remain visible beside the cyan-tinted faces. |
| I-02 excessive Disabled compression | **Resolved** | Compression is 39.3–49.4%, saturation is 0%, and all roles remain countable. |

# Acceptance-criteria audit

| Criterion | Result | Reason |
|---|---|---|
| 1. Contract alignment, clearance, tangencies, clipping | **Fail** | Native frames stay fixed and no clipping is visible, but the portrait system-landing top is 4.184 px from Y and the action-well bottom is 3.680 px from system; the two passive shapes overlap by 8 px. |
| 2. Orientation authorship and unornamented space | **Pass** | Landscape uses offset horizontal laminae; portrait uses separate chambers and a narrow curved bridge. Both retain the required quiet area. |
| 3. Immediate hierarchy | **Pass** | Movement and action are the first two regions at 25%; secondary roles and decoration remain subordinate. |
| 4. Appearance authorship and contrast | **Pass** | Light and Dark use different material logic, and all measured legend contrasts clear their thresholds. |
| 5. State separation | **Pass** | Pressed, Active, and Disabled are meaningfully distinct in every semantic role with no frame or legend shift. |
| 6. Restraint | **Pass** | Cyan, flecks, texture, and depth effects remain within the brief; no logo, HUD, glass, noise field, or decorative text appears. |
| 7. Material consistency and artifacts | **Fail** | General lighting and lamina craft pass, but the overlapping portrait action/system passive boundaries create a real stacked seam/compound landing in the central focal corridor. |
| 8. Originality and native-control boundary | **Pass** | All 16 combinations are present; SVGs contain no fake controls or baked legends; no prohibited motif or copied trade dress is visible. |

# Originality / trade-dress check

No Hollow Knight title, logo, character, mask, horn, weapon, glyph, map symbol, architecture, or recognizable fan-art motif is visible. There are no literal insects, wings, faces, skulls, crests, manufacturer marks, vents, screws, speaker patterns, model text, proprietary glyphs, or recognizable controller color blocking.

The offset eroded lamina silhouettes, asymmetric plate overlap, narrow curved portrait bridge, cold-spring seam, and sparse silt marks now provide a coherent handcrafted identity at 25%. Landscape is no longer reducible to a palette swap once the lamina overlap is visible, and portrait is independently composed rather than rotated or stretched. The legal and originality check passes; C2-01 is a geometry/craft defect, not a trade-dress concern.

# Defects versus optional taste

C2-01 is the only blocking defect in this pass. It is tied to explicit clearance, tangency, system-air, and material-boundary criteria.

The following are not requested changes:

- Do not widen the portrait bridge or refill the central air; the revised bridge and negative space pass.
- Do not separate the custom ledges farther merely because the 25% overview makes their active edges look longer. Exact-pixel review confirms fixed geometry and clear independent rounded silhouettes.
- Do not brighten movement, add cyan, add motes, or increase texture to force hierarchy. Movement and action are already the first two regions, and the current restraint supports the authored material.
- Do not reintroduce radial Pressed shading or stronger Disabled compression; the revised state logic passes.

# Final verdict

**`revise`** — there are no blockers, state regressions, missing controls, clipping defects, or originality concerns, and five critique-1 findings are fully resolved; the remaining portions of C-01 and C-02 reduce to one unresolved **major** finding that prevents `visual-pass`: the portrait action well and system landing overlap inside the canonical Y/system gap and produce real 3.680–4.184 px passive-edge tangencies. Correct that open-boundary geometry while preserving the successful bridge, lamina, state, and contrast work, then render a new exact native contact sheet for another independent review.

**Report path:** `docs/skins/examples/pale-cavern/reviews/critique-2.md`

**Three highest-priority findings:**
1. **Major:** remove the portrait action/system passive-boundary overlap and both sub-5 px tangencies without moving native frames.
2. **Pass to preserve:** the 86 px curved bridge, 13–16 px utility gap, independent custom ledges, and visible lamina overlap now satisfy the composition corrections.
3. **Pass to preserve:** all native frames and legends remain intact across states; Pressed, dark Active action boundaries, and Disabled grouping now meet the interaction criteria.
