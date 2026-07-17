# PocketPad visual quality bar

## What “handcrafted” means

A handcrafted skin communicates one physical or graphic idea through composition, not just token changes. It has authored hierarchy, silhouette, material transitions, edge treatment, negative space, and state behavior tied to a known layout.

A skin fails this bar when it looks like:

- a generic gradient with controls placed on top;
- every available glow, blur, shadow, and texture applied at once;
- the same composition stretched into portrait;
- a console replica with changed colors;
- a diagnostic layout preview;
- one state with opacity changed four times;
- artwork that competes with or obscures native controls.

## Composition review

Require:

- immediate movement/action grouping at thumbnail size;
- a clear primary silhouette and consistent internal margins;
- art aligned to canonical control centers and safe areas;
- intentional portrait recomposition, not accidental stretching;
- balanced visual weight around shoulders and utility controls;
- decorative lines or texture subordinate to control hierarchy.

Reject clipped shell edges, wells that drift from controls, tangencies within 4–8 px, inconsistent radii, and unexplained empty regions.

## Material review

Require:

- one consistent lighting direction;
- highlight, bevel, stroke, and shadow logic that agrees;
- restrained depth tiers: canvas, shell, wells, controls, legends;
- texture scale that suggests a plausible surface;
- light and dark appearances designed separately;
- at least 4.5:1 preferred legend contrast, 3:1 absolute minimum for large marks.

Glow is not a substitute for a material edge. Transparency is not a substitute for layering. Noise is not a substitute for texture design.

## State review

- **Normal:** stable baseline with strongest material identity.
- **Pressed:** reads as physical depression or activation; no geometry drift or label jump.
- **Active:** clearly stronger than normal and distinct from pressed.
- **Disabled:** visibly unavailable while labels and grouping remain understandable.

Every semantic material needs all four states. Review states side by side in both appearances; subtle differences that disappear in the contact sheet do not pass.

## Originality review

Category references may inform ergonomics or material vocabulary. Do not copy:

- manufacturer marks, model names, logos, or proprietary glyphs;
- recognizable hardware outlines, vent patterns, color blocking, or trade dress;
- character art, game art, stickers, or another skin's bitmap/SVG;
- a reference skin's exact component arrangement or decorative motif.

Document what is original: silhouette logic, palette, material treatment, decorative grammar, and legend system.

## Pass criteria

A critic may issue `visual-pass` only when:

- there are no blockers or unresolved major findings;
- portrait and landscape each feel composed;
- light and dark each feel authored;
- normal, pressed, active, and disabled read distinctly;
- native labels and controls stay legible;
- no visible raster artifacts, clipping, accidental seams, or misalignment remain;
- the work is legally distinct;
- the art-direction acceptance criteria are met.

A quality score is not a substitute for visual judgment, and a visual pass is not human publication approval.