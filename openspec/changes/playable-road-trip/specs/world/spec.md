## MODIFIED Requirements

### Requirement: Dynamic traffic
Traffic SHALL cruise at differing speeds, follow leaders, select motivated lane changes and respect barriers and closed lanes. Driver profiles SHALL vary courtesy, desired gaps and signal reliability. Rare unsignaled changes SHALL still be visually readable. Supported entry and exit lanes SHALL guide NPC routes; scenic ramp art alone SHALL NOT count as connected lane topology.

#### Scenario: merging traffic
- **WHEN** an NPC merges into a player-accessible lane
- **THEN** the merge is continuous and leaves an achievable avoidance response

## ADDED Requirements

### Requirement: Surface and condition consistency
Road materials and weather SHALL influence handling and presentation. Flooded dirt-road closures, advance warnings and route eligibility SHALL describe the same generated state. The short second proof MAY retain existing grip tuning while production surface combinations remain acceptance work.

#### Scenario: flooded detour
- **WHEN** a generated attempt closes a flooded dirt detour
- **THEN** the approach warning and barrier SHALL agree with the unavailable route

## Research and reference traceability

Use the [shared reference register](../../../../../docs/research/reference-register.md)
for original research, project interpretation, historical validation and asset
provenance. Specific current-pass evidence: [camera/flow](../../../../../docs/research/camera-flow-next.md),
[contacts](../../../../../docs/research/collision-forgiveness.md),
[lane-following proposal](../../../../../docs/research/lane-following-assist.md),
[radio](../../../../../docs/radio-surfing-draft.md) and
[roadside pacing](../../../../../docs/research/roadside-flow-review.md).
