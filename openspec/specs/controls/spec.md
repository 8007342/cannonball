# Controls

## Purpose
Responsive landscape mobile controls with keyboard and touch fallbacks.

## Requirements

### Requirement: Landscape play
Gameplay SHALL remain landscape. Native orientation preferences SHALL request both landscape directions. Browsers that cannot lock orientation SHALL show a rotate prompt before play; device behavior must be tested rather than assumed.

#### Scenario: portrait browser
- **WHEN** the playable viewport is portrait
- **THEN** the player is prompted to rotate before starting or resuming driving

### Requirement: Tilt with immediate fallback
The game SHALL offer optional calibrated tilt steering, request any browser sensor permission from a user gesture, and retain touch steering when tilt is unavailable or disabled. Horizon roll SHALL be independent of steering, with flat and comfort settings; final roll behavior is undecided.

#### Scenario: denied motion permission
- **WHEN** the player declines sensor permission
- **THEN** touch steering remains available without trapping the player

### Requirement: Oversized wheel overlay
Touch steering SHALL use a wheel enlarged beyond the viewport: a translucent rim visible mainly along the sides, a fully clear center, rendered above the driving view. Dragging SHALL steer. Gesture direction, return behavior, active touch areas and maximum rotation require confirmation; a small conventional wheel is not the intended design.

#### Scenario: braking while steering
- **WHEN** one touch drags the steering region while another holds the brake region
- **THEN** steering and braking are processed independently without jumps when either touch lifts

### Requirement: Brake and utility controls
Holding the configured screen brake area or Down arrow SHALL brake; releasing SHALL resume auto acceleration. Left/Right SHALL support desktop steering. Tilt, mute, profile and pause SHALL remain small, visible and reachable above gameplay; user-requested low opacity SHALL retain usable contrast and touch targets.

#### Scenario: toggling tilt during play
- **WHEN** the player disables tilt with the persistent toggle
- **THEN** touch steering takes over without an abrupt steering discontinuity
