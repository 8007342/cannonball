## ADDED Requirements
### Requirement: Reproducible local asset pipeline
Generated art SHALL come from committed family specs and workflows run on local
models whose licences are recorded in the licence register. Each shipped sprite
SHALL trace to a provenance record (workflow, models, prompt, seed, output hash,
pick reason). Finishing and packing SHALL be deterministic from committed
picked sources, so a family can be re-packed or extended without regeneration.

#### Scenario: adding a new roadside prop
- **WHEN** a builder adds an item to a family spec and runs the pipeline
- **THEN** candidates are generated locally, a pick is recorded with provenance,
  and the repacked atlas and manifest include the prop without hand editing

### Requirement: Depth-banded scenery
Scenery SHALL be assigned a band (near, mid, far, vista) by distance from the
road. Far and vista objects SHALL move with slow, distance-consistent parallax
and SHALL NOT sweep past at road speed. Rigid structures SHALL keep perspective
consistent with the roadside camera.

#### Scenario: passing a distant farm
- **WHEN** the car drives past a farmstead with grazing cattle placed in the far band
- **THEN** the farm stays visible for several seconds while drifting slowly,
  while near furniture passes quickly

### Requirement: Varied scheduled scenery
Scenery SHALL be selected from a varied library by deterministic per-level zones
with density envelopes, recency exclusion and quiet road-only stretches, rather
than repeating one sprite at a fixed stride.

#### Scenario: quiet stretch
- **WHEN** the course enters a quiet zone
- **THEN** only road furniture and far/vista layers remain and the road alone
  carries the sense of motion
