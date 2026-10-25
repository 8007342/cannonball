## ADDED Requirements

### Requirement: Final Corvette unlock
The final unlock SHALL be a white 2019 Corvette Stingray Coupe driven with its removable targa roof panel off. Its open cabin and white body SHALL remain recognizable across rear, turning and crash presentation. Other cars SHALL be unlocked before it becomes available.

#### Scenario: selecting the final car
- **WHEN** the player has earned the final Corvette and selects its key
- **THEN** the garage identifies the 2019 Stingray and the driving view presents its white body with roof removed

### Requirement: Approved motion direction
The approved motion/art research SHALL guide diffused pixel edges, coherent sprite poses, stable frame pacing, separate mobile/desktop resolution tiers and modest control-specific camera lean. Approval of the research SHALL not be reported as physical-device validation or approval of unseen production art.

#### Scenario: accepting visual production
- **WHEN** production assets are reviewed
- **THEN** animation, pixel-edge softness and readable speed are checked in motion on representative browsers

### Requirement: Lively cartoon world
The driving presentation SHALL use textured surfaces, coherent cartoon car animation, regional scenery and layered parallax inspired by the user's Baja reference. Primitive rectangle vehicles and scenery SHALL NOT count as an accepted visual result. Wheels, suspension, slopes, turning and impacts SHALL have readable motion with consistent ground contact.

#### Scenario: reviewing the city-edge sample
- **WHEN** the player drives the visual proof through a curve, hill and bridge
- **THEN** car poses, terrain flow, scenery depth and traffic occlusion remain coherent in motion

### Requirement: Measured visual proof
Before expanding production packs, the team SHALL deliver a moving sample and report rendering cadence, interval percentiles, backing resolution, graphics backend and simulation-to-wall-time behavior. A logical canvas size, passing unit tests or screenshots alone SHALL NOT establish rendering performance. Reports SHALL distinguish browser scheduling from measured presented frames.

#### Scenario: comparing render quality tiers
- **WHEN** the same sample is tested at different scene pixel budgets
- **THEN** the report records visual quality and timing for each actual buffer size while preserving physics and sharp HUD controls

### Requirement: Starter departure ritual
The next proof SHALL offer an older desirable S2000 starter from a wooden garage wall keybox. Key pickup, garage reveal, approach, implied entry and chase launch SHALL form a reusable sequence. Empty hooks SHALL suggest unlocks. The race clock SHALL remain paused during the departure; repeat players SHALL be able to skip it.

#### Scenario: taking the first keys
- **WHEN** the player selects the available key set
- **THEN** the hand collects it and the departure leads into controllable auto-accelerating driving

### Requirement: Palette-varied traffic
Traffic paint variants SHALL preserve fixed tire, glass, cabin and lighting details. Directional steering and skid presentation SHALL reflect signed motion at high and low speeds.

#### Scenario: steering right at speed
- **WHEN** the player steers strongly right above the skid threshold
- **THEN** the sprite SHALL present rightward motion rather than reusing an uncorrected leftward pose

### Requirement: Continuous departure composition
The proof departure SHALL preserve car proportions, present a readable reach/grasp/withdraw, coordinate the turn toward the doorway, and bridge cabin/rear/driving views with consistent composition and sound. The clock SHALL remain paused before handoff; skip, reduced motion and mute SHALL remain supported.

#### Scenario: wide landscape cabin
- **WHEN** a landscape viewport changes aspect ratio
- **THEN** the cabin SHALL crop or frame proportionally rather than stretching the steering wheel and car interior

### Requirement: Progressive steering poses
Steering presentation SHALL pass through gentle/intermediate angles before a sustained full turn, preserve small angles for gentle held input, and respond smoothly on reversal. Timing SHALL be frame-rate independent and playtested; full input SHALL NOT automatically imply an immediate skid.

#### Scenario: brief arrow tap
- **WHEN** a short full-strength steering input begins
- **THEN** the first visible turn SHALL be gentle rather than an immediate hard/skid pose

### Requirement: Camera and roadside rhythm review
The proof SHALL compare a lower horizon with prior camera heights while preserving
player ground contact and readable near traffic. Distant scenery SHALL enter through
bounded depth fade/haze rather than a hard opaque draw-boundary appearance. Sparse
pictorial businesses SHALL vary roadside composition without covering ramp pavement
or overwhelming consequential warnings. Speed sensation SHALL be tunable separately
from encounter frequency and game timing.

#### Scenario: a roadside business enters view
- **WHEN** a distinctive business passes from the distance band into the visible road corridor
- **THEN** it appears progressively, stays outside playable/merging pavement and does not replace a required warning

### Requirement: Art reference traceability
The art requirements SHALL link to the [shared reference register](../../../../../docs/research/reference-register.md), retaining original sources, historical validation and asset provenance with their applicability limits.

#### Scenario: reviewing art evidence
- **WHEN** the implementation is assessed against this capability
- **THEN** reviewers can follow the register to original references and distinguish historical observations from unverified production acceptance

### Requirement: Responsive grounded chase composition
The proof SHALL default to the approved wide camera. Speed, braking and turning
MAY drive bounded damped composition and suspension cues while shared projection
preserves vehicle contact and hazard positions. Stable and reduced-motion modes
SHALL suppress optional movement/effects. The central driving corridor SHALL
remain readable when peripheral speed effects are enabled.

#### Scenario: braking from high speed
- **WHEN** the player brakes while dynamic chase and suspension cues are active
- **THEN** the camera and car presentation settle smoothly while controls and contacts remain immediate
