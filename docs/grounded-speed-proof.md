# Fast, grounded and controllable proof — 2026-10-25

Local next proof on `work/grounded-speed-proof`, based on recovered
`work/steering-camera-repair` at `f4e8cf5`. It is an illustrative two-minute
S2000 course, not a verified geographic campaign or production art approval.

## What changed

- The original accepted inner rim contour is preserved, including its thumb
  grip shape. Leather fills outward beyond every viewport corner. Paint and
  hit geometry are independent; angular steering remains the default.
- `touch=travel` optionally normalizes tangential travel to160 CSS pixels per
  full-scale steering command. This is a tuning hypothesis, not an established
  hand size. Pointer ownership, neutral guards and central braking are retained.
- Course car art keeps the coherent rear silhouette. A critically damped,
  camera-relative slope cue replaces abrupt uphill/downhill cell switching.
  `slope=legacy` retains those old cells for comparison. Cues are bounded below
  2.4% sprite-height deformation and combined with existing small load cues;
  this is a presentation proxy, not a calibrated four-wheel suspension rig.
- `ProofCourse` now has more than ten left/right reversals, gentle-to-firm
  curves, shallow/medium/steep positive and negative grades, repeated crests/dips
  and compound transitions. Chapters1–8 retain straight, bends, climb, descent,
  worksite, canopy, bridge and tunnel entry locations. R restarts a chapter.
- Default `motion=velocity` uses168 presentation units versus132 for retained
  `hyperspeed`, about27% more flow. Actual acceleration/top speed and legacy
  receipts are unchanged. An adaptive180-segment depth mesh preserves fine
  near samples and extends far samples: conservative geometric preview is
  326.614 course units at the new preset. Terrain can still conceal hazards;
  preview time is a draw-range estimate, not guaranteed clear sight distance.
- Dashed lines intersect fixed world intervals rather than classifying adaptive
  strips wholesale; mesh advancement cannot change their world-space lengths.
- Traffic admission repeats build/overtake/release beats over1100 course units.
  Capacity/interval pairs are18/1s,22/.7s and12/1.8s. Existing cars remain alive
  when a lower-capacity beat begins. Existing stagger/gap guards remain in use.
- Trees have bounded, position-phased main sway through per-instance atlas
  rotation around authored ground anchors. `foliage=still` and reduced motion
  disable it. Crest-cropped sprites do not rotate, preserving the clip boundary.
  Leaf detail and multi-segment branches need separated paintings and remain
  deferred; this is not a claim that current trees have independent leaf rigs.

The [source application ledger](research/next-proof-source-review.md) identifies
adopted, deferred and excluded research and its limitations. Active art, controls,
racing and world specs link it explicitly. No project package or artwork was
copied from the sibling games. Juckett's explained second-order equations inform
the independently expressed closed-form slope response; no external source-code
body was vendored. Existing original artwork is reused.

## Local verification

- Format check and analyzer clean;135 Flutter tests passed, including real-image
  rim repaints, varied viewport openings, angular/travel controls, independent
  brakes, slope/curve coverage and continuity, schedule consistency, preview
  budget, world-dash partition invariance, ground-pivot atlas transforms and
  actual controller actor retention during release admission.
-32 browser/bootstrap/audio tests and14 Worker tests passed. Worker packaging
  passed `npm --prefix services/api run check` as a **dry-run**.
- Release web build passed. Strict OpenSpec validation passed8/8. Source-register
  regeneration/check is part of final integration. No GitHub workflows or
  remote build hooks were added or enabled; compilation ran locally in forge.
- Local Chromium loaded S2000 art with `assetsReady:true`, `artError:null`,
  `speedPreset:velocity`, grounded slope mode and animated foliage enabled.
  The outward rim and road/car presentation were inspected in moving browser
  samples, including climb/curve travel. This is agent review, not user approval.
- Browser keyboard Right produced steering1. In a separate headless
  `touch=travel` check, left-side upward touch produced steering.505489 without
  braking; adding an independent center touch retained that steering and set
  braking true. Releasing touches returned steering0/braking false after the
  existing short brake-release hold. Browser console contained no exceptions.
  CDP touch events were sampled after a rendered frame; immediate reads before
  Flutter processes pointer events are not reliable input evidence.

## Uncaptured timing sample

The final release was sampled in foreground visible Chromium at1280×720 CSS,
native DPR1,720×405 backing pixels, seed731, velocity preset, during the S-bends
chapter. No screenshots were taken during the sample; builds/tests had finished.
Raw bookends and counters: [grounded-speed-metrics.json](research/grounded-speed-metrics.json).

Over5009.5ms wall time, simulation advanced5.0333s and the renderer recorded301
calls. rAF interval p50/p95/p99 were16.7/16.7/16.8ms, with mean CPU drawing-command
recording.832ms per render. These are scheduling and CPU-recording measurements,
**not presented-frame FPS**, GPU timing, or physical-phone performance. No matched
old-build benchmark was collected in this pass, so this is not a measured speedup.

## Review remaining

Open `/?proof=1`; take the keys or press Enter. Compare one option at a time:
`motion=hyperspeed`, `slope=legacy`, `touch=travel`, `foliage=still`, and the
retained body/chase/camera/effects controls. Keys1–8 let reviewers repeat gradient
and curve sections without waiting for the complete course. Sound starts from
the actual start gesture and can be muted.

Physical-phone reach, gain, reversal precision, motion comfort, sustained timing,
audible mix and perceived challenge remain unverified. User moving review is
still needed for art approval. Gentle-road assist, per-leaf/branch packs,
IDM/MOBIL replacement, higher actual-speed physics, nationwide content and live
identity/save/ranking deployment remain separately tracked or deferred. Do not
archive the active change while production acceptance remains open.
