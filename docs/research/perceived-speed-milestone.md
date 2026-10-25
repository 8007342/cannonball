# Perceived speed: third-proof research and review protocol

Research checked 2026-10-25. These sources inform experiments; none validates our
pseudo-3D phone presentation or supplies a universal camera preset.

## Direct evidence and limits

[Holm, Skovhus and Kraus (2017)](https://eudl.eu/pdf/10.1007/978-3-319-55834-9_14)
tested 40 participants with a third-person rolling-sphere scene on a straight
textured road. Wider geometric FOV raised perceived velocity; strong motion blur
reduced it; camera altitude interacted with velocity. Therefore camera projection
and near-road optic flow deserve isolated tests. A lower camera is not automatically
faster, and excessive widening can distort cars and reduce useful preview distance.

[Sandin et al. (2016), Driving Simulation Conference](https://proceedings.driving-simulation.org/proceeding/dsc-2016/effects-of-sensory-cues-on-perceived-simulated-speed/)
used 12 experienced drivers in a full-motion simulator. Acoustic cues affected
selected speeds in some active-driving conditions, but the direction differed
between tasks. It supports testing coherent engine/road sound alongside visual
flow, not a claim that louder audio universally feels faster.

[Schlöter et al. (2025), Transportation Research F](https://www.sciencedirect.com/science/article/pii/S1369847825000543)
investigates visual and matching acoustic flow. The publisher abstract was found,
but full-text access was blocked in this run, so no detailed parameters or numerical
claims from it are used to prescribe implementation.

## Proposed controlled comparison (our design inference)

Compare the same fixed car, seed, geometry, speed curve, traffic and raster budget:

1. Baseline: current camera and existing road-reference density.
2. Wider readable camera: modest projection/framing change, no travel-speed change.
3. Wider plus near flow: same preferred framing, visible world-fixed road seams,
   reflector posts and varied silhouettes passing through the lower peripheral view.

Do not simultaneously change field of view, car scale, road width and acceleration
and then attribute the result to one setting. Preserve a stable central traffic
view; avoid full-screen blur and random hazard-position jitter. The authored
straight, S-bend, climb/curve, crest/descent and tunnel sections make the comparison
more useful than an endless straight. First ensure the geometry is visible rather
than flattened by a forward-distance multiplier.

Ask which variant feels faster, which remains controllable, and which makes the
upcoming road easiest to read. Hide mph numerals for one comparison. Record run
completion, collisions, successful passes, braking, time at road edges and timing
percentiles. Test audio on/off independently. Repeat in a different presentation
order; record device/viewport and comfort feedback rather than relying on one
reviewer's first impression. These are proposed acceptance methods, not completed
human study results.

## Viewport diagnosis

The parent reproduced a live layout viewport change from1280x720 to1920x1080:
Flame logical size and CSS canvas grew to1920x1080 while the deliberately capped
backing buffer stayed720x405. That is correct stretching of raster density across
a larger logical viewport, not evidence of a fixed-size game. Maximizing a host
viewer can leave its emulated browser viewport unchanged; the user's report still
needs a native-window versus viewer comparison.

[Flutter's view documentation](https://api.flutter.dev/flutter/dart-ui/FlutterView/devicePixelRatio.html)
separates logical dimensions from device pixels and describes metric-change
notifications. [MDN's browser viewport documentation](https://developer.mozilla.org/en-US/docs/Web/API/Window/innerWidth)
defines innerWidth as the layout viewport, distinct from browser chrome or an
external preview viewer. Diagnostics should report layout size, visual viewport,
CSS surface bounds and actual backing pixels separately. A720x405 buffer alone
must never be labelled a720x405 displayed game.

Keep the proof-only DPR override documented as a prototype workaround affecting
the whole Flutter root; it is not a supported scene-only Flutter render-scale API.
No forced CSS or canvas-width mutation is justified by the passing live-resize
case. Add geometry evidence first, then fix a reproducible layout mismatch.
