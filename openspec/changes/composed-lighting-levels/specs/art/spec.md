## ADDED Requirements
### Requirement: Night illumination and independent emissive lights
Night scenes SHALL retain readable scenery and car silhouettes. Headlights SHALL
illuminate projected road and nearby side objects with bounded steering response
and local falloff. Tail lamps, brake lamps, night lamps and roadside signals SHALL
retain bright cores and restrained halos independently of ambient grading.
Light pools and emissive sources SHALL respect hill/scene occlusion. Signals in
this proof are scenic, not an implemented stop-rule or playable junction.

#### Scenario: passing a lamp on a bend at night
- **WHEN** the car steers through a lit night section
- **THEN** the beam moves smoothly, nearby surfaces brighten locally, passing
  lamps retain luminous cores and distant traffic tail lights remain visible

### Requirement: Bounded temporal light accents
Short light trails SHALL use time-based decay and bounded per-source history,
clear on reset/level swap, and disappear under reduced decorative motion. They
SHALL NOT smear whole cars, road edges, or the entire frame. They are a stylized
bright-source accent, not a validated physiological persistence model.

#### Scenario: pausing or changing levels
- **WHEN** the player pauses or switches levels
- **THEN** light histories do not grow during pause or leak into the new level

### Requirement: Grounded conditional autumn canopy
Overhead foliage SHALL belong to roadside tree crowns and appear only where
vegetation, road width, clearance and regional metadata permit it. It SHALL NOT
appear as a detached central arch or inside hard tunnels/bridge clearances. An
autumn sunset sample SHALL combine golden/brown foliage, restrained transmitted
light, dappled surface shading and wet leaf drifts near shoulders while preserving
readable pavement and traffic-cleared tracks.

#### Scenario: leaving the wooded autumn corridor
- **WHEN** the road reaches an open, built or tunnel section
- **THEN** canopy coverage thins or is excluded according to metadata without
  detached hanging foliage, and roadside vegetation remains coherently grounded

### Requirement: Lighting research and honest approximation
The [source ledger](../../../../../docs/research/level-lighting-scenery.md) SHALL
identify applied spotlight/emissive/wet-material/vegetation techniques and deferred
full volumetric, IES, normal-map or temporal-buffer approaches. Agent browser
inspection SHALL NOT be reported as human or physical-phone acceptance.

#### Scenario: reviewing the night proof
- **WHEN** reviewers compare the night levels
- **THEN** local lighting, glow, wetness and trail approximations are documented
  alongside backing pixels and measured frame scheduling
