# S2000 departure and reactive-traffic proof

Implemented on `work/next-driving-proof`, with durable specialist checkpoints on
`work/reactive-traffic`, `work/s2000-render` and `work/garage-radio`. Main is not
advanced by this proof. Review locally at `/?proof=1`; this is a 90-second sample,
not a complete city-to-city campaign stage or a production deployment.

## What to review

The painted keybox has one S2000 key set and empty hooks. Taking keys runs the
pickup, reveal, approach, door/cabin and chase-launch sequence. The simulation
clock stays zero during all departure shots. Repeat/skip and direct telemetry
start are supported. Driving launches at 110 arcade mph and auto-accelerates.

Signed turn/skid poses, eight cached traffic paint variants, stronger optical
flow, roadside reflectors, an auxiliary joining ribbon and an actual initial
right-lane worksite are implemented. The joining ribbon is scenic/NPC-only;
it does not establish connected ramp routing or playable forks.

Traffic has persistent profiles, following/passing decisions, close-pass flinches,
panic braking, observed-state braking propagation and bounded contact incidents.
A browser smoke driver using ordinary steer/brake inputs triggered eight reactions
by 65.1 simulated seconds without injecting vehicles. It did not cause a secondary
incident; contact/recovery scenarios are established by focused simulation tests.
The reproducible input-only driver is `tool/traffic_probe.js`.

Music uses three original oscillator arrangement families. The sequence cuts to
brief tuning noise, a condition-derived report and the next arrangement. A browser
check observed Forest music resume after a report. Actual listening quality and
regional accents are not established by a headless window: voices remain device
TTS fallback, with production regional voice packs still required. Optional
captions default off. The initial worksite report now derives from closed-lane
state rather than falsely describing unrestricted lanes.

The local stage-record foundation retains versioned immutable attempts and finds
a connected best journey across mixed cars. It is not wired to city-keybox UI or
cloud storage, and experimental records are not submitted to the old Top100 API.

## Measured rendering

Foreground Chromium, native DPR 1, CSS 1280x720, actual canvas720x405. WebGL
reported ANGLE/Vulkan SwiftShader. Seed731, S2000, arcade motion preset; 1.5-second
warmup followed by eight seconds without screenshots or screencast capture.
Build/tests were finished before measuring. Redundant agent preview windows
were closed. These are single host samples, not physical-phone or presented FPS.

| Measurement | Before furniture batching | After |
|---|---:|---:|
| Render calls/second | 34.90 | 48.31 |
| Median rAF interval | 33.3 ms | 16.7 ms |
| p95 interval | 33.4 ms | 33.4 ms |
| p99 interval | 33.5 ms | 33.4 ms |
| CPU recording across sample | 634.575 ms | 438.000 ms |

The same object placement/density, seed, physics, motion and pixel budget were
retained. Markers, cones and lamps were cached into the scenery atlas instead
of issuing per-object geometry and forcing atlas flushes. Net texture cost is
approximately3MiB. This recovered cadence but does not establish locked60fps.
The older, simpler Corvette sample's52.85calls/sec remains a historical baseline,
not an identical-scene comparison.

Raw counters: `research/second-proof-before-batching.json` and
`research/second-proof-final-metrics.json`; matching source/asset hashes accompany
them. `tool/proof_sample.js` reproduces the screenshot-free sample.

## Validation

- Final full Flutter suite:76passed; static analysis clean.
- Browser bootstrap/audio scripts:18passed.
- Worker unit tests:14passed; Wrangler package dry-run passed. No live deployment.
- OpenSpec strict validation:8items passed; format and whitespace checks clean.
- Browser: artwork ready without asset errors; departure clock/handoff; high-speed
  right steering; visible cone taper; actual traffic reactions; audio sequencing.
- Emulated mobile landscape844x390/nativeDPR3: actual794x367 backing pixels;
  simultaneous rim steering and outside braking, then release, verified. This is
  not a physical tilt, touch-latency, audio or sustained-memory acceptance test.

Artwork/source prompts and geometry are under `assets/proof-next/`. These are
sample paintings and atlases, with runtime mask/crop guards. Production authored
paint masks, complete car/body libraries, verified city geography, surface/grip
balancing, playable interchanges, remote staged saves and rankings remain ahead.
