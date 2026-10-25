# Cruising road feel — 2026-10-25

The user asked for more dramatic curves/hills, rewarding long gentle bends,
progressive keyboard steering and a wheel showing real steering plus cruise
corrections. This extends the [lane-following research](lane-following-assist.md)
and [Ranitas/Demon Attack source review](next-proof-source-review.md).

| Primary source | Applied here | Limits / not used |
| --- | --- | --- |
| [Cannonball rewrite: oferrari.cpp](https://github.com/djyt/cannonball/blob/master/src/main/engine/oferrari.cpp) | Separate road curve adjustment from intentional steering. Preserve road-relative offset by canceling only synthetic outward force on gentle bends. Reopened this iteration. | Independent rewrite, no source copied, no assertion that SEGA used our hysteresis or lane assist. Lane-center magnets and automatic traffic avoidance rejected because they undo player choices. |
| [Autodesk vehicle control properties](https://help.autodesk.com/cloudhelp/ENU/Stingray-Help/stingray_help/creating_gameplay/physics/vehicle_physics_properties.html) | Separate rise/fall rates and speed-dependent response. Reopened this iteration. | No PhysX dependency or real tire simulation. Our rates are playtest hypotheses, not documented optimal values. No additional key-event delay. |
| [Fiedler: Fix Your Timestep](https://www.gafferongames.com/post/fix_your_timestep/) | Keep smoothing/assist on the existing fixed60Hz simulation; test60/120Hz scheduling consistency. | Not a reason to change the renderer refresh or claim identical visual latency on every phone. |
| [Booth, Valve: AI Systems of Left4Dead](https://cdn.fastly.steamstatic.com/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf) | Pressure/release pacing: alternate strong signed bends and roller groups with gentle sweeps; keep existing traffic budget. Reopened primary PDF this iteration. | No survivor intensity estimator, adaptive Director or imported timing constants. This authored course is not adaptive difficulty. |
| [Sweetser/Wyeth: GameFlow](https://doi.org/10.1145/1077246.1077253) and [Ambinder: Valve playtesting](https://cdn.fastly.steamstatic.com/apps/valve/2009/GDC2009_ValvesApproachToPlaytesting.pdf) | Retain player control, visible feedback and readable challenge as review dimensions; automation tests force/control invariants. | Previously reviewed in source ledger; no quantitative racing difficulty formula. Human/phone evaluation remains open. |
| [Gordon: pseudo3D hills](https://codeincomplete.com/articles/javascript-racer-v3-hills/) | Extend existing shared continuous hill/curve profile with more rollers and signed bend peaks. | No renderer rewrite; no literal geographic survey claim. Existing grounded slope cues remain bounded. |
| [Juckett damped springs and other animation sources](next-proof-source-review.md) | Keep existing grounded car, camera and suspension damping. | Do not add another delayed filter to the wheel: it reports the applied simulation steering. No new asset generation. |

## Local tuning, not research constants

Curve load was curvature*55 capped at.4; most bends reached that ceiling. It is
now curvature*8 capped at.4. Enter assist at absolute raw curvature<=.018, leave
at>=.026, retain state between, blend over.2seconds. Convert canceled lateral
force into equivalent steering using speed, handling and grip. Add that value
to user steering for movement and displayed angle. No preferred X/lane is read.
Gentle input retains the same command authority as a straight. Strong bends
retain outward load after assistance fades.

Input rise is5.5 units/s at rest to4 at top speed (about250ms to full lock);
release7 units/s (about143ms from full lock). Response starts on the next fixed
step. Values apply only to the proof; legacy receipts retain direct steering.
Accepted analog/touch rise5.5 and release10 units/s remain unchanged.
Touch demand remains independent from wheel presentation so the displayed
correction cannot feed back into touch accumulation.

The first straight is shortened. Major signed bend peaks are roughly doubled,
with smooth interpolation and recovery stretches. Additional rollers cover
climb/descent, canopy, bridge and tunnel intervals without moving structures.
Tests cover offset preservation, manual input, strong-bend demand, deterministic
60/120Hz schedules, signed gradient/curve coverage and UI applied-angle binding.
Browser review is agent evidence; user feel and physical-phone comfort remain
open. No claim of universally balanced gameplay follows from these checks.

Moving review found that the velocity presentation compressed bend displacement
too far. A shared6x lateral coordinate scale now applies when integrating road
centers (both base and level adapters), while normalized curvature still drives
bounded arcade forces. The camera tangent, scenery, lane/traffic projection all
use the same resulting centers. This is a declared presentation-unit conversion,
not real vehicle curvature physics. A screen-space test requires a strong bend
to displace the road by over60 logical pixels at200 course units ahead under
velocity framing, beyond merely checking that curvature is nonzero.

## Local verification

148 Flutter tests pass, including hysteresis state retention, gentle offset
preservation, deliberate lane changes, strong-curve demand,60/120Hz agreement,
wheel binding and screen-space curvature. Format/analyzer and strict OpenSpec
validation pass; browser scripts32/32 and API14/14 pass. Worker check is a dry
run, not a deployment. Root browser inspection confirmed the painted garage
without a proof parameter and a291,600-pixel backing surface. Keyboard inspection
showed raw-1 progressing to applied/visual-.574 instead of snapping to full lock;
no asset error or console exception. Final curve-scale release built successfully and rendered at course690.65
with playerX-.025, bounded relative pitch-.064 and no asset error. Root was
reopened without a proof parameter after merging; ready state and291,600
backing pixels were verified. Main push was durably accepted by the upstream
GitHub relay. Physical-phone and user moving review remain open.
