# Solar Sumi — Independent Visual Critique 2

- **Reviewer:** `pocketpad-visual-critic`
- **Date:** 2026-07-17
- **Evidence:** `docs/skins/examples/solar-sumi/reviews/contact-sheet-2.png` (2176 × 1714)
- **Comparison:** `reviews/contact-sheet-1.png` and `reviews/critique-1.md`
- **Art direction:** `reviews/art-direction.md`
- **Verdict:** **revise**
- **Finding count:** 0 blockers, 3 major, 1 minor

## Inspection coverage

All 16 native-renderer panels were inspected at full source resolution and at an exact 25% reduction (544 × 429): portrait and landscape, light and dark, normal, pressed, active, and disabled. Pass 1 evidence was inspected at the same scales for direct comparison. No source was used to override the rendered result.

At 25%, both orientations now preserve an action-first read, the landscape current travels left-to-right, and the portrait composition reads upward. Dark controls and the quiet utility lane survive reduction. The remaining failures are the disabled/active semantics and a newly conspicuous prohibited brush-circle motif around the joystick.

## Prior-finding audit

| Prior finding | Status | Pass 2 evidence |
|---|---|---|
| **C-01** Generic landscape fight-stick enclosure | **Resolved** | The deeper center saddle, stepped lower edge, left clip, and rising right shoulder remain visible at 25%. The continuous case-like lower lip is gone. |
| **C-02** Portrait crown top-edge tangency | **Resolved** | B4 and the upper current retain a clean fiber cap at full resolution and at 25%; no control or artwork mass reads cropped. |
| **C-03** Current/gutters merge into a button plate | **Resolved** | The repeated control-shaped wells have been replaced by open fiber channels. Action controls no longer read as one commercial button plate. |
| **M-01** Dark-mode depth tiers collapse | **Resolved** | The deck/current boundary, action silhouettes, system tab, and Coin key remain visible at 25% in all four dark panels. |
| **M-02** Violet puck steals the material/state hierarchy | **Resolved as a major; accepted native variance** | The hardcoded violet puck remains in normal and disabled, but the larger vermilion action pair now holds the first read at 25%. Its disabled-state consequence is still counted under **I-01**. |
| **M-03** Mechanical dry-brush rhythm | **Unresolved** | Regular pale notches remain aligned to successive action rows, especially on the portrait outer rails. See **M-03** below. |
| **I-01** Disabled does not read unavailable | **Unresolved** | Disabled is flatter, but vermilion becomes stronger and the violet puck returns. See **I-01** below. |
| **I-02** Pressed/active hierarchy fails | **Unresolved** | Pressed now reads as depressed; active still depends primarily on the joystick/system rings and collapses toward normal elsewhere. See **I-02** below. |
| **I-03** Dark system/Coin visibility | **Resolved** | Both silhouettes survive in all dark panels, including pressed and disabled, without relying on their small legends. |

## Acceptance-criteria summary

| Criterion | Result | Evidence |
|---|---|---|
| 1. All 16 combinations; separately authored portrait | Met | All panels are present, and portrait remains a separate vertical composition. |
| 2. Every canonical role visibly covered | Met | B1–B8, Stick, Start, Coin, and system are visible in both appearances and all states. |
| 3. Action-first read and directional read at 25% | Met | Actions lead; landscape travels left-to-right and portrait upward. |
| 4. Clearances, alignment, and no clipping/tangency | Visually met | B4 and the far-right controls remain intact; fiber channels separate artwork from native frames. |
| 5. Legend and active-index contrast | Not met | Legends remain readable, but active indices on Start, Coin, and several actions do not separate active from normal at 25%. |
| 6. Four distinct states | Not met | Pressed is distinct; disabled reads enabled and active remains too close to normal outside the joystick/system. |
| 7. Edge, light, texture, and artifact craft | Partial | No seam, banding, clipping, or contradictory light was found; repeated brush notches remain mechanical. |
| 8. Originality and trade dress | Not met | Commercial plate/case risk is resolved, but the open dry-brush joystick surround reads as the explicitly prohibited ensō-like circle. |

# Pass 1 — Composition

No unresolved composition blocker or major remains from pass 1. The asymmetry survives thumbnail reduction, portrait is not a transformed landscape, and the large portrait waist interval reads as deliberate rather than empty. The aggressive right-side portrait cut is a taste choice, not a defect: it does not displace controls, reverse the upward path, or weaken the action crown.

# Pass 2 — Material and craft

## M-03 — Brush-edge notches still follow the control grid

- **Severity:** minor
- **Affected panels:** all eight portrait panels; secondarily all eight landscape panels around the action register
- **Visible evidence:** At full resolution, three or more pale bristle gaps recur at near-equal intervals along the portrait outer carbon rails and line up with successive action rows. Similar short marks repeat along the landscape action arcs. The gold register cadence is intentional; the pale edge gaps are what make the carbon edge look plotted rather than pressure-varied.
- **Likely cause:** The revised artwork removed repeated control wells but retained evenly distributed gap segments keyed to canonical control positions.
- **Concrete correction:** Keep individual edge variation within **1–3 artboard px** and gaps within **1–4 px**, but remove every run of three equally spaced pale notches and offset remaining gaps by at least **6 artboard px** from action-center crosslines. At 100%, the pale gaps must not form a second register parallel to the gold marks.

The five depth tiers now remain separable in dark mode. Highlights consistently read upper-left and shadows lower-right. No raster seam, glow, banding, stretched fiber, duplicate legend, or label warp was observed.

# Pass 3 — Interaction

## I-01 — Compiler-derived disabled state remains visually enabled

- **Severity:** major
- **Affected panels:** landscape light disabled, landscape dark disabled, portrait light disabled, portrait dark disabled, each compared with its matching normal panel
- **Visible evidence:** Shadows are removed, but B1/B2 and Start become cleaner, darker, and in dark mode more saturated than normal. The native violet joystick puck also returns. At 25%, each disabled panel can be mistaken for a crisp flat normal state; the primary pair often looks more assertive than in normal. Labels remain legible, but unavailability does not.
- **Likely cause:** The compiler derives disabled output from shared material tokens rather than accepting semantic state-specific materials; the renderer also preserves its hardcoded puck accent in disabled.
- **Concrete correction:** Adjust authorable material inputs or the native state derivation before rerendering so disabled removes cast shadow/specular edge and reduces B1/B2/Start chroma by at least **30% relative to normal**, replaces gold with a neutral edge, and prevents the puck accent from re-energizing the state. Preserve disabled legend contrast at **≥3.5:1**. In a headerless exact-25% comparison, all four disabled panels must be identified as unavailable without confusing them with normal.

## I-02 — Active remains normal-like outside the joystick and system tab

- **Severity:** major
- **Affected panels:** all four active panels compared with matching normal; strongest in landscape light active and portrait light active
- **Visible evidence:** Pressed now has reduced shadow, darker fill, and a stable center, so that half of the prior finding is resolved. Active, however, is recognized mainly by the gold joystick and system outlines. Start and Coin look effectively normal, and several action indices reproduce normal highlight/stroke weight. With the joystick hidden, normal and active are not reliably separable at 25%, especially in light mode.
- **Likely cause:** Derived active outlines reuse colors already present in normal highlights and strokes. Light-fiber indices on vermilion merge with the fiber surround, while normal and active gold edges on carbon roles remain too similar.
- **Concrete correction:** Give every semantic role a continuous **2 artboard px** active index measuring **≥3:1 against both control fill and immediate surround**; add a contrasting outer separator where the light-fiber vermilion index meets the light deck. Coin must gain a visibly new carbon index and Start a visibly new active edge rather than a normal highlight. At exact 25%, with every joystick masked, all four active panels must remain distinguishable from normal from the action and utility controls alone.

No control frame or legend visibly shifts between states. Pressed controls now communicate depression without label jump.

## Native-renderer limitation determination

The documented schema limits are explanatory, not exemptions:

- The **hardcoded joystick puck accent** is acceptable native behavior on its own in normal/pressed/active because it occupies a small area and no longer outranks B1/B2 at 25%. It is not a blocker or major palette defect in pass 2.
- The accent's return in **disabled**, and the compiler's broader **derived-state** result, are not acceptable because the rendered semantic states fail criteria 5 and 6. A schema limitation does not make an enabled-looking disabled panel or normal-looking active panel a visual pass.

## Originality and trade-dress check

The revised landscape no longer reads as a generic commercial enclosure, and the action field no longer forms a familiar unified row plate. No manufacturer mark, model name, logo, proprietary glyph, mounting hardware, copied cabinet outline, game art, commercial color blocking, duplicate legend, or calligraphic lettering is visible.

## O-01 — Joystick artwork has regressed into a prohibited ensō-like brush circle

- **Severity:** major
- **Affected panels:** all 16; strongest in all eight light panels and the two dark active panels
- **Visible evidence:** The passive black artwork follows most of the joystick's circular perimeter as a broken, pressure-varied loop. In landscape it reads as an open brush circle around the Stick; in portrait the lower pool reads as a large horseshoe loop. Hiding the native joystick face leaves a recognizable incomplete brush circle. This is precisely the cultural shorthand prohibited by the art direction, independent of whether it copies a specific source.
- **Likely cause:** The pass 1 filled joystick mass was thinned into a circumferential outline to separate artwork from the native control, converting an off-round grounding island into a ring motif.
- **Concrete correction:** Rebuild the joystick ground as an asymmetric filled/connected carbon island extending **18–24 artboard px** beyond the native frame while retaining the required **8 px** control clearance. No continuous artwork arc may track more than **90°** of the joystick perimeter, and at least **40%** of that perimeter must open into a non-circular current neck or fiber field. With the native joystick face hidden at 25%, the remaining artwork must read as an irregular ground mass, never an open circle or horseshoe.

This is a prohibited-motif defect, not a claim that a protected mark or a specific product was copied.

## Defects versus optional taste

The four findings above are criterion-linked defects. No correction is requested for the deeper landscape saddle, the large portrait right-side notch, or the thinner revised action current; those are optional taste choices that currently preserve hierarchy, clearance, and orientation-specific movement.

## Final verdict

**revise** — no blocker remains, and six of nine prior findings are resolved, but three major findings prevent `visual-pass`: disabled still reads enabled, active remains normal-like outside the joystick/system, and the joystick ground now forms an explicitly prohibited ensō-like brush circle. The derived-state and puck schema limits do not override the rendered acceptance criteria.

**Report:** `docs/skins/examples/solar-sumi/reviews/critique-2.md`

**Three highest-priority findings:**
1. **I-01:** Disabled strengthens vermilion and restores the violet puck, so unavailable controls read enabled.
2. **I-02:** Active depends on joystick/system rings and does not survive a puck-masked 25% comparison.
3. **O-01:** The revised joystick surround reads as a prohibited incomplete brush circle in both orientations.
