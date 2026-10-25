# Authored road-feel milestone: evidence and implementation

This proof is an authored test course. It is not a new verified New York route,
a complete city-to-city stage, a live traffic model, or production acceptance.
It preserves the established fixed-step simulation and legacy receipts by using
an explicit `testCourse` start option. Rendering, inputs and content remain
separate from persistence and the old public leaderboard.

## Primary research

**Racing camera experiment.** Holm, Skovhus and Kraus found that increasing
geometric field of view increased perceived velocity in a third-person 3D racing
setup. Strong motion blur decreased perceived velocity. Their altitude results
also depend on speed; this does not justify assuming that a lower camera always
feels faster. The study supplies hypotheses for our tests, not phone camera
constants: [Increasing the Perceived Camera Velocity in 3D Racing Games by
Changing Camera Attributes](https://eudl.eu/doi/10.1007/978-3-319-55834-9_14).

**Optic flow.** Mourant, Jaeger and Lin's driving-simulator experiments found
participants distinguished optic flow across geometric fields of view. They
explain that nearby/peripheral reference objects create stronger flow than the
horizon's expansion point. Their apparatus and tasks differ from a tiny
pseudo-3D browser game. Our inference is to preserve a stable distant view while
making close road edges, roadside references and overtakes visibly sweep by:
[DSC 2007 original paper](https://www.nads-sc.uiowa.edu/dscna/2007/papers/Section%207B%20-%20Simulator%20Characteristics%20-%20Sight%20and%20Sound/Mourant.pdf).

**Steering response.** Autodesk's vehicle documentation explicitly separates
input rise/fall smoothing and speed-dependent steering response. This establishes
a practical vehicle-input architecture, not the right numeric settings for
Cannonball: [Vehicle physics properties](https://help.autodesk.com/cloudhelp/ENU/Stingray-Help/stingray_help/creating_gameplay/physics/vehicle_physics_properties.html).

Friston, Karlstrom and Steed found measurable effects of low latency in pointing
and path-steering tasks. These are not racing trials. We use the finding to avoid
an intentional dead interval before response: magnitude starts changing on the
first fixed step, rather than waiting for an animation to finish. The sourced
study does not prescribe a car steering ramp: [UCL author's repository](https://discovery.ucl.ac.uk/id/eprint/1471049/),
[DOI](https://doi.org/10.1109/TVCG.2015.2446467).

## Concrete causes addressed

The old centerline sampled simulation distance after dividing by the optical
flow multiplier. Raising that multiplier made the fixed visible road window
cover a shorter part of each bend. Subtracting the camera tangent then left a
near-straight road. `ProofCourse` now authors centerline curvature and elevation
in one fixed distance domain, independently of projection presets. Both actual
steering load and rendered road curvature consult it.

The worksite cone loop previously started at `max(authoredStart, cameraNear)`.
Once culling reached the row, each cone effectively followed the near plane.
The new sequence starts from a fixed authored origin and integer indices. Culling
only chooses which existing identities to draw. The origin also excludes visual
fixed-step interpolation lag, so cones cannot jitter with the render remainder.
Road-marking phase remains anchored to world distance. We do not randomize hazard
positions to disguise temporal aliasing.

The new road-prop source sheet is not a perfect uniform grid. Explicit measured
rectangles isolate the painted cone, barrier, reflector, canopy, portal and lamp.
The portal opening is transparent. These source regions are copied once into an
extended scenery atlas so depth-ordered scenery and props retain batching. Ground
footprints keep city facades beyond the curb; overhead foliage is a separate
object type instead of a wall sprite arbitrarily spilling onto the road.

## Authored course and comparison controls

Distance units are arcade simulation units. With a 155-mph car at full speed,
7,600 units spans approximately95seconds before incidents or braking. Root's
120-second UI study allows some recovery. This is not physical road mileage.

| Course interval | Feature |
|---|---|
| 0–600 | Open straight, reference markers |
| 600–2,100 | Obvious opposite-direction sweeping bends |
| 2,100–3,200 | Climb combined with a bend |
| 3,200–4,200 | Crest and descent |
| 4,200–5,000 | Worksite; actual right-lane closure4300–4920 |
| 5,000–5,550 | Three overhead foliage spans |
| 5,550–6,050 | Small bridge rise and scenic span |
| 6,050–6,820 | Portal, localized tunnel darkness and readable headlight pool |
| 6,820 onward | Return to open road |

`RaceGame.setCameraPreset('baseline'|'wide'|'flow')` compares projection/cues while
holding simulation speed, curve geometry, seed and traffic rules fixed. Baseline
uses projection coefficient.88; wide/flow use.64. These are implementation
coefficients, not measured real camera degrees. Flow adds the close reference
markers. The existing optical-flow presets remain separate for comparison and
are not evidence that changing displayed mph fixes perceived speed.

`courseStartDistance` starts a fresh isolated attempt at a chapter's geometry,
with elapsed time and actual route distance still zero. It is an offset into the
experimental course, not an invented completed route or a valid cloud receipt.
`courseDistance`, `proofStage`, camera preset and steering telemetry make the
current scene observable. The local countdown is300seconds so the shorter UI
study, rather than an old90-second timeout, determines its review duration.

## Progressive steering and animation

The controller distinguishes target steering from proof-only effective steering.
Effective steering starts moving immediately, taking roughly.18seconds from zero
to full demand; release is quicker. A separate time-based presentation value
progresses through the authored gentle, medium and hard signed pose pairs.
Small held input stays gentle regardless of duration. A high-speed skid needs
sustained strong demand; it is no longer selected simply because a key was pressed
while the speed exceeded100mph. Reversals cross neutral and release cannot leave
a queued opposite-direction pose.

The rough80–100ms gentle phase,~200ms full-strength progression and sustained
skid threshold are **our tuning hypotheses**, not published optimal delays.
Physical touch/tilt comfort, perceived input lag and the appropriate cornering
load still require player review. The legacy direct-input path and stateless
sprite selector remain intact for existing routes and tests.

## Depth, visibility and limits

Depth haze uses atlas color blending toward a sky-compatible color, rather than
always darkening remote sprites or using costly per-object blur. Canopies and
portal facades share world depth with traffic; the tunnel uses a localized roof/
lighting treatment. This is a 2.5D scenic structure, not drivable multiple decks
or a general volumetric lighting engine. Hazard readability must be reviewed in
motion. Alpha-heavy paintings and the extra atlas rows have memory/fill costs.

The source pack's turn poses receive alpha-measured tire contacts and centers;
frames are not stretched into fabricated camera orbits. Production art still
needs a fuller coherent turn/suspension/crash library and authored paint masks.

## Verification

`proof_course_test.dart` covers opposite bends, mixed grade/turn, visible deviation
from a local straight tangent, fixed cone identities, fresh chapter starts and
immediate progressive actual control. `steering_presentation_test.dart` covers
taps, held gentle demand, gentle/medium/hard progression, delayed skids, reversal,
release and30/120Hz schedules. Pure-Dart smoke checks measured an authored lateral
deviation of about501presentation units450simulation units ahead on a bend.

The forge Flutter wrapper only mounts the root checkout; root performs integrated
analysis/tests/build and browser inspection after cherry-picking these checkpoints.
No screenshot or passing unit test establishes perceived speed, physical input
latency or presented-frame rate. Root records actual backing size, update/render
counts, scheduling percentiles and moving feedback separately.
