# Design

## Context
First-pass simulation, Flame renderer, UI and durable Worker exist. The user rejected the renderer and reported poor speed/smoothness. A foreground software-rendered browser audit found resolution-sensitive frame scheduling and an independent optical-flow scale problem; see docs/research/renderer-audit.md. Exact Google origin registration is now operator-confirmed, while live sign-in and deployment remain unverified.

## Goals / Non-Goals
Goals: an integrated playable browser implementation of the run lifecycle, testable simulation, durable API, browser controls/audio and clear production-readiness evidence.
Non-goals: native applications, equalized competition, claiming an initial procedural rendering pass is the final approved asset library, or claiming desktop tests establish phone comfort.

## Decisions
- Astra engine owns lib/game: fixed-step model, route graph and pure receipt, with Flame road projection. Its first procedural rectangle-based composition was rejected; replace it with textured geometry and authored animated cartoon sprites. UI observes controller state at a bounded rate. Physical simulation is distinct from drawing and real route miles from compressed driving coordinates.
- Root owns Flutter garage/HUD/angular wheel/initials/map/profile integration. Default wheel returns to center; every active pointer is tracked by ID. Tap outside rim briefly brakes, hold sustains it. Utility overlays capture their own pointers. Keyboard and tilt normalize to the same steering intent.
- Astra platform owns browser interop, gesture-gated sensors, no-event fallback, landscape orientation mapping, lifecycle callbacks, synthesized original music/engine sound and nonblocking speech. Captions are authoritative when speech/audio fail.
- Astra backend owns same-origin GIS nonce login and SQLite Durable Object accounts/sessions/records. Reuse the public Arabiya client ID; the operator confirms exact Cannonball origin registration. Never share cookies across sibling hosts.
- Anonymous runs remain local. Signed-in starts get server tickets; finished receipt validation and idempotent ranking precede initials entry. One canonical Top100 deliberately mixes unequal cars, routes and luck. All cloud failures remain separate from local play.
- Six initial car slots end in the white 2019 Stingray, targa off. Starter and intermediate fictional designs are working choices subject to review; original procedural visuals enable animation/handling feedback without commissioning unreviewed bulk assets.
- Candidate real-road corridor graph uses approximate geographic nodes and documented road names. Exact production intersection geometry, landmark sightlines and complete regional asset packs require source review; do not call the initial graph a verified map atlas.

## Risks / Trade-offs
- Browser tilt/audio variation → feature detection, user gestures, immediate fallback and real-device checklist.
- Asset and route depth exceeds first integration → retain explicit content acceptance tasks and report actual implementation maturity; do not erase requirements.
- Browser-reported scores can be forged → server tickets, timing bounds, known route/car validation, duplicate protection; replay verification remains a cost/rigor decision.
- Live Google login remains unverified despite operator-confirmed exact-origin registration → test the real flow; keep actionable errors and local driving available.
- Motion comfort cannot be automated → steady horizon option and uncompleted physical-device acceptance checklist.

## Migration Plan
Run local checks, publish a local review build, then use the prepared Pages/Worker configuration when live credentials/resources are available. SQLite migration creates new Cannonball-only objects. Roll back code by redeploying the prior version without deleting progress storage.

## Renderer replacement decision

Retain simulation/identity/progression. Replace the visual pass with reusable
textured road vertex buffers, cached distant composites, independently moving
parallax layers and batched, depth-sorted authored sprites. Bridge decks/supports,
traffic and hill occlusion must share an explicit depth model. Interpolate render
snapshots; calibrate camera trail, width, marking and prop frequency together.
Source-frame pixel styling must not force position snapping.

Render scale must cap actual scene pixels independently of sharp HUD/text. The
observed SwiftShader DPR2 slowdown versus DPR1 makes this a mandatory benchmark
variable, not proof of any phone's capabilities. Benchmark the same seeded scene
in foreground without screenshot capture, then compare embedded and direct views.
Report update/render counts, rAF interval percentiles, renderer/DPR, input latency
and simulation/wall-time ratio separately; do not call rAF presentation FPS.

The next deliverable is one30–60s city-edge/vegetation/hill/bridge scene with an
animated car and traffic, not bulk placeholder expansion. Compare CanvasKit and
Wasm as measured options. Do not promise a framework/renderer migration will fix
performance until that scene demonstrates the desired result.
