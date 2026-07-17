# Foldline Relay — Art Direction

## Contract and inspected geometry

- **Skin:** Foldline Relay (`com.codybontecou.pocketpad.foldline-relay`)
- **Canonical artboard:** `productivity-one-handed-left-v1`, template `productivityOneHandedLeft`, **revision 1**
- **Required semantic roles:** `movement`, `primary_action`, `secondary_action`, `utility`, `menu`, and `system`
- **Landscape:** 874 × 402; safe rectangle x 4.5–95.5%, y 3.5–96.5% (approximately x 39.3–834.7, y 14.1–387.9 px).
- **Portrait:** 402 × 874; safe rectangle x 2.5–97.5%, y 5.5–95.5% (approximately x 10.1–392.0, y 48.1–834.7 px).

The native controls form the same four-row left-thumb matrix in different proportions. In landscape, the three columns begin near x 60.7, 218.1, and 375.3 px; rows begin near y 174.3, 230.6, 286.9, and 343.2 px. In portrait, columns begin near x 13.7, 86.0, and 158.4 px; rows begin near y 462.9, 559.0, 655.2, and 751.2 px. Each key is about 53 × 53 px. The system control is isolated at top center: approximately 60 × 44 px at (407, 24) landscape and (171, 79) portrait.

Role order is fixed: Up above Left/Down/Right; Return and Tab on row three with Escape at the inner/right position; Command and Prefix on row four with Palette at the inner/right position. The large upper and right fields are real canonical negative space, not missing controls. No source workspace existed at inspection time; this direction file is the only artifact to create.

## Concept and emotional target

**Foldline Relay is an editorial dispatch sheet folded into a one-handed command surface: a compact stack of die-cut thumb tabs sends one precise routed signal through generous paper space, creating a feeling of poised focus, quick handoff, and tactile intelligence.**

This is not “paper texture applied to a keypad.” The folds organize weight, the registration marks establish measurement, the route explains the empty field, and the colored tabs communicate command classes.

## Originality boundary

Category language may inform key travel, thumb reach, paper scoring, crop marks, and print-registration mechanics. Do not copy or closely evoke Teenage Engineering’s OP-1/Field System modular key grid, Braun calculator layouts, Playdate’s yellow identity, Apple keyboard keycap styling, Nintendo/Sega/Sony/Microsoft controller silhouettes, label-maker trade dress, stationery-brand marks, or another skin’s folds, route, palette blocking, or control arrangement. Do not use logos, model names, proprietary glyph sets, faux keyboard rows, console button-letter arrangements, traced hardware outlines, screws, vents, ports, or speaker patterns.

The legally distinct signatures are the **Thumb Folio** (an asymmetric scored-paper mass implied around the canonical left cluster), the **Relay Fold** (one line that changes direction only at visibly folded handoff points), and **open registration brackets** (short L-shaped print marks that measure space without resembling controls). Never reproduce an existing product’s silhouette or exact color placement.

## Orientation-specific composition

### Landscape — low dispatch packet

Treat the warm stock as the canvas itself; do not add a hardware shell or an enclosing lower border that tangles with the bottom row, whose native frames already end about 5.5 px from the canvas edge. Build the Thumb Folio as a low, stepped set of broad folded planes behind the left cluster, with a clean upper shoulder above Up and a clipped inner fold beyond the Escape/Palette column. Its visible top and inner edges create the silhouette; its lower continuation is the canvas stock, not a cropped shell.

The three control columns should read as a four-row die-cut tab stack, not a keyboard grid: movement forms the first dark anchor, ultramarine Return/Tab form the second beat, then Command/Prefix, Escape, and Palette create an intentionally uneven right edge. Begin the Relay Fold outside the cluster’s inner edge, carry it into the empty right field, make one signal-orange handoff turn, then return toward the isolated top-center system control. Keep most of the right field unfilled; the line should explain the space, not occupy it.

**Focal hierarchy:** dense-ink movement group first; ultramarine Return/Tab second; the chartreuse Palette and orange Escape as two small terminal accents third; routed line and system tag fourth. At thumbnail size the left cluster must outweigh the route by at least 3:1 in apparent area.

### Portrait — tall folded docket

Recompose rather than rotate. Use a narrow folded-paper docket rising from the lower-left control zone, with a vertical score just beyond the third column and one oblique fold above Up. The four rows become a descending stack of thumb tabs with a deliberately ragged inner/right contour. Preserve the huge upper field and the full right half as calm proofing space.

Route the Relay Fold from the Palette/Escape side into the right field, run it upward as a long editorial rule, and fold it left toward the top-center system control. Use only two directional turns in portrait. Place one pair of registration brackets along this vertical run to measure the negative space; do not mirror the landscape brackets or stretch its fold plane.

**Focal hierarchy:** the lower-left tab docket first; the vertical relay rule second; the isolated system tag third. The route may be longer than in landscape but must remain optically lighter than every native control face.

## Palette tokens and appearance intent

| Token | Light | Dark | Purpose |
|---|---:|---:|---|
| `canvas_stock` | `#F3E7C9` | `#12171D` | Warm uncoated sheet / carbon-blue proofing ground |
| `fold_plane` | `#FFF5DA` | `#23282F` | Raised paper plane / graphite folded stock |
| `crease_edge` | `#C6B78F` | `#080B10` | Fold shadow and scored edge |
| `dense_ink` | `#171C24` | `#0D1117` | Movement tabs, rules, and dark structural mass |
| `ultramarine` | `#2446C7` | `#4058D0` | Primary-action tabs and authored route segments |
| `acid_chartreuse` | `#C7EF4A` | `#D3F75D` | Utility tab, registration index, active signal on dark fills |
| `signal_orange` | `#F26432` | `#FF7448` | Escape and the single relay handoff point |
| `secondary_stock` | `#DDD0AC` | `#C9B993` | Command/Prefix tab stock; intentionally quieter than primary |
| `registration_gray` | `#6D665B` | `#8F9188` | Subordinate crop/measurement marks |
| `legend_stock` | `#FFF3D6` | `#FFF0CF` | Native legends on ink and ultramarine |

Dark appearance is a separate carbon-proof composition, not a hue-inverted light version: the paper plane becomes graphite, crease shadows deepen, registration marks lift, and chromatic tabs gain enough luminance to remain distinct without glow. Normal legend contrast targets are **at least 7:1 preferred and never below 4.5:1**; the proposed pairs are approximately 15.5:1 for stock on ink, 6.9:1 for stock on light ultramarine, 5.3:1 for stock on dark ultramarine, 12.9:1 or better for ink on chartreuse, and 5.4:1 or better for ink on orange. Disabled legends must remain at least 3:1.

## Material, edge, light, texture, and legend system

Use five depth tiers: canvas stock; raised fold planes; shallow printed/creased grouping fields; raised native die-cut tabs; native legends. Light comes consistently from the upper-left at roughly 315°. Every raised paper edge gets a narrow upper-left fiber highlight and a 2–3 px lower-right contact shadow; every crease gets a dark 1 px score with a softer 1–2 px shadow on its lower-right side. Fold intersections must resolve as over/under layers, never transparent glass overlaps.

Native controls should read as thick die-cut editorial tabs: nearly matte faces, a crisp 1 px cut edge, 1–2 px paper ply, and a compact lower-right shadow. Movement is dense-ink stock; Return/Tab are ultramarine; Command/Prefix are secondary stock; Palette is chartreuse; Escape is signal orange; the system role is a low-profile dense-ink tag with a restrained ultramarine edge. Keep role shapes native—artwork must not redraw key faces.

Paper fiber is directional and extremely fine: 0.6–1.2 px flecks/threads at 1×, under 3% tonal variance, visible at 100% but absent at 25%. Ink faces may show only a sparse 0.5–0.8 px tooth, never uniform noise. No glass, bloom, neon, metallic bevels, blur haze, scanlines, halftone fields, torn edges, tape, stickers, or decorative shadows unrelated to the 315° light.

All visible legends and glyphs remain native, centered, flat, and unwarped; SVG artwork contains no duplicate labels or key symbols. At 1×, `Command`, `Palette`, `Escape`, `Return`, and `Prefix` must remain single-line and untruncated with at least a 9 px cap height and 4 px horizontal clear space from the native face edge. The system control may retain its native compact glyph instead of printing the accessibility name “Control Bar Toggle” as microtext.

## Native state behavior

- **Normal:** full tab color and paper tooth, 1× centered geometry, crisp cut edge, upper-left highlight, and compact lower-right shadow.
- **Pressed:** center-anchored scale of 0.96–0.97; shadow depth reduced by at least 60%; upper-left highlight narrows; fill darkens 8–12%; a subtle inner lower-right edge makes the tab feel pushed into its die cut. Native frame and legend center do not move.
- **Active:** return to 0.99–1× and restore the raised edge; add a crisp 2 px registration index with no glow. Use chartreuse on movement, primary, and system; ultramarine on secondary and utility; use dense ink on orange menu controls. Every active index must reach at least 3:1 against its face and be visibly stronger than normal without resembling pressed.
- **Disabled:** flatten the cast shadow, remove the fiber highlight, reduce chroma by 55–70%, and replace the crisp cut edge with a quiet neutral edge. Preserve role grouping and at least 3:1 legend contrast; do not implement disabled as opacity alone.

Every semantic material must explicitly support all four states in both appearances. Static canvas artwork does not change state and must never be the only state cue.

## Artwork alignment to semantic roles

Use material assignments, not artwork, for the six native roles. Passive fold planes may follow the union of related frames but must stop at least 8 px from native faces wherever canvas clearance permits. The landscape bottom edge is the sole constrained area: place no fold line, border, bracket, or shadow between the bottom-row controls and canvas edge. Maintain at least 10 px clearance between the Relay Fold/registration marks and all key frames, and at least 8 px around the system frame before the route terminates.

Registration brackets must be open L marks, 6–10 px long with 1–1.5 px strokes, placed in noninteractive negative space. They may align to row baselines or the system centerline but cannot form crosshairs, circles, key outlines, or tappable-looking targets. Artwork remains below native controls and cannot alter hit testing, geometry, labels, state rendering, bindings, haptics, or accessibility.

## Measurable acceptance criteria

1. The native contact sheet includes all **16 combinations** (2 orientations × 2 appearances × 4 states), and portrait is independently composed rather than rotated or stretched landscape art.
2. At 25% scale, a reviewer identifies the lower-left command cluster within two seconds; in both orientations its apparent area is at least three times that of the Relay Fold, and the upper/right field still reads as intentional breathing room.
3. All role artwork tracks the inspected canonical frames within **±3% of canvas dimensions**; route and registration strokes remain at least 10 px from key frames and 8 px from the system frame, with no 4–8 px accidental tangencies or clipped decorative edges.
4. Normal legend contrast is ≥4.5:1 (≥7:1 preferred), disabled legend contrast is ≥3:1, and every active index is ≥3:1 against its face in light and dark.
5. At 1×, `Command`, `Palette`, `Escape`, `Return`, and `Prefix` are single-line, untruncated, ≥9 px cap height, and retain ≥4 px horizontal face clearance; no SVG label or glyph duplicates native content.
6. Pressed tabs scale to 0.96–0.97 with at least 60% less cast shadow; active tabs return to ≥0.99 with a crisp 2 px index; disabled tabs change edge, chroma, and depth rather than opacity alone. All four states are distinguishable side by side.
7. All highlights point upper-left and shadows lower-right; paper texture stays within 0.6–1.2 px and ≤3% tonal variance. No glow, glass, banding, raster seam, fold-layer contradiction, or texture blob is visible at 100%.
8. Originality review finds no logo, model name, proprietary glyph arrangement, hardware shell, keyboard grid, console trade dress, copied color blocking, faux port/vent/screw, or artwork-rendered control face.

## Strongest design risks

- The canonical bottom landscape row sits only about 5.5 px from the canvas edge, so any enclosing shell, border, crease, or shadow there will look clipped or create a tangent.
- Three columns by four rows can drift into a generic keyboard/keypad; the ragged role-colored contour and fold hierarchy must prevent uniform-grid reading.
- The routed line and registration marks can resemble circuitry or fake controls if they gain nodes, crosshairs, glow, or excessive weight.
- Warm stock and chartreuse are close in light-mode luminance; separate them with dense-ink edges and placement, not shadows or saturation alone.
- Long native labels have little room on ~53 px faces; texture, thick borders, or duplicate artwork will quickly compromise legibility.
