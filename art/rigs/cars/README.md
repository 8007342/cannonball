# Car rigs (player sheets, traffic atlas, garage key card)

Parametric car bodies built in headless Blender (`bpy`, see `../README.md`), rendered from
the game's rear chase camera with a stylised cel material set, then assembled on the CPU.

| File | Role |
| --- | --- |
| `cars.json` | one entry per car: dimensions, body profile curves, cabin type (open / closed, glass or painted roof), bed, lamps, plate, exhaust, spoiler, mirrors, wheel style, paints, `use` (player / traffic), `sporty`, `large` |
| `poses.json` | the camera and every pose's yaw / FRONT-wheel steer / roll / pitch; mirrored in `lib/game/render/vehicle_pose.dart` (`VehiclePoseGeometry`, kept equal by `test/car_pose_geometry_test.dart`) |
| `car_rig.py` | builds the car (body loft + arch, cockpit and bed cuts, greenhouse, decal-projected lamps, separate wheels on hubs) and renders the poses, hero passes (clay, hint, depth) and the key card |
| `run.lua` | entry point; `tool/rigs/cars/main.go` assembles atlases, `assets/cars/manifest.json` and `art/contact/cars.png` |

    lua art/rigs/cars/run.lua all        # ~2 min CPU (8 threads): renders + key card + assemble

Renders stay in `~/.cache/tillandsias-project/cannonball-art/cars/renders`; only `assemble`
writes the checkout (about 3 MB).

## Wheels and steering

Only the two front hubs rotate about their kingpins (`steer`). Rear wheels are rigid
children of the car root, so they stay aligned with the body in every pose. Yaw and pitch
pivot on the ground under the rear axle (the chase camera follows the tail), and roll leans
the body out of the turn over planted wheels. The previous image-generated S2000 sheets
showed rear wheel faces swinging out under a square body, which read as rear steering.

## Contract

Player sheets: 3 x 2 cells of 512 px, `body` = flat, left, right, uphill, downhill,
right-skid; `turn` = gentle/medium/strong x left/right. The flat pose is 432 px wide with the
tyres on y 448, matching the hand-painted S2000 sheet, and every pose of a car shares that
scale and ground line (each is centred on its own silhouette; the renderer measures anchors).
Traffic: `traffic-atlas.png`, 8 columns of 256 px cells, cell = model row x 4 + paint, the
same contract at half size. Brake-lamp offsets come from the rig's projected lamps.

## Look

Emission-only cel shading in Cycles: three soft-edged light bands (cool shadow, mid, warm
lit) from a fixed upper-left light, a hard specular band, a fresnel sky reflection and an
inverted-hull outline. No logos, badges, wordmarks or plate text; names in game are generic
(`lib/game/car_catalog.dart`). A Qwen-Image-Edit hero repaint (`run.lua hero ID`, then
`art/workflows/structure-paint-qwen.json` with `beauty` + `depth`) was evaluated; the shipped
pixels are the rig's own shading because the cel renders stay consistent across poses.

## Add a new car in 3 steps

1. Add an entry to `cars.json` (copy the closest car; set `id`, `use`, `paints`, and the
   body, cabin, lamp and wheel parameters). Traffic models also get `sporty` or `large`.
2. Run `lua art/rigs/cars/run.lua all` and check `art/contact/cars.png`.
3. Add the model to `CarCatalog.traffic` (next `row`, paints and lamp offset from
   `assets/cars/manifest.json`) or to `CarCatalog.players` for a playable car, then run
   `flutter test test/car_catalog_test.dart`. A ninth traffic model adds a fifth atlas row.
