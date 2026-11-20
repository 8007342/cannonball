# Scenic integration review — 2026-11-20

Branch `work/scenic-asset-pipeline`. I reviewed it in the local release preview
(`flutter build web --release`, headless Chromium at 1280×720). Each level ran
from several chapter starts, with a scripted lane-keeping and overtaking pilot
driving through `window.CannonballProof.drive`. These are desktop-emulation
captures only. Phone and user moving review (task 4.2) is still open.

| Shot | What it shows |
|---|---|
| `1-hudson-continuous-vista.png` | Hudson start: one continuous feathered horizon with a ground-haze foot |
| `2-indiana-passing-racer.png` | Electric roadster (key card) overtaking a red sedan in the Indiana autumn sweepers |
| `3-iowa-far-farm-cattle.png` | Iowa: far farmstead, silo, windmill and grazing cattle in front of the prairie vista |
| `4-ohio-night-hairpin.png` | Ohio at night, mid-hairpin: the road now visibly bends away |
| `5-chicago-rain-night.png` | Chicago in rain after dark (the start of the city grid) |
| `6-arizona-canyon-hairpin.png` | Arizona canyon hairpin: dirt desert floor, mesas, a saguaro stand and a white traffic roadster |
| `7-roadster-hudson-bridge.png` | Roadster on the Hudson plank deck between water, with a neighbouring stone-arch bridge |
| `8-ohio-crest.png` | Ohio BLIND CREST after the relief pass. Top: at about 1640 the road climbs as a wall into the sky. Bottom: at the crest (about 1840) the road drops out of sight just ahead, and the vista shows beyond |
| `9-indiana-valley.png` | Indiana, climbing out of the 500–900 dip at about 870: the road rises far up the next swell |
| `10-roadster-door.png` | The roadster departure door shot, re-rendered: white painted door edge, dark trim panel with armrest, pocket and speaker |

## What works
- Depth reads well. Near furniture, mid trees and houses, the far band (farmsteads,
  cattle, water towers, tree lines) and the vista sit in a believable order.
  Quiet zones do drop to road plus distance.
- Traffic gives you racers to pass, and the white traffic roadster and other models
  show tail and brake lights. With traffic avoidance the pilot finished every run
  without a crash.
- Night levels tint the vistas and haze, and the street lamps glow.
- The console showed no errors during the whole session.

## Fixed in this review
1. **Vista rectangles.** `pack` now feathers 14 % of each side of every vista. The
   strip uses 8 overlapping panels instead of 5 spaced ones, at a closer metric
   scale with a height cap of 20 % of the screen. A ground-haze foot
   (`ScenicDraw.foot`) fades the bottom edges and the painted foregrounds into the
   terrain, and far-band sprites draw on top of it. The foot darkens at night and
   turns dusty over the Arizona dirt.
2. **Grey band in the right verge.** This was the free-road proof's periodic slip
   road (`ProofJoiningLane`), with its cones. It appeared in every course level with
   no junction, and it ran across the sidewalks. Course levels no longer draw it.
3. **Keychain on a blank screen.** The garage hides both keychains until the key-box
   wall image has decoded. A widget test covers it.
4. **Sprite batches.** `BillboardBatch` now queues sprites and, at each flush, lets a
   sprite join an earlier batch with the same atlas, blend and opacity only when its
   screen bounds overlap nothing drawn in between. The output is identical to painter
   order (unit-tested). Peak batches per level: Chicago 85 → 59, Hudson 75 → 51,
   Indiana 70 → 44, Ohio 65 → 41, Iowa 52 → 35, Arizona 52 → 34. The budget test
   now requires fewer than 70.
5. **Proof oak sliced by its cell.** The canopy reaches past its 512 px atlas cell,
   which left a vertical cut. The frame is now 572 px wide and drawn centred on the
   cell.
6. **Hairpins read as gentle sweepers.** A faithful projection moved a 140 m hairpin
   only about 60–90 px. Curvature above the corner threshold is now drawn 2.2× more
   strongly. This only changes the picture: physics demand is unchanged, and Hudson's
   legacy bends are untouched (tested).
7. **Wrong geography.**
   - The Rocky Mountains vista appeared in Indiana and Ohio forest zones; it is now
     desert-only.
   - Palms showed up in Chicago, Hudson and Ohio, and mesas, juniper, sagebrush,
     creosote and a desert ranch could appear in Iowa's "plains" zones. All of these
     are now desert-only.
   - The Arizona floor was green meadow; it now uses the red dirt texture.
8. **Far set-piece ground slabs.** These had hard bottom corners. `pack` now feathers
   the foot and lower corners of non-animal far sprites, after the anchor is measured.
9. **Bridges.**
   - Side-elevation bridge sprites stood at the deck edge as camera-facing billboards,
     so a 27–36 m arch wall covered the whole road, or covered bridges sat beside it
     like sheds. They are now neighbouring crossings, 34–42 m up- and downstream.
   - The plank deck showed a chevron pattern from affine texture distortion. Surface
     strips near the camera now split into up to 4 lateral columns (mesh capacity
     doubled).

The pack is still deterministic: two `pack` runs give byte-identical output. The
runtime atlas size is 14.3 MB against a 16 MB budget.

## What remains (not fixed here)
- **Plank deck.** Still a little wavy right in front of the car. Fixing it fully
  needs perspective-correct UVs or finer depth segments.
- **Bridge structures.** Only the plank or steel deck, the parapets and the
  neighbouring bridges suggest a bridge. There is no truss or arch you drive *through*:
  that needs non-billboard geometry, such as a deck-edge mesh with a repeating side
  texture.
- **Chicago at night.** The skyline vista is only a faint silhouette, with no lit
  windows (`nightEmissive` isn't used for vistas). The near city zone still reads as
  suburban: trees, a billboard and a gas station.
- **Hills (after the polish pass).** Desktop emulation only: the comfort of the bigger
  pitch swings still needs a moving review on a phone. Behind a crest, the backdrop
  haze foot shows as a pale band, and one far sprite has an unfeathered side edge
  (Indiana, near the 300 crest).
- **Night horizon haze.** The haze between the vista and the ground is still a pale
  band at night. Darker would be better, but it now reads as mist rather than a gap.
- **Unverified.** I didn't check radio programme audio (the window is headless) or
  phone performance with the doubled surface-mesh capacity.

## Polish pass (hills, asphalt scale, roadster door)

These are desktop headless captures (1280×720) of the rebuilt release preview. I
didn't commit anything.

1. **Much more noticeable hills (presentation only).**
   - `LevelProfile.relief` multiplies the crests and dips, and `riseRelief` the
     long climbs: Indiana 9/1, Ohio 6/2.5, Arizona 6/3, Iowa 1.8 (still calm),
     Hudson and Chicago 1. Before this pass, a 1500-unit crest at the velocity
     flow scale moved the road only about 20 px.
   - The road, the ground, scenery, traffic, light occlusion and the camera all use
     `ProofTerrain.visualElevationAt`. The controller's grade, speed and steering
     still use the raw `elevationAt`, which is tested.
   - Hilly levels now use a soft-limited camera pitch (tanh, maximum .26, follow
     1.1). Hudson and Chicago keep the old linear ±.24 exactly. Comfort mode
     applies half the relief.
   - The ground now reaches the screen edges at every depth, so a raised crest
     reads as a hillside, not a ribbon in front of the sky.
   - The horizon veil follows the ribbon's far end instead of crossing the
     hillside.
   - The player car is never crest-clipped. A test keeps every visual slope below
     the camera-height/trail limit.
   - New tests in `test/terrain_relief_test.dart` check the screen-space road rise
     at the Ohio crest, sight lines over the crests and down into the Indiana dip,
     the hilly-versus-calm ordering, comfort mode, determinism, and that Hudson is
     unchanged. A pitch-step bound was added to the terrain-profile test.
2. **Worn asphalt scale.**
   - `tileM` values, in both the manifest and the family spec: asphalt-worn 6 → 2.8 m,
     concrete 4 → 7.2×9 m (lane-wide slabs whose joints sit on the lane lines through
     `SurfaceMeshes.laneOffsetM`), brick 3 → 1.6 m, cobblestone 3 → 2 m, plank deck
     3 → 2.4 m.
   - Surfaces sample with mipmaps (`FilterQuality.medium`), so distant detail fades
     to its mean colour instead of sparkling.
   - The zone default is now fresh asphalt. Four rural zones use worn asphalt,
     drawn at 55 % over a fresh base, so they read as wear rather than a shattered
     road. Tested in `test/road_texture_scale_test.dart`.
3. **Roadster door.**
   - `SceneCar.open_door` now solidifies the cut door. The outer skin and edge keep
     the toon body paint. The inside is a darker trim panel with an armrest, grip,
     map pocket, insert, sill, chrome release and speaker, and the window frame
     turns to dark trim.
   - I re-framed the door camera in `poses.json`.
   - I re-rendered with `lua art/rigs/cars/run.lua scenes`. Only
     `electric_roadster-entry.png` changed, along with the hashes and sources in
     `electric_roadster-scenes.json`. The exterior and cabin renders came out
     byte-identical.

Checks I ran: dart format, flutter analyze, flutter test (220 tests),
`flutter build web --release`, `openspec validate --all --strict`,
`node --test web/*.test.mjs`, and the services/api test and check (dry run).
