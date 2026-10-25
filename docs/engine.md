# Playable engine

`lib/game/race.dart` exports the Flutter-observable `RaceController`, Flame
`RaceGame`, vehicle definitions, immutable run receipt, and `routeGraph`.
Simulation, route data, drawing, browser inputs/audio and persistence are separate.

The simulation advances at 60 fixed steps per second. UI notifications are capped
at 20 Hz. A delayed frame contributes at most 250 ms; explicit pause freezes race
and countdown clocks. Displayed speed is in arcade mph. Compressed road movement
is `mph × 0.52` units/second; 18 simulated units represent one approximate route
mile. The odometer records corridor miles, not the literal distance a real car
would travel at that speed in the elapsed time.

Cars auto-accelerate. Steering and braking remain independent. Curves, road-edge
slowdown, traffic contact and construction affect driving. Traffic announces lane
changes before moving and checks both vehicle and player gaps. A bounded director
varies spawn intervals and gives a recovery interval after crashes. A flip takes
2.1 seconds; a spin takes 1.25. The timer continues through both. Recovery clears
nearby traffic, restores the car to the open center corridor and provides three
seconds of visible protection. Every 155 route miles adds 45 countdown seconds;
the total elapsed time never decreases.

The initial graph has 24 directed corridor edges and 19 approximate geographic
nodes, including northern and southern alternatives. A seeded closure can disable
one branch; every junction retains a route to the destination. Conditions are
fictional, seeded game conditions rather than live road or weather reports.
Warnings and signs reveal branches before commitment. Steering left or right at
the end of the current corridor selects the corresponding open branch. Centered
steering takes the first open branch. The selected edge sequence, including a
partial final edge on failure, is frozen in the run receipt.

Four secret detours unlock four intermediate cars when traversed completely. The
white 2019 Corvette Stingray Coupe unlocks after all other keys are owned and a
run finishes. Its renderer uses an open dark cabin, two exposed seats and no
opaque targa panel. Starter/intermediate designs are original working designs.
The initial procedural car drawings provide steering, skid, impact/flip, brake
lights and recovery presentation; they are not finished production sprite sheets.

The replacement renderer uses original generated cartoon atlases and a painted
panoramic backdrop. `lib/game/render/proof_art.dart` loads images once and creates
cached asphalt, ground, cloud, shadow and stone-bridge textures. Four reused
triangle buffers draw ground, shoulder, textured asphalt and geometric lane
markings; lane lines are separate from the texture to avoid affine UV distortion.
Depth-sorted billboard batches share a crest-occlusion model for scenery, traffic,
the player and a scenic bridge. Moving clouds, foreground vegetation, distance-
driven tire highlights, suspension bob and six car poses supply motion. Per-pose
anchors compensate for the generated sheet's uneven cell framing.

The first replacement pack is a **single-car visual proof**, not the finished
six-car garage/region library. The scenery proof traverses city-edge, forest and
high-country composition within roughly a minute. Road coordinates are mapped
into presentation coordinates at 12 times simulation distance; this changes
optical flow without changing receipt miles or race timing. Rendering interpolates
between fixed simulation boundaries. The bridge is a scenic span, not a navigable
multi-level interchange, and full authored branch-junction geometry remains ahead.

`RaceGame(controller: ..., proofMode: true)` exposes render/update counts and
cumulative/last/max CPU submission durations. These counters do not measure GPU
completion or display presentation. The proof's browser bootstrap separately caps
actual backing pixels; Canvas coordinate scaling itself does not do that. See
`docs/proof-platform.md` for the whole-view cap and its HUD tradeoff, and
`docs/proof-assets-validation.md` for decoding and atlas evidence. Asset failures
are exposed rather than silently replaced with primitive artwork.

## Evidence and remaining review

`test/renderer_test.dart` adds presentation-reset, zero-delta telemetry, safe
early disposal and pose-anchor checks. `test/game_test.dart` contains 11 tests covering graph reachability, deterministic
30/120 Hz frame schedules, auto-acceleration/braking/pause, bounded notifications,
gate accounting, safe flip recovery, partial failure receipts, seeded closures,
full trips, secret/final unlocks and steady-horizon behavior. A reactive test
driver uses ordinary steering and brake inputs, retains traffic and collision
penalties, and checks successful 10–15 minute simulated runs. The recorded
starter run for seed 731 completed 2,995 corridor miles in **13:20.700**, with
three crashes and 19 gates. Its exact receipt is retained in
`services/api/test/fixtures/engine-completed.json`; the independent Worker
validation and SQLite finish/rank pipeline accept it.

These are deterministic simulation and integration checks, not evidence of
physical-device handling comfort or a human-completed run. Browser smoke tests
confirm the initial canvas renders; final camera, frame-time budgets, sustained
memory, physical phone controls/audio, animation comfort and 10–15 minute human
playtests remain acceptance work.

Corridor road names, node coordinates and approximate lengths are authored from
the research candidates in `docs/research/design.md` (2026-10-25). Departure and
arrival connectors, real junction geometries, exact distances, elevation samples,
landmark sightlines and per-location ecology still need official-source review.
The graph must not be presented as a verified turn-by-turn route atlas. Production
regional packs, car pose sheets, desktop/mobile asset tiers and a reviewed sample
pack/provenance manifest remain distinct from this original procedural preview.
