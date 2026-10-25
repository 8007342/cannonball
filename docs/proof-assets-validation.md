# Visual proof asset validation

On 2026-10-25, five Flutter tests passed against the generated draft sample in
`assets/proof/`. They load the actual Flutter asset bundle and decode PNGs with
`dart:ui`; they do not substitute generated test images or only inspect filenames.
The pack is a visual proof, not approved production artwork or a verified regional
asset library. Provenance and pose names are in `assets/proof/manifest.json`.

Run the checks:

```sh
flutter test test/proof_assets_test.dart
```

To reproduce the pixel measurements below:

```sh
flutter test test/proof_assets_test.dart --dart-define=REPORT_PROOF_ASSET_METRICS=true
```

The checks establish:

- Flutter's generated asset manifest contains all three PNGs and their metadata; each asset loads through `rootBundle`.
- Both atlases decode to 1536 × 1024, with six 512 × 512 cells in the documented 3 × 2 grid. Metadata dimensions, unique pose/cell names and anchor coordinates are consistent. Each recorded car pose anchor is also checked against the decoded silhouette bottom center.
- Every atlas cell has a substantial visible subject: over 10% of pixels have alpha at least 32, and over 8% have alpha at least 200. Less than 90% is visible, rejecting a fully opaque matte.
- At least 70% of each cell's eight-pixel perimeter is nearly transparent, with alpha no greater than 8. This tolerates the draft objects that reach cell edges; it does not certify production gutters.
- The hills image decodes to 2172 × 724, a 3:1 panorama. Its upper 180 rows are over 98% transparent, its lower 120 rows are over 90% solid, and its overall visible coverage is between 25% and 80%.

The generated pack's maximum alpha is 254 rather than 255. That is valid and does
not fail the contract. Colored RGB values beneath zero alpha are invisible under
normal compositing; the tests deliberately do not classify them as an opaque
background. Codec and decoded image handles are disposed after each measurement.

## Observed draft measurements

“Visible” uses alpha ≥32; “solid” uses alpha ≥200. Bounds use alpha ≥100, are
relative to the cell, and have exclusive right/bottom coordinates. Bounds identify
the visible silhouette; they are not a measured wheel contact point.

| Car pose | Visible | Solid | Clear perimeter | Silhouette bounds |
| --- | ---: | ---: | ---: | --- |
| rear-flat | 39.3% | 38.5% | 100.0% | 37,132 → 487,416 |
| rear-left | 40.2% | 39.4% | 100.0% | 16,132 → 493,412 |
| rear-right | 40.0% | 39.2% | 100.0% | 16,131 → 488,415 |
| rear-uphill | 41.1% | 40.3% | 100.0% | 35,88 → 489,372 |
| rear-downhill | 46.7% | 46.1% | 100.0% | 31,86 → 481,400 |
| rear-skid | 39.4% | 38.4% | 99.9% | 8,102 → 493,404 |

| Scenery cell | Visible | Solid | Clear perimeter | Silhouette bounds |
| --- | ---: | ---: | ---: | --- |
| broadleaf-tree | 59.3% | 55.9% | 79.5% | 19,36 → 512,512 |
| pine | 42.8% | 38.5% | 77.6% | 0,10 → 462,512 |
| palm | 35.8% | 29.0% | 89.7% | 73,29 → 494,512 |
| brick-apartment | 67.7% | 66.7% | 94.8% | 25,0 → 512,478 |
| roadside-shop | 47.2% | 45.1% | 82.0% | 0,0 → 512,449 |
| flowering-shrub | 45.1% | 40.9% | 85.5% | 0,0 → 494,451 |

Hills: upper-band transparency 100.0%, lower-band solid coverage 100.0%, overall
visible coverage 48.1%.

## Rendering review implications

The uphill car silhouette ends 44 source pixels above the flat pose. Using an
identical cell anchor for every pose without compensation would shift the visible
car by about 8.6% of its rendered cell height. Per-pose contact anchors or deliberate
suspension offsets need review in motion. The proof renderer now applies the measured per-pose vertical baselines; the moving result still needs review. These asset tests do not silently treat
that displacement as a correctly authored animation.

Several scenery subjects reach the grid boundary; top-row trees reach y=512 and
lower-row cells contain visible pixels at y=0. Check source clipping, neighbor
bleed under bilinear filtering and scenery feet placement against the road. The
70% perimeter threshold establishes mostly transparent exteriors, not full
isolation at every edge. A production pack should have deliberate gutters and
reviewed anchors.

The three decoded RGBA images occupy approximately 18 MiB before GPU copies,
caches, raster textures and render surfaces. Decode once during scene loading and
retain handles; avoid per-frame decoding or recreating the atlas. Initial loading
and GPU upload still need browser measurements. A cached image may reduce CPU
drawing work without reducing all fill-rate or memory costs.

Automated alpha/geometry checks do not establish matching pose scale, recognizable
vehicle details, wheel rotation, suspension quality, backdrop seam continuity,
alpha-edge halos, depth ordering, perceived speed, or final art approval. Review
those in the moving 60-second scene on representative browsers. CPU command
recording timings alone do not establish presented-frame FPS or phone performance.
