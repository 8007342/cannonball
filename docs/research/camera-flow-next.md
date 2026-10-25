# Lower-horizon camera and flow pass — 2026-10-25

## Evidence and applicability

- [SEGA's official 3D OutRun page](https://archives.sega.jp/3d/outrun/index.shtml)
  provides first-party screenshot references and documents selectable4:3/wide/full
  compositions plus optional cabin lean. It does not publish a lens model or
  establish that OutRun's horizon was exactly two-thirds down every frame. The
  requested lower horizon is our authored comparison, not a historical claim.
- [Köhler et al.,2023, Investigating the influence of visuospatial stimuli on
  driver's speed perception](https://pmc.ncbi.nlm.nih.gov/articles/PMC10499724/)
  reports two laboratory experiments manipulating roadside light motion. Their
  effects depended on competing cues such as reflector posts. This supports
  testing reference frequency and salience together; simply adding more sprites
  is not proven to increase our game's perceived speed without limit.
- [Unity's official Gate Fit documentation](https://docs.unity3d.com/Manual/PhysicalCameras-GateFit.html)
  distinguishes cropping, overscanning and stretching across aspect ratios. We
  apply the underlying composition lesson: preserve car proportions and screen
  contact while changing the camera, rather than stretching the rendered world.
  Our renderer is Flutter/Flame; no Unity runtime is introduced.
- Existing context: [course/camera](course-camera.md), [perceived speed](perceived-speed-milestone.md),
  [first speed follow-up](speed-and-score-followup.md), and
  [afterburn draft](../afterburn-draft.md). Sources are hypotheses/evidence rather
  than a universal chase-camera recipe. No exact OutRun drawing frequency or
  machine-dependent timestep is claimed.

## Authored implementation

`camera=flow` moves the flat horizon from.30 to2/3 of frame height, as requested.
`camera=wide` offers.48; `baseline` retains.30. Camera height is solved jointly
with projection so the player's ground contact remains at.876 of frame height
for every preset. This avoids pushing the player off the bottom when lowering
the vanishing point. Small camera lean pivots around that horizon. Backdrop,
sky, clouds, haze and road now share the same anchor.

A lower camera leaves less vertical road-preview room. The pitch response is
compressed to.48 of the shared grade pitch in flow mode, keeping its sign while
actual road elevation/occlusion remains unchanged. This is a readability choice
for human review, not a real driver's head-pose model. `camera=wide` remains a
less extreme compromise if the literal lower-third request feels too shallow.

`motion=hyperspeed` uses132 presentation units per simulation unit, versus84 for
`afterburn` (+57%). Prior presets remain comparisons. Scenery is world anchored,
interpolated and time-based. Near-road reflector sprites are slightly larger;
reference frequency follows world speed rather than frame rate. The road keeps180 segments but extends each to170 presentation units,
restoring traffic preview depth after the flow increase. Alternate distant
vegetation samples fade out before15000 units and are then omitted as a
silhouette LOD; the LOD boundary must not introduce a second pop-in edge. Sprite
counts and the road mesh stay bounded. No ranking time or car mph is fabricated.

The final24% of visible object depth fades smoothly from transparent to opaque,
quantized into8 opacity steps to retain atlas batching. Hazards become fully
opaque well before their contact zone. Existing depth tint remains, and a thin
horizon veil hides the finite road ribbon. These are distance camouflage tools,
not a claim of unlimited draw distance. New objects must not become solid at
the far clip plane. Bridges and quiet tunnel spans remain useful reference beats
between denser vegetation rather than making every segment a wall of trees.

Moving review must check traffic anticipation, crest occlusion, close scenery
aliasing, horizon comfort, mobile aspect ratios and actual render cost. Passing
geometry tests alone does not approve the new camera.
