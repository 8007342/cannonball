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
