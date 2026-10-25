# Visual proof: browser surface and controls

The `?proof=1` route is an isolated sixty-second visual study. It starts paused
with the white Corvette and seed 731, has no GameSession, account service,
progress persistence or leaderboard, and returns to a retry screen at sixty
simulation seconds. The normal game route remains separate.

The scene widget is constructed once. A small HUD listens at up to 10 Hz;
changing timer/speed labels does not rebuild the GameWidget. Arrow keys steer,
Down/Space brakes, and P/Escape pauses. The existing angular wheel supports
independent outside-rim braking. Optional tilt uses the permission/calibration
bridge. Sound starts muted and can be enabled by a gesture. Hidden/background
pages pause and require resume; losing keyboard focus while still visible does
not by itself freeze this proof.

## Actual browser pixel budget

The first detail-preset experiment below used960×540; default smooth is measured
in the final proof report. Load `web/proof_bootstrap.js` synchronously before Flutter bootstrap. Only for
`proof=1`, it supplies a reduced `window.devicePixelRatio` before engine startup,
choosing the lesser of native DPR and a preset pixel budget. Smooth (default)
targets291,600 pixels (720×405 equivalent); quality=detail targets518,400 pixels
(960×540 equivalent). Aspect ratio is preserved. Screen orientation values and
CSS input coordinates are not changed.

This is a **prototype browser adaptation**, not a supported Flutter loader DPR
setting. The [documented initialization configuration](https://docs.flutter.dev/platform-integration/web/initialization)
has no DPR option. The pinned [Flutter 3.47.7 display implementation](https://raw.githubusercontent.com/flutter/flutter/3.47.7/engine/src/flutter/lib/web_ui/lib/src/engine/display.dart)
reads browser DPR and visual-viewport scale; the proof compensates both. The cap
covers the whole Flutter view, including the HUD. It does not keep overlays at
native display resolution, and it does not rasterize/copy the game into a new
image every frame. Canvas coordinate scaling alone would not cap the surface.

Initial proof of this mechanism used the existing release Flutter/CanvasKit
build in a fresh headless Chromium window, with the exact bootstrap script
injected before engine startup:

| CSS viewport | Native DPR | Effective engine DPR | Observed display canvas |
| --- | ---: | ---: | --- |
| 1280×720 | 1 | 0.75 | 960×540 = 518,400 pixels |
| 1280×720 | 3 | 0.75 | 960×540 = 518,400 pixels |

The existing isolated dart2wasm/Skwasm benchmark was also fresh-loaded at
1280×720/native DPR 3 with the same script: actual canvas 960×540. The benchmark
reported `compiledToWasm: true`, and both `main.dart.wasm` and `skwasm.wasm` were
observed as loaded resources. This verifies the cap mechanism in both renderers;
it is not a timing result for the new artwork.

These are actual `canvas.width`/`canvas.height` values found through Flutter's
shadow DOM, not CSS dimensions or an inferred size. Integrated proof-renderer
and compiler-target checks must be recorded separately. Resize, zoom, other
browser engines and physical phones still need validation: internal surface
allocation/retention can differ by renderer. `capApplied` only means the browser
getter was installed; inspect actual canvases before claiming the budget held.

## Measurement hooks

The proof exports `window.CannonballProof`:

- `snapshot()` reports compiled-to-Wasm flag, seed, scene car, simulation clock,
  driving/paused/complete state, speed, steering, braking, scene logical size,
  renderer update/render counts and CPU command-recording times. Its `browser`
  object includes native/effective DPR, actual nested canvas dimensions, viewport,
  focus and visibility from `CannonballProofBootstrap.snapshot()`.
- `reset()` restores the paused seeded test and resets measurement baselines.
- `start()` starts/resumes (browser audio may need an actual gesture).
- `pause(true)` pauses; `pause(false)` resumes.
- `drive(steer, brake)` supplies normalized steering and braking during driving.

Render-call counts and JavaScript requestAnimationFrame intervals are not proof
of presented-frame FPS. Renderer CPU timing records canvas commands; it excludes
asynchronous raster and compositor cost. Collect normal foreground samples
without screenshots first, then compare with any screencast/preview capture.
A paused simulation can still produce rendering/rAF callbacks, so always inspect
simulation advancement and pause state alongside timing.

`test/visual_proof_test.dart` exercises the isolated lifecycle, seeded Corvette,
keyboard control, fixed-duration completion, portrait prompt, and stable scene
widget under HUD updates using a test scene. Browser render quality and actual
surface sizes are verified separately; these widget tests do not load the atlas
or establish visual quality.

## Integrated browser smoke evidence

The first integrated release dart2js/CanvasKit proof also loaded with
`assetsReady: true`, `artError: null`, car `corvette`, seed 731, a paused zero
simulation clock, and an actual 960×540 canvas at 1280×720 CSS/native DPR 3.
CDP keyboard input started driving; ArrowRight produced steering 1 and changed
lateral position, Down produced braking and reduced speed, and pause cleared
steering/braking. Emulated concurrent touch produced nonzero wheel steering with
braking true; releasing all touches returned steering 0 and braking false.

Web Audio activation returned true in that browser, but the headless window has
no speakers, so this is API activation evidence rather than audible validation.
The emulated browser supplied usable orientation readings and enabled tilt;
this does not validate physical phone axes, permission prompts or comfort.
Denied/no-event behavior remains covered by the separate bridge tests. The
initial integrated bundle still contained Unicode arrows and triggered fallback
font requests; those characters were removed from proof source and widget-test
expectations before the final rebuild. Final network/timing verification belongs
to the final published bundle, not that initial capture.

## Final smooth-preset sample

The rebuilt proof was inspected at 1280×720 CSS, native DPR 1, with an actual
720×405 Flutter canvas. The eight-second foreground sample (seed 731, no capture
while measuring) recorded 426 render calls: 52.85/s, median rAF interval 16.7 ms,
p95 33.3 ms, p99 33.4 ms, maximum 50 ms. Simulation advanced 8.033 seconds over
8.060 wall seconds. CPU command recording totalled 317.337 ms over those calls.
Raw counters and browser context are in `research/visual-proof-metrics.json`.
This is host Chromium scheduling evidence, not presented-frame FPS or phone
performance. The host uses software graphics; compilation/tests were also running.
The moving scene was separately inspected after sampling: painted car, aligned
road markings, parallax vegetation and the transition out of the city loaded.

A custom WebGL/WASM Mode 7 compositor remains possible: the simulation, route
state and inputs are independent of `RaceGame` drawing. This sample still uses
Dart JS/CanvasKit; the earlier same-seed JS/Wasm benchmark does not justify
switching the default solely on language choice. A future custom compositor needs
its own identical-scene raster/presentation comparison.
