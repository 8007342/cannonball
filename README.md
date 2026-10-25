# Cannonball

A landscape arcade road trip from New York's Red Ball Garage to The Portofino in
Redondo Beach. Flutter + Flame, web only, mobile first. Successful runs target
10–15 minutes. Routes, traffic and luck differ; better unlocked cars enable better
runs on one shared Top100.

## Current build

The first playable implementation includes a wooden key-box garage, six car slots,
projected road hills/curves, traffic, construction, route choices, gates, crash
recovery, secrets, weather, regional radio, original synthesized music and a US
route recap. The final car is a white 2019 Corvette Stingray Coupe, targa off.
Touch uses an oversized angular rim; tapping outside brakes, holding sustains it.
Left/Right or A/D steer, Down/Space brakes, P/Escape pauses. Optional browser tilt
has permission, calibration and touch fallback. Acceleration is automatic.

Google sign-in, durable account unlocks and global records are implemented in the
Worker; live registration/deployment remain unverified. The user selected
Arabiya's shared public Google client, with an exact Cannonball JavaScript origin
required. Guest progress stays local. Unavailable cloud services never block play
or claim that a local result was saved globally.

**The user rejected this first pass’s graphics and static/slow presentation.**
The renderer is being replanned around Super Off Road: The Baja’s lively motion
with a modern cartoon world. See the [renderer audit](docs/research/renderer-audit.md).
This is not production-complete. Artwork is original
procedural composition; exact road/interchange geometry and landmark sightlines
are not yet a verified atlas. Final sprite/region packs, authored story/cutscenes,
production sound-bank/voice library and real-phone tuning remain tracked in the
[implementation checklist](openspec/changes/playable-road-trip/tasks.md).

## Run and verify

Flutter **3.47.7**, Dart **3.13.5**, Flame **1.38.2**; Node **22+** for Worker tools.

```sh
flutter pub get
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web --release
openspec validate --all --strict
node --test web/platform_bridge.test.mjs
npm --prefix services/api ci
npm --prefix services/api test
npm --prefix services/api run test:runtime
```

The Flutter-only server serves a local game without the API. See the
[deployment guide](docs/deployment.md) and [API runbook](services/api/README.md)
for same-origin integration, Google setup, SQLite migration and storage recovery.
The intended production host is `https://cannonball.tlatoani.net`, with Pages assets
and a Worker on `/api/*`. No production deployment is claimed.

## Project memory

- [Specifications](openspec/specs/) and [active implementation](openspec/changes/playable-road-trip/)
- [Decisions](docs/design/decisions.md), [interview](docs/design/interview.md), [roadmap](plan/roadmap.md)
- [Engine](docs/research/engine.md), [motion/art](docs/research/motion-art.md), [flow/geography](docs/research/design.md)
- [Renderer audit](docs/research/renderer-audit.md) and [Dart/Wasm benchmark](docs/research/wasm-benchmark.md)
- [Browser platform](docs/platform.md), [authentication research](docs/research/auth.md)
- [Asset contract](assets/README.md)

PWA installation is optional; opening the URL is sufficient. Device sensors,
audio and landscape behavior require physical-browser checks. Production art
approval is based on moving gameplay samples, not screenshots alone.

## One-minute visual proof

Open `/?proof=1` on a release web build for the isolated, seed-731 test drive.
It showcases the new painted Corvette/scenery renderer without changing saves or
unlocks. Auto acceleration is always on: left/right arrows or drag the oversized
wheel rim to steer; Down/Space or touching outside the rim brakes. P pauses.
Sound starts muted. `/?proof=1&quality=detail` raises the raster budget.

The normal garage route retains its earlier renderer while this sample is reviewed.
See [proof notes](docs/proof-platform.md), [sample art and prompts](assets/proof/PROMPTS.md),
and [recorded measurements](docs/research/visual-proof-metrics.json).

## Second proof: S2000 departure and reactive traffic

`/?proof=1` now opens the painted wooden keybox. Take the keys (or press Enter)
for the short garage departure, then drive the 90-second study. The fast-forward
icon skips departure. Controls remain rim drag/Left/Right steering, outside-rim
hold/Down/Space braking, and P/Escape pause. Sound starts muted; enable it for
original sample station music and browser speech. Captions are optional.

`?proof=1&motion=classic` and `motion=cruise` compare optical-flow presets against
the default `arcade`; the car physics remain identical. `quality=detail` raises
raster detail. New art and prompts live in [assets/proof-next](assets/proof-next/PROMPTS.md).

[Garage/audio](docs/garage-radio-proof.md), [renderer](docs/renderer-next-proof.md),
[Atrapa-inspired traffic](docs/research/atrapa-traffic.md), and
[stage-record foundation](docs/stage-progress.md) document the second proof.
The stage model is a local, tested foundation; city selection, remote stage saves,
regional voice packs, connected playable ramps and new rankings remain future work.
