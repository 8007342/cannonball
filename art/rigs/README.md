# Blender-guided structure rigs

Rigid roadside objects (buildings, bridges, street furniture, signs, fences) are
modelled as small parametric rigs, rendered in headless Blender from the game's
roadside billboard camera, then painted by Qwen-Image-Edit with the rig owning the
outline: the final alpha is the rig silhouette, so perspective, anchors and edges
never drift and no matting is needed.

```
art/rigs/structures-rigs.json   item list: id, template, params, prompt, band, kind, biomes
art/rigs/structures/<t>.json    parametric templates (the grammar below)
art/rigs/rig.py                 bpy renderer: clay, hint, shade, depth passes + rig.json
art/rigs/workflows/             Qwen-Image-Edit 2511 + Lightning paint graphs
tool/rigs/                      Go: plan / batch / collect / finish / ingest / sheets
art/sources/structures/<id>.png committed picks (RGBA, longest side <= 512)
art/families/structures.json    family items for tool/assets (written by ingest)
art/families/structures-runs.json  provenance ledger keyed <id>/<seed>
art/contact/structures.png      contact sheet of the picks
```

Renders, paints and batches live in `~/.cache/tillandsias-project/cannonball-art/`
(override `CANNONBALL_ART`), never in the checkout.

## Headless Blender (shared, stable)

`lua art/rigs/setup_bpy.lua` creates or verifies a uv-managed Python 3.13 venv with
`bpy==5.3.0` (+ pillow, numpy) at `~/.cache/tillandsias-project/bpy-venv`
(override with `BPY_VENV`; pin with `BPY_VERSION`). It is idempotent (~1 s when the
venv exists, ~1 min / ~430 MB when the cache was wiped) and prints the venv python
path on stdout; `--check` exits 1 without installing. Use it as:

    PY=$(lua art/rigs/setup_bpy.lua)
    $PY -I your_script.py ...          # always -I; CPU only; render threads <= 8

Other rig pipelines (e.g. art/rigs/cars/) reuse this script; keep its interface stable.

## Add a new structure in 3 steps

1. **Rig.** Reuse a template with new params (most variants need nothing else), or
   copy the closest `art/rigs/structures/<t>.json` and edit its parts. Add an item
   to `art/rigs/structures-rigs.json`:
   ```json
   {"id": "barn-blue-gable", "template": "barn",
    "params": {"roof": "gable", "wall": "#3f6f9a"},
    "kind": "structure", "band": "mid", "biomes": ["farm"],
    "prompt": "a blue-painted wooden gable barn with white trim"}
   ```
   Optional: `mirror` (default true), `collides` (default true for structures),
   `maxPx`, `seed`, `denoise`, `view` ({pitch, yaw}), `notes` ("text-ok" lets a
   road sign keep its generic legend). Then render and look at `shade.png`:
   ```
   lua art/rigs/run.lua render barn-blue-gable      # ~0.5 s per item
   ```
2. **Paint.** `rigfinish batch` stages up to four items and prints the exact
   `studio.queue_workflow` arguments (2 seeds per item); submit ONE job at a time,
   then collect the outputs (the studio folder is ephemeral):
   ```
   B=~/.cache/tillandsias-project/cannonball-art/bin/rigfinish
   $B batch -name b20 -ids barn-blue-gable > args.json     # -> workflow, inputs, overrides
   # studio.queue_workflow {workflow, inputs, overrides}; poll studio.job_status
   $B collect-batch -name b20 -job /work/tmp/imagegen/studio/<job>
   ```
   Review `cannonball-art/batches/b20.png`. Single item: `lua art/rigs/run.lua plan
   <id>` + `structure-paint-qwen.json` + `lua art/rigs/run.lua collect <id> <jobdir>`.
3. **Pick.**
   ```
   lua art/rigs/run.lua ingest barn-blue-gable <cache>/paints/barn-blue-gable/<seed>.png "why this one"
   lua art/rigs/run.lua sheet                       # art/contact/structures.png
   go run -C tool/assets . check                    # schema/budget gate, then `pack`
   ```
   Ingest applies the rig silhouette as alpha (eroded 1 px, feathered 1 px at render
   size), trims, area-downscales (longest side 512; near band 384), writes the source
   PNG, the family item (worldWidthM measured from the rig, anchor = ground point under
   the footprint centre in source px) and the provenance ledger entry. Two guards keep
   thin parts honest: pixels inside the silhouette where the paint still shows the flat
   key fall back to the lit rig colour (shade.png), and a template's `keep_rig` colours
   (e.g. utility-pole wires, which the model tends to redraw elsewhere) always take the
   flat hint colour with full, un-eroded rig alpha.

## Camera

Orthographic, from the front-left, `pitch` degrees down (default 7) and `yaw`
degrees off the -Y axis (default 35; signs ~14, fences/bridges ~22, overpass 0).
Model convention: Z up, metres, ground at z = 0, footprint centred on the origin,
the face toward the approaching player is -Y, the road side is -X (an object on
the right of the road). Sprites are mirrored for the left side (`"mirror": true`);
items with legible legends (speed limit, stop, yield) set `"mirror": false`.

## Grammar (templates)

```json
{"template": "barn", "view": {"pitch": 7, "yaw": 35},
 "params":  {"w": 9, "wall": "#a8322a"},          // overridable per item
 "derived": {"fy": "-d/2"},                       // computed from params, in order
 "anchor":  [0, 0, 0],                            // optional ground contact (default origin)
 "keep_rig": ["wire"],                            // optional: hint colours/params kept from the rig
 "parts": [ ... ]}
```

Any number in a part may be a Python expression string over params, derived
values, loop variables and helpers (`sin cos tan sqrt radians atan2 pi min max abs
int range len`, `arc(cx, cz, r, a0, a1, n)`, `stadium(w, d)`,
`arches(L, H, n, span, spring)`). `c` is a hex colour, a param name holding one,
or an expression yielding one; it is the part's flat hint colour (one material per
colour). Part keys:

| key | meaning |
|---|---|
| `p` | primitive (below); omit for a group with `parts` |
| `at`, `rot`, `scale` | translation, XYZ Euler degrees, scale (applied in that order) |
| `if` | expression; part skipped when false (evaluated per repeat iteration) |
| `repeat` | `{"var": "expr"}` iterate the part/group |
| `let` | `{"name": "expr"}` local bindings |
| `sym` | `"x"`: also emit the mirror across x = 0 |
| `parts` | children (a group; its at/rot apply to them) |

| primitive | parameters (anchor) |
|---|---|
| `box` | `size [x, y, z]` (bottom centre) |
| `cyl` | `r`, `h`, `r2` (top radius, 0 = cone), `seg`, `axis` z (base) or x/y (centre) |
| `sphere` | `r`, `seg`, `half` (upper dome) (centre) |
| `prism` | `size [w, d, h]` gable triangle, ridge along `axis` (y) (bottom centre) |
| `hip` | `size [x, y, h]` hip roof / pyramid (bottom centre) |
| `extrude` | `profile [[u, v], ...]`, `depth`, `axis` y (XZ profile), x (YZ), z (XY, upward) |
| `shell` | open polyline `profile` thickened by `t`, extruded like `extrude` (roofs, canopies) |
| `beam` | `from`, `to`, `size [sx, sy]` (braces, truss members, legs) |
| `tube` | `path [[x, y, z], ...]`, `r` (arms, wires) |
| `wire` | `from`, `to`, `sag`, `r` (sagging cable) |

`lua art/rigs/run.lua check [ids]` evaluates the grammar without rendering.

## Passes (per item, `cannonball-art/rigs/<id>/`)

`clay.png` grey Workbench clay (alpha = the silhouette used for the final sprite),
`hint.png` flat hint colours (no AA), `shade.png` hint colours lit from the upper
left over the flat key `#8c9aa6` (the paint input), `depth.png` (near = white),
`rig.json` (camera basis, metres per px, anchor px, resolved params).

## Paint

`structure-paint-qwen.json` (single), `structure-paint-qwen-batch4.json` (4
items x 2 seeds) and `-batch8.json` (8 x 2; `batch` picks it for 5-8 ids, fewer turns
in a busy shared GPU queue; ~16 s per image): Qwen-Image-Edit 2511 fp8 + Lightning 4-step LoRA, 1 MP, euler/simple,
cfg 1, denoise 0.85. Denoise 0.7 kept the clay look too flat; 0.85 adds wood, shingle
and brick texture and warm upper-left light while holding every edge.
`structure-paint-qwen-styled.json` adds the proof scenery atlas as a second reference
image: warmer, but it drifts the hint colours (grey roofs turn brown), so it is not
the default.
