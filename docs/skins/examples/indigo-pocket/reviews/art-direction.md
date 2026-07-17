# Indigo Pocket — Art Direction

## Contract

- Canonical artboard: `showcase-controller-v1`, template `snes`, revision 1.
- Landscape: 874 × 402; safe rectangle x 4.5–95.5%, y 3.5–96.5%.
- Portrait: 402 × 874; safe rectangle x 2.5–97.5%, y 5.5–95.5%.
- Required roles: movement, primary action, secondary action, utility, menu, custom shoulder controls, and system chrome.

## Concept and emotional target

**Indigo Pocket is a compact calibration instrument: a deep-indigo, clipped-edge portable slab whose warm legends and plum controls feel precise, tactile, and quietly treasured rather than nostalgic.** It should evoke confidence at first touch and warmth in extended use.

## Originality boundary

Category language may inform plausible seams, key travel, and molded materials, but the result must not copy the SNES “dog-bone”/lobed outline, its paired circular wells or face-button color blocking; Delta’s console-facsimile skins; Analogue Pocket’s rectilinear front-face grid; Playdate’s yellow/black identity; any manufacturer mark, logo, model name, vent array, proprietary glyph, or traced silhouette. Do not add ornamental button letters or arrows to SVG: native labels are the only control legends.

The original signatures are a **softened octagonal field-case silhouette**, a **single calibration seam** in electric violet, and orientation-specific **control harbors** shaped around semantic groups rather than copied hardware components. No faux speaker, cartridge slot, screen, screws, or decorative controls.

## Composition and hierarchy

### Landscape

Use one low, softened-octagonal shell spanning the usable width, with clipped corners rather than grips or lobes. Create a broad charcoal movement harbor around the left directional cluster and a plum action harbor around the right four-button cluster; each harbor follows the union of its canonical role frames without becoming a drawn D-pad or four fake button discs. The central negative space is deliberate breathing room: seat Select/Start low in a narrow recessed bridge, place the system toggle as a small top-center index, and integrate L/R into a quiet upper shoulder rail.

Focal order: lacquered plum actions first; the larger matte-charcoal movement mass second; warm-ivory utility legends third. The violet calibration seam runs once through the central bridge, interrupted by native controls, to balance the two harbors. It must not become a full perimeter glow.

### Portrait

Recompose; do not rotate or stretch landscape art. Use one tall field-case shell with two broad decks and a shallow central waist. The upper deck contains the plum action harbor; the lower deck contains the charcoal movement harbor. The left edge becomes a structural spine that visually seats the separated R and L shoulder controls, while the waist gives the right-side Start/Select pair a low-profile instrument bay. Keep the top-center system control visually independent of the action cluster.

Focal order: plum upper deck first, dark lower movement deck second, then the right waist controls. Continue the calibration seam across the waist only; this short cross-axis makes the tall composition feel engineered and prevents the empty middle from reading accidental.

## Palette tokens

| Token | Light appearance | Dark appearance | Intent |
|---|---:|---:|---|
| `canvas` | `#E9E2D3` | `#090A13` | Warm tabletop / near-black viewing field |
| `shell` | `#292752` | `#1A1937` | Deep indigo body; never pastel or black |
| `shell_rim` | `#5D5988` | `#48466F` | Thin edge definition, not a glow |
| `well` | `#191832` | `#0F0F23` | Recessed control harbors |
| `movement_charcoal` | `#2B2B33` | `#25252E` | Low-sheen tactile movement controls |
| `action_plum` | `#702653` | `#5A1E45` | Lacquered action controls; one hue across all four |
| `legend_ivory` | `#FFF1D0` | `#FFEFC7` | Native labels and glyphs |
| `electric_violet` | `#A77CFF` | `#B08EFF` | Calibration seam and active-state index only |

Normal native legends must reach 7:1 or better against their local fill (the proposed movement/plum pairs exceed 8.9:1). Disabled legends must remain at least 3:1. Violet active outlines must reach at least 3:1 against adjacent control fill; violet may not be used as a large fill.

## Material, edge, light, and legend system

Lighting is fixed at upper-left (approximately 315°). Stack five depth tiers: matte canvas; satin indigo shell; inset midnight harbors; raised native controls; flush native legends. The shell gets a 1–2 px upper-left rim, a darker lower-right edge, and a soft compact cast shadow. Harbors use inner shadow, not blur, to read 2–3 px below the shell. Movement controls are fine-grain elastomer with broad, subdued highlights. Action controls are plum lacquer with one narrow upper-left specular arc and a crisp lower-right bevel. Utility/menu/system controls are low-profile indigo keys; shoulders use charcoal rail-key material.

Use shell micro-speckle at roughly 1–1.5 px scale and no more than 3% tonal variance; it should disappear at thumbnail size. Keep lacquer and legends clean. No glass, bloom, scanlines, chromatic aberration, or stacked glows. Corners within one depth tier share radii, and highlights, bevels, strokes, and shadows must all agree with the same light direction. Native labels stay centered, unwarped, warm ivory, and unobstructed; no duplicate artwork legends.

## Native state behavior

- **Normal:** full material identity, raised 1× scale, compact lower-right shadow, upper-left highlight, and clear ivory legend.
- **Pressed:** center-anchored 0.96–0.98 scale; cast shadow reduced by at least half; specular highlight reduced; darker fill plus inner shadow communicates depression. Do not move the frame or label.
- **Active:** 0.99–1× scale and raised silhouette return; add a crisp 1.5–2 px electric-violet index ring/seam with a modest fill lift. It must be stronger than normal and visibly different from pressed, without bloom.
- **Disabled:** remove specular highlight and cast shadow, reduce saturation, and use 55–65% visual weight while preserving at least 3:1 legend contrast and recognizable grouping. Do not rely on opacity alone.

Author explicit state styles for every semantic material in both appearances.

## Artwork-to-role alignment

Artwork is passive support only. Center each harbor on the canonical role-frame union and keep its perimeter at least 8 px outside native control frames at 1×. Decorative seams must stop before entering a native frame. Do not draw circles, keys, arrows, letters, or other tappable-looking substitutes beneath or above controls. Use role assignments for materials and leave geometry, hit testing, state rendering, labels, and accessibility native. Any overlay crossing a control region must be purely edge light at low opacity and may not reduce label contrast.

## Acceptance criteria

1. The native contact sheet contains all 16 combinations (2 orientations × 2 appearances × 4 states), with no missing or stretched variant.
2. At 25% contact-sheet scale, movement and action groups are identifiable within two seconds, and portrait’s upper/lower decks read as intentionally recomposed rather than rotated landscape art.
3. Every role-aligned harbor contains its canonical control centers within the quality checker’s ±3% tolerance; no unrelated decorative edge comes within 6 px of a native frame, and no shell edge is clipped.
4. Normal legend contrast is ≥7:1, disabled legend contrast is ≥3:1, and active violet-to-adjacent-fill contrast is ≥3:1 in light and dark.
5. Pressed controls scale to 0.96–0.98 with at least 50% less cast shadow; active controls are ≥0.99 scale with a 1.5–2 px violet index; disabled styling changes more than opacity. All four states remain distinguishable side by side.
6. Electric violet occupies under 2% of either normal-state canvas and appears only in the calibration seam/system index; active outlines are the sole exception.
7. All visible highlights point upper-left and shadows lower-right; no glow, raster seam, banding, inconsistent radius, or texture larger than 1.5 px is visible at 100%.
8. Originality review finds no logos, copied glyph arrangements, dog-bone/lobed shell, paired circular wells, console-specific color blocking, vents, screws, or artwork-rendered control faces/legends.

## Strongest design risks

- The canonical four-direction/four-action geometry can drift into recognizable 16-bit trade dress if harbors become a D-pad cross or paired circular wells.
- Portrait’s large middle gap can feel empty unless the waist, shoulder spine, and short calibration seam provide structure without competing with controls.
- Plum lacquer and violet active indexing can lose separation in dark mode; protect the specified edge contrast and avoid bloom.
- Passive artwork may accidentally resemble controls; keep all tappable faces, glyphs, and state feedback native.
