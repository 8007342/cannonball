# Design

## Context
First-pass simulation, Flame renderer, UI and durable Worker exist. The user rejected the renderer and reported poor speed/smoothness. A foreground software-rendered browser audit found resolution-sensitive frame scheduling and an independent optical-flow scale problem; see docs/research/renderer-audit.md. Exact Google origin registration is now operator-confirmed, while live sign-in and deployment remain unverified.

## Goals / Non-Goals
Goals: an integrated playable browser implementation of the run lifecycle, testable simulation, durable API, browser controls/audio and clear production-readiness evidence.
Non-goals: native applications, equalized competition, claiming an initial procedural rendering pass is the final approved asset library, or claiming desktop tests establish phone comfort.

## Decisions
- Astra engine owns lib/game: fixed-step model, route graph and pure receipt, with Flame road projection. Its first procedural rectangle-based composition was rejected; replace it with textured geometry and authored animated cartoon sprites. UI observes controller state at a bounded rate. Physical simulation is distinct from drawing and real route miles from compressed driving coordinates.
- Root owns Flutter garage/HUD/angular wheel/initials/map/profile integration. Default wheel returns to center; every active pointer is tracked by ID. Tap outside rim briefly brakes, hold sustains it. Utility overlays capture their own pointers. Keyboard and tilt normalize to the same steering intent.
- Astra platform owns browser interop, gesture-gated sensors, no-event fallback, landscape orientation mapping, lifecycle callbacks, synthesized original music/engine sound and nonblocking speech. Captions are authoritative when speech/audio fail.
- Astra backend owns same-origin GIS nonce login and SQLite Durable Object accounts/sessions/records. Reuse the public Arabiya client ID; the operator confirms exact Cannonball origin registration. Never share cookies across sibling hosts.
- Anonymous runs remain local. Signed-in starts get server tickets; finished receipt validation and idempotent ranking precede initials entry. One canonical Top100 deliberately mixes unequal cars, routes and luck. All cloud failures remain separate from local play.
- Six initial car slots end in the white 2019 Stingray, targa off. Starter and intermediate fictional designs are working choices subject to review; original procedural visuals enable animation/handling feedback without commissioning unreviewed bulk assets.
- Candidate real-road corridor graph uses approximate geographic nodes and documented road names. Exact production intersection geometry, landmark sightlines and complete regional asset packs require source review; do not call the initial graph a verified map atlas.

## Risks / Trade-offs
- Browser tilt/audio variation → feature detection, user gestures, immediate fallback and real-device checklist.
- Asset and route depth exceeds first integration → retain explicit content acceptance tasks and report actual implementation maturity; do not erase requirements.
- Browser-reported scores can be forged → server tickets, timing bounds, known route/car validation, duplicate protection; replay verification remains a cost/rigor decision.
- Live Google login remains unverified despite operator-confirmed exact-origin registration → test the real flow; keep actionable errors and local driving available.
- Motion comfort cannot be automated → steady horizon option and uncompleted physical-device acceptance checklist.

## Migration Plan
Run local checks, publish a local review build, then use the prepared Pages/Worker configuration when live credentials/resources are available. SQLite migration creates new Cannonball-only objects. Roll back code by redeploying the prior version without deleting progress storage.

## Renderer replacement decision

Retain simulation/identity/progression. Replace the visual pass with reusable
textured road vertex buffers, cached distant composites, independently moving
parallax layers and batched, depth-sorted authored sprites. Bridge decks/supports,
traffic and hill occlusion must share an explicit depth model. Interpolate render
snapshots; calibrate camera trail, width, marking and prop frequency together.
Source-frame pixel styling must not force position snapping.

Render scale must cap actual scene pixels independently of sharp HUD/text. The
observed SwiftShader DPR2 slowdown versus DPR1 makes this a mandatory benchmark
variable, not proof of any phone's capabilities. Benchmark the same seeded scene
in foreground without screenshot capture, then compare embedded and direct views.
Report update/render counts, rAF interval percentiles, renderer/DPR, input latency
and simulation/wall-time ratio separately; do not call rAF presentation FPS.

The next deliverable is one30–60s city-edge/vegetation/hill/bridge scene with an
animated car and traffic, not bulk placeholder expansion. Compare CanvasKit and
Wasm as measured options. Do not promise a framework/renderer migration will fix
performance until that scene demonstrates the desired result.

## Approved second proof — 2026-10-25
User approved the researched garage, traffic, palette and station design and requested implementation plus frequent remote work-branch checkpoints. Root integrates work/next-driving-proof; isolated agents push work/reactive-traffic, work/s2000-render and work/garage-radio. No production deployment is implied.

The next short local proof uses an S2000-specific CarSpec without mutating the legacy server rules or old full-run receipts. Layered garage paintings, a key/hand atlas and occlusion cuts sell pickup, reveal, walking, entry and chase launch. Simulation stays paused until handoff. Repeat/skip remains available.

Reactive traffic is opt-in so prior receipt fixtures remain stable. It observes bounded neighboring gaps and player motion; persistent profiles choose following, passing, braking and within-lane flinches. Secondary braking/incident states stay local and time-bounded. Atrapa is a design reference, not a supplied trained policy. Original rules and source attribution are documented.

Car source art uses saturated paint separated from fixed details. Cached body-only recoloring preserves lights, glass and tires. Signed turn/skid selection fixes the one-direction high-speed pose. Camera, roadside reference density and relative motion are tuned separately from route miles and elapsed time. Auxiliary ramps are explicitly NPC-only until true playable branch topology is implemented.

The station sequence is song, tuning burst, condition-relevant report, next song. Runtime browser speech is a fallback sample and does not establish regional accent quality. Prepared regional voices remain a production task. Text-free artwork is confirmed; optional captions/UI remain available pending a stricter interpretation.

Campaign direction supersedes the old whole-country 10–15-minute target: major city checkpoints form connected city-to-city stages, with mixed cars allowed across saved stage bests. A local versioned model retains compatible successful receipts and computes a connected best journey. This proof does not submit experimental stage receipts to the old full-run leaderboard. Remote stage migration, full city selector, new rankings and nationwide content are later acceptance work.

## Approved driving-and-camera milestone — 2026-10-25
The next local proof is an authored test course, not verified geographic reconstruction. Shared proof-only course geometry drives road projection and steering demand, keeping legacy full-run simulation/receipts stable. Straight, S-bends, combined climb/bend, crest/descent, worksite, canopy and bridge/tunnel sections must be recognizable in a short drive. World-fixed object IDs/positions and world-phase lane markings prevent camera-attached repetition. Temporal aliasing is evaluated after placement correctness, never hidden by moving hazards randomly.

Camera variants change projection/near-flow cues independently from mph and route timing. Research sources and design inferences remain distinct; no universal speed/FOV or millisecond transition rule is assumed. Stateful steering presentation must expose gentle/intermediate poses on brief large inputs, preserve gentle held inputs, pass through neutral on reversal, and avoid a one-frame jump into skid. A proof-only steering response can be tuned if needed; responsive braking/release remain independent.

Painted replacement props are cached with scenery to preserve batching. Building grounded footprints stay behind curb clearances; canopies/portals use explicit overhead layers. Daytime depth palettes approach sky/haze color with reduced contrast; tunnel exposure changes are localized and must preserve hazard readability. No expensive full-frame blur or gratuitous particles are required.

Preserve the liked keybox and garage exterior artwork. Improve reach/grasp/withdraw and coordinated pan; use a genuinely wide cabin with aspect-preserving cropping. Door/ignition/rev sound bridges the rear-view handoff; preload live scene behind the cinematic while race time remains paused. Reduced-motion/skip/mute/hidden handling remain available. The last viewport test resized a real browser viewport correctly; preview-host fixed viewport and app metrics must be diagnosed separately before changing a working layout.

Use work/road-feel-milestone for integration, with frequent durable specialist pushes. Root runs mounted Flutter checks and browser review centrally. Native/device and production acceptance remain open.

## Soundtrack proof and next driving review
Replace the proof's short oscillator motif with original authored sectional music:
synthpop, cumbia/electronic and hard-driving rock. Store multitrack MIDI and the
render source alongside compressed stereo mixes. Decode only the selected score,
keep a bounded cache and preserve song/tuning/report/song sequencing. Prepared
synthetic presenters improve the default browser voice but do not establish
reviewed city accents or final performances. Missing files must preserve play.

Next driving review: preserve hand proportions; emphasize crests/dips; connect
canopies to large supporting tree sections; mild dirt/rumble shoulder drag; solid
obstacles crash while lightweight cones/mailboxes/cafe furniture scatter. Ramp
footprints must exclude vegetation across the merging pavement. Compare much
stronger near-field optical flow and roadside density independently of physics,
route miles and elapsed time. These requests remain pending implementation and
moving review rather than being implied complete by soundtrack work.

## Speed/traffic draft after soundtrack review
User approves improved music/voices and requests substantially faster apparent
motion, stronger hills, slower launch with diminishing high-speed acceleration,
and traffic. Proof-only acceleration uses a speed-dependent available thrust
curve, steering scrub and grade load. Small sustained steering remains economical;
hard steering/rapid reversals bleed speed. These are arcade tuning hypotheses,
not a validated vehicle model. Keep prior flow settings for comparison, and keep
NPC relative motion consistent with collision coordinates. A dedicated proof
traffic stream must enter beyond the visible ribbon, seed an initial readable
stagger and preserve passing gaps. Legacy cloud receipt physics stay unchanged.

## Lower-horizon, roadside rhythm and forgiving-contact pass
After approving soundtrack/voice improvements, user requests another researched
agent pass: a horizon near the lower-third boundary, stronger passing-object
rhythm, hidden far-distance arrivals, short interjections and occasional
music/static/other-song/static/news/static/music station surfing. Camera placement
is a testable hypothesis, not an established OutRun camera calibration. Preserve
prior comparisons and near-road hazard legibility. Terrain pitch and far scenery
must follow the same projection so the base camera no longer suggests continuous
climbing. Fade/camouflage the distance boundary without per-frame asset loading.

Proof collisions must correspond to visible solid obstacles. An entire closed
lane is not a collision object. Contacts should permit slight visual overlap,
ignore isolated grazing samples, detect high-speed traversals and recover once.
Soft cones scatter and cannot trigger a car crash. Timing/margins are arcade
playtest hypotheses; legacy receipt physics remain separate.

Sparse original gas/burger/motel/diner vignettes with pictorial signs add memorable
beats between quieter repeated foliage. Do not substitute primitive geometry for
painted sprites or turn every exit into visual clutter. Enforce ramp pavement and
building footprint clearance. Research/reference links are indexed from the main
and delta specs; audit authorship and applicability rather than citing GameFlow
as Valve-authored work.

## Wide-camera and rolling-traffic review
User prefers wide framing; make it the proof default. Increase visible traffic
with a dedicated dense stream, alternate lane openings and bounded actor count.
Layer authored smooth irregular elevation rollers onto shared terrain, preserving
bridge/tunnel structure and consistent prop/collision placement. Chase ground
composition starts low and advances with speed; damp brake/turn responses without
moving input or collision coordinates independently of the rendered road.
Reduced motion and a stable chase comparison retain fixed composition. Optional
peripheral speed cues must leave the central traffic corridor clear and avoid
full-frame shader cost until measured. Camera parameters are authored hypotheses,
not a promise of perceptual benefit or a reconstruction of OutRun geometry.

## Steering-camera repair
User reports steering camera pulls as unplayable on keyboard and touch. Root
cause: shifted camera origin entered the20-unit road-heading derivative. Separate
translation from road tangent, reduce bounded look, test depth attenuation and
validate actual keyboard/touch input. Increase optional speed-effect contrast for
an observable A/B. Texture the accepted rim geometry without reducing its target
or neutral guard. Details and art provenance: docs/camera-steering-repair.md and
assets/controls/PROMPTS.md.

## Fast, grounded and controllable proof (2026-10-25)

The user approved implementation by agents after the cross-project review and
requested plenty of curves and hills of differing gradients. This refines the
existing proof rather than authorizing production acceptance. The normative
[source application ledger](../../../docs/research/next-proof-source-review.md)
records Ranitas/Demon Attack research, primary explanations, decisions and limits.
Use it to trace each technique and each deliberate exclusion.

### Separate geometry, pose and secondary motion
Keep road/vehicle/prop contacts in one authored course coordinate system. Evaluate
local grade in presentation-space distance units and compare `atan(grade)` with
camera pitch before selecting a subtle body cue. Use a critically damped response
and distinct entry/exit thresholds so small changes do not abruptly select the
existing steep uphill/downhill artwork. Preserve flat rear art as the grounded
baseline where those old cells imply wheelies; do not claim that vertical scale
is a physically complete pitch rotation. Keep contact pivots/shadow grounded and
limit secondary load motion. Expose relative slope, response and comparison mode
for review. Preserve old behavior only as the labeled `slope=legacy` comparison. Camera pitch
is inferred with `atan(viewPitch/(projection*.70))` from this pseudo-projection,
not measured as a full 3D camera rotation.

The course includes repeated left/right mild, medium and stronger bends,
shallow/medium/steep positive and negative grades, irregular rollers, crests,
dips and combinations around canopy, bridge and tunnel sections. Maintain eased
continuity and replayable chapters. Gradient categories are authored test coverage,
not a real freeway survey or a claim about road legality.

### Rim and touch
Freeze the accepted inner opening and extend the textured translucent rim outward
to the viewport boundary. Separate visible fill, gesture angle center/radius and
input ownership. Preserve neutral guards, deliberate center brake and multi-touch
release behavior. The angular baseline remains default; `touch=travel` compares
normalized tangential thumb travel with a 160 CSS-pixel full-scale range. That
range is a hypothesis rather than a physical millimetre guarantee. Changing art
thickness must not silently change gain. Report the active mapping in telemetry.

### Faster presentation with useful preview
`motion=velocity` is the new default: presentation scale168 versus previous
`hyperspeed`132 (about27% stronger flow). Preserve the previous presets and
vehicle physics. A fixed180-segment mesh uses near step170 with a quadratic far
extension targeting330 course units; use conservative preview at least320 units
for traffic admission across comparison scales. This avoids the old fixed-depth
preview shrinking inversely with the motion multiplier. Measure actual visible
hazard opportunity separately: a crest may still occlude vehicles even inside
the geometric preview. Extend ground-only near-flow references without cluttering
central hazards or adding full-frame blur. Independent actual speed/acceleration
increases are deferred to a subsequent physical challenge comparison.

### Pacing and animated world
Apply Demon Attack's bounded-admission lesson to seeded course-distance beats,
not enemy HP or hidden score compensation. Initial policy repeats every1100
course units: release0–240, build240–560, overtaking560–850, release850–1100.
New admission uses release/build/overtake intervals1.8/1/.7 seconds and capacities
12/18/22. Existing actors are never deleted merely to meet a lower phase budget.
These are review settings, not literature-established difficulty thresholds.
Preserve local following, motivated lane changes, openings and actual unequal
outcomes. Full IDM/MOBIL is deferred; cite it accurately as an audited alternative.

Adapt the Ranitas/GPU Gems coarse-bending principle as seeded, position-phased,
bounded whole-tree sway about the authored ground pivot in the existing atlas
batch. `foliage=still` and reduced motion suppress optional sway. World anchors
keep scenery attached to terrain. Separate leaf flutter, multi-segment branches
and painted detail animation are deferred because the current art has no separated
leaf/branch layers; do not imply a complete physical or hierarchical foliage rig.

### Verification and delivery
Keep correctness, browser render timing and user perception separate. Check
contact invariants, subtle slope transitions, timestep consistency, rim opening,
input ownership, independent brake, graded course coverage, deterministic admission
and constant preview across speed comparisons. Record backing size, cadence and
p95/p99 in an uncaptured foreground sample. Inspect motion separately after timing.
Run builds/tests locally; no GitHub Actions or remote build hooks. Publish only a
local review preview and retain physical-phone and production tasks uncompleted.
