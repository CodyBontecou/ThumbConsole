# Indigo Pocket — Independent Visual Critique 2

- **Reviewed artifact:** `reviews/contact-sheet-2.png`
- **Source resolution inspected:** 2176 × 1714 PNG, including all 16 native-renderer panels at full resolution and at 25% scale
- **Direct comparison:** `reviews/contact-sheet-1.png` at the same 2176 × 1714 resolution
- **References:** `reviews/art-direction.md`, `reviews/critique-1.md`, PocketPad visual quality bar
- **Review date:** 2026-07-17
- **Verdict:** **revise**

The automated 100/100 result is not treated as visual evidence. Contact sheet 2 makes substantial, visible corrections: the glow-based state system is gone, the wells are inset, portrait now has an authored waist and shoulder spine, and dark mode retains its depth stack. One prior major remains unresolved: portrait still places the system control inside—and visibly colliding with—the action cluster. Two minor craft/accessibility issues also remain.

## Direct resolution audit of critique 1

| Prior finding | Status in contact sheet 2 | Rendered evidence |
|---|---|---|
| **C1 — Portrait decks, waist, and shoulder spine** | **Resolved** | The formerly undifferentiated middle is now divided into upper and lower ledges, a chamfered central waist, an attached right utility bay, and a continuous dark left spine. At 25% scale, the plum upper deck and charcoal lower deck read as a portrait-specific composition rather than rotated landscape art. |
| **C2 — System swallowed by action harbor** | **Unresolved major** | The circular system face remains inside the plum polygon at the center of A/X/B/Y. Its top edge meets or passes under A; in active panels the violet system ring is visibly interrupted by A. |
| **C3 — Harbor/rim and shoulder/harbor tangencies** | **Resolved** | Both landscape wells now retain a continuous indigo shell band. In portrait, the action and movement harbors have been pulled rightward, leaving visible clearance from R/L and seating both shoulder faces within the left spine. No shell edge is clipped. |
| **M1 — Violet bloom replacing tactile material** | **Resolved at major level** | Normal contains no violet control halo; active uses crisp local outlines rather than fog. Compact highlights and lower-right edges now remain visible. A smaller material-specific craft issue remains below. |
| **M2 — Dark depth tiers collapse** | **Resolved** | In all four dark states, canvas, shell rim, shell, inset harbors/rails, controls, and legends remain separable without bloom. No rim dropout or merged shell/well region is visible at full resolution. |
| **M3 — Orphan calibration ticks** | **Resolved** | The stray registration ticks are gone. Each orientation retains one restrained, interrupted calibration seam plus the permitted system index. |
| **I1 — States communicate glow intensity** | **Resolved** | Normal is raised, pressed is darker and visually recessed, active restores the raised face with a crisp violet index, and disabled is flatter and desaturated. The four states remain distinct at 25%, and no layout or legend shift is visible. |
| **I2 — Disabled small legends** | **Partially resolved** | L/R and landscape Start/Select are clearer without bloom. Portrait Start/Select, especially dark disabled, still collapse into very small gray strokes at 1:1 contact-sheet viewing. |

## Pass 1 — Composition

### C2-1 — Portrait system/action separation remains unresolved and now clips active feedback

- **Severity:** `major`
- **Affected panels:** All eight portrait panels; most obvious in portrait / light and dark / active
- **Visible evidence:** The system circle remains centered inside the plum action harbor, so the upper group still reads as a five-way face-button pod. There is no continuous indigo moat separating the system role from the plum field. A sits directly against the system face; in both active portrait panels, A interrupts the top of the system’s otherwise crisp violet ring. This is a visible control-to-control collision, not merely close spacing.
- **Likely cause:** The action harbor was moved away from R, but it was not subtracted around the system frame; the system’s raised/ring bounds were also not included in the final portrait clearance check.
- **Concrete correction:** Cut a shell-colored indigo island/notch fully around the system frame and terminate the plum harbor before that island. Preserve the four-action harbor as one group, but do not let its fill or A’s rendered bounds touch the system face or active index.
- **Measurable outcome:** Show at least 8 native-renderer pixels of uninterrupted indigo between the system frame and plum artwork wherever native frames permit, with at least 6 px between the system active ring and every adjacent native face. The complete 1.5–2 px active ring must remain visible for 360° in both portrait appearances. At 25% scale, the system must read as an indigo system index adjacent to—not at the center of—the plum action group.

### Composition findings that are truly resolved

The portrait center is no longer an accidental blank slab: the chamfered waist occupies roughly the intended middle band, the right utility bay shares its contour, and the left shoulder spine is continuous from R to L. The shoulder faces no longer collide with either semantic harbor. Landscape balance also improves materially because the inset wells expose a continuous shell perimeter rather than full-height color-blocked endcaps. These corrections satisfy the prior C1/C3 concerns; no additional portrait-architecture or shoulder-integration defect is being held on taste alone.

## Pass 2 — Material and craft

### M2-1 — Action lacquer and movement elastomer still share nearly the same edge recipe

- **Severity:** `minor`
- **Affected panels:** All normal and active panels, clearest in both landscape appearances
- **Visible evidence:** Action and movement faces are now clean and tactile, but both use the same soft upper-left gradient and rectangular lower-right edge. The plum/charcoal hue change carries almost all of the material distinction. The specified narrow lacquer specular edge on actions versus broad subdued elastomer highlight on movement is not independently legible at full resolution.
- **Likely cause:** The semantic materials appear to share one native elevation/highlight treatment with different fill tokens.
- **Concrete correction:** Give plum action faces a clean 1 px upper-left specular edge and crisp lower-right bevel; keep movement faces on a broader, lower-contrast matte highlight with no hard specular streak. Preserve the current shadow direction and state geometry.
- **Measurable outcome:** At 100%, every normal action face must show one continuous 1 px upper-left specular segment and a crisp lower-right bevel, while movement faces retain a visibly broader, softer highlight. The two materials should remain distinguishable by sheen in a grayscale crop, not only by plum versus charcoal hue.

### Material findings that are truly resolved

The broad violet fog from contact sheet 1 is absent. Active outlines remain local and crisp, normal violet is confined to the seam/system index, and pressed faces no longer look merely “switched off.” Dark panels retain a continuous shell rim and readable inset transitions without using glow. The removed registration ticks leave no orphan marks. No new banding, raster seam, clipped shell edge, enlarged texture, or inconsistent lighting direction is visible. The interrupted portrait active system ring is accounted for under C2-1 rather than duplicated as a raster finding.

## Pass 3 — Interaction

### I2-1 — Portrait disabled Start/Select remain marginal at contact-sheet scale

- **Severity:** `minor`
- **Affected panels:** Portrait / light / disabled and portrait / dark / disabled; strongest on dark Select
- **Visible evidence:** Disabled action letters, arrows, and L/R remain recognizable, but the much smaller Start/Select legends reduce to approximately 4–5-pixel-high antialiased gray marks in the source contact sheet. Their locations remain understandable, yet the words are not comfortably decipherable at 1:1 without enlargement; dark Select is the weakest example.
- **Likely cause:** The disabled legend reduction is still applied uniformly across large glyphs and small text, so the smallest legends lose their solid ivory cores after contact-sheet downsampling.
- **Concrete correction:** Raise disabled small-legend luminance independently of disabled face saturation/depth while leaving large legends and control geometry unchanged.
- **Measurable outcome:** Start and Select must each be readable at 1:1 in both disabled portrait panels without interpolation or zoom, with measured local contrast of at least 4.5:1 against the disabled face. Disabled depth must still remain visibly flatter than normal, and no legend position or bounds may change between states.

### Interaction findings that are truly resolved

All semantic roles now show meaningful four-state behavior. Normal has the strongest material baseline; pressed removes most edge lift and darkens the face; active returns the raised silhouette with a crisp violet outline; disabled removes sheen, lowers saturation, and dims legends. These differences survive at 25% in portrait and landscape, light and dark. No state causes layout shift. The only active-feedback failure is the portrait system-ring collision already covered by C2-1.

## Originality and trade-dress check

No manufacturer mark, model name, logo, proprietary glyph, dog-bone/lobed outline, paired circular wells, console-specific multicolor face-button blocking, vent array, screws, speaker pattern, faux cartridge slot, screen treatment, or artwork-rendered control legend is visible. The softened clipped slab, orientation-specific inset architecture, indigo/plum palette, and single-seam grammar remain original and legally distinct from the named references.

The earlier landscape-endcap caution is resolved by the restored shell band. The portrait five-way reading remains an originality caution—not a trade-dress violation—because the unresolved system/action merge pushes the upper deck toward generic console grammar. Resolving C2-1 should strengthen both role clarity and originality.

## Acceptance summary

- **All 16 native combinations present and unstretched:** met.
- **Landscape and portrait intentionally composed:** met, except for portrait system/action role separation.
- **Harbor alignment, shell clearance, and shoulder integration:** met visually.
- **Normal/pressed/active/disabled distinction:** met, except for the clipped portrait system active ring.
- **Disabled legend legibility:** met for large legends and landscape small legends; portrait small legends remain marginal.
- **Dark five-tier depth:** met.
- **Violet restraint, no bloom, and single-seam grammar:** met.
- **Artifact-free rendering:** not fully met because the portrait system ring is visibly interrupted by A.
- **Originality boundary:** met with the system/action caution above.

## Optional taste

No optional ornament, palette change, additional seam, or decorative detail is requested. The remaining findings derive from explicit role separation, material differentiation, active-ring integrity, and legend-legibility criteria rather than stylistic preference.

## Final verdict

**revise** — Four of the five prior major findings are truly resolved, and the second sheet is materially stronger. `visual-pass` is still unavailable because C2 remains a major role-separation defect and visibly interrupts active system feedback in both portrait appearances. This critique is neither publication approval nor human approval.

**Report:** `docs/skins/examples/indigo-pocket/reviews/critique-2.md`

**Three highest-priority findings:**
1. **C2-1 (`major`):** Separate the portrait system control from the plum action harbor and eliminate the A/system ring collision.
2. **I2-1 (`minor`):** Restore comfortable 1:1 readability for portrait disabled Start/Select, especially dark Select.
3. **M2-1 (`minor`):** Differentiate action lacquer from movement elastomer through material-specific edge and highlight craft, not hue alone.
