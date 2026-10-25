# Second visual proof renderer

The S2000 proof selects `assets/proof-next/s2000-atlas.png` while the prior
Corvette proof keeps its original sheet. Both share the projected road renderer.
Per-pose alpha bounds are measured once during loading to anchor the uneven
source frames at tire contact; source cells keep a half-texel sampling inset.
Some source poses touch their cell edges, so these remain draft sheets.

Signed high-speed skids use the right-skid source and a horizontal reflection for
left steering. Gentle left/right steering uses its own authored cell. Reflection
also reflects the center pivot; clipping and shadow grounding remain independent.
`vehicle_pose_test.dart` covers signed high-speed selection and steering/slope
precedence.

## Speed and world composition

`RaceGame.setSpeedPreset` accepts `classic`, `cruise` and `arcade`. The S2000's
optical flow multipliers are 1, 1.3 and 1.7 times the earlier 12x presentation
scale. Switching presets offsets the presentation origin rather than teleporting
the scenery. Simulated speed, route distance, timing and receipt rules do not
change. The S2000 camera also uses a wider geometric projection and revised
height/trail, with small near-road reflectors adding peripheral references.
These are tuning candidates, not evidence of measured improvement in human
perceived speed. Root integration owns moving review and browser frame samples.

The new proof uses the actual route biome for its label and first city-to-forest
composition boundary, aligned to the initial corridor's physical end. This avoids
announcing forest while still showing the timed demonstration's unrelated city.
Weather rendering reads actual controller rain/snow; it does not roll another
weather event. Prior Corvette proof composition remains unchanged.

An auxiliary right-side joining ribbon shares projection and hill clipping with
the main road. Its center converges smoothly and width tapers to zero, with road
edge markings and separator cones. It is an **NPC-only scenic geometry sample**,
not a selectable fork or a connected simulated merge lane. Actual construction
cones use the controller's closed-lane and worksite positions. Playable forks,
real ramp-linked NPC routes and multi-deck interchange navigation need explicit
lane topology beyond this proof; an image of a bridge is not that capability.

## Palette variants and reactions

The loader downsamples the straight rear cell to 256px and prepares eight body-
paint variants in one 2048x256 traffic atlas. It does not tint the whole car.
The draft mask uses red body chroma, a body region and explicit rear-lamp/cabin/
tire exclusions; a production source should export an authored paint mask.
Recoloring preserves alpha and premultiplied color bounds. Regression tests
preserve rear lights, glass, tires and transparent samples byte for byte.
Variants share the same S2000 silhouette; vans and trucks require separate art.

The controller's actual traffic `x` includes its flinch movement, so the renderer
does not add the reaction offset twice. `paintVariant` selects paint, `braking`
adds rear glow, and `incidentSeconds` animates a bounded body yaw. The physics
controller owns reaction/incident causality and collisions. The palette atlases
are decoded/prepared once; no pixel processing happens in the render loop.

## Verification boundary

`vehicle_pose_test.dart`, `paint_palette_test.dart` and
`proof_road_module_test.dart` target the directional regression, paint exclusions
and monotonic continuous ramp geometry. Existing renderer tests cover timing/reset
and disposal. The sibling worktree cannot invoke this forge's mounted Flutter
runtime, so root integration runs the analyzer/tests/build against cherry-picked
checkpoints. Physical phone, art acceptance, final camera and native presenting
frame measurements remain separate checks.
