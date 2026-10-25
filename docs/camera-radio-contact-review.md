# Low horizon, brief radio and contact review

## Delivered experiment

The proof defaults to `motion=hyperspeed` (132 presentation units,57% above the
previous84), with `camera=flow` placing the flat horizon two-thirds down the
frame. `camera=wide`(.48) and `camera=baseline`(.30) are comparisons. Camera height
changes jointly to preserve car contact at.876, and terrain grade retains its
sign. These are authored experiments, not a reconstructed OutRun camera.

World-fixed references and near posts carry peripheral speed. Far sprites fade
through a quantized depth band and horizon haze; alternate far foliage has its
own fade before LOD removal. The wider depth preview preserves traffic warning
time. Rare fuel/burger/motel/diner sprites provide pictorial landmarks at fixed
stops outside ramp footprints. This is one review sheet, not nationwide content.

All14 prepared radio lines are now1.99–3.10 seconds. Some actual station changes
insert a680ms alternate-song fragment between short noise bursts and the report.
Cold snippets skip immediately. Approved full songs/MIDI remain unchanged.
Prepared voice provenance and encoded measurements are in `assets/audio/`.

Invisible proof lane-volume crashes were removed. Contact dimensions now follow
presentation scale, swept overlap covers fast motion, and up to50ms corrective grace permits grazes. At high closing speed the grace
is capped by the time to traverse one contact half-depth, preventing late crashes
after bodies have visibly separated. Cones share simulation/render identities, launch once,
expire after1.2s and cannot act as later ghost obstacles. Flight forward motion
keeps the initial airborne beat beside the car so it can actually be seen.

Gentle-bend cruising has been researched and specified as canceling artificial
outward drift while preserving lane offset and deliberate input. It is **not
implemented in this draft**; its dedicated acceptance task remains open. Research
and thresholds are in [the lane-following proposal](research/lane-following-assist.md).

## Local observations

The published Chromium proof loaded the new art without errors. The lower camera
was inspected during climb/descent and tunnel approaches. A controlled construction
pass held the cone line and recorded49 distinct cone impacts in8.03s with0 crashes.
This is a targeted simulation/render check, not a human fairness or comfort study.
The browser exercised the surf variant on a region change, played a prepared short
report, resumed the selected score, and returned playback to idle on pause.

Spec reference traceability links through [the full register](research/reference-register.md).
GameFlow is credited to Sweetser/Wyeth; Valve's Director/playtesting/art references
and SDT motivation research are separate. Every timing, camera and collision
margin remains a reviewable project inference. Desktop evidence does not close
physical-phone or production-content acceptance.

## Verification summary

111 Flutter tests,32 browser/bootstrap/audio tests,14 Worker tests, analyzer,
release web build, Worker dry-run packaging and8 strict spec checks passed locally.
High-relative-speed regression cases cover155mph against0/5/30mph NPCs from three
starting phases, requiring a crash before separated bodies rather than afterward.
No live deployment or physical-device validation is implied.

A180-frame uncaptured worksite sample recorded16.8ms p95/33.4ms p99 rAF intervals,
720×405 backing at CSS1280×720, and about1.07ms mean CPU command recording. This
SwiftShader desktop sample is scheduling evidence, not presented-frame FPS or a
controlled before/after benchmark. [Raw metadata](research/camera-contact-metrics.json)
retains the scope and simulation/wall-time discrepancy instead of claiming an
exact speed equivalence from a short snapshot window.
