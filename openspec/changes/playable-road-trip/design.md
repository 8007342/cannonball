# Design

## Context
The code has an empty Flame canvas and a health-only Worker. Specs and research define a larger game; the user now explicitly requests Astra-led implementation. See proposal.md. No production Google or Cloudflare configuration has been verified.

## Goals / Non-Goals
Goals: an integrated playable browser implementation of the run lifecycle, testable simulation, durable API, browser controls/audio and clear production-readiness evidence.
Non-goals: native applications, equalized competition, claiming an initial procedural rendering pass is the final approved asset library, or claiming desktop tests establish phone comfort.

## Decisions
- Astra engine owns lib/game: fixed-step model, route graph and pure receipt, with Flame road projection and procedural pixel-style sprite composition. UI observes controller state at a bounded rate. Physical simulation is distinct from drawing and real route miles from compressed driving coordinates.
- Root owns Flutter garage/HUD/angular wheel/initials/map/profile integration. Default wheel returns to center; every active pointer is tracked by ID. Tap outside rim briefly brakes, hold sustains it. Utility overlays capture their own pointers. Keyboard and tilt normalize to the same steering intent.
- Astra platform owns browser interop, gesture-gated sensors, no-event fallback, landscape orientation mapping, lifecycle callbacks, synthesized original music/engine sound and nonblocking speech. Captions are authoritative when speech/audio fail.
- Astra backend owns same-origin GIS nonce login and SQLite Durable Object accounts/sessions/records. Reuse the public Arabiya client ID; exact Cannonball origin must be registered. Never share cookies across sibling hosts.
- Anonymous runs remain local. Signed-in starts get server tickets; finished receipt validation and idempotent ranking precede initials entry. One canonical Top100 deliberately mixes unequal cars, routes and luck. All cloud failures remain separate from local play.
- Six initial car slots end in the white 2019 Stingray, targa off. Starter and intermediate fictional designs are working choices subject to review; original procedural visuals enable animation/handling feedback without commissioning unreviewed bulk assets.
- Candidate real-road corridor graph uses approximate geographic nodes and documented road names. Exact production intersection geometry, landmark sightlines and complete regional asset packs require source review; do not call the initial graph a verified map atlas.

## Risks / Trade-offs
- Browser tilt/audio variation → feature detection, user gestures, immediate fallback and real-device checklist.
- Asset and route depth exceeds first integration → retain explicit content acceptance tasks and report actual implementation maturity; do not erase requirements.
- Browser-reported scores can be forged → server tickets, timing bounds, known route/car validation, duplicate protection; replay verification remains a cost/rigor decision.
- Google setup ambiguity → exact-origin confirmation and actionable sign-in errors; no blocked driving.
- Motion comfort cannot be automated → steady horizon option and uncompleted physical-device acceptance checklist.

## Migration Plan
Run local checks, publish a local review build, then use the prepared Pages/Worker configuration when live credentials/resources are available. SQLite migration creates new Cannonball-only objects. Roll back code by redeploying the prior version without deleting progress storage.
