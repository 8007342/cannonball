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

### Requirement: World reference traceability
The world requirements SHALL link to the [shared reference register](../../../../../docs/research/reference-register.md), retaining original sources, historical validation and asset provenance with their applicability limits.

#### Scenario: reviewing world evidence
- **WHEN** the implementation is assessed against this capability
- **THEN** reviewers can follow the register to original references and distinguish historical observations from unverified production acceptance

### Requirement: Coherent bounded roadside animation
The next proof SHALL demonstrate a bounded sample of world-anchored vegetation or
roadside secondary motion inspired by Ranitas's batching and GPU Gems's coarse
and detailed wind response. Animation SHALL preserve road clearance, depth order
and the central traffic corridor, and stable/reduced-motion comparisons SHALL
suppress optional decoration. Full independent physical vegetation simulation
SHALL NOT be implied by a small atlas-based sample.

#### Scenario: passing animated roadside vegetation
- **WHEN** wind or phase variation animates visible roadside scenery
- **THEN** its roots remain attached to shared terrain, motion stays bounded, and consequential traffic cues remain readable
