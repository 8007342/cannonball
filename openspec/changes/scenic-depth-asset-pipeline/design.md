# Design

## Pipeline (art/, tool/assets/, licences/)
plan -> generate -> ingest -> finish -> pack -> contact sheet -> pick, as in
demon_attack. One GPU job at a time through `studio.run_workflow` (or
`image.generate` for FLUX.1-schnell); never concurrent GPU calls.

- `licences/register.md` + `licences/acknowledgements/*.yaml`: models approved
  by the user on 2026-11-20 (Apache/MIT set, SDXL OpenRAIL++-M, OpenRAIL-M LoRAs).
- `art/families/<family>.json`: style prompt, negative prompt, workflow,
  candidates, and items {id, prompt, seed(s), band, kind, worldWidthM, tags}.
- `art/workflows/*.json`: ComfyUI API-format graphs bound by `$prompt`, `$seed`,
  `$negative_prompt`, `$init_image`, `$control` titles.
- `art/rigs/`: bpy scripts building simple parametric structures (barn, house,
  bridge, lamp post, hydrant, overpass, car) and rendering clay/depth passes from
  the game's roadside camera; these guide Qwen-Image-Edit/ControlNet paint so
  rigid geometry keeps correct perspective. bpy runs CPU-only in the forge,
  venv under ~/.cache.
- Finishing is deterministic CPU code (Go or Lua; Python only for bpy/Pillow):
  key or BiRefNet matte, trim, downscale, palette caps, soft edge, atlas pack.
- Provenance: `art/families/<family>-runs.json` keyed `<id>/<seed>` with
  workflow, models, prompt, seed, output sha256, selected flag and pick reason.

## Runtime contract: assets/scenic/manifest.json
```
{ "version": "scenic-1",
  "atlases": [{"id": "veg-a", "file": "veg-a.png", "width": 2048, "height": 2048}],
  "sprites": [{
     "id": "oak-round-a", "atlas": "veg-a", "rect": [x, y, w, h],
     "anchor": [ax, ay],            // ground contact in rect pixels
     "worldWidthM": 9.0,            // real width; renderer maps metres to units
     "band": "near|mid|far|vista",  // offset band from the road edge
     "kind": "tree|shrub|grass|crop|structure|animal|furniture|sign|vista",
     "biomes": ["farm", "forest", "town", "city", "river", "plains"],
     "frames": ["oak-round-a"],     // optional animation (grazing, sway)
     "sway": 0.0, "collides": false, "nightEmissive": null
  }],
  "textures": [{"id": "asphalt-worn", "file": "road/asphalt-worn.png",
     "kind": "road|shoulder|sidewalk|ground|bridge-deck",
     "tileM": [7.0, 7.0]}] }
```
Bands (distance from road edge): near 0-6 m (hydrants, posts, mailboxes, signs,
fences, grass), mid 6-60 m (trees, houses, barns), far 60-600 m (farmsteads,
grazing cattle, silos, water towers, tree lines), vista >600 m (ridges, skylines,
mountains) drawn on a horizon layer with heading-driven slow parallax.

## Scheduling
Each level owns a zone list along course distance: zone {start, end, biome,
weights per sprite group, density envelope, quiet flag, set pieces}. Placement
is deterministic from (level seed, course distance), stable under camera and
flow changes. Quiet zones keep only road furniture and far/vista layers.
Asset choice uses recency exclusion so the same sprite does not repeat back to
back on the same side.

## Terrain
Per-level curve and elevation profiles instead of one shared course scaled by
`hills`/`curves`: hairpin-capable levels raise peak curvature and grade; calm
levels lengthen straights. Steering assist and safe speeds are checked so tight
curves are passable with braking.
