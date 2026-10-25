# Review levels

## Purpose
Independently review composed road stages with coherent terrain, assets, metadata
and environmental conditions before promoting them into the connected campaign.

## ADDED Requirements
### Requirement: Independent level selection and chapter replay
The proof SHALL map Q/W/E/R/T/Y to six distinct composed levels, and1–8 to sections
within the selected level. Selecting a level SHALL reset input, race clock,
traffic, lighting histories and level metadata together without replaying the
garage. Backspace SHALL restart the current section. Touch users SHALL have a
visible level selector. Existing steering/braking utility controls SHALL remain.

#### Scenario: switching from daylight to night while steering
- **WHEN** a player selects a night level while holding steering or braking
- **THEN** the new level starts with cleared input, matching road conditions and
  scenery, and no light trails from the preceding level

#### Scenario: replaying a chapter
- **WHEN** the player presses3 in the autumn level
- **THEN** the autumn level remains selected and its climb chapter restarts

### Requirement: Coherent metadata and bounded reusable assets
Each level SHALL declare distinct terrain variation, deterministic seed, scenery
palette/asset selection, sky/lighting, weather and canopy/lamp eligibility. The
engine SHALL prepare assets before use, retain the previous valid pack on failure,
and bound cached variants. Levels SHALL remain illustrative rather than claiming
verified real-world geometry. Unknown level query values SHALL fall back safely.

#### Scenario: repeated pack swaps
- **WHEN** the player repeatedly selects all six levels
- **THEN** valid packs swap coherently, the cache does not grow without bound,
  and ordinary driving does not synchronously load or decode assets

### Requirement: Research traceability
The [lighting/scenery source ledger](../../../../../docs/research/level-lighting-scenery.md)
SHALL record each relevant source, application or deferral, implementation limits
and local versus physical-device evidence.

#### Scenario: adopting an effect
- **WHEN** a lighting or canopy technique is added
- **THEN** the ledger names its source and distinguishes an adaptation from a
  calibrated physical model or measured phone result

### Requirement: Default painted app and readable driving rhythm
The default URL SHALL open the painted prototype. Roads SHALL combine early
bends, sustained gentle sweeps, demanding direction changes, and repeated signed
gradients without changing shared collision/projection coordinates.

#### Scenario: opening the public root
- **WHEN** a player opens the root without a proof query
- **THEN** the painted prototype garage and driving course are available

### Requirement: Progressive steering and gentle-road cruising
Gentle-road assistance SHALL cancel only curve-induced outward force, preserve
arbitrary road-relative offsets, and permit intentional steering in both signs.
Strong bends SHALL retain active steering demand. Hysteresis and bounded blending
SHALL avoid abrupt correction transitions. Keyboard steering SHALL build smoothly
and release promptly at speed. The overlay SHALL show applied steering including
automatic corrections, independently of touch demand.

#### Scenario: cruising then entering a strong curve
- **WHEN** a player releases steering on a gentle sweep then reaches a tight bend
- **THEN** the gentle sweep preserves their offset, the wheel shows small
  corrections, and the tighter bend requires active steering

#### Scenario: intentional lane change
- **WHEN** a player steers in either direction while assistance is active
- **THEN** their command moves the car without a lane-center attraction

Research, rejected alternatives and tuning limits SHALL remain recorded in the
[cruising ledger](../../../../../docs/research/cruising-road-feel.md) and the
[reference register](../../../../../docs/research/reference-register.md).
