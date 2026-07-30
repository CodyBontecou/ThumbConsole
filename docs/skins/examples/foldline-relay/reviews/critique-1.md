# Foldline Relay — Independent Visual Critique 1

- **Evidence reviewed:** `reviews/contact-sheet-1.png`
- **Evidence dimensions:** 2176 × 1714 px
- **Inspection scales:** exact PNG at full resolution, including source-pixel panel crops; 25% overview at 544 × 429 px
- **Art direction:** `reviews/art-direction.md`
- **Quality bar:** Thumble visual quality bar
- **Verdict:** `revise`

The sheet contains all 16 required native-renderer combinations. The lower-left cluster wins the first glance at 25%, portrait is recomposed rather than rotated, and no trade-dress blocker is visible. It does not pass because the bottom of every landscape composition is visibly unresolved, the tab/fold/relay idea still reads largely as a generic keypad plus a line, dark fold tiers collapse, and several native states fail the specified material and interaction behavior.

## Panel coverage

| Panel | Full-resolution and 25% observation |
|---|---|
| Landscape · Light · Normal | Folio and row-four shadows terminate against the bottom crop; regular columns read as a keypad; relay floats in the right field. |
| Landscape · Light · Pressed | Bottom remains clipped; secondary, orange, and chartreuse faces develop heavy center/edge gradients rather than a clean depression; `Command` and `Escape` weaken. |
| Landscape · Light · Active | Active rings are visible on most roles, but look like soft perimeter outlines; Escape lacks a stronger cue than normal. Bottom remains clipped. |
| Landscape · Light · Disabled | Chroma remains high on blue, orange, and chartreuse; state reads mainly as shadow removal. `Command` becomes marginal. Bottom remains clipped. |
| Landscape · Dark · Normal | Outer and inner fold planes merge at 25%; diffuse key edges dominate the scored-paper logic; bottom is cropped. |
| Landscape · Dark · Pressed | Fold tiers remain collapsed; pressed gradients look glossy/illuminated rather than inset; bottom is cropped. |
| Landscape · Dark · Active | Chartreuse/blue rings distinguish most roles, but the fold remains one dark slab and Escape is not meaningfully stronger than normal; bottom is cropped. |
| Landscape · Dark · Disabled | Blue, orange, and chartreuse remain conspicuous; the system tag nearly disappears while action keys stay vivid; bottom is cropped. |
| Portrait · Light · Normal | Independent tall layout is present, but the docket is a simple rectangular mount and the long relay rule reads as a detached bracket. |
| Portrait · Light · Pressed | Pressed faces show radial/edge shading; long legends become muddy at the exact sheet resolution. |
| Portrait · Light · Active | Most active outlines register, but Escape remains effectively normal and the ring treatment is not a crisp registration index. |
| Portrait · Light · Disabled | Disabled chroma remains too close to normal; `Command` is reduced to a low-contrast micro-legend. |
| Portrait · Dark · Normal | Docket tiers and score line collapse into one graphite block at 25%; route remains detached from both endpoints. |
| Portrait · Dark · Pressed | Dark fold hierarchy stays flat; pressed gradients and dim long legends obscure the paper-tab material. |
| Portrait · Dark · Active | Active outlines carry more visual information than the fold construction; Escape again lacks a distinct active index. |
| Portrait · Dark · Disabled | Color accents remain active-looking while the system tag and fold scores recede too far. |

## Pass 1 — Composition

### C1 — Landscape folio and bottom-row shadows are visibly cropped

- **Severity:** major
- **Affected panels:** all eight landscape panels
- **Visible evidence:** The cream/graphite folio mass, its inner vertical score, and its outer vertical edge run directly into the lower image boundary. Command, Prefix, and Palette leave almost no resting canvas, and their normal/active shadows visibly terminate at the crop. At 25%, the entire left packet reads as guillotined rather than intentionally open-ended.
- **Likely cause:** The raised folio and over/under plane continue to the 402 px artboard edge while row four already ends only about 5.5 px above it; the native shadow footprint is too broad for that clearance.
- **Concrete correction:** Resolve the raised artwork back to plain canvas above row four, with no lower border, crease, or cast shadow in the bottom-row-to-edge zone. Reduce the native tab shadow footprint so every row-four face and shadow ends with **at least 4 artboard px of untouched canvas** before y = 402. No non-canvas decorative edge or shadow may touch the bottom boundary in the next sheet.

### C2 — The command cluster reads as a generic keypad, not a die-cut tab docket

- **Severity:** major
- **Affected panels:** all 16 panels; strongest in both portrait rows and the 25% overview
- **Visible evidence:** Equal square keys remain organized as three rigid columns over broad rectangular fields. The small notches on the right edge and role colors do not overcome the grid. In portrait, the folio is principally a straight-sided vertical rectangle; in landscape, the broad planes read as stacked boxes behind a keypad. The intended ragged tab contour and Thumb Folio silhouette are not legible at thumbnail size.
- **Likely cause:** Passive plane and well geometry follows large bounding rectangles rather than visually separating semantic tab groups. The fold changes are too shallow relative to the regular native frames.
- **Concrete correction:** Keep all native frames fixed, but rebuild the passive folio silhouette with **at least three clearly visible 10–16 px setbacks/ledges** around the role groups, including a stronger clipped inner fold beyond Escape/Palette and a resolved oblique fold above Up in portrait. Avoid one continuous rectangular well behind the full matrix. At 25%, the ragged tab stack must remain identifiable before individual legends can be read.

### C3 — The Relay Fold is a detached polyline and does not yet explain the empty field

- **Severity:** major
- **Affected panels:** all 16 panels; strongest in both portrait normal panels and the 25% overview
- **Visible evidence:** The blue route starts in empty space beside the folio and ends offset from the isolated system tag. Its orange handoff is only a short color change, so the line reads as a generic bracket/circuit trace rather than a folded dispatch path. The registration marks are too faint to reinforce measurement at 25%. The canonical negative space should remain open, but currently feels under-explained.
- **Likely cause:** Route endpoints are spatially detached from the semantic source and destination, while the turn has no visible over/under or scored-fold consequence.
- **Concrete correction:** Preserve the required turn counts and clearance, but place the source endpoint **10–14 px from the Escape/Palette-side frame** and align the destination segment to the system control centerline within **±3 px**, terminating **8–12 px outside its frame**. Resolve the orange handoff as one crisp folded transition, not a node or glow. At 25%, the route and one bracket pair must remain detectable while their apparent area stays below one-third of the command cluster.

## Pass 2 — Material and craft

### M1 — Dark-mode fold tiers collapse into a single slab

- **Severity:** major
- **Affected panels:** all eight dark panels
- **Visible evidence:** At full resolution the graphite outer plane, darker inner plane, crease, and canvas can be found only by close tracing. At 25%, the outer/inner distinction and most score detail disappear, leaving one flat dark block behind the controls. This fails the specified canvas → raised plane → shallow score-field depth sequence.
- **Likely cause:** Adjacent dark fills are too close in value and the gray upper-left highlights are too weak; black crease edges disappear into the same low-luminance region.
- **Concrete correction:** Preserve the carbon-proof palette, but strengthen edge construction so both fold planes remain independently traceable at 25%: use a continuous **1 px upper-left fiber highlight** and **2–3 px lower-right contact/crease shadow**, and establish enough adjacent-value separation that the inner plane does not merge with either canvas or outer plane. The next 25% sheet must show two plane tiers and one score line without increasing route weight.

### M2 — Native tabs render as glossy, haloed digital buttons rather than matte die-cut paper

- **Severity:** major
- **Affected panels:** all 16 panels; most severe in the four pressed panels and light normal panels
- **Visible evidence:** Normal faces carry broad soft shadows around multiple sides. Pressed Command/Prefix develop bright centers with dark perimeters, while pressed Escape and Palette resemble shaded orbs. Active edges bloom softly. These cues conflict with the specified crisp cut edge, paper ply, compact lower-right shadow, and 315° light.
- **Likely cause:** Excessive gloss/depth and blur are overpowering the matte face treatment; pressed rendering changes the whole face gradient instead of primarily reducing elevation and uniformly darkening fill.
- **Concrete correction:** Limit interior face variation to **≤3% tonal variance** outside the fine tooth, use a crisp **1 px cut edge**, **1–2 px ply**, and confine cast shadow to **2–3 px lower-right** with no visible upper-left halo. Pressed faces must darken uniformly by **8–12%**, retain center anchoring at **0.96–0.97 scale**, and reduce cast-shadow depth by **at least 60%**. At 100%, no pressed face should show a radial or spotlight gradient.

### M3 — Long legends do not retain reliable fit and contrast in the rendered evidence

- **Severity:** major
- **Affected panels:** all panels, strongest on `Command` in portrait, pressed, and disabled panels; also `Escape` in pressed panels
- **Visible evidence:** `Command` is cramped to the face edges in landscape and collapses into a gray micro-legend in portrait. In pressed light/dark panels, the face gradient runs through `Command`, `Prefix`, `Escape`, and `Palette`, reducing their clarity. No hard ellipsis is visible, but the contact sheet does not demonstrate the required cap height and clear space; `Command` is functionally illegible in several panels.
- **Likely cause:** The native label is scaling too aggressively for the ~53 px face, then being further compromised by glossy/disabled face treatment and low local contrast.
- **Concrete correction:** At the unscaled 1× artboard, keep `Command`, `Palette`, `Escape`, `Return`, and `Prefix` single-line with **≥9 px cap height** and **≥4 px horizontal clearance on both sides**. Flatten the face behind each legend and verify measured contrast of **≥4.5:1 normal** and **≥3:1 disabled** in both appearances. The next full-resolution sheet must show every full word without edge collision or raster collapse.

## Pass 3 — Interaction

### I1 — Disabled states remain too chromatic and still look available

- **Severity:** major
- **Affected panels:** Landscape · Light · Disabled; Landscape · Dark · Disabled; Portrait · Light · Disabled; Portrait · Dark · Disabled
- **Visible evidence:** Return/Tab remain strong blue, Escape remains orange, and Palette remains chartreuse. At 25%, disabled is identified mainly by reduced shadow, while the colored controls retain nearly the same role salience as normal. In dark mode this is especially uneven: the system tag nearly vanishes while the action colors continue to call for interaction.
- **Likely cause:** Disabled rendering flattens depth but reduces chroma only modestly and does not replace all role edges with a consistent neutral edge.
- **Concrete correction:** Reduce role chroma by the specified **55–70%**, remove fiber highlight, flatten cast shadow, and use a quiet neutral cut edge. Preserve grouping and keep every disabled legend at **≥3:1**. In the next 25% side-by-side view, all four disabled panels must be unmistakable without relying on the panel captions.

### I2 — Active treatment is incomplete for Escape and too ring-like elsewhere

- **Severity:** major
- **Affected panels:** all four active panels; menu/Escape role is the failure point
- **Visible evidence:** Movement, primary, secondary, utility, and system controls gain visible colored perimeters. Escape's active dense-ink edge is effectively the same edge already present in normal, so its active state is not meaningfully stronger. The other cues read as soft full outlines rather than crisp registration indices.
- **Likely cause:** The menu material uses the same dense-ink visual for its baseline cut edge and active color, while the renderer applies active color as a perimeter ring rather than a distinct index geometry.
- **Concrete correction:** Give every role a crisp **2 px registration index** with no glow and keep active geometry at **0.99–1×**. For Escape, change the index geometry or placement—not merely its dense-ink color—so it is visibly absent in normal and present in active. Every index must measure **≥3:1 against its face** and remain visible at 25%.

### I3 — Pressed distinction is visible but communicates illumination, not depression

- **Severity:** major
- **Affected panels:** all four pressed panels
- **Visible evidence:** Pressed panels are darker than normal, so the state is distinguishable, but secondary and chromatic tabs gain strong center-to-edge modeling. The result reads as dimming or internal illumination rather than a tab pushed into a die cut. Legend centers stay generally fixed, but the material behavior is wrong.
- **Likely cause:** State change is dominated by face gradient and chroma loss instead of scale, compact inset edge, and shadow collapse.
- **Concrete correction:** Retain the specified centered **0.96–0.97 scale**, apply a uniform **8–12% fill darkening**, reduce cast shadow by **≥60%**, and add only a subtle **1 px inner lower-right edge**. The pressed face must remain matte and must not introduce any new gradient direction.

## Acceptance-criteria audit

| Criterion | Result | Reason |
|---|---|---|
| 1. All 16 combinations; independent portrait | Pass | All combinations are present and portrait is recomposed. |
| 2. Cluster-first hierarchy at 25% | Partial | Cluster wins and outweighs the route, but the route/fold does not make the large field fully intentional. |
| 3. Alignment, clearance, no tangencies/clipping | Fail | Landscape folio edges and bottom-row shadows visibly terminate at the lower crop. |
| 4. Legend/index contrast | Fail by rendered evidence | Disabled `Command` is marginal and Escape lacks a distinct active index; required measured proof is not visually sustained. |
| 5. Long-label fit | Fail | Full words are not hard-ellipsized, but `Command` lacks reliable cap-height/clearance and collapses in several panels. |
| 6. Four distinct native states | Fail | Disabled chroma is too strong; Escape active is not distinct; pressed material logic is incorrect. |
| 7. Lighting, texture, seams, fold logic | Fail | Diffuse halos/gradients contradict the matte 315° edge system; dark fold tiers collapse; landscape bottom is clipped. |
| 8. Originality and prohibited motifs | Pass | No copied logo, proprietary glyph set, hardware silhouette, port, vent, screw, or recognizable console trade dress is visible. |

## Originality / trade-dress check

No legal or trade-dress blocker is visible. The asymmetric folio contour, blue/orange route, registration brackets, and role palette do not closely reproduce a named console, calculator, keyboard, or stationery product. There are no logos, model names, proprietary button-letter patterns, vents, screws, ports, or speaker motifs. The generic-keypad reading identified in C2 is a craft/originality-strength problem, not evidence of copying; the original Foldline signatures need stronger execution.

## Optional taste notes — not defects

- The upper/right negative space should **not** be filled with extra ornament. It is canonical and should stay calm; C3 asks for a clearer route relationship, not more decoration.
- The warm-stock/chartreuse pairing is within the approved palette. Its separation should continue to come from edge logic, not added glow or saturation.

## Final verdict

**`revise`** — no trade-dress blocker was found, but eight unresolved major findings prevent a visual pass. The next iteration should first resolve the landscape lower edge, then rebuild the tab/fold hierarchy, then correct dark tiers and native state behavior before tuning secondary marks.
