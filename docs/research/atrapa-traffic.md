# Atrapa-inspired reactive traffic proof

Inspected Atrapa main at commit `df3d4f3e16b2353013c4d625e8e3a7617b1b236e`
on 2026-10-25 through the connected GitHub reader:

- [README](https://github.com/8007342/atrapa/blob/df3d4f3e16b2353013c4d625e8e3a7617b1b236e/README.md)
- [Bounded baseline bot](https://github.com/8007342/atrapa/blob/df3d4f3e16b2353013c4d625e8e3a7617b1b236e/packages/atrapa_rules/lib/src/bot.dart)
- [Local observation encoder](https://github.com/8007342/atrapa/blob/df3d4f3e16b2353013c4d625e8e3a7617b1b236e/packages/atrapa_rules/lib/src/observation.dart)
- [Policy delivery contract](https://github.com/8007342/atrapa/blob/df3d4f3e16b2353013c4d625e8e3a7617b1b236e/docs/policy-bundle.md)

The actual baseline uses bounded local free-space reasoning, deterministic
seed/tick/actor tie breaking, and a pure simulation separate from presentation.
Its policy contract supports defensive loading of a compatible trained bundle,
but explicitly says this forge supplies no compatible trained game weights.
This proof adapts the **local observation, bounded decision and deterministic
fallback concepts**. It neither imports a trained JEV model nor copies Atrapa's
snake rules, policy runtime, weights or source code. A future learned traffic
policy would need its own observation/action schema and validation corpus.

## Implemented proof behavior

`RaceController.start(..., reactiveTraffic: true, launchSpeed: 110)` opts into
an original small traffic policy. Both options default off/zero; existing
production receipt rules and the deterministic legacy traffic path are retained.
The proof can therefore launch already moving without changing production car
specifications or server acceptance rules.

Each driver keeps a persistent ordinary, cautious, brisk or pushy profile.
The deterministic 20-slot mixture is 65/20/10/5 percent over a full cycle, with
seed-dependent starting point and shuffled order; this is a game tuning choice,
not measured US traffic demographics. Profile controls preferred headway,
straight/curve speed behavior and courtesy. Paint, body and profile are separate.
Pushy drivers can omit signals but move continuously and still check target gaps.

Following acceleration uses observed leader distance and relative speed. Passing
requires a slower leader, enough additional room, an adjacent lane safety check,
a signal/intent delay, continuous lateral movement and a cooldown. Construction
requests a merge and stops an obstructed driver before the restricted lane.
Decisions use pre-step observations rather than an iteration-order-dependent
instantaneous braking wave.

An approaching fast or laterally aggressive player can cause a short flinch away
from their car and, for a close intrusion or cautious driver, braking. The flinch
is damped, limited to 0.12 lane-normalized units, and cannot cross a lane boundary.
A 4.5-second reaction cooldown prevents per-frame panic retriggers. Following
cars react to the resulting speed and gaps. Actual NPC contact with a sufficient
closing speed can trigger a short secondary incident and braking; no wreck is
randomly teleported into an empty lane. Incidents have a ten-second cooldown and
finite recovery rather than creating permanent freeway blockades.

Renderer contract:

- `TrafficCar.x` already includes the flinch: do not add it a second time.
- `currentSpeed`, `braking`, `reactionOffset`, `reactionIntensity`,
  `incidentSeconds`, `profile`, `paintVariant`, and existing signal/target fields
  describe presentation state.
- `trafficReactionCount` and `trafficIncidentCount` are cumulative per attempt.

The traffic policy uses arcade coordinate units and is not a calibrated IDM/MOBIL
implementation. Ramps, NPC route intent, actual lane topology, surface traction,
full crash animations and real-device difficulty review remain separate work.
A favorable or difficult seed remains part of the intended experience.

## Validation

Six focused Flutter tests cover smooth bounded close-pass reactions and cooldown,
following brakes, braking propagation, secondary contact/recovery bounds, passing
intent/signal delay, and matching 30/120 Hz fixed-step schedules with opt-in reset.
Five pure-Dart policy scenarios were also exercised directly in the sibling
worktree because the forge Flutter wrapper only mounts the primary checkout.
The pure traffic file passes local Dart analysis. Integrated Flutter validation
is run from the primary checkout after merging this work branch; it is not
inferred from the pure-Dart smoke checks.

The short reactive proof additionally authors a right-lane construction taper on
its initial NY corridor at the existing 48–59% road interval. It uses actual
controller closure flags, collision boundaries, radio advice and NPC merge/stop
logic. Traffic is not spawned inside that restricted lane. Legacy runs keep
their original seeded closure decisions unchanged.
