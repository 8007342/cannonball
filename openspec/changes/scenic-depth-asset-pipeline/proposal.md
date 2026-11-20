# Proposal

## Why
The demo sequence reads speed by pushing many copies of six roadside sprites past
the camera. The user asked for a larger locally rendered asset library, much more
noticeable hills and tight curves, and depth: distant farms and grazing cattle that
drift slowly, quiet stretches where the road alone carries the drive, and road
surface, sidewalk, bridge and vegetation variety. Cannonball is also the
Tillandsias testbed for an easy-to-update, end-to-end local asset pipeline
(ComfyUI studio, headless Blender, deterministic finishing) modelled on the
sibling demon_attack project.

## What Changes
- Add a local, reproducible asset pipeline: licence register, family specs,
  committed ComfyUI workflows, Blender (bpy) geometry rigs for rigid objects,
  deterministic finishing (matte, trim, palette, pack), contact sheets,
  provenance ledgers and a runtime manifest. Tools follow Lua > Rust > Go.
- Generate an agent-picked scenic pack (user-approved gate, overridable):
  vegetation, farms/animals, houses/businesses, street furniture, bridges and
  structures, distant vistas, and tileable road/shoulder/sidewalk textures.
- Render scenery by depth band (near / mid / far / vista). Far and vista objects
  use slow, distance-correct parallax instead of sweeping past at road speed.
- Replace stride-based copies with scheduled scenic zones: per-level weighted
  sets, density envelopes, quiet road-only stretches and authored set pieces.
- Per-level terrain variety: steep hills and tight hairpins on some levels,
  calm rolling straights on others, with braking-relevant curves.
- Road surface, marking, shoulder and sidewalk variants per level and zone.

## Capabilities
### New Capabilities
- (none; extends existing capabilities)
### Modified Capabilities
- `art`: local asset pipeline, provenance, depth-banded scenic library.
- `review-levels`: per-level terrain character, scenic zones and road variants.

## Impact
New `art/`, `licences/`, `tool/assets/` and `assets/scenic/`; renderer scenery,
road surface and course code under `lib/game/`; tests. Committed runtime art is
budgeted (atlases <= 16 MB total, picked raw sources <= 60 MB) because the
checkout lives on a small tmpfs. No native app, cloud, ranking or deployment
change. Agent-picked art is review material, not final production acceptance;
physical-phone review remains open.
