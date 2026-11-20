# Family specs (`art/families/<family>.json`)

A family is one batch of related assets that share a style prompt and a
workflow. `tool/assets` (`go run ./tool/assets <verb>`) reads every
`art/families/*.json` except `*-runs.json` (provenance ledgers) and this file.
The runtime contract the specs feed is `assets/scenic/manifest.json`
(`openspec/changes/scenic-depth-asset-pipeline/design.md`).

## Family fields

| Field | Required | Meaning |
|---|---|---|
| `family` | yes | Family id; must equal the file name stem. Picks live in `art/sources/<family>/<id>.png`. |
| `type` | yes | `sprite` (RGBA cut-out, goes into an atlas) or `texture` (opaque tileable, goes to `assets/scenic/road/<id>.png`). |
| `atlas` | sprite | Atlas group prefix, e.g. `veg`. `pack` fills `veg-a`, `veg-b`, ... (each <= 2048x2048) in a deterministic order. Several families may share a group. |
| `workflow` | no | ComfyUI API workflow under `art/workflows/` used by `plan`. Omit for families made outside the studio (Blender structures). |
| `style` | no | Text appended to every item prompt (`<item prompt>, <style>`). |
| `negative` | no | Negative prompt (ignored by distilled FLUX models, used by SDXL). |
| `candidates` | no | Candidates per item (default 3). Seeds are `seed, seed+1, ...`. |
| `canvas` | no | `[w, h]` generation size override (`$node:` overrides of the canvas node). |
| `key` | no | Flat background colour `[r,g,b]` the prompt names (default white `[255,255,255]`); used to de-fringe matte edges. |
| `sourceMax` | no | Longest side of committed picks in px (default 512; textures 512; vistas 1536). |
| `colorLevels` | no | Per-channel posterize levels at pack time (0 = off). |
| `matte` | no | `birefnet` (default: use the workflow matte output) or `skyline` (deterministic key cut for horizon strips: below the first non-key run in each column is land). |
| `items` | yes | List of items, below. |

## Item fields (sprites)

| Field | Required | Meaning |
|---|---|---|
| `id` | yes | Unique across ALL families, kebab-case: `oak-round-a`, `barn-red-a`. Becomes the manifest sprite id. |
| `prompt` | generated | Subject text for the generator. |
| `seed` | no | First seed. Default: stable hash of `id` (FNV-1a mod 900000, *10); pin it before renaming an id, or the rename changes the seed. |
| `band` | yes | `near` (0-6 m from road edge), `mid` (6-60 m), `far` (60-600 m), `vista` (>600 m). |
| `kind` | yes | `tree|shrub|grass|crop|structure|animal|furniture|sign|vista`. |
| `worldWidthM` | yes | Real-world width in metres of the opaque sprite (trees 6-14, cow 2.4, barn 18, farmstead 120, ridge strip 4000). |
| `biomes` | yes | Subset of `farm, forest, town, city, river, plains, desert`; `[]` means every biome (road signs, posts). |
| `tags` | no | Emitted to the manifest; the renderer matches `kind/tag` groups (`structure/barn`, `furniture/fence`, `sign/curve`, `vista/ridge`, `vista/skyline`, `vista/mesa`, `vista/hills`, `vista/plains`, `animal` + `cattle`, ...). Id tokens also count as tags. |
| `heightPx` | no | Atlas height override. Defaults by band/kind (see `tool/assets/pack.go` `targetHeight`). |
| `frames` | no | Ordered frame ids (including this id) for animation; every frame is its own item. |
| `derive` | no | `{"from": "<item id>", "workflow": "...", "prompt": "..."}`: generate this item by editing the pick of another item (Qwen-Image-Edit), e.g. a grazing head-down frame. |
| `sway` | no | Wind sway amplitude hint 0..1 (default 0). |
| `collides` | no | Default false. |
| `nightEmissive` | no | Default null. |
| `tileX` | no | Vista strip: cross-fade the ends so it tiles horizontally. |
| `anchorX` | no | Override anchor x as a fraction of width (default: centre of the lowest opaque rows). |

## Item fields (textures)

`id`, `prompt`, `kind` (`road|shoulder|sidewalk|ground|bridge-deck`), `tileM`
`[x, y]` metres one tile covers, `sizePx` (output edge, default 256), `seed`.

## Picks from outside the studio (Blender structures)

Agent-made or hand-made picks only need:
1. `art/sources/<family>/<id>.png`: RGBA, transparent background, object
   standing on its lowest opaque row, longest side <= 512 px (the packer
   downscales, never upscales), lit from the upper left.
2. An item in `art/families/<family>.json` with the sprite fields above
   (`workflow` may be omitted at family level; `prompt` may describe the paint
   pass).
3. Optionally a provenance entry in `art/families/<family>-runs.json` keyed
   `<id>/<seed>` (same shape `ingest` writes: `workflow`, `models`, `prompt`,
   `seed`, `sha256`, `selected`, `pick_reason`, `source`).

Example:

```json
{
  "family": "structures",
  "type": "sprite",
  "atlas": "struct",
  "workflow": "art/workflows/structure-paint-qwen.json",
  "items": [
    {"id": "barn-red-a", "prompt": "red gambrel barn", "band": "mid",
     "kind": "structure", "worldWidthM": 18, "biomes": ["farm"],
     "collides": false}
  ]
}
```

## Provenance ledgers (`<family>-runs.json`)

Written by `ingest` and `pick`; keyed `<id>/<seed>`:
`{workflow, models[], prompt, negative, seed, studio_job, raw (cache path),
sha256 (raw rgb), matte_sha256, selected, pick_reason, source_sha256}`.
Never edit by hand except `pick_reason` wording.
