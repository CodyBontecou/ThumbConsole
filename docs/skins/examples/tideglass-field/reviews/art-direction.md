# Tideglass Field — Art Direction

## Contract inspected

- Skin: `Tideglass Field`; identifier: `com.codybontecou.pocketpad.tideglass-field`.
- Canonical artboard: `game-boy-v1`, template `gameBoy`, revision 1.
- Required semantic roles: `movement`, `primary_action`, `utility`, `menu`, and `system`; there are no secondary-action or shoulder roles in this contract.
- Landscape is 874 × 402 with safe insets 4.5% left/right and 3.5% top/bottom. Movement occupies the left field (frame union x 4.06–31.94%, y 29.51–82.49%); A/B share one diagonal action field at right (x 71.16–91.84%, y 41.66–70.34%); Select/Start form a low central row (x 39.36–60.76%, y 75.00–83.00%); the system toggle is top-center (x 46.57–53.43%, y 6.03–17.97%).
- Portrait is 402 × 874 with safe insets 2.5% left/right, 5.5% top, and 4.5% bottom. A/B form an upper diagonal (frame union x 42.20–69.80%, y 8.41–28.59%); the system toggle is centered below it (x 42.54–57.46%, y 29.48–34.52%); Start and Select form a right-side vertical instrument row (x 71.36–86.40%, y 41.28–58.72%); movement occupies the lower field (union x 30.00–82.00%, y 68.28–95.72%).
- The canonical landscape left movement frame extends 0.44% beyond the nominal left safe inset, and the portrait bottom movement frame extends 0.22% beyond the nominal bottom safe limit. Artwork must honor these actual role frames without clipping them or forcing a false inset alignment.

## Concept and emotional target

**Tideglass Field is a calm hydrographic survey plate assembled from overlapping, tide-worn glass shelves, with etched depth contours, sparse coral datum marks, and tiny oxidized-brass sounding points that invite measured exploration rather than nostalgia.**

## Originality boundary

Marine instruments may inform measured spacing, engraved lines, mineral surfaces, and datum notation, but no commercial handheld may inform the finished outline or ornament. Specifically, do not copy any Game Boy rectangular shell, rounded lower corners, screen/bezel hierarchy, horizontal accent stripes, speaker slots, button angle as decoration, gray/olive/burgundy palette, logo placement, or model typography. Also avoid Analogue Pocket’s stark rectilinear face and screen-led hierarchy, dive-computer bezel language, nautical brand marks, compass roses, proprietary glyphs, and another skin’s glass or contour treatment. There must be no screen surrogate, cartridge seam, vent, screw pattern, fake button, or traced hardware silhouette.

The original visual signatures are the **bathymetric shelf** (one continuous, asymmetrically stepped glass field behind each semantic group), the **coral datum notch** (short isolated registration marks, never stripes), and **sounding pinpoints** (two or three asymmetrically placed flush brass dots tied to contour junctions, never perimeter fasteners). Sea glass is structural and frosted, not generic transparent “glassmorphism”; contours explain flow and grouping rather than supplying retro decoration.

## Silhouette and focal hierarchy

### Landscape — lateral transect

Build a low hydrographic plotting plate from three visibly overlapping but connected shelves: a broad left movement shelf, a narrow central sampling bridge, and a tapered right action shelf. The outer silhouette has a straight upper datum edge, one shallow top-center notch around—but not shaped like—the native system frame, an offset lower terrace beneath utility/menu, and unequal end chamfers. It must not have grips, lobes, a handheld rectangle, or bilateral console symmetry.

The movement shelf is the largest dark-teal mass and follows the union of the four movement frames with a generous irregular shoreline; it must not draw a D-pad cross. The action shelf is one continuous angled embayment around both A and B, not two circular wells and not a decorative echo of their diagonal. Select and Start sit on a slim mineral-foam sampling bridge, differentiated by native semantic materials rather than artwork labels. The system role remains a small, isolated top datum aperture.

Focal order: coral-accented native A/B controls first; the broad frosted movement shelf second; the central utility/menu bridge third; brass pinpoints and contours last. Contours travel predominantly left-to-right, widening through the center so the empty span reads as measured distance rather than unused space.

### Portrait — vertical sounding

Author a separate vertical composition, not a rotation or crop. Form one connected silhouette from an upper action shard, a narrow central sounding neck, and a broad lower movement delta. The upper shard leans slightly left around A/B; the lower delta widens toward the bottom around the movement union; alternating side notches at the neck prevent a commercial handheld outline. The native system frame sits as a centered junction between the upper shard and neck. Start and Select occupy a distinct right-side tide-gauge rail, with enough left-side negative space to keep the neck calm.

The lower movement delta is a single basin beneath all four direction frames, never a cross or four pads. Upper contours arc around the A/B frame union and then turn downward through the neck; lower contours fan outward around movement. The right utility/menu rail receives two coral datum ticks aligned to frame centers but no drawn key slots or duplicate labels.

Focal order: the coral-signaled upper action shard first; the weighty lower movement delta second; the right-side utility/menu rail third; the system junction fourth. This top/bottom counterweight is intentional and must not inherit landscape’s horizontal shelf proportions.

## Separately authored palette tokens

| Token | Light appearance | Dark appearance | Purpose |
|---|---:|---:|---|
| `canvas` | `#E8F2EC` | `#06181D` | Mineral-foam work surface / deep offshore field |
| `shell_glass` | `#4B9691` | `#245F61` | Frosted teal structural shelves; dark is denser, not a dimmed light value |
| `shell_milk_edge` | `#BDE0D4` | `#74AAA4` | Upper-left worn glass edge |
| `well_abyss` | `#083D43` | `#052F35` | Recessed role basins and neck cuts |
| `movement_fill` | `#0B4A50` | `#08393F` | Low-sheen movement material |
| `action_fill` | `#7F3537` | `#692D33` | Deep coral native action material |
| `utility_fill` | `#21585A` | `#103E42` | Quiet, low-profile utility/menu/system material |
| `legend_foam` | `#F7F4E7` | `#F3F1DF` | Native legends only |
| `signal_coral` | `#FF8A76` | `#FF826E` | Sparse datum ticks and active index |
| `oxidized_brass` | `#A57A36` | `#D5AC5C` | Flush sounding pinpoints only |
| `contour_etch` | `#9FC8BC` | `#457A78` | Subordinate etched tide contours |

Normal native legends target at least 7:1 against every semantic control fill (the listed normal pairs range from approximately 7.3:1 to 11:1). Disabled legends must remain at least 3:1. Every control must retain a minimum 3:1 visible boundary against its immediate well through fill contrast or a solid edge. The coral active index must be at least 3:1 against each local control fill in both appearances; coral is not a body fill outside the primary-action material.

## Material, edge, depth, light, texture, and legends

Use five depth tiers: matte canvas; connected frosted-glass shell shelves; etched/inset abyss wells; raised native controls; native legends and state indices. Transparency is limited to subtle edge depth—shell interiors remain at least 88% opaque so controls never float on background content. No blur, bloom, backdrop glass, or luminous perimeter.

Lighting is fixed at upper-left, approximately 320°. Glass gets a crisp 1–1.5 px milky upper-left edge, a 1.5–2 px dense lower-right edge, and a compact lower-right contact shadow no farther than 4 px. Wells sit 2–3 px below the shelf using a hard inner edge, not a fuzzy vignette. Native movement controls are finely abraded elastomer; action controls are smooth tide-polished resin with one short upper-left highlight; utility/menu/system controls are shallow matte keys. Pressed and active treatments must preserve this same light direction.

Etch contours are individually authored for each orientation at 1–1.25 px stroke, 22–30 px average interval at 1×, with no interval below 18 px and no more than seven visible contour paths in one uninterrupted region. They may vary gently but must not create moiré, topographic text, fingerprints, or concentric rings around controls. Shell mineral grain is 1–1.5 px at no more than 2.5% tonal variance and disappears at 25% scale. Brass pinpoints are 3–4 px, flush, limited to three per orientation, and placed asymmetrically on contour junctions so they cannot read as screws. Coral datum marks are 8–14 px long, limited to four in a normal composition, and never form a stripe.

All arrows, A/B text, Select/Start text, and system labeling remain native, centered, unwarped, and `legend_foam`. Artwork contains no lettering, duplicate glyphs, directional marks, or tappable-looking discs. Legend and control faces remain clean—grain and contour etching stop outside them.

## Native state behavior

Author explicit behavior for movement, primary action, utility, menu, and system materials in both appearances.

- **Normal:** stable raised control at 1.00 scale; full semantic fill; crisp upper-left edge and compact lower-right shadow; legends meet the 7:1 target. Coral is limited to the prescribed static datum marks.
- **Pressed:** center-anchored 0.97 scale with no frame or label drift; lower-right cast shadow reduced by at least 60%; upper-left highlight shortened; fill darkened 6–10% and a 1–2 px inner lower-right edge added so depression, not shrinkage alone, carries the state.
- **Active:** return to 0.99–1.00 scale and restored raised edge; add a crisp 1.5–2 px `signal_coral` index on the native control perimeter plus a 6–8% fill lift. No glow. Active must be visually stronger than normal and cannot resemble the inset pressed state.
- **Disabled:** remove specular and cast shadow, reduce saturation by 55–70%, soften the outer edge, and retain 48–58% material weight while preserving at least 3:1 legend contrast. Grouping and silhouette stay intact; opacity alone is insufficient.

## Artwork alignment to semantic roles

Artwork is passive support. Construct each shelf or basin from the union of its canonical semantic frames, then maintain an 8–12 px clear halo outside every native frame at 1×. Contours, datum ticks, brass points, shelf seams, and texture must stop before that halo; no decorative element may cross a native label. Movement and action artwork may surround their groups but cannot reproduce control geometry. Utility and menu share a visual rail yet keep distinct native materials/state assignments; the system decoration remains visually isolated and native-operated. Hit testing, frame geometry, state feedback, labels, and accessibility remain entirely native.

Where canonical control frames slightly exceed nominal safe limits, preserve the control and its halo, taper the nearby shelf inward without clipping, and keep the outer artwork edge at least 4 px from the canvas edge. Never move a control to make the illustration easier.

## Measurable acceptance criteria

1. The native contact sheet shows all 16 combinations (2 orientations × 2 appearances × 4 states), and portrait artwork is separately composed rather than rotated, stretched, or cropped from landscape.
2. At 25% contact-sheet scale, an observer can identify movement and action groups in each orientation within two seconds; landscape reads as a lateral transect and portrait as an upper-shard/lower-delta vertical sounding.
3. Every canonical frame center remains inside its intended semantic basin; artwork preserves an 8–12 px clear halo around native frames, keeps outer edges at least 4 px from the canvas, and shows no clipping or 4–8 px accidental tangencies.
4. Measured normal legend contrast is ≥7:1, disabled legend contrast is ≥3:1, native control boundary contrast is ≥3:1, and active coral-to-control contrast is ≥3:1 in light and dark.
5. Pressed controls are exactly 0.97 center-anchored scale with at least 60% less cast shadow; active controls return to ≥0.99 scale with a crisp 1.5–2 px coral index; disabled controls change saturation, edge, highlight, and shadow rather than opacity alone. All four states are distinct side by side.
6. Contours use 1–1.25 px strokes, 22–30 px average spacing, no gap below 18 px, and at most seven uninterrupted paths per region; mineral grain is ≤1.5 px and ≤2.5% tonal variance, with no moiré or contour crossing inside control halos.
7. Each normal orientation contains no more than four coral datum marks and three 3–4 px brass pinpoints; no mark forms a stripe, screw pattern, fake control, legend, compass, screen, bezel, vent, or speaker detail.
8. All highlights and milky edges face upper-left and all dark edges/shadows fall lower-right; review at 100% finds no glow, blur seam, raster artifact, banding, inconsistent same-tier radius, or copied commercial handheld trade dress.

## Strongest design risks

- The canonical direction cluster and diagonal A/B placement can pull surrounding artwork toward recognizable handheld trade dress; the basins must remain irregular continuous shelves, never crosses, circles, or a console shell.
- “Sea glass” can collapse into generic glassmorphism; opacity, hard worn edges, restrained depth, and the ban on blur/bloom are essential.
- Portrait’s large central interval can feel vacant or disconnected; the sounding neck, isolated system junction, and right tide-gauge rail must structure it without inventing controls.
- Contours, coral ticks, and brass points can compete with native labels or read as tappable marks, stripes, or screws if density and clear halos are not enforced.
- Dark teal layers may merge in dark appearance; preserve solid 3:1 control boundaries and do not compensate with glow.
