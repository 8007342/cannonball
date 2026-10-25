# Renderer rejection, Baja reference and measured limits

2026-10-25, code/build dd37c3c. The user rejected the rectangular graphics and
reported approximately two frames per second with little sense of speed. Earlier
approval covered motion/art research; it did not approve this visual result.
This document is an assessment and replacement proposal, not a completed fix.

## What the reference changes

The reference is **Super Off Road: The Baja** on SNES, interpreted as a modern,
lively cartoon driving scene with readable vehicle motion and a richly composed
world. It is not satisfied by rectangles, superficial pixelation or Gaussian blur.
The original [Tradewest manual](https://db.hfsplay.fr/files/2022/07/13/Super_Off_Road_-_The_Baja_USA_30zqr4G.pdf)
connects terrain, impacts and suspension to driving. Publisher [back-box artwork](https://snescentral.com/0/6/7/0677/SNS-R8-USA-box-back.jpg)
is another primary artifact; [catalog provenance](https://snescentral.com/box.php?id=0677&num=0&side=back)
identifies the archived scan. Original-game imagery such as this [San Felipe screen](https://cdn.mobygames.com/screenshots/16127478-super-off-road-the-baja-snes-racing-around-san-felipe.png)
is reference material, not reusable Cannonball art. Some page-image retrievals
were inaccessible or timed out; no pose counts or animation rate were measured.

Do not claim that brown terrain was the original game's sole technical reason
for its off-road setting. No original-developer explanation establishing that or
its exact rendering implementation was found. A [firsthand Randal Linden interview](https://limitedrungames.com/blogs/news/development-interview-with-randal-linden-and-john-linneman)
identifies John Morgan as its developer, but its later Super FX account discusses
other games. It does not establish The Baja's hardware technique.

For Cannonball, carry the reference's terrain/vehicle emphasis into a present-day
US road journey. Roads need asphalt detail, shoulders, medians, merge geometry,
city approaches, vegetation and landmarks. Cities and bridges must be composed
as environments the car moves through, not icons on a mostly unchanging backdrop.
Cartoon treatment needs silhouettes, highlights/shadows and coherent poses; shape
language and motion matter more than simply choosing a low resolution.

## What is actually wrong in current code

The renderer in lib/game/race_game.dart draws individual Canvas primitives. It
has no production car animation atlas, ground texture atlas or regional art pack.

| Finding | Evidence / implication |
| --- | --- |
| Motion scale too slow | Maximum starter speed136 × .52 gives70.72 scene units/s. Markings repeat500 units (~7.07s); props every600 units (~8.48s). A2200-unit-wide road is mismatched to this travel rate. |
| Quantized slow clouds | .007 ×70.72 gives .495 logical px/s, then `_rect` rounds coordinates. Visible cloud changes can occur only about every2s. |
| Missing vehicle animation | Small bob/skew and rigid crash rotation substitute for wheel phases, suspension, slope/turn poses and authored deformation. Car screen height does not follow projected ground contact. |
| Repeated scenery | Prop selection at index%6==0 makes a subsequent index%3 variation always0. |
| Expensive primitive stream | Up to93 candidate slices,186 projections, many fresh paths/offset lists, repeated clipping and scenery details each render. Traffic is searched per strip. Counts are code bounds, not a CPU profile. |
| No actual resolution tier | A1000×560 coordinate system scaled with Canvas is not a1000×560 rendering surface. The observed DPR2 buffer was1688×780 for an844×390 viewport. |
| Broad UI updates | Whole-screen session rebuilding at20Hz adds work, although the same RaceGame instance persists and Flame's independent ticker is not capped to20Hz. |
| Simplified depth model | Forks widen a shoulder rather than render a true diverging road; bridge drawing is not in one shared depth/occlusion queue with traffic. |
| Focus behavior | Every non-resumed Flutter lifecycle state pauses the race. Visibility/focus and active simulation must be checked separately from rAF. |

Existing fixed-step logic and backend tests remain useful. They do not establish
smooth rendering, correct optical flow, visual quality or phone performance.

## Browser measurement

Release build, headless Chromium156, foreground844×390 CSS viewport, no
screenshots during sampling. Graphics identified itself as **SwiftShader software
rendering**, not a hardware GPU. Raw evidence: renderer-audit-metrics.json.

| Scene / surface | rAF cadence | Median interval | p95 interval |
| --- | ---: | ---: | ---: |
| Garage, DPR2 |60.55/s |16.7ms |16.8ms |
| Initial active run, DPR2 |25.37/s |33.4ms |50.1ms |
| Warm active run, DPR1 (844×390 pixels) |60.00/s |16.7ms |16.8ms |
| Warm active run, DPR2 repeated (1688×780 pixels) |27.54/s |33.3ms |50.0ms |

A separate8s GL-instrumented active sample had221 callback intervals with GL
submissions, about27.6/s. It made66,509 intercepted GL draw calls (roughly301 per
interval). Wrapping those methods perturbs work and is not a GPU timing trace.
The unwrapped samples above remove that instrumentation. The scenes were
sequential, not identical replay frames, so these measurements demonstrate a
resolution-sensitive performance problem without uniquely identifying its cause.

These are browser scheduling/render-activity indicators, **not measured display
presentation FPS**, phone benchmarks, or a reproduction of the user's2fps.
There is no evidence here for promising60fps on all devices. Full
[Flutter web profiling](https://docs.flutter.dev/perf/web-performance) requires
profile mode and Chrome timeline capture to separate build/layout/paint work.
User device/browser and embedded-viewer versus direct-URL context remain useful
for reproducing their exact experience.

## What Flutter + Flame can support

Flame supplies loop/input/component/animation infrastructure. The racing renderer
and asset pipeline remain our responsibility. Its [image/animation support](https://docs.flame-engine.org/latest/flame/rendering/images.html)
and [cached layers](https://docs.flame-engine.org/latest/flame/rendering/layers.html)
are largely unused in this build. Flutter can draw [texture-backed triangle meshes](https://api.flutter.dev/flutter/dart-ui/Canvas/drawVertices.html)
and [batched atlas sprites](https://api.flutter.dev/flutter/dart-ui/Canvas/drawAtlas.html).
These are the relevant building blocks, not proof of a finished scene's speed.

Proposed renderer:

1. **Ground/road:** textured projected strips/mesh for asphalt, markings, shoulders
   and terrain; hill-aware geometry and smooth camera motion. Reuse typed vertex
   buffers and project each sample once. A flat Mode7-style ground alone does not
   supply hills or elevated interchanges.
2. **Depth composition:** one authored road-coordinate/depth model for traffic,
   trees, roadside buildings, supports, decks, signs and horizon occlusion. Cache
   distant compositions and cull objects before submitting sprites. True elevated
   routes need explicit geometry/collision separation.
3. **Animated cars:** aligned multi-pose sprites for flat/crest/descent, gentle/hard
   steering, body roll, suspension travel, wheel speed, braking, sliding, impacts
   and flips. Author intermediate poses; don't enlarge or skew one box and call
   it animation. Open-roof Corvette identity must survive every pose.
4. **Layered world:** independent sky/cloud movement, distant mountains, city
   silhouettes, midground buildings/vegetation, dense near-road props and shadows.
   Region packs carry palette, lighting, ecology, landmarks and composition rules.
5. **Optical flow:** retune road width, camera trail/height, surface texture
   frequency and prop cadence together. Separate visual scene units from real
   route miles and10–15 minute run timing. Smooth subpixel transforms and
   interpolated render snapshots prevent artificial snapping.
6. **Budgeted rendering:** cap actual race backing resolution/pixel ratio by
   measured capability while keeping HUD/text separate and sharp. Batch sprites,
   cache scenery and stop rebuilding the whole race UI on every HUD tick.
   Compare CanvasKit with Wasm only as measured alternatives, not magical fixes.

## Next acceptance proof

Build one30–60s moving route through a city edge, a curve/hill, vegetation and a
bridge, using one coherent sample car/environment pack. Include traffic so the
benchmark exercises occlusion and relative speed. Review video/interaction, not
screenshots alone. Instrument update, render, browser frame intervals and
simulation/wall-time ratio independently, with hardware/renderer/DPR recorded.

Proposed target: stable60Hz on agreed target browsers at an explicit scene pixel
budget, with a measured30Hz fallback where needed; p95/p99 and input latency must
be reported, not just an average. Thresholds are proposed acceptance goals, not
current achievements. Compare the same seeded scene at multiple render scales,
without screenshots first, then through the preview viewer. Final style and
production asset expansion follow the moving proof. No more region/car expansion
should be justified merely by existing unit tests passing.
