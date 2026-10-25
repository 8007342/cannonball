# Racing

## Purpose
Fast paced arcade driving across a branching cross-country run.

## Requirements

### Requirement: Continuous speed and timed stages
The game SHALL auto accelerate, permit braking, and award extra countdown time at multiple gates per stage. Perceived speed SHALL remain strong in dense traffic through scenery motion, audio and readable passable gaps. A successful coast-to-coast run SHALL target 10–15 minutes of play; routes may differ in distance, traffic, complexity and random conditions. Exact stage timing and speed balance remain design decisions.

#### Scenario: crossing a gate
- **WHEN** the car crosses a timed gate for the first time in a run
- **THEN** its configured time bonus is applied once while total elapsed race time continues

### Requirement: Crashes and recovery
Cars SHALL have readable uphill, flat, gentle turn, hard turn, sliding, crash and flipping states. A crash SHALL reset the player to the center of a safe road segment; the recovery penalty and protection window require design approval.

#### Scenario: recovering from a flip
- **WHEN** a crash animation finishes
- **THEN** the player returns to a safe central position without overlapping traffic

### Requirement: Flow and bounded difficulty

The runtime SHALL increase complexity through authored constraints and seeded variation, with readable challenges and recovery intervals. Valve's AI Director and GameFlow SHALL guide pacing review, not prescribe every mechanic. Warnings SHALL permit a viable response. The Hall of Fame SHALL record actual outcomes without equalizing cars, routes or luck.

#### Scenario: escalating a challenge
- **WHEN** the director raises traffic, weather or route complexity
- **THEN** warnings arrive early enough to act and at least one viable response remains

### Requirement: Continuous transitions
The game SHALL preload the next region and blend scenery, music and radio while driving. Story scenes and hint presentations SHALL not block active driving. Explicit pause and inactive-app handling are separate from stage transitions.

#### Scenario: entering a region
- **WHEN** the car crosses a stage boundary
- **THEN** driving continues with brief, nonblocking hints and no compulsory loading screen

## Research and reference traceability

The [project reference register](../../../docs/research/reference-register.md) indexes all research, design,
validation and asset-provenance documents used by this specification. Follow each
entry for original sources and applicability limits. Historical proof evidence
does not imply current production or physical-device acceptance.
