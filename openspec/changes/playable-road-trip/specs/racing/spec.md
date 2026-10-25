## MODIFIED Requirements

### Requirement: Continuous speed and timed stages
The game SHALL auto accelerate, permit braking, and award extra countdown time at multiple gates per stage. City-to-city campaign stages SHALL target 10–15 minutes, with a longer coast-to-coast journey composed across stages. Short proofs MAY compress this for review. Perceived speed SHALL remain strong through optical flow, sound and navigable traffic gaps. Routes and luck SHALL remain unequal.

#### Scenario: crossing a gate
- **WHEN** the car crosses a timed gate for the first time in a stage attempt
- **THEN** its time bonus is applied once without subtracting total elapsed time

## ADDED Requirements

### Requirement: Readable reactive traffic
Nearby traffic SHALL be able to brake or flinch within its lane in response to aggressive player moves. Braking SHALL affect following vehicles; actual contacts MAY cause bounded secondary incidents. Reactions SHALL use local observed state, remain continuous and preserve an achievable player response.

#### Scenario: close pass
- **WHEN** a fast player passes closely enough to trigger a nearby driver's reaction
- **THEN** that driver can flinch or brake without teleporting across lanes

### Requirement: Authored driving test course
The local proof SHALL include readable straights, opposing bends, combined elevation/curvature, a crest/descent and an actual worksite. Geometry and steering demand SHALL agree. Camera comparison variants SHALL preserve comparable car physics and stage timing.

#### Scenario: following a gentle bend
- **WHEN** the player maintains an appropriate small steering input on a long gentle curve
- **THEN** the car SHALL remain controllable with a gentle visual turn angle

### Requirement: Forgiving visible contacts
Proof vehicle crashes SHALL require a contact consistent with projected vehicle
positions and shall permit a small documented overlap and corrective grace.
Construction-lane designation alone SHALL NOT crash the car. Swept contacts SHALL
be evaluated during fast crossings. Cosmetic cone impacts SHALL launch bounded
one-shot flights, never act as an invisible solid lane or trigger a car crash.

#### Scenario: grazing a neighboring vehicle
- **WHEN** a brief lateral graze clears within the corrective window
- **THEN** the car continues without a crash

#### Scenario: hitting an orange cone
- **WHEN** the player crosses a visible cone footprint
- **THEN** that cone scatters once and cannot trigger a subsequent crash as a ghost obstacle

### Requirement: Racing reference traceability
The racing requirements SHALL link to the [shared reference register](../../../../../docs/research/reference-register.md), retaining original sources, historical validation and asset provenance with their applicability limits.

#### Scenario: reviewing racing evidence
- **WHEN** the implementation is assessed against this capability
- **THEN** reviewers can follow the register to original references and distinguish historical observations from unverified production acceptance

### Requirement: Rolling dense-traffic comparison
The next proof SHALL offer irregular continuous rise/dip terrain and a denser
reactive traffic stream with bounded actor count, same-lane headway and spawn
openings. Terrain SHALL remain shared by road, props and vehicles. Prior traffic
and stable-camera comparisons SHALL remain available for review.

#### Scenario: approaching a rolling crest
- **WHEN** the player approaches a crest with dense traffic ahead
- **THEN** vehicles and roadside props follow the same terrain and traffic enters from beyond the preview rather than teleporting into the near driving area

### Requirement: Gradient and curvature review coverage
The next local proof SHALL contain numerous left/right curves at gentle, medium
and stronger demand and shallow, medium and steep climbs and descents. Crests,
dips, repeated reversals and combined slope/curve sections SHALL exercise the
subtleties of grounded poses and steering. Course geometry SHALL remain continuous,
shared by traffic/props and replayable by chapter.

#### Scenario: inspecting hill and curve subtleties
- **WHEN** the reviewer traverses or replays the course sections
- **THEN** both slope signs and multiple gradient/curvature magnitudes are exercised, including compound transitions rather than only one exaggerated hill and bend

### Requirement: Faster flow preserves preview
The new stronger-speed presentation SHALL preserve an explicitly budgeted useful
geometric road preview across motion comparisons. Road sampling MAY redistribute
a fixed mesh budget toward the distance. Traffic admission, contact positions and
projected motion SHALL use the same coordinates. Faster presentation SHALL NOT
silently change vehicle physics, campaign timing or the available draw range.

#### Scenario: switching to the stronger flow comparison
- **WHEN** the reviewer selects the new motion preset
- **THEN** scenery flow increases while the road preview budget and traffic admission remain coherent, and telemetry identifies scale and preview separately

#### Scenario: traffic behind a crest
- **WHEN** terrain occludes a traffic actor within the geometric preview range
- **THEN** the review distinguishes terrain occlusion from draw-boundary clipping rather than claiming the full preview is guaranteed visible reaction time

### Requirement: Bounded encounter admission beats
The next proof SHALL separate speed sensation from new traffic admission and
provide repeatable build, overtaking and release beats. A lower phase capacity
SHALL restrict new arrivals without deleting visible actors. Existing local driver
responses and passable spawn gaps SHALL remain bounded and deterministic. Actual
car, route and random-condition advantages SHALL remain intact.

#### Scenario: entering a release phase with traffic present
- **WHEN** the encounter beat changes from overtaking to release
- **THEN** admission eases without teleporting existing vehicles away or imposing score compensation
