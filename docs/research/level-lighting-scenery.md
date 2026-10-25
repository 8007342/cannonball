# Composed levels, night lighting and autumn canopy research

2026-10-25. The user requests Q–Y independent levels, bright moving car/lamp
lights, steering headlights, richer night scenery and an Indiana/Iowa-inspired
sunset foliage tunnel with golden/brown leaves and wet shoulder accumulation.
The six level themes are illustrative composition choices, not verified roads.

## Diagnosis and application

The previous `RaceGame._courseAtmosphere` paints a blanket tunnel veil after cars,
so car lights darken with everything else. `vegetationAllowedAt` also removes
vegetation in the tunnel. Three centered canopy arch sprites do not belong to
the roadside tree geometry. Fix material/occlusion/layer ownership before adding
larger glow blobs. Separate ambient grade, incident illumination, emissive cores,
soft halos and short temporal accents. Preserve the shared road projection.

| Source | Apply | Deferred/excluded and limits |
| --- | --- | --- |
| [Ranitas visual-envelope audit](https://github.com/8007342/ranitas/blob/main/docs/visual-envelope.md), [design](https://github.com/8007342/ranitas/blob/main/openspec/changes/visual-envelope/design.md) | Keep emissives independent from night grading; material-aware palettes, explicit layer slots, bounded caches and readable central lane. | Its early masks missed real lantern/fungus sources and keyed reflections/petals. Do not use global brightness keys as a substitute for authored lamp positions. Pond color matrices alone cannot illuminate a driving road. |
| [Ranitas layer implementation](https://github.com/8007342/ranitas/blob/main/lib/game/scene_layers.dart) and [foliage](https://github.com/8007342/ranitas/blob/main/lib/game/foliage.dart) | Reuse seeded placement, bounded sway, atlas batching and clear-lane metadata concepts. | Do not paste hanging corner strands onto every biome; roadside canopy requires trees, plausible span, height, open gaps and tunnel/bridge exclusions. |
| [LearnOpenGL: light casters](https://learnopengl.com/Lighting/Light-casters) | Explained spotlight dot-product cutoff/penumbra and distance attenuation inform local road-coordinate beams and surface response. | Adaptation to2.5D; no claim of per-pixel normals, physical lux or complete shadow maps. A screen-centered radial wash is not a steering headlight. |
| [HELLA bend lighting](https://www.hella.com/techworld/us/technical/automotive-lighting/bend-lighting/) | Steering/speed-dependent direction and smooth transitions inform bounded beam aim and optional corner spill. | Real system numbers are not arcade defaults; the S2000 is not claimed to have this production hardware. No legal/road-safety claim. |
| [Epic: IES profiles](https://dev.epicgames.com/documentation/en-us/unreal-engine/using-ies-light-profiles-in-unreal-engine) | Reference for shaped lamp distributions and distinct luminous source/illumination. | Full photometric file support deferred; existing browser renderer needs a small authored lobe, not an Unreal dependency. Engine-specific cost claims are not ours. |
| [GPU Gems21: Real-Time Glow](https://developer.nvidia.com/gpugems/gpugems/part-iv-image-processing/chapter-21-real-time-glow) | Separate luminous cores and halos; short dimmed source histories convey a stylized afterimage. Use bounded timestamps and reset on swaps. | Full-screen feedback/bloom buffer deferred. Long ghosts obscure steering and are not a validated model of human persistence of vision. No frame-count-dependent trails. |
| [GPU Gems3,13: volumetric scattering](https://developer.nvidia.com/gpugems/gpugems3/part-ii-light-and-shadows/chapter-13-volumetric-light-scattering-post-process) | Reference for sparse transmitted sun shafts through foliage and the need for occlusion. | Full radial-blur scattering deferred: screen-space shafts can leak in front of foreground objects, flicker at boundaries and cost fill rate. A few bounded canopy-local accents are an art approximation. |
| [GPU Gems3,16: Crysis vegetation](https://developer.nvidia.com/gpugems/gpugems3/part-iii-rendering/chapter-16-vegetation-procedural-animation-and-shading-crysis) | Separate main bending, finer detail, per-instance phase and two-sided leaf-lighting concepts. Use the existing painted foliage vocabulary and rooted crowns. | Per-leaf normal/subsurface rig needs new separated art; this sample's warm transmission is a material approximation. Do not animate every leaf with independent primitives. |
| [GPU Gems7: grass](https://developer.nvidia.com/gpugems/gpugems/part-i-natural-effects/chapter-7-rendering-countless-blades-waving-grass) | Cluster instancing and distance detail motivate sparse grounded shoulder leaves. | Full intersecting3D grass planes are unnecessary in the current atlas/mesh renderer. |
| [Lagarde: physically based wet surfaces](https://seblagarde.wordpress.com/2013/03/19/water-drop-3a-physically-based-wet-surfaces/) | Wet material darkening and concentrated reflection motivate darker asphalt and sparse elongated lamp/sunset glints, with dry/wet response separated. | No full PBR BRDF, screen-space reflections or arbitrary white floor overlay. Leaf texture and water are separate material cues. |
| [US Forest Service: why leaves change color](https://www.fs.usda.gov/Internet/FSE_DOCUMENTS/stelprd3817419.pdf), [NOAA fall color](https://www.noaa.gov/stories/cool-autumn-weather-reveals-nature-s-true-hues), [Smithsonian](https://www.si.edu/stories/why-do-leaves-change-color-fall) | Mixed yellow/orange/brown with residual green; variation between trees and warm low sunlight inform the autumn pack. | Pigment science does not specify artistic alpha/glow or establish exact Indiana/Iowa road species. No seasonal simulation or live foliage feed. |
| [Forest Landscape PDF](https://research.fs.usda.gov/treesearch/download/23991.pdf) | Its indexed description identifies road canopy enclosure as a landscape composition device; background reference only. | Full text was not analyzed for numeric canopy rules; no precise clearance or frequency claim is derived from it. |
| [Leaf-layer friction paper](https://pmc.ncbi.nlm.nih.gov/articles/PMC7426055/) | Not used for tire physics. | Wheel–rail friction is a different material/contact regime. Do not transplant its coefficients to rubber/asphalt. Shoulder drifts and cleared tracks follow the user's observed scene and authored composition. |
| [PBRT: surface reflection](https://www.pbr-book.org/3ed-2018/Color_and_Radiometry/Surface_Reflection), [Stanford layered subsurface model](https://vis.stanford.edu/papers/subsurface/) | Reference for the distinction between surface reflection and transmitted/subsurface light. | Full BSSRDF/layered transport is deferred; this painted2.5D proof does not have per-leaf geometry/thickness and cannot claim physically accurate leaf transmission. |

## Intended review compositions

Q Hudson daylight: green roadside trees, blue sky, gently rolling approach.
W Indiana golden canopy: warm sunset, rooted crowns, mixed gold/brown trees,
dapple and wet shoulder leaves. E Iowa prairie sunset: open skyline, fewer trees,
long broad rollers and sparse rural lamps. R Ohio wooded night: readable cool
silhouettes, headlight sweeps, red traffic cores and occasional warm lamps.
T Chicago wet night: denser roadside structures, wet reflections, signals and
more lamps. Y Arizona desert dusk: dry warm ground, sparse non-canopy vegetation,
different curves/grades and twilight lighting. These names describe illustrative
packs, not verified local species, junctions or a finalized route itinerary.

## Implementation and review limits

Cap local light sources and emitter history. Clear trails on discontinuity;
freeze time under pause; suppress decorative trails under reduced motion.
Headlights and lamp pools must use road coordinates and terrain visibility,
not illuminate across a crest or through a tunnel wall. Light cores are not
darkened again after material grading. Brake brightness and tail running lights
remain distinct. Scenic signals do not introduce unspec'd stop rules.

Asset variants reuse original approved paintings and provenance indexed in the
[reference register](reference-register.md). Cache count/decoded memory and actual
canvas dimensions must be reported, not inferred from file size. Repeated level
swaps must not accumulate resources. Timing is local browser scheduling/CPU
evidence, not displayed FPS or a phone benchmark. Human/phone comfort, exact art,
full volumetric/PBR/IES rendering and nationwide geography remain open.
