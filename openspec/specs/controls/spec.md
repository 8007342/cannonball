# Controls

## Purpose
Responsive landscape mobile controls with keyboard and touch fallbacks.

## Requirements

### Requirement: Landscape play
Gameplay SHALL remain landscape in mobile and desktop browsers. No native Android/iOS app is planned. Browsers that cannot lock orientation SHALL show a rotate prompt before play; device behavior must be tested rather than assumed.

#### Scenario: portrait browser
- **WHEN** the playable viewport is portrait
- **THEN** the player is prompted to rotate before starting or resuming driving

### Requirement: Tilt with immediate fallback
The game SHALL offer optional calibrated tilt steering, request any browser sensor permission from a user gesture, and retain touch steering when tilt is unavailable or disabled. The horizon SHALL remain mostly flat with subtle lean, somewhat stronger under motion steering. Roll SHALL be independently damped and calibrated for each control mode, with a zero-roll comfort option. Direction, amplitude and timing require browser-device trials.

#### Scenario: denied motion permission
- **WHEN** the player declines sensor permission
- **THEN** touch steering remains available without trapping the player

### Requirement: Oversized wheel overlay

Touch steering SHALL use an enlarged wheel with a clear center and cropped translucent rim above the driving view. Angular dragging SHALL turn it: right-edge down / left-edge up steers right; right-edge up / left-edge down steers left. Return behavior and maximum rotation remain tunable.

#### Scenario: braking while steering
- **WHEN** one touch drags the steering region while another holds the brake region
- **THEN** steering and braking are processed independently without jumps when either touch lifts

### Requirement: Brake and utility controls
Touching and holding outside the wheel SHALL brake; utility controls SHALL consume their own touches. Holding Down arrow SHALL also brake; releasing all brake inputs SHALL resume auto acceleration. Left/Right SHALL support desktop steering. Tilt, mute, profile and pause SHALL remain small, visible and reachable above gameplay; user-requested low opacity SHALL retain usable contrast and touch targets.

#### Scenario: toggling tilt during play
- **WHEN** the player disables tilt with the persistent toggle
- **THEN** touch steering takes over without an abrupt steering discontinuity
