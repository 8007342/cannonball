# Gentle-road cruising without a lane-center magnet

## What the user means

Small changes in road direction should carry a cruising car along its current
road-relative lateral position. Meaningful bends should still ask for steering.
The car must not snap toward a lane center, aim at the nearest traffic gap, or
undo an intentional lane change. This is a heading/road-coordinate behavior,
not autonomous lane selection.

Our existing proof already represents `playerX` relative to the moving road. A
zero lateral velocity therefore follows road heading automatically. The unwanted
motion is the added outward curve-load term. In the current authored course,
`steeringLoadAt` multiplies raw curvature by55 and clamps to±.4. Even a nominal
.002 authored bend becomes.016 after the visual emphasis multiplier, and therefore
saturates at.4. The current control demand loses the distinction between small
and major bends before the player ever touches the wheel.

## Primary reference and limits

[Chris White's Cannonball rewrite, oferrari.cpp](https://github.com/djyt/cannonball/blob/master/src/main/engine/oferrari.cpp)
contains separate steering and `set_curve_adjust` routines. The latter derives a
lateral correction from the road geometry, applies integer quantization, and
scales by speed. This is direct implementation evidence for road-relative
curve-induced displacement with a small numerical deadband, not evidence that
all old arcade racers use modern lane keeping. It is an independent rewrite,
not an official SEGA source release; no code from it is copied into this project.
The source was examined at the current master version on2026-10-25, function names
rather than unstable line numbers identify the relevant routines.

[SEGA's official OutRun manual](https://www.sega.jp/mdmini2/en/assets/manual/pdf/EU_OutRun.pdf)
(page26, helpful hints) advises players about traction on tight corners and
inside-line cornering. This supports retaining active driving demand on stronger
bends; it does not specify an assistance threshold or prove automatic small-bend
tracking. [The rewrite author's control manual](https://github.com/djyt/cannonball/wiki/Cannonball-Manual)
documents digital steering adjustment as well as analog input, useful context
for testing both input forms. A control smoothing delay is not lane following.

## Proposed testable proof tuning

This document proposes, rather than claims to implement, the following:

- Evaluate absolute **raw** `ProofCourse.curvatureAt(courseDistance)` before
  `steeringLoadAt` clamps it. Enter gentle-road cruising at≤.018; leave it at≥.026.
  Hold the previous state between thresholds to prevent chatter at a boundary.
- While gentle-road cruising is active, cancel only the synthetic centrifugal
  displacement. Keep normal user steering, grip, acceleration, braking and all
  collision rules. Do not read or target lane-center coordinates.
- Blend cancellation over about.2s so an alternating authored threshold cannot
  kick the car laterally. This time and the curvature thresholds are tuning
  hypotheses, not constants prescribed by the original game or studies.
- Never change `playerX` to a preferred lane position. Preserve an off-center
  position on a long gentle bend with hands off. Intentional steering should
  move normally in either direction, including across lane boundaries.
- Meaningful bends beyond the upper threshold retain the outward drift/control
  demand and the progressive gentle/medium/hard car presentation. The assistance
  must not make the entire proof drive itself.

Acceptance tests should hold positions−.65,0,.65 and an in-between.24 through a
long gentle curve without drift; prove that both signs of deliberate input move
immediately; prove a strong curve produces outward movement without input; sweep
threshold values up/down to check hysteresis; and compare60Hz/120Hz scheduling.
A gentle curve plus a lane-change command should produce the same commanded
lateral displacement as a straight under the same speed/grip. All changes should
remain proof-only until user moving review, leaving legacy run receipts stable.

Implementation status: collision/cone work is implemented separately; this
lane-following behavior is a researched design proposal awaiting integration.

Implemented in the painted default prototype on2026-10-25; see [current tuning and evidence](cruising-road-feel.md). Earlier proposal/status above preserves discovery history. Human/physical-phone acceptance remains open.
