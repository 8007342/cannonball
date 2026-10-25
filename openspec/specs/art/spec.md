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

Before bulk generation, the team SHALL agree on pixel density, palette, edge treatment, lighting, camera geometry, sprite pivots, angles, scale and layers. Car sheets SHALL include rear views across slopes, turn strengths, slides and crash/flip frames with consistent identity. Atlases SHALL include metadata and approved references.

#### Scenario: importing a car
- **WHEN** a car sheet enters the asset pipeline
- **THEN** dimensions, pivots, states and scale are checked before use

### Requirement: Storyboards and uninterrupted story
Storyline, storyboards, cutscenes, transition treatments and contextual hints SHALL be designed as a coherent journey. Active driving SHALL not be interrupted by compulsory scenes. The world is present-day; tone, characters and narrative stakes remain interview topics.

#### Scenario: optional story content
- **WHEN** a player starts a run after seeing an intro
- **THEN** they can skip it and reach driving promptly

### Requirement: Original assets with provenance
Production art, music, fonts and voice assets SHALL record provenance, rights and generation references. Inspirations SHALL inform an original visual direction rather than copying game assets or recognizable car badges without an explicit decision.

#### Scenario: approving a generated pack
- **WHEN** a pack is promoted to production
- **THEN** its source references, usage rights and engine validation are recorded

### Requirement: Diffused pixel art in motion
Art SHALL mix pixelated forms with diffused edges. Motion smoothness and readable speed SHALL be evaluated in moving scenes, not assumed from blur alone. Desktop SHALL support higher-resolution variants of the same style; mobile SHALL load suitable packs within measured download and memory budgets.

#### Scenario: reviewing a style sample
- **WHEN** an art sample is evaluated on mobile and desktop
- **THEN** reviewers compare moving silhouettes, scaling, pose changes and hazard readability across the proposed resolution tiers

## Research and reference traceability

The [project reference register](../../../docs/research/reference-register.md) indexes all research, design,
validation and asset-provenance documents used by this specification. Follow each
entry for original sources and applicability limits. Historical proof evidence
does not imply current production or physical-device acceptance.
