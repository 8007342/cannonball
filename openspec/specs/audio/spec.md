# Adaptive audio and radio

## Purpose
Music and radio sustain speed and communicate useful world changes.

## Requirements

### Requirement: Regional adaptive score
An original synthesized soundtrack SHALL transition between regions and respond to intensity without audible blocking. A MIDI-compatible synthesizer and licensed sound bank are intended; browser Web MIDI hardware access is not a substitute for synthesis.

#### Scenario: changing region
- **WHEN** the car enters a new musical region
- **THEN** the score transitions on a suitable musical boundary while gameplay continues

### Requirement: Useful radio voice
Radio anchor lines SHALL announce contextual traffic, viable route choices, weather and local color. Speech SHALL be captioned, prioritized, interruptible and backed by prerecorded or cached speech where runtime TTS is unavailable. Guidance SHALL derive from actual run state.

#### Scenario: announcing snow
- **WHEN** snow is scheduled on an upcoming section
- **THEN** the player receives an early voice and text warning before the handling change

### Requirement: Browser audio activation
Sound SHALL begin after an appropriate user interaction, respect mute and pause, and avoid overlapping critical instructions.

#### Scenario: audio blocked by browser
- **WHEN** autoplay is unavailable
- **THEN** the game remains usable and captions convey critical guidance

## Research and reference traceability

The [project reference register](../../../docs/research/reference-register.md) indexes all research, design,
validation and asset-provenance documents used by this specification. Follow each
entry for original sources and applicability limits. Historical proof evidence
does not imply current production or physical-device acceptance.
