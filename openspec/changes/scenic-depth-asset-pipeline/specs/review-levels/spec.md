## ADDED Requirements
### Requirement: Per-level terrain character
Each review level SHALL have its own curve and elevation profile. At least two
levels SHALL include tight curves that require braking at top speed and steep
crests that hide the road beyond; at least one SHALL keep long calm straights.
All curves SHALL remain passable with braking under the steering assist.

#### Scenario: hairpin at speed
- **WHEN** the player enters a tight curve on a hilly level at top speed
- **THEN** braking lets the car hold the road, and the same curve is
  deterministic across replays

### Requirement: Road surface variety
Levels and zones SHALL select road surface, marking, shoulder and sidewalk
variants (for example worn asphalt, concrete slabs, brick, gravel shoulder,
curbed sidewalk, bridge deck) with continuous transitions.

#### Scenario: entering town
- **WHEN** a rural road enters a town zone
- **THEN** the shoulder transitions to a curbed sidewalk without a visible seam
