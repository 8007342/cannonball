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
- [Browser platform](docs/platform.md), [authentication research](docs/research/auth.md)
- [Asset contract](assets/README.md)

PWA installation is optional; opening the URL is sufficient. Device sensors,
audio and landscape behavior require physical-browser checks. Production art
approval is based on moving gameplay samples, not screenshots alone.
