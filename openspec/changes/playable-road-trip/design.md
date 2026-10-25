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

## Approved second proof — 2026-10-25
User approved the researched garage, traffic, palette and station design and requested implementation plus frequent remote work-branch checkpoints. Root integrates work/next-driving-proof; isolated agents push work/reactive-traffic, work/s2000-render and work/garage-radio. No production deployment is implied.

The next short local proof uses an S2000-specific CarSpec without mutating the legacy server rules or old full-run receipts. Layered garage paintings, a key/hand atlas and occlusion cuts sell pickup, reveal, walking, entry and chase launch. Simulation stays paused until handoff. Repeat/skip remains available.

Reactive traffic is opt-in so prior receipt fixtures remain stable. It observes bounded neighboring gaps and player motion; persistent profiles choose following, passing, braking and within-lane flinches. Secondary braking/incident states stay local and time-bounded. Atrapa is a design reference, not a supplied trained policy. Original rules and source attribution are documented.

Car source art uses saturated paint separated from fixed details. Cached body-only recoloring preserves lights, glass and tires. Signed turn/skid selection fixes the one-direction high-speed pose. Camera, roadside reference density and relative motion are tuned separately from route miles and elapsed time. Auxiliary ramps are explicitly NPC-only until true playable branch topology is implemented.

The station sequence is song, tuning burst, condition-relevant report, next song. Runtime browser speech is a fallback sample and does not establish regional accent quality. Prepared regional voices remain a production task. Text-free artwork is confirmed; optional captions/UI remain available pending a stricter interpretation.

Campaign direction supersedes the old whole-country 10–15-minute target: major city checkpoints form connected city-to-city stages, with mixed cars allowed across saved stage bests. A local versioned model retains compatible successful receipts and computes a connected best journey. This proof does not submit experimental stage receipts to the old full-run leaderboard. Remote stage migration, full city selector, new rankings and nationwide content are later acceptance work.

## Approved driving-and-camera milestone — 2026-10-25
The next local proof is an authored test course, not verified geographic reconstruction. Shared proof-only course geometry drives road projection and steering demand, keeping legacy full-run simulation/receipts stable. Straight, S-bends, combined climb/bend, crest/descent, worksite, canopy and bridge/tunnel sections must be recognizable in a short drive. World-fixed object IDs/positions and world-phase lane markings prevent camera-attached repetition. Temporal aliasing is evaluated after placement correctness, never hidden by moving hazards randomly.

Camera variants change projection/near-flow cues independently from mph and route timing. Research sources and design inferences remain distinct; no universal speed/FOV or millisecond transition rule is assumed. Stateful steering presentation must expose gentle/intermediate poses on brief large inputs, preserve gentle held inputs, pass through neutral on reversal, and avoid a one-frame jump into skid. A proof-only steering response can be tuned if needed; responsive braking/release remain independent.

Painted replacement props are cached with scenery to preserve batching. Building grounded footprints stay behind curb clearances; canopies/portals use explicit overhead layers. Daytime depth palettes approach sky/haze color with reduced contrast; tunnel exposure changes are localized and must preserve hazard readability. No expensive full-frame blur or gratuitous particles are required.

Preserve the liked keybox and garage exterior artwork. Improve reach/grasp/withdraw and coordinated pan; use a genuinely wide cabin with aspect-preserving cropping. Door/ignition/rev sound bridges the rear-view handoff; preload live scene behind the cinematic while race time remains paused. Reduced-motion/skip/mute/hidden handling remain available. The last viewport test resized a real browser viewport correctly; preview-host fixed viewport and app metrics must be diagnosed separately before changing a working layout.

Use work/road-feel-milestone for integration, with frequent durable specialist pushes. Root runs mounted Flutter checks and browser review centrally. Native/device and production acceptance remain open.

## Soundtrack proof and next driving review
Replace the proof's short oscillator motif with original authored sectional music:
synthpop, cumbia/electronic and hard-driving rock. Store multitrack MIDI and the
render source alongside compressed stereo mixes. Decode only the selected score,
keep a bounded cache and preserve song/tuning/report/song sequencing. Prepared
synthetic presenters improve the default browser voice but do not establish
reviewed city accents or final performances. Missing files must preserve play.

Next driving review: preserve hand proportions; emphasize crests/dips; connect
canopies to large supporting tree sections; mild dirt/rumble shoulder drag; solid
obstacles crash while lightweight cones/mailboxes/cafe furniture scatter. Ramp
footprints must exclude vegetation across the merging pavement. Compare much
stronger near-field optical flow and roadside density independently of physics,
route miles and elapsed time. These requests remain pending implementation and
moving review rather than being implied complete by soundtrack work.
