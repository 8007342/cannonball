## MODIFIED Requirements

### Requirement: Regional adaptive score
Original regional track families SHALL use varied eligible arrangements. Station changes SHALL sequence music, a tuning burst and contextual radio, then a new track without an audible fade or gameplay pause. Browser speech fallback SHALL NOT be presented as guaranteed local accents. Prepared regionally reviewed voices remain production content.

#### Scenario: changing region
- **WHEN** driving enters a new station region
- **THEN** a relevant report bridges eligible tracks while driving continues

## ADDED Requirements

### Requirement: Contextual humorous radio
Radio variants SHALL prioritize actual closures and weather over ambient humor, avoid immediate repeats, and use local references where authored. Failed speech or missing audio SHALL NOT delay simulation.

#### Scenario: speech unavailable
- **WHEN** the browser cannot speak a selected report
- **THEN** music and driving SHALL continue and optional captions SHALL remain available

### Requirement: Short interjections and occasional station surfing
Prepared proof reports SHALL be brief interjections rather than long monologues.
Some actual station changes MAY insert a short alternate-song fragment between
noise bursts and the report. Snippets SHALL have a fixed maximum duration, skip
if not ready and cancel on mute, pause, hidden or disposal. Audio sequencing SHALL
never stop gameplay or wait on a missing snippet.

#### Scenario: an alternate station fragment is unavailable
- **WHEN** the station-surf fragment is not decoded at its scheduled beat
- **THEN** the sequence skips it immediately and continues to the report and selected music

## Research and reference traceability

Use the [shared reference register](../../../../../docs/research/reference-register.md)
for original research, project interpretation, historical validation and asset
provenance. Specific current-pass evidence: [camera/flow](../../../../../docs/research/camera-flow-next.md),
[contacts](../../../../../docs/research/collision-forgiveness.md),
[lane-following proposal](../../../../../docs/research/lane-following-assist.md),
[radio](../../../../../docs/radio-surfing-draft.md) and
[roadside pacing](../../../../../docs/research/roadside-flow-review.md).
