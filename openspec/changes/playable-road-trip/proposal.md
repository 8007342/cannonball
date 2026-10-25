# Proposal

## Why
Cannonball now has first-pass simulation, UI and persistence. The user rejected its rectangular graphics and static/slow presentation, identifying Super Off Road: The Baja as the motion and cartoon-world reference. The implementation must replace that renderer and prove visual quality and frame pacing, rather than treating passing logic tests as game readiness.

## What Changes
- Implement continuous pseudo-3D driving, angular rim steering, tilt fallback, braking, timed gates, traffic, crashes and route choices.
- Add a wooden key-box garage, progression through six initial cars, and a final white 2019 Corvette Stingray Coupe with its targa panel removed.
- Replace primitive scenery/car drawing with textured terrain, authored animated cartoon sprites, layered parallax, depth-correct scenery and an actual render-resolution budget.
- Prove the look, optical flow and measured frame pacing in a short moving city/vegetation/bridge scene before expanding content.
- Add region scenery/weather, original synthesized adaptive music and captioned radio speech.
- Add Google identity using the shared Arabiya client with explicit Cannonball origin registration, durable saves and the global unequal-run Top100.
- Add three-letter entry before a qualifying run's route-map recap; record actual time, distance and car.
- Package for Pages and Worker deployment with tests and an explicit browser/device validation ledger.

## Capabilities

### New Capabilities
None. Implement the existing capabilities rather than duplicating them.

### Modified Capabilities
- `controls`: resolve angular direction and outside-wheel braking.
- `progress`: shared Google client, concrete browser-first save and run lifecycle.
- `racing`: city-to-city timing and reactive traffic.
- `world`: heterogeneous local traffic and consistent road conditions.
- `audio`: hard-cut station breaks and honest speech fallback.
- `art`: approved research, rejected primitive preview, Baja-inspired animated cartoon presentation, measured rendering proof and final Corvette unlock.

## Approved next proof
The first moving proof is provisionally accepted as a technology test. The next proof adds an S2000 starter/departure, palette-varied reactive traffic, stronger optical flow, condition-driven radio/music and a local stage-record foundation. Successful campaign stages now target 10–15 minutes; the short proof compresses that experience for review. Rankings remain undecided, preserving the legacy board without new claims.

## Approved driving-and-camera milestone
The user approved a researched test-course milestone after reviewing the second proof: visibly authored curves and hills, fixed world-anchored cones, sprite road furniture, intentional scenery clearance/occlusion, stronger perceived speed, aspect-correct garage camera continuity and live resize verification. Progressive gentle-to-hard steering presentation is now required for keyboard/touch inputs. Geometry/sound experiments must preserve comparable physics and record measurement limits.

## Impact
Flutter game/UI modules, browser sensor/audio/GIS bridge, Worker API and SQLite Durable Object, deployment configuration and validation. Native apps remain excluded. Tests must verify clock/gate/branch logic, UI state transitions and API acceptance failures. Real phone comfort/performance and live Google/Cloudflare setup remain separate observable checks, never inferred from a dry-run. Initial authored visuals and real-road corridor data must be labeled honestly until production asset and exact-junction review is complete.
