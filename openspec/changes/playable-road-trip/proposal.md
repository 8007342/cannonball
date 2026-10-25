# Proposal

## Why
Cannonball currently starts on a placeholder screen. The user has approved motion/art research and requested an Astra implementation team to turn the documented arcade road trip into an end-to-end playable web game.

## What Changes
- Implement continuous pseudo-3D driving, angular rim steering, tilt fallback, braking, timed gates, traffic, crashes and route choices.
- Add a wooden key-box garage, progression through six initial cars, and a final white 2019 Corvette Stingray Coupe with its targa panel removed.
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
- `art`: approved motion direction and final Corvette unlock.

## Impact
Flutter game/UI modules, browser sensor/audio/GIS bridge, Worker API and SQLite Durable Object, deployment configuration and validation. Native apps remain excluded. Tests must verify clock/gate/branch logic, UI state transitions and API acceptance failures. Real phone comfort/performance and live Google/Cloudflare setup remain separate observable checks, never inferred from a dry-run. Initial authored visuals and real-road corridor data must be labeled honestly until production asset and exact-junction review is complete.
