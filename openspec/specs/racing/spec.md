# Racing

## Purpose
Fast paced arcade driving across a branching cross-country run.

## Requirements

### Requirement: Continuous speed and timed stages
The game SHALL auto accelerate, permit braking, and award extra countdown time at multiple gates per stage. Perceived speed SHALL remain strong in dense traffic through scenery motion, audio and readable passable gaps. Stage durations and speed balance remain design decisions.

#### Scenario: crossing a gate
- **WHEN** the car crosses a timed gate for the first time in a run
- **THEN** its configured time bonus is applied once while total elapsed race time continues

### Requirement: Crashes and recovery
Cars SHALL have readable uphill, flat, gentle turn, hard turn, sliding, crash and flipping states. A crash SHALL reset the player to the center of a safe road segment; the recovery penalty and protection window require design approval.

#### Scenario: recovering from a flip
- **WHEN** a crash animation finishes
- **THEN** the player returns to a safe central position without overlapping traffic

### Requirement: Flow and bounded difficulty
The runtime SHALL use authored constraints and seeded variation to increase complexity with readable challenges and recovery intervals. Valve's AI Director research and the separate GameFlow literature SHALL guide pacing evaluation; neither is a universal specification for every menu or mechanic. Difficulty must not silently compromise ranked comparability.

#### Scenario: escalating a challenge
- **WHEN** the director raises traffic, weather or route complexity
- **THEN** warnings arrive early enough to act and at least one viable response remains

### Requirement: Continuous transitions
The game SHALL preload the next region and blend scenery, music and radio while driving. Story scenes and hint presentations SHALL not block active driving. Explicit pause and inactive-app handling are separate from stage transitions.

#### Scenario: entering a region
- **WHEN** the car crosses a stage boundary
- **THEN** driving continues with brief, nonblocking hints and no compulsory loading screen
