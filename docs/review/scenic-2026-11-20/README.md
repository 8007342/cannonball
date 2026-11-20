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
- **Roadster departure door shot.** The door-opening cell of the electric roadster's
  entry atlas renders untextured grey door slabs. This needs a re-render in the car
  rig pipeline; the renderer can't fix it.
- **Plank deck.** Still a little wavy right in front of the car. Fixing it fully
  needs perspective-correct UVs or finer depth segments.
- **Bridge structures.** Only the plank or steel deck, the parapets and the
  neighbouring bridges suggest a bridge. There is no truss or arch you drive *through*:
  that needs non-billboard geometry, such as a deck-edge mesh with a repeating side
  texture.
- **Chicago at night.** The skyline vista is only a faint silhouette, with no lit
  windows (`nightEmissive` isn't used for vistas). The near city zone still reads as
  suburban: trees, a billboard and a gas station.
- **Hills.** Crests and climbs are present but mild on screen. Unlike the curves, I
  didn't exaggerate elevation; worth a moving review on a phone.
- **Night horizon haze.** The haze between the vista and the ground is still a pale
  band at night. Darker would be better, but it now reads as mist rather than a gap.
- **Unverified.** I didn't check radio programme audio (the window is headless) or
  phone performance with the doubled surface-mesh capacity.
