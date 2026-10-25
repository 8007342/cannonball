# World and traffic

## Purpose
Recognizable American regions and meaningful route choices.

## Requirements

### Requirement: Cross-country route graph

Runs SHALL start at New York's Red Ball Garage and finish at The Portofino Hotel & Marina in Redondo Beach. Present-day real freeways, state roads, cities, interchanges, landmarks and secret backroads SHALL form a coherent graph compressed to the 10–15 minute play target. Source dates and connectivity SHALL be recorded. Current geography does not imply live traffic/weather feeds. Exact corridors and stage count await approval.

#### Scenario: choosing a branch
- **WHEN** a player reaches a playable fork
- **THEN** readable signage communicates the destinations early enough to choose

### Requirement: Construction and safe closures
Seeded road and lane closures SHALL include construction cones, lane guidance or a stranded truck with advance warning. The generator SHALL never close every route to the destination or create an unavoidable collision. NPC-only exits SHALL be visibly blocked to players.

#### Scenario: a route closes
- **WHEN** construction disables a branch
- **THEN** advance cones and signs guide the player to a reachable alternative

### Requirement: Dynamic traffic
Traffic SHALL cruise at differing speeds, make telegraphed lane changes, and merge through supported entry and exit lanes. It SHALL respect barriers and lane availability. Density SHALL preserve agency and the impression of speed.

#### Scenario: merging traffic
- **WHEN** an NPC merges into a player-accessible lane
- **THEN** the merge is readable and leaves an achievable avoidance response

### Requirement: Regional composition
Region packs SHALL distinguish local terrain, vegetation, city silhouettes, landmarks, weather and researched local humor. Tile and prop composition SHALL follow biome and road metadata rather than arbitrary mixing.

#### Scenario: entering Colorado from Nebraska
- **WHEN** a run transitions between those approved route regions
- **THEN** terrain, vegetation, weather messaging and music transition consistently with the authored region pack

## Research and reference traceability

The [project reference register](../../../docs/research/reference-register.md) indexes all research, design,
validation and asset-provenance documents used by this specification. Follow each
entry for original sources and applicability limits. Historical proof evidence
does not imply current production or physical-device acceptance.
