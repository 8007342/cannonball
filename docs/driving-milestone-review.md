# Driving-and-camera milestone review

Local route: `/?proof=1`, two-minute study. Integration branch:
`work/road-feel-milestone`; specialist branches `work/course-camera`,
`work/departure-continuity`, `work/viewport-speed-research`. Source/art checkpoints
were pushed throughout. Game implementation stays on work branches; main received only the workflow-removal/local-build-policy correction. No production deployment was made.

## Implemented

- Authored illustrative straight, S-bends, climb/bend, crest/descent, worksite,
  canopy, bridge and tunnel. This is not a geographically verified campaign.
- Fixed world-anchored cone positions; painted cones, reflector posts, lamps,
  canopies and tunnel portals cached with scenery. Building footprints use curb
  clearances; overhead art is separate. Tunnel arches replace outdoor vegetation.
- Grade-driven horizon pitch with a stable player-ground screen anchor, stronger
  authored bends, depth haze and localized tunnel exposure.
- Camera baseline/wide/flow comparisons preserve car physics and seed. Only flow
  adds the near-road references. Camera comparison is separate from optical-flow
  multipliers and does not establish subjective speed by itself.
- Immediate-but-ramped proof steering, gentle/medium/firm signed turn sheets,
  faster release and neutral-crossing reversal. Gentle held input remains gentle;
  skid presentation requires sustained high demand. The approximately80–140ms
  gentle-phase target and .18s effective full-input ramp are playtest hypotheses,
  not universal racing-study prescriptions or measured device latency.
- Revised reach/grasp/withdraw, coordinated garage pan, true-wide cabin crop,
  rear match and starter/rev audio prelap. Sound begins through the key gesture;
  mute, skip, reduced motion and hidden-tab cancellation remain supported.
- Live viewport diagnostics distinguish layout, visual viewport, CSS surface and
  backing resolution. No speculative canvas resize patch was applied.

## Verification

The integrated full Flutter suite passed95tests, plus23browser-script tests and
14Worker tests. Static analysis and package dry-run passed. The final geometry,
fog and UI changes received focused regression checks and a release build.
A pixel test verifies haze cannot reveal transparent sprite rectangles.

Moving browser inspection covered painted curves/hills, repeated tunnel arches,
cone worksite and steering. Digital full input progressed through lower effective
and visual steering rather than jumping straight to1. Held .2 input settled at
.2 in all three input/effective/visual signals. Emulated touch produced
steering .224 with braking true concurrently, then both released.

A live landscape resize to844x390/nativeDPR3 produced a logical844x390 scene and
794x367 backing surface with full CSS coverage. Earlier genuine1280x720→1920x1080
live resizing also passed without reload. Maximizing an external preview viewer
is not proof its emulated browser viewport changed. Physical phone tilt, latency,
audio quality and sustained memory remain unverified.

## Scheduling samples

One foreground Chromium window, CSS1280x720/nativeDPR1, actual720x405 backing
surface. Other owned previews were closed. Samples use1second warmup plus4seconds
without screenshots or screencast capture. Compiler/tests were not running during
these samples. The host browser uses software graphics; these are render calls
and rAF intervals, not presented-frame FPS or physical-phone performance.

| Camera / section | Render calls/s | Median interval | p95 interval |
|---|---:|---:|---:|
| Baseline / straight | 59.84 | 16.7ms | 16.8ms |
| Wide / straight | 59.82 | 16.7ms | 16.7ms |
| Flow / straight | 59.80 | 16.7ms | 16.7ms |
| Flow / worksite | 59.83 | 16.7ms | 16.7ms |
| Flow / tunnel | 56.26 | 16.7ms | 33.3ms |

The straight comparisons use the same seed, car and start section, with simulation
keeping pace with wall time. Worksite/tunnel samples are separate section checks,
not an identical-scene before/after comparison. Raw records are in
`research/driving-milestone-metrics.json`; source hashes accompany the review.

## Remaining acceptance

This milestone improves a review proof. It does not establish final handling,
subjective speed, complete driver/crash animation, verified real geography,
production regional voices, remote staged saves or rankings. All eight broader
production tasks from the previous change remain open. Test camera/steering feel
on real phones before bulk asset production. Art/prompts: `assets/milestone/`.

Final departure review corrected a detached wrist by keeping hand/key scale modest
and extending only the painted distal forearm offscreen. The hanging key and
fingers share the actual cover-transformed hook anchor. Departure panels preload
before their first shot. Final source hashes are in driving-milestone-final.sha256;
the earlier measurement hashes are retained. The forearm-only correction does not
change the driving renderer used for the timing samples.

GitHub builds were explicitly removed from all nine published branches after the
user clarified local-only validation. See github-build-audit.md. Local checks
continue; no workflow was restored by the final integration.
