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

## Default app and cruising road feel
The painted prototype becomes the public root; injected GameSession tests retain
the legacy receipt pipeline. Curve load now uses raw shared terrain curvature
times8, capped at.4, instead of saturating almost every bend with times55.
Gentle assistance enters at.018 and exits at.026 raw curvature, blending over.2s.
It cancels outward curve force with a small equivalent steering correction, never
reading a lane target. Both signs of intentional input remain additive. The wheel
and car receive the actual applied steering, including correction. Digital rise
is5.5 to4 units/s as speed rises; release7 units/s. These are local tuning values.
Earlier bends, stronger alternating peaks and more rollers alternate with longer
gentle sweeps; structural chapter distances remain fixed. Research/dispositions:
[cruising-road-feel](../../../docs/research/cruising-road-feel.md).

Road center integration uses a shared6x lateral presentation scale so strong bends remain visible at velocity framing; normalized curvature supplies bounded arcade steering load. Camera tangent, scenery and traffic use those same centers.

## Sequential mobile review and discoverable deployment
The default prototype advances Hudson→Indiana→Iowa→Ohio→Chicago→Arizona at
each120-second boundary. Reset outside the controller notification stack; clear
inputs and light histories, carry speed, retain prepared atlas variants, and
skip garage/departure. Stop after Arizona; replay restarts Hudson. Manual keys
and touch selection retain stage-local resets. This remains illustrative stage
playback rather than a surveyed campaign; physical-device review is still open.

Root package.json supplies npm run build, npm run deploy and a dry-run check.
Root wrangler.jsonc declares build.command, build/web assets, SPA routing and
the custom domain. Use an installed Flutter or a checksum-verified official
pinned Linux SDK when absent. Build locally/manual-publish; never enable push
hooks. Existing nested Pages config is a documented alternative, not the root
publisher target. API deployment remains separate and unverified.
