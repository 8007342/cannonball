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
