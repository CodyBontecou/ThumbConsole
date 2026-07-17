# Solar Sumi — Independent Visual Critique 4

- **Reviewer:** `pocketpad-visual-critic`
- **Date:** 2026-07-17
- **Evidence:** `docs/skins/examples/solar-sumi/reviews/contact-sheet-4.png` (2176 × 1714)
- **Comparison:** `reviews/contact-sheet-3.png` and `reviews/critique-3.md`
- **Art direction:** `reviews/art-direction.md`
- **Verdict:** **visual-pass**
- **Open finding count:** 0 blockers, 0 major, 0 minor

## Inspection coverage and renderer-delta audit

All 16 current native-renderer panels were inspected at the exact 2176 × 1714 source resolution and at 25% scale (544 × 429): landscape and portrait; light and dark; normal, pressed, active, and disabled. Exact-pixel crops were used to inspect every `Start`, `Coin`, and `Stick` legend across both orientations, appearances, and all four states. State comparisons were repeated while excluding the Stick so it could not carry the active distinction by itself.

The pass-3/pass-4 raster comparison confirms the stated renderer-only change:

- **4,951 of 3,729,664 pixels differ (0.133%).**
- 4,949 changed pixels have a maximum per-channel delta of **1/255**; the remaining two peak at **2/255**. The maximum summed RGBA delta for any pixel is 3.
- At exact 25% reduction, 486 pixels differ, all by at most **1/255** per channel.
- Differences remain on low-order antialias fringes in the rerendered native layer, including the long-label controls. There is no high-contrast displacement, changed glyph footprint, layout shift, clipping, or artwork/silhouette movement.

`Start`, `Coin`, and `Stick` remain complete, centered, upright, and readable in every panel. No terminal letter is clipped; no legend touches its control edge; and no legend changes position between normal, pressed, active, and disabled. The tiny numerical delta is not visually perceptible at full resolution or 25% and introduces no regression.

## Critique-3 finding audit

| Prior finding | Pass-4 status | Current rendered evidence |
|---|---|---|
| **C-01** Generic landscape enclosure | **Passed; stable** | The clipped lower-left corner, saddle, stepped lower edge, and rising right shoulder remain distinct at 25%; the deck does not read as a commercial case. |
| **C-02** Portrait crown tangency | **Passed; stable** | Every portrait panel retains a clean fiber cap above B4 and the upper current; neither control nor artwork is clipped. |
| **C-03** Current/gutters form a button plate | **Passed; stable** | Open fiber channels still separate the current from individual actions, preventing a unified row plate. |
| **M-01** Dark depth tiers collapse | **Passed; stable** | Canvas, smoked deck, absorbed current, native controls, utility lane, and legends remain separable in all dark panels, including at 25%. |
| **M-02** Violet Stick puck | **Passed; stable** | The Stick remains carbon in normal/pressed, gold in active, and neutral gray in disabled; no violet returns. |
| **M-03** Regular brush-notch register | **Passed; stable** | Current edges stay sparse and irregular. No mechanical pale notch cadence competes with the intentional gold register. |
| **I-01** Disabled reads enabled | **Passed; stable** | All four disabled panels lose chroma, cast depth, and specular weight together while retaining labels and grouping. |
| **I-02** Active depends on Stick/system | **Passed; stable** | With Stick ignored, the primary pair, indexed custom quartet, secondary pair, Start, Coin, and system treatment still separate active from normal in both appearances and orientations. |
| **I-03** Dark Coin/system visibility | **Passed; stable** | Coin and system silhouettes remain visible in dark normal, pressed, active, and disabled; their recognition does not depend on text alone. |
| **O-01** Ensō-like joystick surround | **Passed; stable** | The filled asymmetric island remains connected to the current and never becomes an open circle, horseshoe, or perimeter-tracing loop. |

## Art-direction acceptance criteria

| Criterion | Pass-4 result | Evidence |
|---|---|---|
| 1. All 16 combinations; separately authored portrait | **Met** | All combinations are present. Portrait retains its vertical deck, upward current, left waist, and lower bay rather than a transformed landscape composition. |
| 2. Every canonical role visibly covered | **Met** | B1–B8, Stick, Start, Coin, and system are visible and materially grouped in every state. No nonexistent movement-role styling appears. |
| 3. Action-first and directional read at 25% | **Met** | The action register remains the first read. Landscape travels left-to-right from Stick to actions; portrait rises from the lower pool into the split action rails. |
| 4. Clearances, alignment, and no clipping | **Visually met and unchanged** | Top portrait B4 and far-right landscape actions remain intact; outer margins and fiber gutters stay open with no new tangency. The antialias-only delta cannot represent a geometry shift. |
| 5. Legend and active-index contrast | **Visually met** | Normal and disabled legends remain legible in light and dark. Active perimeter/fill changes survive 25%, including with Stick excluded. Long labels remain complete and centered. |
| 6. Four distinct states | **Met** | Normal is raised, pressed is darker/flatter, active returns raised with strong indexing, and disabled is neutral and unavailable. No state introduces label or frame drift. |
| 7. Material and raster craft | **Met** | Lighting remains upper-left/lower-right; texture remains restrained; no glow, banding, seam, stretched texture, clipping, regular notch run, or label artifact appears. |
| 8. Originality and trade dress | **Met** | No logo, copied hardware silhouette, mounting detail, commercial row framing, circular plate, cultural stock motif, or artwork-rendered control face is present. |

# Pass 1 — Composition

No composition defect is visible.

Landscape retains the asymmetric Offset Fiber Deck, grounded Stick island, narrowing middle current, and open action channels. Its outer edge remains clear of B4/B8, and the system/utility lane stays balanced rather than floating in unexplained space.

Portrait remains a genuine recomposition with a broad action crown, quiet left waist, right-side upward bend, and offset lower Stick bay. The top cap, central interval, and side channels survive all state and appearance changes. No panel shows clipping, crowding, control/artwork tangency, or orientation-specific regression.

# Pass 2 — Material and craft

No material or craft defect is visible.

Light and dark remain separately authored. Both preserve the intended five-tier depth hierarchy, coherent upper-left highlights, lower-right containment, flat absorbed current, restrained directional fiber, and sparse gold register. Dark mode does not collapse the deck, current, control, and legend tiers.

At exact pixels, the native long-label rendering remains clean: `Start`, `Coin`, and `Stick` have stable baselines, complete glyphs, consistent centering, and no warp or edge collision. The pass-3/pass-4 changes are only 1–2 code-value antialias fluctuations and do not create a seam, halo, blur, jagged contour, truncation, or contradictory lighting cue.

# Pass 3 — Interaction

No interaction defect is visible.

- **Normal:** raised, materially stable baseline with clear vermilion, carbon-soft, carbon, and fiber families.
- **Pressed:** darker and flatter with reduced cast shadow; control centers and all legends remain fixed.
- **Active:** raised geometry returns with strong role-appropriate perimeter/fill treatment. The action and utility groups preserve the distinction when Stick is excluded.
- **Disabled:** desaturated, flattened, and neutral across every semantic role while labels and group boundaries remain understandable.

The four states remain distinguishable side by side in light and dark at 25%. Active does not collapse toward normal; pressed does not resemble disabled; and disabled does not retain an energized vermilion or gold focal cue. There is no layout shift or native-control visibility regression.

## Originality and trade-dress check

The visible signatures remain the original asymmetric Offset Fiber Deck, connected Carbon Current, and sparse Solar Register. Sheet 4 contains no manufacturer mark, logo, model name, proprietary glyph, cabinet/fight-stick case, mounting plate, bolt pattern, circular action plate, copied row framing, game art, ensō/open circle, rising-sun device, seal block, kanji, pseudo-calligraphy, or duplicate artwork legend.

The canonical eight-button geometry is not reinforced with familiar commercial hardware framing. The filled Stick island remains irregular and materially connected, not a simulated mounting plate. No originality or trade-dress regression is visible.

## Defects versus optional taste

**Defects:** none. There are no blocker, major, or minor findings to register.

**Optional taste:** the aggressive portrait waist cut and broad gold active treatment remain assertive authored choices. They do not reduce hierarchy, state recognition, clearance, label legibility, or originality and require no correction.

## Final verdict

**visual-pass** — contact sheet 4 has no blocker, major, or minor defect. Every criterion and closure recorded in critique 3 remains passed. The 4,951 changed pixels are imperceptible low-order native-layer antialias differences, and the current renderer introduces no actual visual regression. This verdict is visual review only, not human approval or permission to publish.

**Report:** `docs/skins/examples/solar-sumi/reviews/critique-4.md`

**Three highest-priority verified results:**
1. `Start`, `Coin`, and `Stick` remain complete, centered, legible, and stationary in all 16 panels despite the renderer delta.
2. Active remains distinct from normal without relying on Stick, while disabled remains unmistakably unavailable in both appearances and orientations.
3. All critique-3 composition, material, interaction, and originality closures remain stable; no clipping, tangent, raster artifact, or trade-dress regression is visible.
