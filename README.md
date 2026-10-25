# Cannonball

A landscape arcade road trip from New York's Red Ball Garage to The Portofino in
Redondo Beach. Flutter + Flame, web only, mobile first. Successful runs target
10–15 minutes. Routes, traffic and luck differ; better unlocked cars enable better
runs on one shared Top100.

## Current build

The first playable implementation includes a wooden key-box garage, six car slots,
projected road hills/curves, traffic, construction, route choices, gates, crash
recovery, secrets, weather, regional radio, original synthesized music and a US
route recap. The final car is a white 2019 Corvette Stingray Coupe, targa off.
Touch uses an oversized angular rim; tapping outside brakes, holding sustains it.
Left/Right or A/D steer, Down/Space brakes, P/Escape pauses. Optional browser tilt
has permission, calibration and touch fallback. Acceleration is automatic.

Google sign-in, durable account unlocks and global records are implemented in the
Worker; live registration/deployment remain unverified. The user selected
Arabiya's shared public Google client, with an exact Cannonball JavaScript origin
required. Guest progress stays local. Unavailable cloud services never block play
or claim that a local result was saved globally.

**The user rejected this first pass’s graphics and static/slow presentation.**
The renderer is being replanned around Super Off Road: The Baja’s lively motion
with a modern cartoon world. See the [renderer audit](docs/research/renderer-audit.md).
This is not production-complete. Artwork is original
procedural composition; exact road/interchange geometry and landmark sightlines
are not yet a verified atlas. Final sprite/region packs, authored story/cutscenes,
production sound-bank/voice library and real-phone tuning remain tracked in the
[implementation checklist](openspec/changes/playable-road-trip/tasks.md).

## Run and verify

Flutter **3.47.7**, Dart **3.13.5**, Flame **1.38.2**; Node **22+** for Worker tools.

```sh
flutter pub get
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web --release
openspec validate --all --strict
node --test web/platform_bridge.test.mjs
npm --prefix services/api ci
npm --prefix services/api test
npm --prefix services/api run test:runtime
```

The Flutter-only server serves a local game without the API. See the
[deployment guide](docs/deployment.md) and [API runbook](services/api/README.md)
for same-origin integration, Google setup, SQLite migration and storage recovery.
The intended production host is `https://cannonball.tlatoani.net`, with Pages assets
and a Worker on `/api/*`. No production deployment is claimed.

## Project memory

- [Specifications](openspec/specs/) and [active implementation](openspec/changes/playable-road-trip/)
- [Decisions](docs/design/decisions.md), [interview](docs/design/interview.md), [roadmap](plan/roadmap.md)
- [Engine](docs/research/engine.md), [motion/art](docs/research/motion-art.md), [flow/geography](docs/research/design.md)
- [Renderer audit](docs/research/renderer-audit.md) and [Dart/Wasm benchmark](docs/research/wasm-benchmark.md)
- [Browser platform](docs/platform.md), [authentication research](docs/research/auth.md)
- [Asset contract](assets/README.md)

PWA installation is optional; opening the URL is sufficient. Device sensors,
audio and landscape behavior require physical-browser checks. Production art
approval is based on moving gameplay samples, not screenshots alone.

## First visual proof (historical)

The initial one-minute seed-731 Corvette study established the painted renderer
baseline. Its [timing record](docs/research/visual-proof-metrics.json) and
[sample art prompts](assets/proof/PROMPTS.md) remain available. The current
`/?proof=1` route runs the second S2000 proof below. The regular garage route
still retains the earlier full-run prototype while staged progression is designed.

## Second proof (historical): S2000 departure and reactive traffic

The second proof introduced the painted wooden keybox. The current route runs the milestone below. Take the keys (or press Enter)
for the short garage departure, then drive the 90-second study. The fast-forward
icon skips departure. Controls remain rim drag/Left/Right steering, outside-rim
hold/Down/Space braking, and P/Escape pause. Sound starts muted; enable it for
original sample station music and browser speech. Captions are optional.

`?proof=1&motion=classic` and `motion=cruise` compare optical-flow presets against
the default `arcade`; the car physics remain identical. `quality=detail` raises
raster detail. New art and prompts live in [assets/proof-next](assets/proof-next/PROMPTS.md).

[Garage/audio](docs/garage-radio-proof.md), [renderer](docs/renderer-next-proof.md),
[Atrapa-inspired traffic](docs/research/atrapa-traffic.md), and
[stage-record foundation](docs/stage-progress.md) document the second proof.
The stage model is a local, tested foundation; city selection, remote stage saves,
regional voice packs, connected playable ramps and new rankings remain future work.

## Driving-and-camera milestone

Open `/?proof=1` for the current two-minute authored test course. Take the keys
or press Enter for the revised departure. Sound starts with that gesture; the
speaker button mutes it. Steering progresses through gentle/medium/firm poses.

- Arrows or rim drag steer; Down/Space/outside-rim hold brakes.
- C or the camera icon cycles baseline / wide / flow (flow starts selected).
- R restarts the selected section without replaying the garage.
- Keys1–8 jump to straight, S-bends, climb, descent, worksite, canopy, bridge, tunnel.
- `?proof=1&chapter=5` starts the worksite review; `camera=baseline` or `camera=wide`
  selects a camera comparison. All camera variants retain the same physics.

This is an illustrative test course, not the verified real-world campaign.
See [course/camera research](docs/research/course-camera.md),
[perceived speed evidence](docs/research/perceived-speed-milestone.md),
[departure continuity](docs/garage-continuity.md), and
[new art/prompts](assets/milestone/PROMPTS.md).

## Soundtrack listening draft

Open `/soundtrack.html` in the locally published build to audition three original
sectional scores and prepared neural radio presenters, and download multitrack
MIDI. The proof selects scores by station and keeps reports between songs.
[Composition sources and provenance](assets/audio/SCORE_NOTES.md) distinguish
these drafts from final regional performances. No voice service runs during play.

The current speed comparison defaults to `motion=turbo` (36 presentation units per
simulated metre); use `?proof=1&motion=arcade` for the previous20.4 setting. Stage
timing and car physics are unchanged. Joining-road scenery now clears the entire
pavement/gore footprint. Hill height/pitch are exaggerated for moving review.


## Afterburn traffic draft

`/?proof=1` now starts from rest with tapered acceleration and steering speed
losses. The default `motion=afterburn` more than doubles the previous draft's
scenery flow; `motion=turbo` retains that previous visual rate with the new
physics. Stronger hills, an early rise/dip and staggered reactive traffic are
ready for review. [Tuning notes](docs/afterburn-draft.md) explain the arcade
exaggeration and remaining validation. Keys1–8 still jump to course chapters.


## Low-horizon, radio and forgiving-contact draft

`/?proof=1` defaults to `motion=hyperspeed` and `camera=flow`, putting the flat
horizon two-thirds down the frame. C cycles the `.30`/`.48`/`2/3` camera comparisons;
`camera=wide` selects the middle view. Distant sprites fade into haze, new roadside
businesses appear sparingly, cones scatter, and NPC contact follows projected
bodies with corrective grace. Reports are now2–3 seconds with occasional station
surfing. [Review/evidence](docs/camera-radio-contact-review.md) and the
[spec-linked source register](docs/research/reference-register.md) record provenance
and limitations. Gentle-bend cruising assist is researched/spec'd, still pending
implementation; current curves retain prior steering demand.

## Rolling traffic and touch draft

The proof now defaults to the approved wide camera, denser traffic, irregular
rollers, speed-responsive chase framing and small sprung pitch/roll/heave cues.
The translucent wheel arcs span the screen height with generous touch bands and
neutral side guards. Center touches still brake deliberately.

V or the speed-effect utility toggles optional peripheral streaks/vignette;
`?proof=1&effects=on` enables them initially. Compare
`?proof=1&traffic=light&chase=stable&body=stable` for the earlier traffic density
and steady presentation. [Research, controls and limits](docs/research/rolling-chase-suspension.md).

## Steering-camera repair

The latest proof fixes the steering-dependent camera-heading regression on both
keyboard and touch. It keeps the approved wide framing and protected steering
arcs, now with original translucent leather/stitching artwork. V toggles stronger
optional peripheral trails and vignette; compare at driving speed. Root-cause,
input-check evidence and art provenance are in
[the repair notes](docs/camera-steering-repair.md).

## Fast, grounded and controllable proof

`/?proof=1` now opens the revised two-minute S2000 course, with more than ten
left/right curve reversals and a range of shallow/medium/steep climbs, descents,
crests and dips. The wheel fills outward from the accepted inner opening. Subtle
camera-relative slope cues retain the rear silhouette instead of snapping into
the old wheelie-like uphill cells. Ground-pivoted vegetation responds gently.

Default `motion=velocity` raises presentation flow from132 to168 while extending
the fixed180-segment mesh's far range to retain over320 course units of geometric
preview. Actual speed physics is unchanged; hills can still conceal the road.
Traffic admission has bounded build/overtake/release beats. Keys1–8 replay the
existing chapters, R restarts, C cycles camera, V toggles optional edge effects.

Compare `motion=hyperspeed`, `slope=legacy`, `touch=travel` (optional160 CSS-pixel
tangential steering comparison), or `foliage=still` independently. The default
touch behavior remains angular. [Research application ledger](docs/research/next-proof-source-review.md)
records adopted, deferred and excluded techniques; [proof review](docs/grounded-speed-proof.md)
records local evidence and limits. Physical-phone comfort and moving art approval
remain open.

## Six composed review levels

Open `/?proof=1` and use Q/W/E/R/T/Y (or the level-name popup) to select Hudson
daylight, Indiana golden canopy, Iowa prairie sunset, Ohio wooded night, Chicago
rain after dark, and Arizona desert dusk. These are illustrative pack compositions,
not verified real-world roads. Each has a distinct seed/terrain, conditions,
sky/ground palette, scenery selection and canopy/lamp eligibility.

Keys1–8 replay sections of the selected level; **Backspace** now restarts the
section because R selects Ohio. Arrow/touch steering and braking stay unchanged.
Direct links accept `level=indiana`, `level=ohio`, `level=chicago`, etc.

Night materials use local steering/NPC headlights and passing lamps. Running/brake
lights and scenic signals retain bright cores/halos and short source-only trails;
wet surfaces have selective reflection cues. Autumn adds warm foliage, conditional
rooted crowns, dapple and wet shoulder leaves. These are bounded2.5D effects, not
full PBR/volumetric optics. The [lighting/scenery research](docs/research/level-lighting-scenery.md)
and [review notes](docs/composed-levels-review.md) record sources, deferrals and
local verification. Real-phone comfort/performance and final art approval remain open.
