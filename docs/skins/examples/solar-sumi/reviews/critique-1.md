# Solar Sumi — Independent Visual Critique 1

- **Reviewer:** `pocketpad-visual-critic`
- **Date:** 2026-07-17
- **Evidence:** `docs/skins/examples/solar-sumi/reviews/contact-sheet-1.png` (2176 × 1714)
- **Art direction:** `docs/skins/examples/solar-sumi/reviews/art-direction.md`
- **Verdict:** **revise**
- **Finding count:** 0 blockers, 8 major, 1 minor

## Inspection coverage

All 16 native-renderer panels were inspected at the contact sheet's full source resolution and again at an exact 25% reduction (544 × 429): landscape and portrait; light and dark; normal, pressed, active, and disabled. Source SVG/JSON was consulted only to explain defects already visible in the evidence.

At 25%, the light compositions retain their intended direction, but the dark Carbon Current, utility lane, and several state cues collapse. At full resolution, no native frame or legend visibly translates between states, and B4 itself is not raster-clipped; the portrait crown nevertheless has an artwork-to-deck tangency that reads as clipping once reduced.

## Acceptance-criteria summary

| Criterion | Result | Evidence |
|---|---|---|
| 1. All 16 combinations; separately authored portrait | Met | All panels are present, and portrait is visibly recomposed vertically. |
| 2. Every canonical role visibly covered | Not met | The dark system tab and Coin key lose their control silhouettes; secondary/custom separation is weak. |
| 3. Action-first read and directional read at 25% | Partial | Light reads left-to-right/upward; the current and hierarchy collapse in dark. |
| 4. Clearances, alignment, and no clipping/tangency | Not met | No native control is visibly cropped, but the portrait current cap becomes top-edge tangent and the repeated action gutters merge with native housings. |
| 5. Legend and active-index contrast | Not met | Light active rims disappear into the fiber gutter; dark Coin/system legibility is not demonstrated. |
| 6. Four distinct states | Not met | Disabled reads enabled, and light active is barely stronger than normal. |
| 7. Edge, light, texture, and artifact craft | Not met | Lighting direction is consistent, but the top tangency and mechanically repeated brush gaps remain. |
| 8. Originality and trade dress | Not met | No copied mark or cultural motif is visible, but the landscape silhouette and unified action plate remain too close to generic commercial fight-stick language. |

# Pass 1 — Composition

## C-01 — Landscape deck resolves to a generic fight-stick enclosure

- **Severity:** major
- **Affected panels:** all eight landscape panels
- **Visible evidence:** At full resolution the shallow center saddle and clipped lower corner are present, but at 25% those deviations disappear. The deck reads as a long rounded rectangular case with a continuous lower lip, joystick at left, and eight-button bank at right. This is the exact category silhouette the direction says the Offset Fiber Deck must avoid.
- **Likely cause:** The silhouette's authored deviations from a rounded rectangle are too shallow, while the continuous perimeter bevel and shadow reinforce a manufactured enclosure.
- **Concrete correction:** Increase the rising-right-shoulder, lower-left clip, and lower-edge offset by **16–24 artboard px** without reducing any native-frame clearance below **12 px**. Remove the visually continuous case-like lower lip. At 25%, the deck silhouette must remain recognizably asymmetric with all controls temporarily obscured.

## C-02 — Portrait crown has a top-edge near-tangency

- **Severity:** major
- **Affected panels:** all eight portrait panels; strongest in both dark normal/pressed/disabled and both light normal/disabled
- **Visible evidence:** The upper Carbon Current cap behind the right action rank leaves only about five source-sheet pixels to the deck top; at 25% this collapses to roughly one pixel and reads as a clipped black mass. B4's native housing is intact at full resolution, but the entire B4/B8 crown lacks the clean fiber breathing strip required for the canonical top-edge exception.
- **Likely cause:** The portrait Current rises almost to the deck's top boundary before the control gutters are composited, so antialiasing and reduction erase the remaining separation.
- **Concrete correction:** Lower the highest Current cap until the exact contact sheet retains at least **8 source-sheet pixels** of uninterrupted fiber above it (about **20–22 portrait-artboard px**), keep B4's canonical frame unchanged, and reverify an **8 px minimum** artwork mask around B4/B8. The 25% panel must show at least a clean two-pixel fiber strip rather than a tangent.

## C-03 — Carbon Current, gutters, and native action housings merge into one button plate

- **Severity:** major
- **Affected panels:** all 16; strongest in all portrait panels and all dark panels
- **Visible evidence:** Each action has a control-shaped fiber cutout immediately under its native housing. In portrait, the left branch becomes a repeated staircase around B4/B3/B2/B1; in landscape, the eight cutouts resolve as one regular bank inside a continuous black field. At 25%, the fiber cutouts merge with native bevels, so the Current looks like an authored button plate rather than passive ink. B3/B4 and B5–B8 then differ mostly by labels and very slight edge color.
- **Likely cause:** Repeated rounded-rectangle `native-control-gutters` track every frame too literally, while the secondary and custom edge treatments are too close after compositing and downsampling.
- **Concrete correction:** Recut the Current as irregular, continuous fiber channels that remain at least **8 artboard px** from every native frame without forming repeated button-shaped wells. Keep Solar Register marks at least **6 px** away. Make B3/B4's vermilion hairline and B5–B8's gold hairline independently visible at 100%; at 25%, a viewer must distinguish the secondary pair from the custom quartet without reading their labels.

# Pass 2 — Material and craft

## M-01 — Dark-mode depth tiers collapse

- **Severity:** major
- **Affected panels:** all eight dark panels; strongest in normal, pressed, and disabled
- **Visible evidence:** The smoked deck, Carbon Current, joystick island, system tab, and carbon action fills cluster into near-black values. At full resolution, B3/B4/B5–B8 rely on thin outlines and legends for boundaries. At 25%, the Current's joystick-to-action path nearly disappears, the system tab vanishes, and the action controls read as labels floating in a black bed. Dark is therefore a dimmed hierarchy, not a separately legible material stack.
- **Likely cause:** `carbon-ink`, carbon controls, and the canvas are too tightly grouped in rendered value, and the one-pixel normal edges do not survive reduction.
- **Concrete correction:** Re-space the dark deck/current/control tiers so the full Current boundary survives as at least **one continuous pixel at 25%**, while every essential carbon-control boundary has a **2 px native edge** with at least **3:1 contrast** against its immediate surround. Preserve distinct carbon-soft secondary fills rather than globally brightening the deck.

## M-02 — Violet joystick puck is outside the material system and steals state hierarchy

- **Severity:** major
- **Affected panels:** landscape light normal/disabled, landscape dark normal/disabled, portrait light normal/disabled, portrait dark normal/disabled
- **Visible evidence:** A saturated violet center appears in every normal and disabled joystick, while pressed changes it to gray/black and active to black. Violet is not part of the Solar Sumi palette, pulls focus away from B1/B2, and makes disabled look energized.
- **Likely cause:** The native joystick's inner puck appears to be using an unmapped/default accent instead of the assigned carbon-rubber material and role-specific state treatment.
- **Concrete correction:** Remove violet from all four states. Use carbon/carbon-soft for normal, a **6–10% darker** pressed center with reduced shadow, a **2 px gold perimeter index** for active, and a neutral desaturated disabled center. The joystick must communicate state through depth/index behavior, not a hue absent from the approved palette.

## M-03 — Dry-brush craft becomes mechanical at the action crown

- **Severity:** minor
- **Affected panels:** all 16; strongest along the portrait action branches and the landscape action-bed perimeter
- **Visible evidence:** Full-resolution inspection shows repeated short pale ticks and hard 90-degree gutter steps at regular action intervals. These read as plotted vector notches rather than pressure-varying absorbed carbon. No glow, banding, raster seam, or contradictory lighting direction was observed.
- **Likely cause:** Sparse line-segment gaps are layered over geometrically repeated rectangular gutters, making the edge rhythm follow the control grid.
- **Concrete correction:** Keep edge variation within the required **1–3 px** and bristle gaps within **1–4 px**, but remove visible 90-degree stair steps and avoid any run of three evenly spaced gaps. At 100%, the edge must read as one irregular absorbed stroke rather than a perforated plate.

# Pass 3 — Interaction

## I-01 — Disabled is not visibly unavailable

- **Severity:** major
- **Affected panels:** all four disabled panels, compared with their four matching normal panels
- **Visible evidence:** B1/B2 and Start retain strong vermilion, the joystick retains the same saturated violet center, and most action boundaries retain normal-state weight. At 25%, normal and disabled cannot be reliably identified without reading the panel header; in places disabled appears more saturated than normal.
- **Likely cause:** Disabled appears to rely on a generic renderer transform rather than explicit role-family desaturation, neutral edging, and shadow/specular removal.
- **Concrete correction:** Author disabled treatment per semantic material: remove cast shadow and specular edges, desaturate every fill, replace gold with a neutral edge, and preserve legend contrast at **≥3.5:1**. In a headerless 25% comparison, all four disabled panels must be identifiable as unavailable while B1/B2, B3/B4, B5–B8, Start, Coin, system, and Stick remain grouped and readable.

## I-02 — Pressed/active hierarchy is too dependent on puck color; light active indices fail

- **Severity:** major
- **Affected panels:** landscape light pressed/active, portrait light pressed/active; secondarily both dark pressed panels
- **Visible evidence:** Light active is only marginally different from light normal because its pale/gold rims merge into the fiber gutters; several normal rims appear brighter than active. Pressed is recognized most readily by the invalid joystick-puck color change rather than depression across the action register. Dark active is clearer, but this does not rescue the light appearance.
- **Likely cause:** One bright-gold active color is reused across appearances, normal fiber rims are already high-weight, and the required shadow reduction/inner containment is too subtle after downsampling. The rendered light-gold/fiber pairing is visibly weak; the authored `#D0A64C` against `#F3E4C2` is only about **1.81:1**.
- **Concrete correction:** Keep pressed at **0.96–0.98 scale**, reduce cast shadow by **≥60%**, darken fill **6–10%**, and add inner lower-right containment. Return active to **≥0.99 scale** with a crisp **2 px** role-appropriate index measuring **≥3:1 against both fill and surround**. Carbon roles need a darker light-appearance gold; vermilion roles need the light-fiber index plus a contrasting outer separator; Coin needs the specified carbon index rather than a low-contrast gold edge. With the joystick center obscured, normal/pressed/active must still be identifiable at 25% from the actions and utility lane alone.

## I-03 — System and Coin controls lose visibility in the dark utility lane

- **Severity:** major
- **Affected panels:** all four dark landscape panels and all four dark portrait panels; strongest in dark normal, pressed, and disabled
- **Visible evidence:** The system control is a nearly black unlabeled oval that disappears into the smoked deck except for its active gold ring. Coin is deck-colored with a very low-weight boundary; its small legend is barely readable at full resolution in portrait and disappears at 25%. Start remains visible because of vermilion, leaving the quiet lane visually unbalanced.
- **Likely cause:** The system fill/current value and the Coin fill/deck value are intentionally matched, but their neutral normal/pressed/disabled edges are too weak to preserve native control silhouettes.
- **Concrete correction:** Give system and Coin distinct **2 px non-glowing neutral boundaries** in normal, pressed, and disabled; reserve gold for the appropriate active index. Verify Coin/Start/Stick legends at **≥4.5:1 normal** and **≥3.5:1 disabled** from the composited output. At 25%, both utility/system silhouettes must remain visible even where their small legends no longer resolve.

## Defects versus optional taste

All recommendations above are criterion-linked defects. No optional taste changes are requested in this pass.

## Originality and trade-dress check

No manufacturer mark, logo, model name, mounting hardware, circular action plate, proprietary glyph, cultural stock motif, calligraphic imitation, ensō, rising-sun device, seal block, or duplicate artwork legend is visible. The separately composed upward portrait Current and sparse cross-register are visually original devices.

The originality review is nevertheless unresolved because C-01 and C-03 make the landscape read as a generic commercial fight-stick enclosure with a unified button plate at reduced scale. This is a category/trade-dress risk, not a finding that a specific product was copied. The correction should strengthen the asymmetric fiber silhouette and passive ink separation without introducing bolts, row plates, familiar color blocking, or hardware details.

## Final verdict

**revise** — no blocker is present, but eight major findings remain. Solar Sumi cannot receive `visual-pass` until dark tiers, four-state hierarchy, native-control separation, top-crown breathing room, utility/system visibility, and fight-stick silhouette risk are corrected and rerendered.

**Report:** `docs/skins/examples/solar-sumi/reviews/critique-1.md`

**Three highest-priority findings:**
1. **M-01:** Dark-mode depth tiers collapse, erasing the Current and carbon-control boundaries at 25%.
2. **I-01/I-02:** Disabled does not read unavailable, and light pressed/active states are not independently legible.
3. **C-03:** The Current and repeated gutters merge with native actions into a fight-stick-like button plate.
