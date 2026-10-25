# Dart JavaScript vs Dart WebAssembly experiment

2026-10-25. Question: does replacing the Dart-to-JavaScript build with Wasm fix
the rejected racer's performance? **This experiment does not establish that.**
It shows faster drawing-command recording, but no improvement in overall render
cadence on the tested software graphics environment.

## Targets and method

Flutter3.47.7, Flame1.38.2, release builds of the same isolated renderer harness:
`tool/renderer_benchmark.dart`. No changes to game simulation or renderer code;
root HUD, account/network services, tilt and audio are excluded. Both builds use
starter wagon and seed731, reset before each short initial-city measurement.
A0.5s warm-up precedes about3s of sampling. Measure actual positive-dt update and
render method invocations, browser rAF intervals and simulation advancement.
Source clock measures command-recording CPU work, not asynchronous GPU work.

- JS target: dart2js application + CanvasKit. CanvasKit itself is already Wasm.
- Wasm target: dart2wasm application + Skwasm. Verified
  `bool.fromEnvironment('dart.tool.dart2wasm') == true` and actual loading of
  main.dart.wasm and skwasm.wasm; no silent JavaScript fallback.
- Same headless Chromium156 host,844×390 CSS viewport and SwiftShader software
  graphics. No screenshots during timing. One fresh page initialization per DPR.
- No cross-origin isolation, so Skwasm is single-threaded. Multithreaded Skwasm and
  physical hardware/phone browsers are not evaluated by this experiment.

## Valid full-reload measurements

| Actual scene surface | dart2js / CanvasKit render calls/s | dart2wasm / Skwasm render calls/s |
| --- | ---: | ---: |
|844×390 pixels, DPR1 |59.67 |52.05 |
|1688×780 pixels, DPR2 |29.17 |27.51 |

At DPR2, p95 browser intervals were49.9ms(JS) and50.0ms(Wasm). CPU command-recording
per render was about4.38ms(JS) versus0.98ms(Wasm); simulation update CPU time was
about0.035ms versus0.048ms per update. Both advanced approximately3s of simulation
in the measured3s wall-time window.

Interpretation: the Wasm pipeline makes recording this primitive-heavy scene
cheaper on the CPU, yet the end cadence remains limited elsewhere in this test.
The large pixel-budget effect is consistent with substantial raster/presentation
cost in the software graphics environment. This does not isolate GPU time or
prove a single bottleneck. The two targets change Flutter's renderer as well as
Dart compilation, so do not attribute the difference solely to the language.

These are render-invocation and browser scheduling measurements, **not confirmed
presented-frame FPS**. Samples are short and sequential. They cannot establish
that Wasm is universally faster/slower, reproduce the user's reported2fps, or
predict a real phone's performance. Raw results and explicit exclusions are in
wasm-benchmark-metrics.json.

## Experimental issues retained rather than hidden

The local static preview served main.dart.mjs as text/plain; Chrome refused the
module. `tool/prepare_wasm_preview.mjs` makes a byte-identical .js alias and points
the experimental bootstrap at it. Production hosting should serve .mjs with a
JavaScript MIME type instead. The Wasm bytecode is unchanged.

Initial experiments changed DPR without reloading. Wasm output then visibly
occupied only part of the surface, invalidating a superficially better timing
result. Those samples are excluded. Valid samples reload after setting DPR;
the DPR2 Wasm scene was visually checked to fill the full surface. The exact
resize anomaly is not diagnosed and is not a general claim about Skwasm.

## Reproduce

```sh
flutter build web --release --target tool/renderer_benchmark.dart \
  --output build/web/bench/js --base-href /bench/js/ --no-wasm-dry-run
flutter build web --release --wasm --target tool/renderer_benchmark.dart \
  --output build/web/bench/wasm --base-href /bench/wasm/
node tool/prepare_wasm_preview.mjs
```

Serve build/web; visit /bench/js/ or /bench/wasm/. Set the intended viewport/DPR
before loading. Wait for cannonballReadBenchmarkStats to exist, then evaluate
`tool/benchmark_sample.js` in the page. The code resets the seed automatically.
Verify the compile flag and loaded renderer resources, record actual surface
size/backend, and inspect the scene before accepting any new configuration.
A normal build/web release rebuild removes these nested benchmark artifacts;
the source harness and recorded evidence remain versioned.

## Recommendation

Keep Dart/Flame while replacing the renderer's primitive stream with coherent
animated art, batched/cached composition, proper optical-flow scale and a real
scene pixel budget. Keep Wasm as a measured build option, not a promise that a
compiler flag repairs animation, art or raster load. Rebenchmark the new scene
on hardware-backed desktop and target phones, then decide the shipping default.

Flutter's [Wasm guide](https://docs.flutter.dev/platform-integration/web/wasm)
documents compiling the same Dart application to Wasm, runtime fallback,
verification and the isolation headers required for multithreading. Our current
popup-friendly auth headers do not provide that isolation; test the real GIS
flow before changing production policy. For detailed work attribution, use
[Flutter web profiling](https://docs.flutter.dev/perf/web-performance).
