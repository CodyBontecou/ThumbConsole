# Pale Cavern — Art Direction

**Working name:** Pale Cavern
**Planned identifier:** `com.codybontecou.pale-cavern`
**Canonical contract:** `showcase-controller-v1`, revision 2
**Variants:** landscape `874 × 402`; portrait `402 × 874`

## Concept and emotional target

**Pale Cavern is a quiet controller formed from overlapping mineral laminae beside a cold underground spring: calm, precise, and faintly alive, with the native controls—not the scenery—as the unmistakable focal point.**

The emotional target is focused solitude rather than menace or spectacle. The design should feel premium because its spacing, edges, and material transitions are controlled, not because effects have been accumulated.

## Originality boundary

Permitted category cues are broad nocturnal-cavern atmosphere, insect-ecology subtlety, pale chitin-like mineral material, cool bioluminescence, and sparse suspended motes. The original visual ideas for this skin are:

- **Moonstone Lamina:** smooth, offset shell plates that read equally as eroded mineral and abstract insect material without depicting an organism.
- **Cold Spring Seam:** one restrained cyan seam that joins or separates compositional zones and guides the eye toward controls.
- **Silt Constellation:** a few irregular mineral/spore motes used only to balance negative space.

These ideas must be drawn from first principles and must not reproduce any existing game asset, skin, controller, or fan-art composition. Specifically forbidden:

- the Hollow Knight title, logo, typography, named characters, character silhouettes, masks, horns, weapons, proprietary glyphs, map symbols, architecture, copied game art, or recognizable fan-art motifs;
- recognizable console outlines, vent patterns, button color blocking, manufacturer marks, model names, or protected controller trade dress;
- literal insects, wings, faces, skulls, crests, emblems, or character-like symmetry;
- generic neon-gamer treatment, full-panel glow, glassmorphism, decorative HUD marks, faux runes, or “retro” pixel ornament.

The shell may suggest a wing or carapace only through soft overlapping plates. It must have no pointed tips, horn-like projections, bilateral creature face, or vein pattern that reads as a literal wing. No logo or skin-name lockup appears on the controller face.

## Canonical geometry and safe areas

Artwork is authored against the normalized frames from revision 2; no control frame may be moved to improve the illustration.

### Landscape

- Canvas: `874 × 402`.
- Safe-area bounds are approximately `x 39–835`, `y 14–388` (4.5% left/right, 3.5% top/bottom).
- Movement occupies the left field, approximately `x 43–254`, `y 124–310`.
- Primary/secondary actions occupy the right field, approximately `x 630–839`, `y 120–322`.
- Custom shoulder roles sit at upper left and upper right, approximately `x 127–223` and `x 651–747`, `y 48–81`.
- Utility/menu roles sit low in the center, approximately `x 345–530`, `y 316–343`.
- The system decoration is top-center, approximately `x 407–467`, `y 24–68`.

### Portrait

- Canvas: `402 × 874`.
- Safe-area bounds are approximately `x 10–392`, `y 48–835` (2.5% left/right, 5.5% top, 4.5% bottom).
- Action controls form the upper cluster, approximately `x 121–321`, `y 38–242`.
- Movement forms the lower cluster, approximately `x 125–309`, `y 622–829`.
- Custom roles form separate left-side rails around `y 160–190` and `y 684–715`.
- Menu and utility form a restrained right-middle pair around `x 300–359`, `y 363–511`.
- The system decoration sits near upper-middle center, approximately `x 171–231`, `y 258–302`.

Artwork wells must be centered on these role frames within 2 px. Keep at least 10 px of quiet clearance between a native control frame and any artwork edge, seam, mote, or material transition; use 12 px where space permits. Canonical frames are authoritative even where a frame crosses a listed safe-area inset (notably the upper portrait action and far-right landscape action); artwork must accommodate them rather than move or clip them.

## Silhouette and focal hierarchy

### Landscape composition

Use a low, continuous **offset-lamina silhouette**: two broad rounded plates overlap across the center without forming a familiar gamepad outline. The upper plate supports the custom shoulders and system role; the lower plate carries movement, actions, and utility. The outer arc is softly eroded and asymmetrical by a few pixels, with a shallow lower-center flattening rather than handles, grips, wings, or pointed ends.

Focal order:

1. native primary-action and movement controls, equal in visual authority;
2. secondary-action controls, differentiated by a cooler edge but not brighter than active primary controls;
3. custom shoulder controls;
4. menu/utility and system controls;
5. the Cold Spring Seam and Silt Constellation.

Movement and action wells should balance across the long axis. The central third remains mostly quiet so the two control groups read immediately at thumbnail size. The cyan seam may cross the center plate but must terminate at least 12 px before every native frame.

### Portrait composition

Do not rotate or stretch the landscape shell. Build a **descending two-chamber composition**: a rounded upper lamina contains the action cluster, a separate lower lamina contains movement, and a narrow, softly curved mineral bridge visually relates them without enclosing the entire canvas. Menu/utility occupy a small right-middle shelf; custom roles sit on two subdued left ledges. Preserve an open central “cavern air” region around the system role.

Focal order:

1. upper action cluster and lower movement cluster, balanced despite their vertical separation;
2. secondary actions and the two custom ledges;
3. right-middle menu/utility shelf and system role;
4. one short Cold Spring Seam segment and sparse motes.

At least 28% of the portrait safe-area surface and 24% of the landscape safe-area surface should remain free of seams, motes, labels, and high-contrast texture. Empty space must feel intentional, not like a missing panel.

## Palette tokens

All values are starting targets; any adjustment during native review must preserve the stated contrast and hierarchy.

### Dark appearance — subterranean blue-black

| Token | Target | Purpose |
|---|---:|---|
| `dark.canvas` | `#070C14` | deepest cave ground |
| `dark.shell.base` | `#111B27` | main lamina |
| `dark.shell.raised` | `#182736` | upper-left raised plane |
| `dark.well` | `#0C141E` | recessed role wells |
| `dark.ivory` | `#D9E0D2` | pale mineral/chitin accent and selected control faces |
| `dark.legendOnDark` | `#F1F3E9` | native legends on dark faces |
| `dark.legendOnIvory` | `#18232C` | native legends on pale faces |
| `dark.cyan` | `#72D4CF` | active edge and Cold Spring Seam only |
| `dark.cyanDeep` | `#2E777B` | normal-state cool edge |
| `dark.shadow` | `#02050A` | shell and well shadow |

### Light appearance — misty limestone

Light mode is separately composed: warmer ground, flatter shadow, darker legends, and less luminous cyan. It is not an inversion.

| Token | Target | Purpose |
|---|---:|---|
| `light.canvas` | `#E7E2D5` | misty limestone/parchment ground |
| `light.shell.base` | `#D2D5CA` | main lamina |
| `light.shell.raised` | `#EEF0E7` | upper-left raised plane |
| `light.well` | `#B9C4C1` | recessed role wells |
| `light.ivory` | `#F5F3E9` | pale control faces |
| `light.legend` | `#26333C` | all primary native legends |
| `light.cyan` | `#255F67` | active edge and seam |
| `light.cyanMuted` | `#66898A` | normal-state cool edge |
| `light.shadow` | `#667078` | low-opacity shell and well shadow |

Cyan is an orientation cue and state accent, not ambient neon: it may occupy no more than 6% of visible pixels in either appearance. Normal legends target at least `7:1` contrast against their immediate face; pressed and active legends must remain at least `4.5:1`; disabled legends must remain at least `3:1` while staying visibly unavailable. Large non-text boundaries must retain at least `3:1` against adjacent material where they convey grouping.

## Material, edge, depth, and texture rules

Use five depth tiers only: canvas, shell shadow, shell laminae, recessed wells, then native controls/legends. Lighting comes from the upper left at roughly 35° in both orientations and appearances.

- **Shell:** matte mineral/chitin, never glossy or translucent. Use a 1 px upper-left highlight, 1 px boundary, and a 3–5 px lower-right shadow. Outer corner radii stay within a coherent 28–44 px family; internal shelves use 14–22 px radii.
- **Lamina overlap:** one clear 2 px occlusion edge plus a 4 px soft shadow. No stacked outlines, inner-glow rings, or glass blur.
- **Wells:** 10–14 px beyond the grouped native-frame envelope, darkened/recessed by a single 1 px inner boundary and 2–3 px lower-right inner shadow. Never draw fake buttons inside them.
- **Cold Spring Seam:** one 1–2 px curved stroke, never a closed halo around the shell. Dark-mode local bloom is optional but capped at 4 px radius and 12% opacity; light mode uses no bloom.
- **Texture:** use authored, irregular mineral flecks rather than procedural full-surface noise. Flecks are 1–3 px at native canvas size, with local contrast no greater than 6%. Cap free-floating motes at 12 in landscape and 10 in portrait; no repeated grid, starfield, dust cloud, or particle trail.
- **Edges:** avoid tangencies. Decorative strokes either terminate at least 10 px before wells/native frames or cross behind a broad uninterrupted material field with no apparent attachment to a control.

## Semantic role treatment

Artwork provides passive grouping aligned to semantic frames; the native renderer remains responsible for control geometry, hit testing, labels, accessibility, and every interaction state.

- **`movement`:** one quiet, cool-slate recessed field. Directional controls read as a unit; no drawn D-pad cross or arrow artwork.
- **`primary_action`:** pale mineral faces with the strongest normal-state material clarity. They share one well but remain distinct native controls.
- **`secondary_action`:** same construction as primary action with a muted cyan-deep boundary, never a separate bright color family.
- **`custom`:** narrow raised ledges using `shell.raised`; visually subordinate to movement/action and free of shoulder-button replicas.
- **`utility`:** low-contrast recessed shelf with compact native legends.
- **`menu`:** shares the utility shelf but receives a slightly clearer boundary so the pair remains distinguishable.
- **`system`:** a neutral, quiet aperture/landing zone; no emblem, eye, crest, rune, or glowing icon.

Legends use the native renderer’s plain, semibold sans-serif treatment. Keep arrows and text literal and functional; do not replace them with custom icons, faux language, serif display lettering, proprietary symbols, or artwork-baked labels. No SVG may contain key codes, bindings, hit regions, control labels, or interaction feedback.

The eventual executable profile—not the artwork—may retain the supplied mappings: attack `7`, dash `8`, focus `0`, jump `6`, movement `123/124/125/126`, map `35` with modifiers `3`, pause `53`, and custom mappings `1, 2, 3, 1, 34, 48, 53, 34`. Their presence must not alter the canonical visual-role treatment or create artwork for controls absent from the artboard.

## Native state behavior

Every semantic material must define and visibly demonstrate all four states in both appearances. Artwork stays fixed between states; only native style tokens change.

- **Normal:** stable matte face, clear 1 px upper-left highlight, full legend contrast, and no cyan glow. Primary action is pale; other roles remain restrained.
- **Pressed:** reads as physical depression. Reduce outer shadow scale to 35–45%, suppress the upper-left highlight, strengthen the inner/lower-right edge by 1 px, and shift face luminance by 10–14% relative to normal. Native frame and legend baseline remain fixed—no geometry drift or label jump.
- **Active:** must be stronger than normal and distinct from pressed. Restore the raised silhouette, use a 2 px `cyan` boundary and a controlled 8–12% cyan face tint. Dark mode may add the capped 4 px/12% bloom; light mode relies on edge and tint only. Active cannot be represented solely by increased opacity.
- **Disabled:** reduce saturation to 10% or less and compress face-to-well contrast by 35–50%; remove cyan and raised highlights. Preserve role grouping and at least `3:1` legend contrast. Disabled controls must not look pressed or disappear into the shell.

State differences must remain obvious when normal, pressed, active, and disabled are viewed side-by-side in the native contact sheet at 50% scale.

## Acceptance criteria

A critic or QA agent may pass the direction only when all eight criteria are met:

1. **Contract alignment:** all wells and ledges are centered on revision-2 semantic role frames within 2 px; canonical native frames remain unchanged even where they cross a safe-area inset; every seam/mote has at least 10 px clearance from native frames; and shell/well edges have 10–14 px clearance with no 4–8 px tangencies or canvas clipping.
2. **Orientation authorship:** landscape uses the offset horizontal lamina and portrait uses separate upper/lower chambers; neither is a rotated, cropped, or non-uniformly stretched version of the other. Required unornamented safe-area space is at least 24% landscape and 28% portrait.
3. **Immediate hierarchy:** at 25% contact-sheet size, movement and primary-action groups are the first two readable regions, custom/menu/utility remain secondary, and the shell/seam never competes with native controls.
4. **Appearance authorship and contrast:** light and dark use their specified material logic rather than inversion; measured native legend contrast is at least 7:1 normal, 4.5:1 pressed/active, and 3:1 disabled. Group-defining non-text boundaries are at least 3:1 where required for recognition.
5. **State separation:** in all seven semantic roles, pressed changes luminance by 10–14% and reduces shadow scale to 35–45%; active has a 2 px cyan boundary plus tint; disabled has ≤10% saturation and 35–50% reduced face/well contrast. No label or frame shifts between states.
6. **Restraint:** cyan covers no more than 6% of any rendered panel; motes do not exceed 12 landscape or 10 portrait; texture marks stay 1–3 px with ≤6% local contrast; there is no full-panel glow, noise, glass, HUD, logo, or decorative text.
7. **Material consistency:** every highlight and shadow follows the same upper-left light direction; the render uses only the five declared depth tiers, coherent radius families, and no unexplained seams, clipping, raster artifacts, or mismatched bevels.
8. **Originality and native-control boundary:** visual review finds none of the prohibited game/character/hardware motifs, literal insect imagery, copied trade dress, or proprietary glyphs; SVG/background artwork contains no labels, key codes, state feedback, or fake controls, and the full native sheet contains all 16 orientation × appearance × state combinations.

## Review gate

This brief authorizes design exploration only. It does not authorize publication, installation, catalog edits, staging, commits, pushes, or approval. Human approval remains pending until a human explicitly approves the exact final native contact sheet and exact package SHA-256 after critique and strict QA.
