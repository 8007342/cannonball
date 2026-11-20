# Grounding and hairpin handling review (2026-11-20)

Branch `work/smooth-soundtrack-grounding`. This responds to user feedback after
the scenic review: *"the background, and a few of the larger assets are just
floating around"* and *"the turns caused some clipping and were hard to play at
least with the mouse on desktop"*.

The captures come from the local release preview (`flutter build web
--release`) in headless Chromium at 1280×720, scaled to 960×540. They are
desktop emulation only. Phone review is still open. Nothing is committed.

| Shot | What it shows |
|---|---|
| `1-before-arizona-climb.png` / `1-after-…` | Arizona switchback climb. Before: the ground ends well below the horizon, and mesas, a saguaro stand and the vista hang over a pale haze band. After: the terrain continues to the horizon, and the same sprites and vista stand on it. |
| `2-before-arizona-roadside.png` / `2-after-…` | Arizona about 1500. Before: a gas station, billboard and saguaros float in the haze. After: they stand on the hazed far ground. |
| `3-after-ohio-crest-wall.png` | The Ohio blind-crest wall at night. The far tree line now sits on the crest top. Compare `../scenic-2026-11-20/8-ohio-crest.png` (top), which has a pale band there. |
| `4-after-ohio-beyond-crest.png` | Past the Ohio crest. The vista and tree lines meet the ground without a gap. |
| `5-after-indiana-valley.png` | The Indiana valley (relief ×9). Beyond the road mesh the far ground climbs up the next swell, and the hedges, tree lines and vista stand on it. |
| `6-after-ohio-hairpin-night.png` | Inside the first Ohio hairpin, after the change: chevron and grounded far band. |

## Root causes found
1. **The terrain ended at the road mesh (about 330 course units ahead).**
   Far-band sprites stream up to 1500 units ahead, so most of them were placed
   past the end of the terrain, over the horizon haze. Their anchors were
   correct, at the exaggerated road elevation for their own `s`, but no
   ground was drawn under them. The vista strip sat at a fixed
   `horizon + 5 %`, and the opaque haze foot and veil filled the gap between
   the strip and the end of the mesh. That gap is the "pale band behind
   crests", and it grows on descents and dips with relief ×6–9.
2. **Steering was cancelled by the brake key.** Any key event recomputed the
   steering from the arrow keys. Pressing or releasing Down while dragging the
   rim with the mouse snapped the steering to 0. I confirmed this in the
   browser over CDP.
3. **Full mouse lock was out of reach on screen.** On desktop the rim sits at
   the screen edge, and only about ±0.6 rad of it is visible. Full lock
   needed 0.85 rad, so a drag from mid-height reached only about 0.66 steering.
4. **Hairpin margins were small for imprecise input.** Before this change, a
   pilot with a 0.3 s reaction, a bounded steering rate and moderate braking
   (to 80 %) left the road by up to 0.25–0.34 half-widths in Ohio and Arizona.
   It spent 1–2 s off the road at 37–55 mph, which looks like the car cutting
   through the roadside furniture and scenery.

I found no road or ground mesh tearing in the captures. If the user's
"clipping" meant something else, we still need their description.

## Changes
- **Far ground** (`RaceGame._projectTerrain`, `_drawFarGround`). This adds 36
  geometric depth samples from the end of the mesh to the end of the far band,
  plus a skirt to the horizon. They use the same projection and exaggerated
  elevation and share one crest-clip chain with the mesh.
  - It is drawn in the ground textures' mean colour
    (`ScenicLibrary.measureSurfaces`) and fades toward the distance haze. The
    mesh's last 28 strips fade into it.
  - The colour has no local lights, so lamps never flicker the horizon.
  - The vista and fallback hills stand on the furthest ground line. Their foot
    fades into that ground's colour. The old veil and haze band are gone on
    course levels.
- **Handling** (`RaceController`).
  - Steering into a marked hairpin cancels up to 22 % of its extra demand.
  - The shoulder pushes back by up to 0.9 half-widths/s beyond the edge.
  - At top speed without braking the car still leaves the road (existing
    test).
- **Warnings.** The radio warning now comes 60–340 units out (about 4 s). Four
  curve or chevron signs stand 200, 130, 80 and 35 units before each hairpin.
- **Input.**
  - Mouse rim drags reach full lock in 0.45 rad. Touch keeps 0.85.
  - Only the arrow keys change keyboard steering.

## Tests added
- `test/scenic_grounding_test.dart` covers Ohio, Indiana and Arizona crests,
  dips and hairpins. Every visible scenic anchor in every band must lie on a
  camera-facing drawn ground segment within 2 px, and never above the ground
  top. The vista base must sit on the far ground. It fails when the far ground
  is removed.
- `test/mouse_pilot_test.dart` covers a reaction-delayed, rate-limited pilot
  that only brakes moderately. The average profile stays on the road with no
  crash in all six levels, and a slower profile only brushes the shoulder.
  The run is deterministic, and the assist and edge return stay bounded.
- `test/mouse_rim_brake_test.dart`: the Down key no longer zeroes rim steering.
- `test/wheel_test.dart`: mouse full lock is reachable, and touch gain is
  unchanged.

## Still open or unverified
- **No human drove a hairpin with a mouse.** The tool round trip is 1–2 s, so a
  CDP-driven hairpin run crashed from late inputs. It only confirmed that the
  rim steering survives the brake key. The playability evidence comes from the
  simulated pilots. Phone touch and tilt are untested.
- **Far ground seam.** A faint tone step can remain where the textured mesh
  meets the far ground, for example in the Indiana valley. The mean texture
  colour only approximates the mip-mapped GPU result.
- **Art.** Far set pieces with painted pale ground slabs (the Arizona saguaro
  stand) still read slightly as islands. The art needs a feathered or
  terrain-coloured foot.

Checks run: dart format, `flutter analyze`, `flutter test` (228 tests),
`flutter build web --release` and `openspec validate --all --strict`.
