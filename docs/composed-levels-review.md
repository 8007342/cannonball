# Six composed road packs — local review, 2026-10-25

Built on `work/composed-lighting-levels` from `4c35075`. This is a next composition
proof, not a verified real-world route atlas or finished nationwide art pack.

## Review controls and compositions

| Key / level query | Composition |
| --- | --- |
| Q / `hudson` | Green daylight approach, rolling terrain and roadside structures |
| W / `indiana` | Golden/brown sunset woodland, rooted crowns, dapple and wet shoulder leaves |
| E / `iowa` | Flatter open sunset skyline, sparse trees and broad rollers |
| R / `ohio` | Cool wooded night, illuminated shoulder objects, warm lamps and red traffic cores |
| T / `chicago` | Wet urban night, rain, denser lamps, scenic signals and reflection accents |
| Y / `arizona` | Dry warm ground, sparse alternate vegetation and different dusk gradients/curves |

Open `/?proof=1&level=indiana`; take the keys or use the level popup below the
title. Q–Y immediately select a level without the garage.1–8 select chapters
within that level. **Backspace replaces the old R restart shortcut.** Arrows,
rim steering, center braking and other utility controls retain their behavior.
These six names are illustrative corridor themes, not researched exact roads,
species inventories or an approved final campaign itinerary.

## Engine and lighting changes

Each immutable level declares its seed, curve/elevation coefficients, sky/ground
palette, vegetation selection/density, wetness/weather and canopy/lamp metadata.
The controller and renderer share a terrain adapter. Selecting a pack resets
input, traffic, course clock and light history together; chapters retain the pack.
All art variants are prepared before play, not decoded on a level-switch gesture.

Three shared material atlases serve the six packs. The measured atlas total is
14,155,776 pixels, approximately54 MiB at four bytes/pixel; this excludes other
assets, copies, driver allocations and application/browser overhead. Repeated
swaps did not increase this cache. This footprint still needs real-phone review.
The paintings are reused from the original approved sample packs; only material
variants and a small seeded runtime leaf texture are composed here. No bulk
generation or final region-pack approval is implied.

Night ambient grading happens on materials rather than as an overlay over the
finished scene. Bounded player/nearest-NPC headlight fields use angular penumbra,
distance falloff, steering aim and terrain-visibility samples. Nearby lamps add
local surface light. Tail running lights, brighter brake lamps, night lamps and
scenic signal cores render independently of ambient grade. Their halos and short
source-only histories are stylized effects. Histories are bounded to64 sources,
12 samples/source and.12 seconds; pause/reset/reduced motion clear/suppress them.
This is not a validated physiological persistence model or full shadow/PBR rig.

Local surface-light and terrain-visibility evaluations are cached within a frame
and cleared every render. The fixed road-strip count stays180, with three lateral
asphalt bands for directional lighting. Additional work is bounded, but night is
measurably heavier than the earlier daylight proof.

The previous three detached center canopy arches are removed. Conditional tree
crowns reuse the roadside art vocabulary with roots beyond the shoulder, varied
stagger and open gaps. Bridge/hard-tunnel intervals exclude crowns. Autumn material
variants, dappled road shade and world-anchored shoulder leaf texture provide the
first warm woodland composition; tire lanes remain clear. Warm painted foliage
is a transmission cue, not physically simulated per-leaf subsurface scattering.

The [source ledger](research/level-lighting-scenery.md) is linked from the new
OpenSpec requirements. It records Ranitas's lighting-mask shortcomings and the
application/defer reasons for LearnOpenGL, HELLA, GPU Gems, IES, wet-material,
leaf-transmission and autumn-color research. Full volumetrics, IES parsing,
normal-mapped leaf lighting and per-pixel physical transport are deferred.

## Verification and remaining limits

141 Flutter tests passed, covering level/condition/terrain repeatability, canopy
clearance, repeated asset selection/cache bounds, light falloff/aim/temporal
limits and the actual Q–Y/digit/restart widget flow with cleared input. Targeted
checks were repeated after the final canopy-eligibility adjustment. Analyzer and
format checks are clean.32 browser/audio and14 Worker tests passed; Worker
packaging passed as a **dry-run**, not a live deployment. Release web build and
strict OpenSpec checks passed locally. No GitHub workflow or remote build hook
was added or enabled.

In Chromium, all six levels were selected twice using actual key events. Each
reported its matching id/seed/weather, reset clock, ready assets, no art error,
and the same three-atlas/14,155,776-pixel cache. Existing light histories were
cleared between daylight/night packs. Visual checks inspected golden foliage
and leaf drifts, the open prairie skyline, and wooded/wet night illumination.
The sky check caught and fixed inherited paint alpha from a prior effect;
ambient state is now explicitly reset before painting the sky. Browser console
showed no exceptions during repeated swaps. Agent inspection is not user approval.

The uncaptured wet-night S-bend sample recorded5024ms wall time,5.0667s simulation,
194 render calls, rAF p50/p95/p99 of33.3/33.4/50ms and mean CPU drawing-command
recording5.955ms. Canvas was720×405 backing at1280×720 CSS/native DPR1. Raw counters
and repeated swaps are in [composed-levels-metrics.json](research/composed-levels-metrics.json).
These are host Chromium scheduling/CPU measurements, **not displayed-frame FPS**,
GPU timing or phone performance. The sample preceded the final alternate-level
scenery-side parity and canopy-chapter corrections; its Chicago S-bend code path
is unchanged by those corrections. No controlled old/new benchmark was run.

Physical-phone reach, night visibility, glow/trail comfort, sustained performance,
audio mix and final art coherence remain for human review. The wet-night measured
cost is a specific follow-up for phone profiling. Full campaign streaming, exact
geography, production regional paintings and cloud stage saves remain separate.
