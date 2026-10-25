# Design decision register

## Confirmed

- Cannonball; arcade speed; NY Red Ball Garage → Portofino in Redondo Beach.
- Successful run target: **10–15 minutes**.
- Flutter + Flame + OpenSpec; **web only**, mobile first, desktop with higher
  resolution asset packs. URL access sufficient; PWA optional. No native apps.
- Current-day real road network, cities, interchanges and landmarks; compressed
  gameplay with dated geographic sources. A live weather/traffic service is not implied.
- Pixelated art with diffused edges and mixed styling; animation flow and speed
  must be evaluated in motion before bulk generation.
- Landscape, auto acceleration, braking, optional tilt and oversized transparent
  center wheel with cropped translucent rim. Angular wheel gesture confirmed.
- Right rim up / left rim down = steer left; right rim down / left rim up =
  steer right. Outside-wheel taps brake; holds sustain braking. Auto accelerate otherwise.
- Mostly flat horizon with subtle lean, somewhat stronger with motion steering.
- Multiple stages/gates, different route distances and complexity, construction
  warnings, lane closures, traffic merges and secret-backroad car unlocks.
- Continuous driving with minimal loading until the run ends; regional scenery,
  radio, music, weather, hints and transitions sustain the journey.
- One global Top100 by actual total time: car advantages, route distance, traffic
  and luck are deliberate. Better unlocked cars yield better future attempts.
- Qualifying finish: initials screen first, save time/distance/car, then US-map
  road-graph recap with animated fill of the actual path. Other endings go to recap.
- Google remote saves and the shared Arabiya Google web client (exact Cannonball origin still unverified).
  Cannonball and Arabiya are sibling hosts, each with its own application session.
- Garage wooden box, starter keys with shabby keychain, car sheets, storyboards,
  cutscenes and contextual hints remain core scope.

## Proposed

- Projected road strips and billboard sprites with explicit elevation/occlusion.
- Same-origin API Worker + Pages; SQLite Durable Objects for durable records.
- Fixed-step simulation, separate random streams and bounded pacing director.
- Damped camera lean with a zero-roll comfort setting; tune using browser devices.
- Real-world route miles recorded separately from compressed game coordinates.

## Open

See interview.md. Next: return-to-center tuning,
distance representation, starting car and story, failure recap, minimum devices,
guest/save policy and pause behavior. Do not reopen equalized competition or
native release scope as if they were undecided.

## Implementation authorization — 2026-10-25

The user approved motion/art research and requested an Astra fleet. Three Astra
specialists own engine, backend and browser platform; root owns UI/integration.
Final unlock: white 2019 Corvette Stingray Coupe, targa roof removed. Production
asset approval and physical-device validation remain actual acceptance work.

## Visual rejection and updated reference — 2026-10-25

The user rejected the rectangle-based preview and reported approximately2fps and
a static feel. The target is a modern animated-cartoon interpretation of Super
Off Road: The Baja, with cities, vegetation, clouds, parallax mountains/buildings
and bridges. Research approval does not approve the current graphics. Reopen
renderer acceptance; use a moving, measured scene before more content expansion.
See ../research/renderer-audit.md for measured versus calculated findings.

The user explicitly confirms https://cannonball.tlatoani.net is registered on the
shared Google client. Origin setup is no longer an unanswered user question;
actual live login remains an integration check.

## Wasm experiment — 2026-10-25

Dart already compiles to Wasm, so no language rewrite is required to evaluate it.
An isolated same-seed release comparison verified real Wasm execution. On the
headless software renderer, command-recording CPU cost improved while overall
cadence did not; DPR mattered strongly. Keep both pipelines available for the
new scene; do not change the shipping default based on this narrow experiment.
See ../research/wasm-benchmark.md for evidence and limitations.

## Moving proof review — 2026-10-25

The user considers the one-minute cartoon proof a successful-ish technology test:
arrow steering works and animation feels smooth. This is not approval of final
balance or asset packs. Forward motion still feels extremely slow, independently
of frame cadence. High-speed steering appears to use the same left-facing sprite
in either direction. Source inspection finds that both steering signs select the
same skid frame above 100 mph and steering magnitude .87; this is the likely
cause, pending a corrected moving comparison.

New content direction: design palette-remappable car paint so shared vehicle
sheets can supply varied traffic. Keep glass, tires, lights, cabin and shading
independent of paint. Regional news should use local accents. Add cute local
incidental details throughout development. These directions still need sample
and runtime design; they are not implemented capabilities.

Proposed next slice: a continuous 90-second playable departure corridor, with a
short repeatable speed/handling test first. Compare optical-flow/camera settings
without changing route time or distance rules; correct directional skid poses;
then review one palette-remappable traffic family and a small regional radio/
roadside-detail sample before expanding production content. Exact route, starter
car and radio personality remain interview choices rather than approved defaults.
