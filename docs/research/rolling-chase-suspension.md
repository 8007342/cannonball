# Rolling terrain, traffic and sprung chase cues

## Primary references and interpretation

[Holm, Skovhus and Kraus2017](https://eudl.eu/doi/10.1007/978-3-319-55834-9_14)
study geometric field of view, blur and camera altitude in third-person racing.
The paper reports that motion blur can decrease perceived velocity in its setup;
therefore blanket blur is not assumed to improve Cannonball. The publisher
abstract was retrieved; direct PDF retrieval timed out in this pass. Earlier
paper interpretation is recorded in perceived-speed-milestone.md. No universal
camera height or effect intensity is inferred from the study.

[Unity's Position Composer documentation](https://docs.unity3d.com/Packages/com.unity.cinemachine@3.1/manual/CinemachinePositionComposer.html)
separates desired screen position, damping and lookahead, and notes that noisy
lookahead can amplify jitter. This supports separating our composition response
from input and physics. Cannonball implements its own small damped response;
Unity is a reference architecture, not a dependency or proof of ideal constants.

[NVIDIA's PhysX vehicle documentation](https://nvidia-omniverse.github.io/PhysX/physx/5.6.1/docs/Vehicles.html)
explains sprung masses, suspension spring response and damping. Our inference is
to use a bounded spring response to make changes in load settle rather than
step. This draft does not simulate four contact patches, actual sprung/unsprung
mass or a calibrated S2000 suspension. Full vehicle dynamics are not required to
review tiny visual cues. Existing sprite art includes wheels, so these are subtle
whole-sprite tilt/squash/heave proxies; independent body/wheel rigging remains a
possible asset improvement after moving review.

## Concrete draft

Wide framing(.48 horizon) is now default. Chase ground starts at.925 of frame,
moves toward.848 with speed, and settles lower on braking/recovery. Small damped
lateral look follows steering. Camera height shifts the entire projected road,
traffic and car together. `chase=stable` and reduced-motion use the previous.876
fixed ground composition; no player steering or collision geometry is delayed.

Body cues add bounded roll(up to.03rad), rear-view pitch proxy(up to.025 scale),
and2.5px heave. Acceleration/braking drive pitch, steering drives roll, grade
changes drive settling, and cone strikes supply a small pulse. The contact shadow
stays grounded. Substeps at120Hz bound spring integration. `body=stable` or
reduced-motion disables this animation. Replacing the prior distance-frequency
bounce avoids high-speed vibration becoming an unintended strobing pattern.

Eight different smooth compact rise/dip pairs overlay the existing course. Heights
and periods vary, and construction/props share exactly the same surface. Bridge
and tunnel modules retain their existing elevation design. This is authored
arcade exaggeration, not real US freeway survey data.

Dense proof traffic starts with10 staggered vehicles rather than4, caps at24,
and replenishes more often just beyond the camera preview. Same-lane headway and
longitudinal pair limits prevent three-wide spawn walls. `traffic=light` retains
the previous stream. This changes the proof's challenge, not legacy run rules.

Optional `effects=on` adds weak peripheral streaks and a tunnel-like edge vignette;
V or the speed-effect utility toggles it. It defaults off and reduced motion
suppresses it. The central road stays sharp. This first comparison uses simple
paint operations; true peripheral image blur needs separate measured review.

## Review

Compare `/?proof=1`, `?proof=1&traffic=light&chase=stable&body=stable`, and
`?proof=1&effects=on`. Check approaching crests, brake/reaccelerate, change lanes,
clip cones, and inspect traffic escape gaps. Automated tests cover response
consistency, settling, terrain continuity and deterministic initial spacing.
Human challenge, readability, comfort and actual mobile costs remain acceptance
work. GameFlow/Valve pacing guidance continues to separate speed cues from
required-decision density; increasing traffic is an experiment, not a reason to
fill every second with unavoidable lane changes.

## Touch-control correction

The previous radius exceeded half the screen width, hiding the rim at mid-height.
The new radius places the middle of each visible side arc55–65 CSS pixels inside
the edge in typical landscape sizes. The painted silhouette is40–52 pixels wide,
with low-alpha shading. Steering accepts a64–68px radial half-band, considerably
beyond the paint. A32px neutral buffer and protected outer margins prevent edge
misses from braking. Neutral gestures can slide onto steering with a fresh angle
baseline; they never become brakes mid-drag. Deliberate center touches retain
independent tap/hold braking. Tilt-hidden input keeps its prior touch-brake fallback.

These dimensions follow the user's requested geometry, not a claim of universal
physical thumb size. Unit/widget checks cover landscape arc placement, angular
signs, neutral acquisition, near misses, two-pointer ownership and brake release.
Real-phone reach and sensitivity still require the user's next moving review.

## Local integration evidence

118 Flutter tests,32 browser/audio tests and14 Worker tests passed locally, with
clean analyzer, release web build, Worker dry-run and8 strict spec checks. This
includes the sprung response tests and10 touch-control tests. In a real browser
input-injection check, a guard touch dragged to the center remained non-braking;
a left-rim upward drag produced positive steering without braking; adding a
separate center finger applied braking while retaining the steering value.
The new arcs were inspected across the full landscape height. This is emulated
input/desktop evidence, not a claim of real-phone comfort.

A240-rAF uncaptured dense/roller sample with edge effects enabled recorded33.3ms
p95 and33.4ms p99 intervals, with about0.87ms mean CPU command recording at
720×405 backing/CSS1280×720. Grade pitch crossed from−.051 to+.101, dynamic ground
composition changed from.915 to.880 and ten traffic actors remained present.
[Raw scope/metadata](rolling-chase-metrics.json) distinguishes callback scheduling
from displayed-frame performance. This short software-browser sample is not a
controlled performance comparison or a physical-phone result.
