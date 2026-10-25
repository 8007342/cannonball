# Art, story and asset production

## Purpose
An original coherent arcade world within measured renderer limits.

## Requirements

### Requirement: Garage opening
The finished landing scene SHALL show a wooden garage box with only the first old key set and a shabby keychain initially available. It SHALL establish progression through keys. The current foundation screen is a placeholder, not the finished art.

#### Scenario: first launch
- **WHEN** a new player opens the finished game
- **THEN** only the starter key set is available in the garage box

### Requirement: Engine-compatible style guides
Before bulk generation, the team SHALL agree on pixel density, palette, lighting, camera geometry, sprite pivots, angle conventions, scales and layer ordering. Car sheets SHALL include rear views across slopes, turn strengths, slides and crash/flip frames with consistent identity. Atlases SHALL include metadata and approved reference assets.

#### Scenario: importing a car
- **WHEN** a car sheet enters the asset pipeline
- **THEN** dimensions, pivots, states and scale are checked before use

### Requirement: Storyboards and uninterrupted story
Storyline, storyboards, cutscenes, transition treatments and contextual hints SHALL be designed as a coherent journey. Active driving SHALL not be interrupted by compulsory scenes. Tone, characters, era and narrative stakes remain interview topics.

#### Scenario: optional story content
- **WHEN** a player starts a run after seeing an intro
- **THEN** they can skip it and reach driving promptly

### Requirement: Original assets with provenance
Production art, music, fonts and voice assets SHALL record provenance, rights and generation references. Inspirations SHALL inform an original visual direction rather than copying game assets or recognizable car badges without an explicit decision.

#### Scenario: approving a generated pack
- **WHEN** a pack is promoted to production
- **THEN** its source references, usage rights and engine validation are recorded
