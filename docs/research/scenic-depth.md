# Scenic depth, zones, road variety and per-level terrain

Implementation notes for tasks 3.1–3.5 of
`openspec/changes/scenic-depth-asset-pipeline`. The runtime contract is the
manifest in that change's `design.md`. These are local implementation notes.
They are not user or physical-phone acceptance.

## Layering (simulation / projection / streaming kept apart)

| Concern | File | Notes |
| --- | --- | --- |
| Terrain profiles (simulation) | `lib/game/terrain/level_profiles.dart` | Pure data: bends, hills, rises, hairpin demand |
| Terrain sampling | `lib/game/proof_level.dart` (`ProofTerrain`) | Integrates centres and exposes curvature, elevation, demand and section |
| Manifest model | `lib/game/scenic/scenic_manifest.dart` | Parses the design.md JSON and skips malformed entries |
| Metric bands / parallax | `lib/game/scenic/scenic_bands.dart` | Metres to units mapping, band ranges, pinhole helpers |
| Zones (authoring) | `lib/game/scenic/scenic_zones.dart` | Per-level zone lists, biome group weights, set pieces |
| Scheduler (streaming) | `lib/game/scenic/scenic_scheduler.dart` | Deterministic precomputed plan with range queries |
| Surfaces | `lib/game/scenic/road_surfaces.dart` | Road, shoulder and ground tracks with continuous blends |
| Loader | `lib/game/scenic/scenic_library.dart`, `scenic_fallback.dart` | Images, procedural tiles, proof-art fallback |
| Rendering | `lib/game/render/surface_meshes.dart`, `scenic_draw.dart`, `race_game.dart` | Meshes, vista strip, far pass |

## Metric mapping

The road half-width is 1100 lateral units, which is a 5.5 m half carriageway,
so the mapping is **200 lateral units per metre**. At top speed (155 mph,
69 m/s) the car covers 80.6 course units/s, so one course unit is about
0.86 m. At the default `velocity` flow (168 world units per course unit),
forward world units are about 195 per metre. That matches the lateral scale,
so sprites keep their real proportions and parallax is distance-correct. The
other flow presets stretch z as before. Placement is keyed on course
distance, so it does not move when the preset changes.

## Depth bands

These are measured from the road edge.

- **Near (0.6–6 m) and mid (6–60 m)** stream inside the road mesh window. They
  use the normal projection, crest clip and depth fade. Their lateral position
  is `side·(1 + offset/5.5 m)` half-widths, with clearance for half the
  sprite's width.
- **Far (60–600 m)** streams up to 1500 course units ahead, far beyond the mesh
  (about 335 at velocity). The same pinhole projection gives distance-correct
  parallax. At the same screen position, a far object's screen velocity is
  `zNear/zFar` times a near object's (the test checks for less than 1/30). A
  farm 300 m out stays on screen for more than 8 s at top speed. Far objects
  have their own pass, painted back to front by true distance (`dz²+dx²`)
  before near/mid objects. Beyond the road mesh, a far-ground extension
  (36 geometric depth samples out to the far band's end, plus a skirt to the
  horizon) continues the terrain at its exaggerated elevation. It is drawn
  in the ground textures' mean colour and fades toward the distance haze, so
  far sprites stand on drawn ground and a crest in front hides them through
  the same clip chain (`test/scenic_grounding_test.dart`). They fade in over the last 24% of the window with a
  0.9 peak opacity. Only far sprites get a 1.7× artistic size boost. Their
  positions stay metric, so the parallax rate is unchanged.
- **Vista (>600 m)** is a wrapped horizon strip, 2.6 screens wide. Its offset
  is `-projection·heading·halfScreen`, using the absolute road heading from
  `ProofRoadFrame`. It moves only when the road turns and never with speed.
  Each zone gets five vista slots, and zones cross-fade over 300 units.
  The strip's base sits on the furthest far-ground line (or the horizon,
  whichever is higher on screen). Its foot fades into that ground's colour,
  not into a pale haze band. When
  a zone has vista sprites they replace the shared painted hills. Otherwise
  the hills stay, now also driven by heading instead of lateral position.
- Animated sprites (`frames`) change frame at 0.45 Hz for animals (grazing)
  and 1.2 Hz for other kinds, with a per-placement phase.

## Scheduler

`ScenicPlan.build` precomputes a whole level (9000 units) once per level
selection. It is deterministic from (level seed, course distance, manifest),
so replays, camera presets and flow presets all see the same scenery.

- Band cells (near 3, mid 6, far 30 units) on each side hash to an accept
  probability: density envelope × cell / 100. The envelope is the zone peak ×
  soft zone-edge ramps × slow value-noise breathing.
- **Quiet stretches** come from authored `quiet` zones plus noise gaps of about
  20%. In them the mid band is empty and the near band keeps only
  `furniture`/`sign` at 35% density. Far and vista layers continue. Course-keyed
  reflector posts (every 7 units, alternating sides) remain as road furniture.
- Group weights (`kind` or `kind/tag`) come from the zone or its biome preset.
  Each group's weight is split across its matching sprites. Biomes are tried
  in preference order, then relaxed. `hasTag` also matches id tokens, so
  `barn-red-gambrel` counts as a barn without explicit tags.
- **Recency exclusion**: the last 3 sprite ids per band and side are excluded
  whenever alternatives exist.
- Fences and `run` tags form 3–9 segment runs. Far animals form herds of 2–4,
  60–170 m out.
- **Set pieces**:
  - farmstead: barn, silo, house, trees and a herd.
  - grazing herd.
  - water tower.
  - village: mid-band houses.
  - bridge: deck and water surfaces, procedural 0.6 m parapets, and
    `structure/bridge` sprites along the span.
  - Curve-warning signs (`sign/curve`) are generated 110 units before every
    hairpin.
- Nothing is scheduled in the tunnel. The renderer streams nearest first with
  budgets of 72 near/mid and 28 far sprites per frame.

## Road surfaces

Zones name the road (`asphalt-worn`, `asphalt-fresh`, `concrete`, `brick`,
`bridge-deck`), the shoulder (`gravel`, `grass`, `sidewalk`, `none`) and the
ground (`meadow`, `crop-rows`, `water`).

- `SurfaceTrack` blends over 60 units at zone cuts and 10 units at bridge
  abutments. Windows are clamped so they never overlap. Each strip draws its
  base surface opaque and the incoming surface with vertex alpha `t`, which
  is evaluated at both strip ends. The result is continuous, with no seam.
- Shoulder width also blends: gravel 1.14, grass 1.2, sidewalk 1.34, bridge
  1.0. A curb line fades in with the sidewalk weight.
- Textures tile by `tileM`, in metres. Pack textures override procedural tiles
  with the same id. `asphalt-worn` and `meadow` reuse the proof art.
- Each layer has one mesh per surface id, with bases drawn before overlays.
  That is 8–10 surface draw calls per frame.

## Terrain

Hudson keeps the reviewed shared course exactly. The other five levels have
their own profiles:

| Level | Character | Highlights |
| --- | --- | --- |
| Indiana | rolling | Frequent sweepers, ±1600 swells, one .15 full-lock bend |
| Iowa | calm | Straights over 1200 units, |c| ≤ .014, long low swells |
| Ohio | hairpins | Hairpin pair, blind crest then hairpin, switchback climb, descent hairpin, final pair |
| Chicago | city | Flat grid, .15–.20 short corners: light braking in the rain |
| Arizona | mountain | +7000 switchback climb, blind summit and −.30 hairpin, fast descent into a hairpin |

- Structural chapters keep their positions: worksite 4120–4920 with cones,
  canopy, bridge 5450–6050 and tunnel 6050–6820. They stay gentle on every
  profile, so chapter replay keys are unchanged. Levels label their own
  opening chapters (`HAIRPIN PAIR`, `LONG STRAIGHT`, and so on).
- Curvature above 0.1 adds centrifugal demand of `(|c|−0.1)·18.75` half-widths
  per second at top speed, scaled by speed ratio squared. A .26 hairpin
  demands 3.0. The S2000's full authority at top speed is 1.73 and grows only
  linearly with speed, so it can hold the road at about 70% speed. Braking
  therefore matters, and the advantage it buys is deterministic. Legacy
  bends (≤ .08) are untouched. The cruising assist still releases above
  .026.
- The radio warns "Hairpin ahead" 60–340 units before a hairpin (about 4 s
  at top speed). An advance sign and chevrons stand 200, 130, 80 and 35 units
  before it, on the outside of the bend.
- Steering into a marked hairpin cancels up to 22% of its extra demand
  (`RaceController.hairpinAssist`, scaled by the square root of the steering
  share). Beyond the road edge the shoulder pushes back by up to 0.9
  half-widths/s (`edgeReturn`). Without braking, the car still leaves the road
  at top speed (tested). `test/mouse_pilot_test.dart` checks that a delayed,
  rate-limited pilot that only brakes moderately stays on the road in every
  level.
- Slopes stay under 23 elevation units per course unit. The existing ±0.24
  pitch clamp holds at every flow preset.

## Evidence

The evidence comes from local tests (`flutter test`). It is not a device
review.

- `test/terrain_profiles_test.dart`: a look-ahead braking pilot holds every
  level (max |x| < 1.0). Ohio and Arizona leave the road at top speed without
  braking. Hairpin runs are deterministic. The test also checks character
  counts, gentle structural chapters and pitch clamps.
- `test/scenic_test.dart`: the loader handles the fixture PNG, missing or
  invalid manifests and supplementation. The test also covers id-token tags,
  parallax rate, vista offset, scheduler determinism and window independence,
  recency, quiet zones, bounded density, the tunnel exclusion, signs and
  bridge structures, surface blend continuity and the curb transition.
- `test/scenic_render_test.dart` renders all six levels at 1280×720 with the
  current pack. The latest maxima:

| Level | Billboard batches | Sprites | Far sprites | Surface draws |
| --- | --- | --- | --- | --- |
| Hudson | 39 | 115 | 28 | 8 |
| Indiana | 39 | 112 | 28 | 8 |
| Iowa | 30 | 74 | 28 | 8 |
| Ohio | 39 | 110 | 18 | 8 |
| Chicago | 44 | 103 | 10 | 10 |
| Arizona | 23 | 77 | 16 | 8 |

The previous stride layout placed a scenery sample every 330 world units
across the whole mesh, plus a post and a shrub per sample.

## Partial packs

While the pack grows, `ScenicLibrary.supplement` keeps a proof-art sprite only
when no pack sprite covers its (band, kind, biomes) slot. Arizona palms and
far tree lines, for example, remain until the pack has desert or far trees.
As the pack grows, the proof art drops out without code changes. Sprites
whose atlas fails to decode are dropped. An empty or invalid manifest falls
back fully.

## Open

- Vista art, road/shoulder textures, desert, forest and city sprites, bridge
  structures and curve signs are expected from the scenic pack. Until then,
  procedural tiles and proof art stand in.
- Moving browser review of all six levels, physical-phone frame times, and
  user tuning of hairpin difficulty and far-band size are still needed.
- The shared painted hills backdrop, with its forest and city, stays the
  horizon on every level until vista sprites land.
