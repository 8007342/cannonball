# Design

## Context
See proposal.md. RaceGame currently grades the tunnel after all actors, hides
vegetation there and uses three centered canopy arches. ProofCourse is static;
the renderer already shares its projection with the controller and caches art.

## Goals / Non-Goals
Goals: six coherent packs, varied shared road generation, reusable painted asset
variants, illuminated night materials and a convincing first autumn composition.
Non-goals: certified automotive optics, full deferred renderer, verified road
atlas, online weather, new race receipts or wholesale art generation.

## Decisions
- A small immutable ProofLevel table owns seeds, terrain amplitude/phase, material
  palette, biome asset index, weather, sky and canopy/lamp flags. Six illustrative
  samples: Hudson daylight, Indiana golden canopy, Iowa prairie sunset, Ohio
  wooded night, Chicago wet night, Arizona desert dusk. They test composition;
  final campaign geography and names still require authored verification.
- A ProofTerrain adapter applies the level's coefficients consistently to both
  controller demand/elevation and projected road/objects. Keep chapter distances
  and shared collision coordinates. Level swaps are explicit review resets;
  normal campaign streaming remains independent.
- Reuse the approved painted art; cache three shared palette/material atlas variants for six levels
  once during loading and select ready images atomically. Tree-only autumn
  filtering preserves building/car colors. No broad glow key on painted pixels.
- Apply night ambient grade at material submission, with additive bounded
  directional light evaluated in road coordinates. Player and nearest NPC
  headlights, local lamps and wet-road response share a finite light budget.
  Emissive sources render with the actor depth ordering outside ambient grade.
  This avoids an end-of-frame blanket veil which dims all lights equally.
- Use spotlight angular cutoff/penumbra and range falloff from LearnOpenGL's
  explained model, adapted to road coordinates. HELLA informs steering/speed
  response, not literal S2000 adaptive hardware. IES profiles and full shadowed
  volumes are deferred. Light does not reach over an intervening terrain crest.
- GPU Gems glow informs separate bright cores/halos and short decaying source
  histories. Use explicit bounded emitter samples rather than framebuffer
  feedback, reset at discontinuities, suppress under reduced motion.
- Canopies use the same painted tree vocabulary, rooted beyond shoulders with
  larger overlapping crowns only in eligible wooded intervals. Open gaps and
  staggered crown heights prevent a repeating garland. Autumn material and
  roadside leaf patches follow deterministic world positions; wet glints are
  sparse and traffic tracks stay clear. Transmitted light is a painted-material
  approximation, not per-leaf subsurface scattering.
- Q–Y select levels,1–8 select chapters, Backspace restarts; keep arrows/touch
  steering. A compact popup supports touch and identifies the selected sample.

## Risks / Trade-offs
- Added local lighting/atlas work → fixed actor/light/history/cache limits and
  local timing/backing-pixel checks before claiming performance.
- One painted pack cannot represent six finished ecosystems → explicit sample
  label, per-pack asset selection and material changes; new production packs
  remain after moving approval.
- Trails/glows can obscure gaps → small, short source-only accents, depth clips,
  reduced-motion fallback, no full-frame blur or unbounded additive energy.
- Wet leaf appearance does not establish tire friction → keep physics weather
  explicit and existing calibrated effects; no railway coefficient transplant.

## Migration Plan
Proof-only changes on a durable work branch; local build/preview only. Keep
legacy runs/receipts and the previous commit available for comparison/rollback.
