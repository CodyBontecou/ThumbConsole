# Indigo Pocket — Independent Visual Critique 1

- **Reviewed artifact:** `reviews/contact-sheet-1.png`
- **Source resolution inspected:** 2176 × 1714 PNG, including all 16 native-renderer panels
- **Art direction:** `reviews/art-direction.md`
- **Quality standard:** Thumble visual quality bar
- **Review date:** 2026-07-17
- **Verdict:** **revise**

The automated 100/100 result is not treated as visual evidence. The sheet contains every required variant, but it does not yet establish the reference bar: portrait composition is unresolved, several artwork edges collide with native controls or the shell rim, and the control material/state system relies on violet bloom instead of physical edge logic.

## 16-panel inspection record

| Orientation / appearance | Normal | Pressed | Active | Disabled |
|---|---|---|---|---|
| Landscape / light | Groups read immediately; every control already looks energized by a violet halo. | Glow removal is obvious, but controls read switched off rather than physically depressed. | Stronger bloom is visible; no crisp index ring is visible. | Grouping survives; small utility and shoulder legends are weak. |
| Landscape / dark | Groups remain identifiable; shell depth is flatter against the near-black canvas. | Keys are dark and flat, with little recess cue. | Bloom spreads through both harbors and becomes the dominant depth cue. | Silhouette survives; small legends approach marginal legibility. |
| Portrait / light | Upper/lower groups are recognizable, but the center is under-composed and the system control reads as a fifth action. | Same structural faults; reduced effects expose the flat deck construction. | Halos dominate the action harbor, shoulder rails, utility bay, and movement harbor. | Structure remains recognizable; utility labels are too faint at contact-sheet scale. |
| Portrait / dark | Same composition faults, with weaker shell/canvas depth separation. | The long center reads especially empty and the controls read unlit. | Violet fog, rather than a ring, carries active state. | The lowest-contrast panel; small labels remain technically present but not comfortably readable. |

## Pass 1 — Composition

### C1 — Portrait does not resolve the intended decks, waist, and shoulder spine

- **Severity:** `major`
- **Affected panels:** Portrait / light and dark / normal, pressed, active, and disabled
- **Visible evidence:** The plum action pod and charcoal movement pod occupy the extreme ends of the shell, while roughly the middle two-fifths is an undifferentiated indigo run. The short seam does not connect the left shoulder controls to the right utility bay, and there is no continuous left structural spine behind R and L. The Start/Select bay consequently floats on the right rather than completing a waist. At thumbnail scale this reads as two control islands on a long blank slab, not two broad decks joined by an engineered waist.
- **Likely cause:** Fixed portrait control centers were enclosed individually, but the passive artwork was not recomposed into a second orientation-specific internal structure.
- **Concrete correction:** Extend the upper and lower deck architecture toward the waist, build one continuous shell-backed left spine that seats both shoulder rails, and integrate the right utility bay into a shallow cross-axis waist. Keep the center quiet, but make its boundaries structural rather than empty.
- **Measurable outcome:** Reduce the uninterrupted central field from approximately 40% of shell height to no more than 25–30%; at 25% sheet scale, upper deck, waist, lower deck, and shoulder spine must each be identifiable within two seconds. Keep every new edge at least 6 px from native frames.

### C2 — The portrait system control is swallowed by the action harbor

- **Severity:** `major`
- **Affected panels:** All eight portrait panels
- **Visible evidence:** The circular top-center system control sits inside the plum harbor at the center of A/X/B/Y. It reads as a fifth face button in a five-way pod, not as an independent system index. This breaks the specified portrait focal hierarchy and makes the action group more console-like than instrument-like.
- **Likely cause:** The action harbor was expanded around the action-role union without subtracting or isolating the system role.
- **Concrete correction:** Carve the plum harbor away from the system control and expose an indigo shell island or notch around it; retain only the small violet system index.
- **Measurable outcome:** Maintain an 8 px minimum indigo moat between the system frame and the plum perimeter at 1×. At 25% scale, the system control must read outside the four-action group rather than as its center.

### C3 — Harbors and shoulder rails form hard tangencies instead of inset groups

- **Severity:** `major`
- **Affected panels:** All 16 panels; clearest in landscape outer edges and portrait left-side R/L controls
- **Visible evidence:** In landscape, the charcoal harbor terminates against the shell’s left rim and the plum harbor against its right rim, so both read as color-blocked endcaps rather than recessed wells. In portrait, the R rail intersects the action-harbor corner and the L rail meets the movement-harbor corner; both bars also protrude over the shell edge without the promised spine. These are visible 0–2 px contacts, not deliberate clearances.
- **Likely cause:** Role-union expansion was clamped to the outer silhouette, and the shoulder frames were not included in a final artwork-to-native clearance pass.
- **Concrete correction:** Pull landscape harbors inward to restore a continuous shell band, reshape portrait harbor corners away from R/L, and extend the portrait shell spine beneath the full shoulder faces.
- **Measurable outcome:** Preserve at least 8 px of shell between each harbor and the inner shell rim, at least 8 px between harbor artwork and shoulder frames, and never less than the art-direction minimum of 6 px between an unrelated decorative edge and a native frame.

## Pass 2 — Material and craft

### M1 — Violet bloom replaces the specified tactile material system

- **Severity:** `major`
- **Affected panels:** All normal and active panels in both orientations and appearances
- **Visible evidence:** Broad violet fog extends roughly 8–16 px beyond movement, action, shoulder, utility, and system faces. It spreads evenly around controls and stains the surrounding wells. Narrow upper-left lacquer arcs, compact lower-right shadows, and a clear distinction between elastomer, lacquer, and low-profile keys are not legible. Normal therefore looks electronically lit rather than raised and tactile; active looks like more of the same effect.
- **Likely cause:** Large-radius colored shadows/highlights are being used as the primary depth treatment across semantic materials.
- **Concrete correction:** Remove colored outer glow from normal and active materials. Rebuild depth with a 1–2 px upper-left highlight, a crisp lower-right bevel, and a compact 2–3 px lower-right cast shadow; keep action lacquer clean and movement highlights broad but subdued.
- **Measurable outcome:** No colored halo may remain more than 2 px outside a native face, every visible highlight must resolve on the upper-left edge, and every cast shadow must resolve only on the lower-right. Violet in normal may appear only in the calibration seam/system index.

### M2 — Dark appearance does not fully preserve the five depth tiers

- **Severity:** `minor`
- **Affected panels:** Landscape and portrait / dark / all four states, most visible in pressed and disabled
- **Visible evidence:** The outer cast shadow disappears into the near-black canvas, and the shell’s lower-right edge and charcoal harbor lose more separation than their light counterparts. In pressed and disabled panels, removal of the luminous effects leaves shell, well, and control faces unusually flat. The silhouette remains traceable, but the depth stack is less coherent than in light mode.
- **Likely cause:** Dark mode uses the same edge weights and shadow behavior as light mode despite the much lower canvas luminance.
- **Concrete correction:** Tune dark-specific rim, lower-right edge, and harbor inner-shadow values rather than relying on the light-mode treatment or glow for separation.
- **Measurable outcome:** Retain a continuous 1–2 px shell rim and a visible 2–3 px inset-well transition at 100%, with no edge dropout longer than 4 px; shell, harbor, and controls must remain separable at 25% in pressed and disabled panels without bloom.

### M3 — Orphan calibration ticks weaken the “single seam” grammar

- **Severity:** `minor`
- **Affected panels:** All 16 panels
- **Visible evidence:** Several faint vertical ticks appear across the landscape center, while short horizontal ticks appear above and below the portrait waist. They do not establish a repeatable scale, nearly disappear by state/appearance, and compete with the stated signature of one violet calibration seam.
- **Likely cause:** Decorative registration marks were retained as low-opacity texture rather than resolved into the final seam system.
- **Concrete correction:** Remove the orphan ticks and keep only the orientation-specific calibration seam, interrupted by native controls as specified.
- **Measurable outcome:** Exactly one calibration seam should remain per orientation; it must stop at least 6 px before native frames, and normal-state violet coverage must remain under 2% of the canvas.

## Pass 3 — Interaction

### I1 — Normal, pressed, and active communicate light intensity rather than physical state

- **Severity:** `major`
- **Affected panels:** All 16 panels, especially every normal/pressed/active triplet
- **Visible evidence:** Normal controls already carry a strong violet aura. Pressed primarily removes that aura and darkens the key, so it reads as “off,” with little visible inner-shadow depression. Active restores and enlarges the aura, but a crisp 1.5–2 px violet index ring is not visible. Normal and active are distinguishable only by bloom strength, the exact behavior the art direction prohibits. There is no visible layout shift, but state semantics are wrong.
- **Likely cause:** States appear derived from global glow/opacity multipliers instead of explicit material-specific raised, depressed, indexed, and unavailable styles.
- **Concrete correction:** Author state behavior independently for movement, action, utility/menu/system, and shoulder materials: tactile raised normal; center-anchored recessed pressed; raised active with a crisp violet ring; flat, desaturated disabled.
- **Measurable outcome:** Pressed must remain at 0.96–0.98 scale with at least 50% less cast shadow and a visible inner shadow; active must return to 0.99–1.00 scale with a 1.5–2 px ring and no bloom; normal must contain no violet control halo. All four states must remain identifiable at 25% without using position changes.

### I2 — Disabled small legends carry avoidable accessibility risk

- **Severity:** `minor`
- **Affected panels:** All four disabled panels, strongest on portrait Start/Select and landscape/portrait L/R in dark appearance
- **Visible evidence:** Disabled arrows and large action letters remain recognizable, but the much smaller Start, Select, L, and R legends become low-contrast gray marks. They are barely resolved at native contact-sheet scale, particularly in portrait dark, even though the surrounding group remains understandable.
- **Likely cause:** Disabled visual weight is being reduced on both the control material and the legend, with small text receiving no contrast compensation.
- **Concrete correction:** Keep disabled depth and saturation reductions, but raise small legend luminance independently instead of fading the whole control uniformly.
- **Measurable outcome:** Small disabled legends should meet the quality bar’s preferred 4.5:1 contrast against their local fill in both appearances; all other disabled marks must remain at least 3:1. Start and Select must be readable without zooming the final contact sheet.

## Originality and trade-dress check

No manufacturer marks, model names, logos, proprietary glyphs, vents, screws, speaker arrays, screens, traced hardware outlines, dog-bone shell, paired circular wells, or artwork-rendered button legends are visible. The clipped slab silhouette, indigo/plum palette, and single-seam premise remain legally and visually distinct from the named references.

There is nevertheless an **originality caution**, not a trade-dress rejection: the landscape wells becoming full-height colored endcaps and the portrait system control becoming the center of a five-way action pod push the work back toward generic console control grammar. Findings C2 and C3 should be corrected while preserving the softened-octagonal field-case identity.

## Acceptance summary

- **16 required combinations:** met; no missing or stretched panel.
- **Immediate semantic grouping:** met in landscape; only partial in portrait because the system role merges with actions and the center lacks structure.
- **Orientation-specific composition:** not met.
- **Artwork/native clearance and inset depth:** not met visually despite automated geometry scoring.
- **Legend visibility:** normal states are clear; disabled small legends remain an accessibility risk.
- **Pressed/active behavior:** not met.
- **Violet restraint and no-glow rule:** not met.
- **Consistent upper-left lighting/material tiers:** not met.
- **Originality boundary:** met with the caution above.

## Optional taste

No optional taste request is being used to hold the verdict. The requested changes follow explicit composition, clearance, state, material, and accessibility criteria. Alternate ornament, extra labels, or decorative detail are neither requested nor recommended.

## Final verdict

**revise** — No blocker was found, but five major findings remain. This cannot receive `visual-pass` until portrait architecture is recomposed, harbor/control tangencies are cleared, and the glow-based material/state system is replaced with tactile edges and crisp active indexing. This critique is not publication approval or human approval.

**Report:** `docs/skins/examples/indigo-pocket/reviews/critique-1.md`

**Three highest-priority findings:**
1. **I1:** Replace glow/opacity state changes with raised, depressed, indexed, and disabled native material states.
2. **C1:** Recompose portrait into legible upper/lower decks, a shallow waist, and a continuous shoulder spine.
3. **C3:** Remove shell/harbor and shoulder/harbor tangencies with measured 6–8 px clearances.
