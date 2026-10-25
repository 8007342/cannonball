# Afterburn speed/traffic draft

User requested another substantial increase after approving the music, voices and
first speed improvement. The proof defaults to `motion=afterburn`:84 presentation
units per simulated distance unit, versus36 for `motion=turbo` and20.4 for
`motion=arcade`. This is a2.33× visual increase over the immediately previous draft.
The movement remains delta-time based. No machine-speed-dependent stepping,
artificially boosted leaderboard mph or displaced collision sprites is used.

A180-segment road ribbon extends the preview distance for traffic and terrain.
The main climb reaches7000 presentation units, versus2200 previously; an early
800-unit rise/dip introduces vertical variation before the main climb. Pitch is
bounded at±.24. These are arcade exaggerations and need motion-comfort review.
Earlier perception sources and their applicability limits are recorded in
[the speed research follow-up](research/speed-and-score-followup.md).

The initial departure starts at0mph instead of the former110mph jump. Chapter
shortcuts start at95mph to make repeated section review practical. Available
acceleration tapers with speed; smooth flat driving can approach155mph, but hard
steering, repeated corrections and uphill load reduce speed. Small steady input
(up to.15) has no steering-scrub penalty. These are tuning choices, not a measured
S2000 engine/gearing/aerodynamics model. Legacy races keep their existing physics.

Reactive proof traffic is seeded as four staggered cars and replenished ahead of
the camera, with a65-unit minimum longitudinal separation and closure checks.
Previously spawns started520–1040 units away: at high presentation scales the
entire visible ribbon could contain no cars. The dedicated proof stream starts
95–375 units ahead, with later entries300–325 ahead. The first lead vehicle cruises at55mph so it stays visible during launch.
Drivers retain following,
passing, flinch, braking and bounded incident behavior. Flow comparison settings
share simulation positions and collision coordinates. No full-width spawn wall is
created. NPC speed differences can produce bunches and must be human-playtested.

Use arrows or rim drag, Down/Space to brake, keys1–8 for chapters, R to restart.
The prior optical settings remain query comparisons, but now share the new proof
acceleration/traffic. This is not a frozen old-build comparison. Pending hand,
canopy supports and soft-prop impact work remains separate.
