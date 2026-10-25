## MODIFIED Requirements

### Requirement: Oversized wheel overlay
Touch steering SHALL use an enlarged wheel with a clear center and cropped translucent rim above the driving view. Angular dragging SHALL turn it: right-edge down or left-edge up steers right; right-edge up or left-edge down steers left. Initial implementation SHALL return smoothly to center when released; sensitivity remains tunable.

#### Scenario: braking while steering
- **WHEN** one touch drags the steering region while another holds outside the wheel
- **THEN** steering and braking are processed independently without jumps when either touch lifts

#### Scenario: clockwise wheel rotation
- **WHEN** the player drags the right rim downward or left rim upward
- **THEN** the car steers right without applying the brake

### Requirement: Brake and utility controls
Outside-wheel taps SHALL briefly brake, and holding SHALL sustain braking. Holding Down arrow SHALL also brake. The car SHALL otherwise auto accelerate continuously. Left/Right SHALL support desktop steering. Tilt, mute, profile and pause SHALL remain visible and reachable above gameplay, consuming their own touches rather than braking.

#### Scenario: toggling tilt during play
- **WHEN** the player disables tilt with the persistent toggle
- **THEN** touch steering takes over without an abrupt steering discontinuity

#### Scenario: releasing brake
- **WHEN** the player releases all brake inputs
- **THEN** acceleration resumes automatically after any brief tap-brake pulse

## ADDED Requirements

### Requirement: Gentle bend cruising assist
The driving model SHALL carry the car through insignificant heading changes
without corrective steering. Assist SHALL cancel only road-induced drift, preserve
lane position and deliberate input, and blend out on meaningful curves. Thresholds
and hysteresis SHALL be documented and playtested.

#### Scenario: cruising through a gentle bend
- **WHEN** the player releases steering on a subtle sustained bend
- **THEN** the car maintains its road-relative lateral position without snapping toward lane center

#### Scenario: steering deliberately during assist
- **WHEN** the player changes lane while gentle-bend assist is active
- **THEN** assist preserves the requested movement and does not pull the car back to the previous lane

#### Scenario: entering a meaningful curve
- **WHEN** curvature exceeds the documented assist exit threshold
- **THEN** assistance blends out and the player must steer without an abrupt lateral jump

### Requirement: Controls reference traceability
The controls requirements SHALL link to the [shared reference register](../../../../../docs/research/reference-register.md), retaining original sources, historical validation and asset provenance with their applicability limits.

#### Scenario: reviewing controls evidence
- **WHEN** the implementation is assessed against this capability
- **THEN** reviewers can follow the register to original references and distinguish historical observations from unverified production acceptance
