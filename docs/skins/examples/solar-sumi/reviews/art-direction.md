# Solar Sumi — Art Direction

## Contract inspected

- Skin: `Solar Sumi`; identifier: `com.codybontecou.pocketpad.solar-sumi`.
- Canonical artboard: `arcade-stick-v1`, template `arcadeStick`, revision **1**.
- Expected semantic roles: `joystick`, `primary_action`, `secondary_action`, `custom`, `utility`, `menu`, and `system`. There is no separate `movement` role; the joystick is the movement input.
- Landscape is 874 × 402 with safe insets 4.5% leading/trailing and 3.5% top/bottom. The joystick occupies x 14.55–29.45%, y 41.8–74.2%; the eight-button field occupies x 54.05–95.95%, y 29.58–68.42%; Coin and Start sit at the upper center; the system toggle sits above them.
- Portrait is 402 × 874 with safe insets 2.5% leading/trailing, 5.5% top, and 4.5% bottom. The eight actions become two vertical ranks across x 30–68%, y 4.24–45.76%; Start and Coin form a left-side waist at y 46.74–61.26%; the system toggle is centered at y 47.48–52.52%; the joystick sits at x 45.04–70.96%, y 72.04–83.96%.
- Canonical geometry slightly crosses the nominal safe rectangle at landscape B4’s trailing edge and portrait B4’s top edge. Artwork must accommodate those authored frames rather than crop, shift, or “correct” them.

## Concept and emotional target

**Solar Sumi is a warm fiber control deck charged by one broad, absorbed carbon current that carries the eye from a grounded joystick island into an eight-button solar register, creating tactile momentum and focused heat rather than nostalgia or cultural pastiche.**

## Originality boundary

The original visual signatures are the **Carbon Current** (one pressure-varying brush mass), the **Solar Register** (short, sparse gold indexing marks between native action controls), and the **Offset Fiber Deck** (an asymmetric paper-panel silhouette authored separately per orientation). These are compositional devices, not references to an existing product.

Do not copy or approximate any manufacturer logo, model name, cabinet/fight-stick outline, tournament-panel graphic, mounting plate, bolt pattern, cable port, bezel, side profile, or recognizable commercial button-panel treatment. The canonical eight-button coordinates are a geometry contract; do not reinforce them with copied row plates, repeated circular wells, or familiar hardware color arrangements.

The name and ink medium do not license generic “Japanese” styling. Specifically prohibit ensō circles, rising-sun rays, hanko/seal blocks, kanji or pseudo-calligraphy, torii, seigaiha waves, ukiyo-e imagery, Zen slogans, kintsugi cracks, ornamental ink splatter, or imitation of a named calligrapher’s stroke. Do not trace natural-media scans or reuse another skin’s textures. Existing arcade hardware may inform only plausible control depth and durable surface behavior.

## Silhouette and focal hierarchy

### Landscape

Use a single low **Offset Fiber Deck** spanning approximately x 2–98%, y 3–96%: a long lower edge, a gently rising right shoulder, a clipped lower-left corner, and one shallow upper-center saddle for the system/utility lane. It must not become a rectangular metal fight-stick case. Keep the outer silhouette at least 12 px from native frames, including the far-right B4.

The joystick receives an off-round, dry-brush background island extending 18–24 px beyond its native frame. From that island, the Carbon Current narrows through the open middle below Coin/Start, then widens once into an oblique action bed behind the eight-button union. Mask the brush back around each native button so it never draws a substitute button face. The Solar Register is limited to short gold dashes in the negative channels between actions, never a ring, starburst, or connecting diagram.

Focal order: the two vermilion primary actions B1/B2; the full eight-button register carried by the Carbon Current; the joystick’s grounded carbon mass; then Coin, Start, and the top-center system tab. Secondary B3/B4 and custom B5–B8 remain visibly distinct through native material assignments, not separate decorative plates.

### Portrait

This is a true vertical recomposition, not rotated or stretched landscape art. Use a tall Offset Fiber Deck spanning approximately x 3–97%, y 2–98%, with a broad upper action crown, a narrow left waist for Start/Coin, and an offset lower bay around the joystick. The top edge must leave clean breathing room around B4 even though its canonical frame enters the nominal top inset.

Author a new upward Carbon Current: it begins as a broad pool behind the lower joystick, bends up the right side of the central system control, and forks only once beneath the two action ranks. The left waist stays mostly uninked so Start, Coin, and the system toggle remain legible and the large middle interval feels deliberate. The Solar Register becomes a vertical cadence of short gold cross-marks between the two action ranks; do not rotate the landscape marks or connect button centers.

Focal order: the vermilion primary pair within the upper action crown; the alternating primary/secondary/custom vertical cadence; the lower joystick pool; then the left waist controls and centered system tab. The eye should travel upward, giving portrait its own kinetic direction.

## Separately authored palette

Dark appearance is smoked fiber under low warm light, not an inverted or opacity-reduced light palette.

| Token | Light appearance | Dark appearance | Purpose |
|---|---:|---:|---|
| `canvas-backing` | `#C7AE7E` | `#0C0B09` | Clay-fiber surround / near-black room |
| `fiber-ground` | `#F3E4C2` | `#29251E` | Raw uncoated deck / smoked umber deck |
| `fiber-shadow` | `#CDBA92` | `#100F0C` | Lower-right deck edge and compact shadow |
| `carbon-ink` | `#171714` | `#080907` | Carbon Current, joystick, custom controls |
| `carbon-soft` | `#302D27` | `#181814` | Secondary actions and recessed beds |
| `vermilion` | `#8F281F` | `#A93428` | Primary actions and Start; warmer/brighter in dark |
| `metal-gold` | `#A77B27` | `#D0A64C` | Sparse registration marks and carbon-role active index |
| `legend-light` | `#FFF4D6` | `#F8E8C5` | Native legends on carbon/vermilion |
| `legend-dark` | `#171714` | `#F8E8C5` | Native legends on light/smoked fiber keys |

Measured baseline contrast targets: light/dark legends on vermilion are approximately 7.7:1/5.4:1; legends on carbon are approximately 16.4:1/16.5:1; light carbon-on-fiber is approximately 14.3:1 and dark light-legend-on-smoked-fiber is approximately 12.6:1. Gold against carbon is approximately 4.7:1 light and 8.8:1 dark. Gold must not be the sole state edge on vermilion because that pairing does not meet 3:1.

## Material, edge, light, texture, and legends

Use five depth tiers: canvas backing; uncoated fiber deck; absorbed ink artwork; shallow role beds; raised native controls and flush native legends. Illumination is consistently upper-left at roughly 315°. The deck has a 1–2 px warm upper-left edge, a 2 px darker lower-right edge, and one compact shadow; no floating-card blur. Carbon artwork is optically flat and absorbed, with 1–3 px dry-brush edge variation and sparse 1–4 px bristle gaps. It casts no shadow.

Native joystick and custom controls use fine-grain carbon rubber. Primary actions and Start use low-gloss vermilion resin. Secondary actions use carbon-soft resin with a restrained vermilion edge. Custom B5–B8 use carbon rubber with a hairline gold edge, keeping all four subordinate to the primary pair. Coin is a low-profile fiber key with a carbon legend. The system control is a carbon registration tab with one gold edge, not a decorative seal.

Paper texture is directional fiber, 0.5–1.5 px thick, 6–18 px long, under 4% tonal variance, and absent from controls and legends. Use no generic noise, paper stains, bloom, glass, scanlines, fake scratches, or scattered splatter. Metallic gold appears only as narrow directional edge strokes or dashes with a small upper-left highlight and darker lower-right edge; it may occupy no more than 1.5% of a normal-state canvas.

All legends remain native, centered, upright, and unwarped: `Stick`, `B1`–`B8`, `Coin`, and `Start`. Use `legend-light` on carbon/vermilion and the appearance-appropriate high-contrast legend on fiber. Add no artwork letters, arrows, symbols, translations, or duplicate labels.

## Native state behavior

Author all four states explicitly for every semantic material in both appearances.

- **Normal:** stable 1.0 scale; upper-left edge light and compact lower-right shadow communicate shallow travel. Primary B1/B2 and Start are vermilion; B3/B4 are carbon-soft with a vermilion hairline; B5–B8 and joystick are carbon; Coin is fiber; system is carbon/gold.
- **Pressed:** center-anchored 0.96–0.98 scale, at least 60% less cast shadow, reduced upper-left highlight, and a 6–10% darker fill plus inner lower-right containment. Frames and legends do not translate or jump.
- **Active:** return to 0.99–1.0 scale and raised silhouette. Carbon roles gain a crisp 2 px gold index; vermilion roles gain a 2 px light-fiber index (gold may appear only as a secondary tick); the fiber Coin key gains a 2 px carbon index. Each active edge must contrast at least 3:1 with both control fill and immediate surround and must not glow.
- **Disabled:** remove cast shadow and specular edge, desaturate each material, retain its role family, and reduce visual weight without global opacity alone. Native legends remain at least 3.5:1, group boundaries remain readable, and gold is replaced with a neutral edge.

## Artwork-to-role alignment

Artwork is passive and cannot replace native geometry, hit testing, labels, accessibility, or state rendering. Align the joystick island to the union of the canonical `joystick` frame; align the action bed to the combined `primary_action`, `secondary_action`, and `custom` frames; keep utility, menu, and system on their own quiet registration lane. The Carbon Current may connect group beds, but it must be masked at least 8 px outside each individual native frame and may not form circles, capsules, knobs, or tappable-looking silhouettes. Solar Register marks stay in negative space, at least 6 px from native frames. State effects belong to native controls only, never to the SVG artwork.

## Acceptance criteria

1. The native contact sheet shows all 16 combinations (2 orientations × 2 appearances × 4 states), with portrait using separately authored vertical artwork rather than transformed landscape artwork.
2. Every canonical role is visibly covered: B1/B2 primary, B3/B4 secondary, B5–B8 custom, Stick joystick, Start menu, Coin utility, and the control-bar toggle system; no nonexistent movement-role styling is introduced.
3. At 25% sheet scale, the action register is the first read and the joystick-to-action direction is understandable within two seconds; portrait reads upward while landscape reads left-to-right.
4. Role beds contain their canonical frame unions within ±3% normalized alignment; artwork marks remain ≥6 px from native frames, the Carbon Current mask remains ≥8 px away, outer deck edges remain ≥12 px away, and no right/top canonical control is clipped.
5. Normal legend contrast is ≥4.5:1 (target ≥5:1), disabled legend contrast is ≥3.5:1, and every active index is ≥3:1 against both its fill and adjacent surround in light and dark.
6. Pressed controls scale to 0.96–0.98 with ≥60% shadow reduction; active controls return to ≥0.99 with a crisp 2 px role-appropriate index; disabled controls change saturation, edge, highlight, and shadow rather than opacity alone. All states are distinguishable side by side.
7. At 100%, all highlights point upper-left and shadows lower-right; fiber stays within the 0.5–1.5 px × 6–18 px scale, carbon edges within 1–3 px variation, gold under 1.5% canvas area, and there is no glow, banding, raster seam, accidental tangent, or stretched texture.
8. Originality review finds no logo, copied trade dress, cabinet/fight-stick silhouette, mounting hardware, circular action plate, commercial row framing, cultural stock motif, calligraphic imitation, artwork-rendered control face, or duplicate legend.

## Strongest design risks

- The canonical eight-button arrangement can resemble existing fight-stick panel art if it is enclosed by familiar plates, rings, or hardware details.
- The broad carbon current can swallow carbon controls or imply a giant hit region unless the required fiber gutters and native edges remain clear.
- Portrait’s action rank begins above the nominal safe inset; a heavy top border or rotated landscape composition will clip B4 and feel accidental.
- Metallic gold can become decorative luxury styling or lose contrast on vermilion; keep it sparse and use the specified role-dependent active edge.
- Ink/fiber language can slip into cultural shorthand; the design must stay grounded in material behavior and the three original compositional signatures only.
