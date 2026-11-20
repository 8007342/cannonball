# Cannonball art pipeline

Local, reproducible pipeline for the scenic library (`assets/scenic/`):
family spec -> studio jobs (ComfyUI on the host GPU) -> ingest + provenance ->
finish (matte, trim, downscale) -> pick -> pack (atlases, road textures,
manifest) -> contact sheets. Design and runtime contract:
`openspec/changes/scenic-depth-asset-pipeline/design.md`.

| Path | What |
|---|---|
| `art/families/<family>.json` | Family specs (schema: `art/families/README.md`). |
| `art/families/<family>-runs.json` | Provenance ledger, keyed `<id>/<seed>` (written by `ingest`/`pick`). |
| `art/workflows/*.json` | ComfyUI API workflows (bindings below). |
| `art/sources/<family>/<id>.png` | Committed picks (RGBA, <= 512 px; far/vista <= 1536 px). `pack` rebuilds everything from these. |
| `art/contact/<family>.png` | Contact sheets of the picks (labels: id, band, width in m). |
| `art/rigs/` | Blender rigs for rigid structures (owned by the structures pipeline; see `art/rigs/README.md`). |
| `tool/assets/` | The Go CLI (`plan run ingest finish pick pack contact check status`). |
| `licences/` | Model licence register and acknowledgements. |
| `~/.cache/tillandsias-project/cannonball-art/` | Raws, candidates, job files, candidate sheets (NOT committed; lost on a forge reset, which is fine because picks are committed). |

## Add or update an asset in 3 commands

```bash
A="go run -C tool/assets ."     # or build once: go build -C tool/assets -o ~/.cache/tillandsias-project/bin/scenic-assets .
# 0. add/edit the item in art/families/<family>.json (id, prompt, band, kind, worldWidthM, biomes)

$A plan vegetation --item birch-clump-b        # 1. writes the studio job(s)
#    then run each entry of `$A run vegetation --next 10` with studio.queue_workflow
#    (an agent passes "studio_args" verbatim; the host queue runs one GPU job at a time)
$A ingest && $A finish vegetation --item birch-clump-b   # 2. raws + ledger + candidates + candidate sheet
#    look at ~/.cache/tillandsias-project/cannonball-art/contact/vegetation-candidates.png
$A pick birch-clump-b 1234561 "why this one" && $A pack  # 3. commit pick, rebuild atlases/manifest/sheets
```

`ingest` finds finished studio jobs by itself (it matches workflow, prompt
and first seed against the provenance sidecars in `/work/tmp/imagegen/studio/`),
so the dispatcher only has to run the calls. `run --done <family/item> <st-job>`
records one by hand if needed. `check` validates specs, ledger hashes and the
16 MB / 60 MB budgets. `status [-v]` lists picked/missing items.

To re-roll an item: `plan <family> --item <id> --redo` (seeds stay the same:
change `seed` in the item, or add candidates, for new images). To change only
size/placement data (band, worldWidthM, heightPx, biomes), edit the spec and
run `pack`: no GPU needed.

`pack` is deterministic: the same picks and specs give byte-identical
`assets/scenic/*` (checked by running it twice). GPU re-rendering of the same
seed is *not* guaranteed byte-identical, which is why picks are committed.

## Workflows and bindings

All bind by node title: `$prompt`, `$negative_prompt`, `$seed` (the main
KSampler), `$init_image` / `$control` / `$mask` (LoadImage `image` values),
and the canvas node titled `canvas` (`$node:<id>.width/height` overrides).

| Workflow | Graph | Inputs | Outputs |
|---|---|---|---|
| `sprite-flux2-matte.json` (default sprites) | FLUX.2-klein 4B, 4 steps, euler/simple, cfg 1 on a flat white background -> BiRefNet matte in-graph | `$prompt`, `$seed`, canvas node `6` | node 9 `save rgb`, node 13 `save matte` |
| `texture-flux2.json` (default textures) | klein 1024² plain render; `finish` tiles it deterministically (roll by half, smoothstep cross-fade of a 1/6-width band around the centre lines back to the unrolled image, then a 1/32 wrap blend) | `$prompt`, `$seed`, canvas node `6` | node 9 `save rgb` |
| `texture-flux2-tile.json` (superseded, kept for provenance of `cobblestone`, `dirt-shoulder`) | klein -> in-graph roll by half (ImageCrop/ImageCompositeMasked) -> masked seam repaint (denoise 0.6) | `$prompt`, `$seed`, `$mask` | node 23 `save tile`. Left a visible repainted cross on stochastic textures (gravel, grass), hence the Go tiler. |
| `structure-paint-qwen.json` | Qwen-Image-Edit 2511 + Lightning 4-step; image1 = `$init_image`, image2 = `$control`; latent from the init (keeps framing); BiRefNet matte | `$prompt`, `$negative_prompt`, `$seed`, `$init_image`, `$control` | node 15 `save rgb`, node 19 `save matte` |
| `sprite-sdxl-layerdiffuse.json` (alternative) | SDXL base + pixel-art-xl + LayerDiffuse conv | `$prompt`, `$negative_prompt`, `$seed`, canvas node `6` | node 10 `save rgb`, node 12 `save alpha` |

Animation frames (e.g. a grazing head-down cow) use `derive` in the item:
`plan` composites the parent pick on the key colour into
`/work/tmp/imagegen/scenic/inputs/<id>-init.png` and binds it to the Qwen edit.

## Prompting lessons (from demon_attack and this pack)

- Name a flat key colour ("isolated on a flat pure white background"), never
  "plain background"; BiRefNet then mattes cleanly and `finish` removes the
  white fringe from soft edges.
- Avoid effect words ("sunlight", "glow", "rays"): klein paints light shafts
  that the matte keeps. "warm late-afternoon light from the upper left" is safe
  for sprites; vistas use "calm even daylight".
- klein ignores most negations; leave unwanted things out instead of "no X"
  where possible (e.g. "no lane lines" made it paint lane lines).
- One GPU job at a time: use `studio.queue_workflow` (host-serialised); never
  run a parallel ComfyUI client.

## Finishing (deterministic, `tool/assets`)

`finish`: matte x RGB, de-fringe against the key colour (skipped for
LayerDiffuse alpha), alpha snap (<6% -> 0, >97% -> 1), trim, `tileX` cross-fade
(1/8 width) for vistas, area downscale to `sourceMax`. `pack`: area downscale
to the band height (near 160-192 px, mid trees 320, structures 288, animals
128, far 192, far animals 96, vista 320; `heightPx` overrides), alpha clean,
optional `colorLevels` posterize, trim, anchor = centre of the lowest opaque
rows / bottom edge (or a supplied `anchor` scaled from source pixels), shelf
pack by height into <= 2048² pages per atlas group, manifest `scenic-1`.

## Provenance

Every candidate is recorded in `<family>-runs.json` with workflow, model files
with repo@revision and licence (from the studio sidecar), prompt, seed, studio
job, raw sha256, matte sha256; `pick` sets `selected`, `pick_reason`, `source`
and `source_sha256`. Picks are agent-made (user-approved gate, 2026-11-20) and
are review material: override by re-picking another seed.
