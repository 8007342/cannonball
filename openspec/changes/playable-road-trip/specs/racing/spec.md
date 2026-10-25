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

## Research and reference traceability

Use the [shared reference register](../../../../../docs/research/reference-register.md)
for original research, project interpretation, historical validation and asset
provenance. Specific current-pass evidence: [camera/flow](../../../../../docs/research/camera-flow-next.md),
[contacts](../../../../../docs/research/collision-forgiveness.md),
[lane-following proposal](../../../../../docs/research/lane-following-assist.md),
[radio](../../../../../docs/radio-surfing-draft.md) and
[roadside pacing](../../../../../docs/research/roadside-flow-review.md).
