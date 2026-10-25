# Next proof: source review and application ledger

Reviewed 2026-10-25 for the user's next S2000 proof: a thicker outward rim,
grounded subtle slope poses, precise touch steering, much stronger speed and a
course rich in curves and hill gradients. This ledger is part of the active
`playable-road-trip` specification through its art, controls, racing and world
requirements. It supplements, rather than replaces, the [reference register](reference-register.md)
and the older source documents indexed there.

**Evidence rule:** a useful explanation, peer-reviewed result, implemented
example and human-tested Cannonball result are different things. The entries
below record what was found, what it supports, our adaptation, and why other
ideas were deferred or excluded. Numerical gains, timing, grades and traffic
budgets are Cannonball tuning hypotheses. No inherited source establishes phone
comfort, displayed-frame performance or a universally correct steering scheme.

## How this proof uses research

1. Separate ground geometry, camera, car pose and secondary suspension cues.
2. Preserve the accepted wheel opening and touch baseline while extending rim art
   outward; compare normalized thumb travel explicitly rather than silently
   changing sensitivity with artwork.
3. Compare speed presentation while recording useful road preview. Do not obtain
   faster scenery by unknowingly collapsing the visible decision horizon.
4. Exercise left/right curves at mild, medium and strong demand; shallow, medium
   and steep climbs/descents; crests, dips and combined slope/curve transitions.
5. Borrow bounded encounter budgets and recovery beats without equalizing cars,
   routes or luck or introducing hidden score compensation.
6. Animate a small coherent roadside sample with cached/batched work before
   expanding art packs. Maintain reduced-motion and stable comparisons.

## Ranitas: inspected research and implementation

These are project evidence and design interpretations, not independent efficacy
studies. The review followed the linked files on the repository's default branch;
future reviews should retain the exact revision alongside collected metrics.

Repository tree snapshots inspected in this session: Ranitas
[`03f3901`](https://github.com/8007342/ranitas/tree/03f3901ba0022746ea1920564bd2df3b90d7e98f)
and Demon Attack
[`7ef1b57`](https://github.com/8007342/demon_attack/tree/7ef1b57337e38b1a487fd755943f1bbdc9ced52d).
The links below retain readable default-branch paths; these snapshots identify
the versions reviewed, rather than implying future edits were inspected.

| Source | Disposition and use in Cannonball | Limits / excluded part |
| --- | --- | --- |
| [Research and experience evidence](https://github.com/8007342/ranitas/blob/main/docs/research.md) | Apply the separation of seeded model, presentation, foreground pacing and honest validation; use bounded state transitions for environmental events. | Do not transplant the tranquil session length, sleep system, insect biology or synthetic jump-policy prior into racing. No human wellbeing benefit was established. |
| [Visual-envelope research](https://github.com/8007342/ranitas/blob/main/docs/visual-envelope.md) | Apply layered depth, explicit asset-memory accounting, ground-relative scale, cheap lagged foliage and a record of design-versus-code deviations. | Its 641×359 pixel grid and quantized nearest-neighbor animation are not automatically appropriate for Cannonball's diffused pixel motion. |
| [Visual-envelope design](https://github.com/8007342/ranitas/blob/main/openspec/changes/visual-envelope/design.md) | Adapt seeded time envelopes, source-specific randomness, layered composition and independently bounded motion. | Rain ecology, pad roaming and frog depth targets are pond-specific. A shader or learned model is not required for this proof. |
| [Animation and micro-expression guide](https://github.com/8007342/ranitas/blob/main/art/ANIMATION_STYLEGUIDE.md) | Apply separate ground point/shadow, timed pose phases, small secondary reactions and silhouette discipline to car contact and load cues. | Frog squash/stretch amplitudes, fish wave mechanics and underwater attenuation are not car suspension constants; styleguide examples are not proof of current implementation. |
| [Interaction and layering guide](https://github.com/8007342/ranitas/blob/main/art/INTERACTION_STYLEGUIDE.md) | Apply impulse → damped response → settling, layered actor/effect order and explicit interaction event tables. | Do not copy every guide formula: its jump timing and some implementation descriptions differ from other Ranitas snapshots. Pad springs cannot by themselves solve incorrect car artwork. |
| [Visual style guide](https://github.com/8007342/ranitas/blob/main/art/STYLEGUIDE.md) | Apply coherent pose/atlas/pivot contracts and biome-wide art decisions. | Do not import its strict nearest-neighbor pixel rules or prime dimensions as universal antialiasing techniques. |
| [Quiet awakening research](https://github.com/8007342/ranitas/blob/main/docs/quiet-awakening.md) | Adapt continuous environmental reveals and coordinated sound/visual envelopes at nonblocking road-region handoffs. | Hiding changes is not a racing objective; hazards and instructions must remain apparent. No mandatory tranquil opening or sleep choreography. |
| [Shader-grade plan](https://github.com/8007342/ranitas/blob/main/docs/shader-grade-plan.md) | Deferred. Retain material-aware lighting as a possible later comparison. | A speculative shader plan does not establish mobile-web support or benefit. This proof needs geometry/contact and bounded atlas work first. |
| [Frog renderer](https://github.com/8007342/ranitas/blob/main/lib/game/frog_sprites.dart) | Apply the implementation pattern of separate ground coordinates, pose selection, depth cues and optional asset fallback. | No frog artwork or code is copied. Quantized sprite scaling is not adopted indiscriminately. |
| [Foliage implementation](https://github.com/8007342/ranitas/blob/main/lib/game/foliage.dart) and [layer stack](https://github.com/8007342/ranitas/blob/main/lib/game/scene_layers.dart) | Adapt per-instance phase, world-anchored motion and atlas batches for a bounded roadside sample; retain root-to-tip lag as the next separated-art technique. | Painted/procedural mismatch and authoring cost remain visible limits; no claim that every existing tree is independently rigged. |

### Primary research found through Ranitas

| Source | Disposition and application | Limits / why not more |
| --- | --- | --- |
| [Booth, Valve: AI Systems of Left 4 Dead](https://cdn.cloudflare.steamstatic.com/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf) | Apply pressure/release pacing and the distinction between encounter frequency and threat strength. | Its survivor intensity estimator and 3–5/30–45 second examples are not racing defaults; no adaptive Director is implied. |
| [Simons, Franconeri and Reimer: gradual change blindness](https://journals.sagepub.com/doi/10.1068/p3104) and [Rensink et al.: interrupted-scene change detection](https://www2.psych.ubc.ca/~rensink/publications/abs.00.12.html) | Background context for smooth scenic transitions. | Not adopted as concealment techniques; distinct experiments do not prescribe our fades or establish comfort. |
| [Change-blindness review found in quiet-awakening research](https://pmc.ncbi.nlm.nih.gov/articles/PMC11401121/) | Background only; no new gameplay rule. | Not needed to implement a visible, continuous driving transition. |
| [NN/g: animation usability](https://www.nngroup.com/articles/animation-usability/) | Apply legible cause/effect and purposeful transition motion. | Design guidance, not a numeric vehicle model. |
| [GDC audio-feel talk linked by Ranitas](https://www.gdcvault.com/play/1034773/Audio-Summit-How-Sound-Can) | Background motivation for matching feedback across audio and motion. | No detailed quantitative claim or new audio engine is derived from the talk listing. |
| [W3C animation-from-interactions guidance](https://www.w3.org/WAI/WCAG21/Understanding/animation-from-interactions) | Preserve reduced decorative motion and stable presentation comparisons. | Does not require removing essential road/traffic movement. |
| [Tammero and Dickinson: fruit-fly flight](https://pubmed.ncbi.nlm.nih.gov/11854370/), [Fuller et al.: wind sensing](https://pmc.ncbi.nlm.nih.gov/articles/PMC3977237/), [Olberg et al.: dragonfly interception](https://pubmed.ncbi.nlm.nih.gov/10707313/) | Not used in this proof. | Biology-informed insects are not a justified solution for road traffic or steering. Smooth NPCs do not need a simulated insect sensory system. |
| [Atrapa policy/training snapshot](https://github.com/8007342/atrapa/tree/df3d4f3e16b2353013c4d625e8e3a7617b1b236e) | Retain deterministic local observation/fallback lessons already documented in [traffic research](atrapa-traffic.md). | Do not transplant its neural weights or Ranitas's synthetic-imitation policy; teacher-action agreement is not driving quality. |

## Demon Attack: inspected research and implementation

| Source | Disposition and use in Cannonball | Limits / excluded part |
| --- | --- | --- |
| [Difficulty calibration](https://github.com/8007342/demon_attack/blob/main/plan/difficulty-calibration.md), [current audit](https://github.com/8007342/demon_attack/blob/main/plan/calibration-current.md), [historical audit](https://github.com/8007342/demon_attack/blob/main/plan/calibration-baseline.md) | Apply explicit whole-encounter budgets, generated-seed audits and before/after measurements. Identify compounded pressure from density, closing speed, bend demand, visibility and recovery cost. | Enemy HP, damage and 2.5× defense-budget ceilings are shooter-specific. Automated protected pilots measure workload, not human fairness. |
| [Difficulty policy code](https://github.com/8007342/demon_attack/blob/main/lib/game/difficulty.dart) | Adapt the small centralized bounded-policy pattern where this proof adds encounter pacing. | No Easy/Normal/Hard racing modes, car parity or partitioned rankings are introduced. |
| [Current game design](https://github.com/8007342/demon_attack/blob/main/plan/game-design.md) and [balance design](https://github.com/8007342/demon_attack/blob/main/openspec/changes/balance-five-tour-campaign/design.md) | Apply separation of progression, encounter policy and presentation; preserve finite review sections. | Five-tour rewards, lives, power stacking, bosses and scoring are not racing requirements. |
| [Endless-design research](https://github.com/8007342/demon_attack/blob/main/plan/endless-design-research.md) | Apply readable telegraphs, bounded escalation, environmental storytelling and recovery opportunities. | Do not indefinitely reduce reaction time or make all variables harder together. Endless loops are outside this proof. |
| [Transition research](https://github.com/8007342/demon_attack/blob/main/plan/transition-research.md) | Adapt one normalized transition clock, overlapping visual/audio envelopes and immediate event feedback. | Do not insert mandatory intermission cutscenes into active driving or add a Godot dependency. |
| [Style guide](https://github.com/8007342/demon_attack/blob/main/plan/style-guide.md) and [sprite atlas contract](https://github.com/8007342/demon_attack/blob/main/plan/sprite-atlas.md) | Apply authored intermediate silhouettes, consistent atlas anchors and state-driven warning/damage phases. | Its strict hard-pixel 32×32 logical creature art is not Cannonball's soft-edged car style; avoid stretching one sprite to fake every pose. |
| [Sector style guide](https://github.com/8007342/demon_attack/blob/main/plan/sector-style-guide.md) | Apply strong environment identity and restrained peripheral motion while keeping a clear gameplay lane. | No space paintings, palette or combat effects copied; tiny decorative detail must not compete with brake lights or gaps. |
| [Hint usability](https://github.com/8007342/demon_attack/blob/main/plan/hint-usability.md) | Apply brief contextual, action-first advice and actual phone-size review. | Its loading-only hint policy is not transplanted; Cannonball must keep driving continuous. |
| [Original-game research](https://github.com/8007342/demon_attack/blob/main/plan/research-original.md) | Apply its method of separating primary manuals and platform-specific behavior. | Imagic enemy/boss mechanics and historical sprites are not relevant racing assets. |
| [Audio/backend notes](https://github.com/8007342/demon_attack/blob/main/plan/audio-backend.md) | Retain gesture gating, scheduled audio, bounded release tails and failure fallback. | Existing Cannonball scores/radio remain; no duplicate MIDI engine or client-reported honor-board contract. |

### Primary research found through Demon Attack

| Source | Disposition and application | Limits / why not more |
| --- | --- | --- |
| [Sweetser and Wyeth: GameFlow](https://doi.org/10.1145/1077246.1077253) | Apply control, feedback, readable goals and appropriate challenge as review dimensions. | GameFlow is not Valve-authored and does not specify a racing difficulty formula. |
| [Ambinder, Valve: empirical playtesting](https://cdn.fastly.steamstatic.com/apps/valve/2009/GDC2009_ValvesApproachToPlaytesting.pdf) | Apply iteration with observed collisions, correction behavior, gaps and comfort; record negative feedback. | Technical checks are not a substitute for human playtesting. |
| [Riot: VALORANT gameplay clarity](https://www.riotgames.com/en/news/valorant-shaders-and-gameplay-clarity) | Apply silhouette/brightness priority for consequential objects and a quiet central corridor. | Shooter colors and render pipeline are not imported. |
| [Valve: Portal narrative/design postmortem](https://cdn.akamai.steamstatic.com/apps/valve/2008/GDC2008_PortalPostMortem.pdf) | Deferred campaign use: environmental roadside storytelling rather than exposition during driving. | This proof is a handling course, not a completed story stage. |
| [Game Accessibility Guidelines](https://gameaccessibilityguidelines.com/full-list/) | Retain immediate play, legibility and usable control targets as review criteria. | No unrelated menu redesign in this proof. |
| [Audiokinetic interactive music](https://www.audiokinetic.com/en/public-library/2024.1.8_8893/?id=creating_interactive_music&source=Help), [stinger tutorial](https://www.audiokinetic.com/en/learn/videos/flrz463kvei?course=wwise301&lesson=1), [segment timing](https://www.audiokinetic.com/library/2024.1.2_8726/?id=music_segment_property_editor&source=Help) | Reference for separate immediate feedback and scheduled musical handoffs; preserve existing score/radio integration. | No Wwise dependency, forced bar wait for a hazard cue or score rewrite. |
| [Godot Tween documentation](https://docs.godotengine.org/en/stable/classes/class_tween.html) | Apply the engine-independent idea of one clock coordinating sequential/parallel eased properties. | Flutter/Flame remains the implementation stack. |
| [Xbox XAG 101](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/101), [114](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/114), [116](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/116), [Apple onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding), [W3C timing adjustable](https://www.w3.org/WAI/WCAG22/Understanding/timing-adjustable), [pause/stop/hide](https://www.w3.org/WAI/WCAG22/Understanding/pause-stop-hide.html) | Reference for readable contextual instructions, controllable review and nonblocking information. | Do not infer that one timing value suits all readers or create a new mandatory tutorial flow. |

## Direct implementation references found for this iteration

| Source | Disposition and use | Limits / excluded part |
| --- | --- | --- |
| [Ryan Juckett: Damped Springs](https://www.ryanjuckett.com/damped-springs/) | Apply its explained second-order response model: separate target, velocity, damping and frequency; use a bounded settled response for car/camera cues. | Existing semi-implicit substeps may remain where verified. Exact coefficients are an implementation choice, not a prerequisite to use the principle; retain license if source code is copied. |
| [Glenn Fiedler: Spring Physics](https://gafferongames.com/post/spring_physics/) and [Integration Basics](https://gafferongames.com/post/integration_basics/) | Apply explicit spring/damper forces and deliberate integration/step-size choices; verify schedule consistency and bounded settling. | A full chassis/rigid-body simulation is unnecessary for a subtle visual cue. |
| [Jake Gordon: pseudo-3D hills](https://jakesgordon.com/writing/javascript-racer-v3-hills/) and [example repository](https://github.com/jakesgordon/javascript-racer) | Apply a shared elevation coordinate, eased road transitions and consistent projection for road and actors. | Demo geometry and car frames are not production geography or reusable original assets. |
| [Lou Gorenfeld: pseudo-3D roads](https://www.extentofthejam.com/pseudo/) | Apply the explained perspective/curve/hill vocabulary when checking projection and preview. | Historical line-warp tricks are reference techniques, not a requirement to rewrite our mesh renderer. |
| [Descenders mobile controls postmortem](https://www.gamedeveloper.com/game-platforms/deep-dive-creating-the-touch-controls-for-descenders-on-mobile) | Apply representative demanding maneuvers, minimal controls, multiple usable comparisons and iteration with skilled players. | Does not prescribe our wheel layout or prove two sticks are best for racing. |
| [Cairns, Li, Wang and Nordin: mobile controllers](https://pure.york.ac.uk/portal/en/publications/the-influence-of-controllers-on-immersion-in-mobile-games/) ([author PDF](https://www-users.york.ac.uk/~pc530/pubs/Li_CHI2014.pdf)) | Supports investigating natural mapping and immersion separately from performance. Keep accepted touch mapping as baseline and compare deliberately. | Author PDF retrieval timed out during this pass; inspected institutional abstract and indexed excerpts. No ranking of our wheel versus tilt, no universal gain or latency target inferred. |
| [Apple WWDC21: virtual/physical controllers](https://developer.apple.com/videos/play/wwdc2021/10081/) | Apply separation of visual controls from normalized input and attention to grip/hand sizes. | Native Game Controller APIs are not a browser dependency. |
| [Unity On-screen Controls](https://docs.unity.cn/Packages/com.unity.inputsystem%401.10/manual/OnScreen.html) | Apply visual/input separation, gesture-origin-relative drag and a documented movement range as a comparison pattern. | Unity package is not imported; a touch joystick is not automatically a better wheel. |
| [Enhanced On-Screen Stick implementation](https://github.com/starburst997/Unity.OnScreenStick) | Optional reference for fixed/floating/dynamic origins and explicit dead zones. | Not adopted as a dependency; extra dead zones or moving origins could harm precision and need comparison first. |
| [Schmierbach et al.: personalized speed](https://pubmed.ncbi.nlm.nih.gov/22687145/) | Not adopted as touch-wheel evidence; background on natural controls/customization. | A console steering-wheel study does not establish thumb travel, phone precision or a browser wheel gain. |
| [Mobile top-down control comparison for children](https://ciencia.ucp.pt/pt/publications/mapping-controls-on-a-2d-user-drawn-racetracks-driving-game-an-us/) | Deferred follow-up context only. | Different audience, view and tasks; no direct numeric prescription used. |
| [Smartphone as remote PC-racing controller thesis](https://www.diva-portal.org/smash/get/diva2%3A831318/FULLTEXT01.pdf) | Deferred. | Phone-as-controller for a separate display differs from touch overlaid on the gameplay view; no evidence of the right rim proportions here. |
| [Tilt versus facial tracking research](https://www.yorku.ca/mack/ieeegem2014b.html) | Not adopted for touch-wheel selection. | The evaluated comparison is not our wheel and adding facial tracking is outside the approved input scope. |
| [Designing Driver Assistance for Racing thesis](https://odr.chalmers.se/server/api/core/bitstreams/46318a38-52af-4ee5-b33d-5d77c200e27c/content) | Deferred as a broader assistance reference. | This pass retains the separately researched gentle-road assist track and does not add autonomous gap/line selection. |
| [Steering feedback in dynamic simulators](https://arxiv.org/abs/2403.17800) | Not used for this proof. | Physical steering torque/vibration in a driving simulator does not establish a touch response or a visual suspension amplitude. |
| [Suhaib: Tilt or Touch?](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3409575) ([publisher listing](https://ijircce.com/article/tilt-or-touch-an-evaluation-of-steering-control-of-racing-game-on-tablet-or-smartphonemuhammad-suha-9743)) | Excluded from control-selection evidence. | Its abstract reports two participants, each assigned a different control; participant differences confound a general winner. It cannot justify replacing accepted touch controls. |
| [Touchscreen-control critique, Anna Marsh](https://www.gamedeveloper.com/game-platforms/designing-better-controls-for-the-touchscreen-experience) | Background challenge to assumptions about virtual controls. | Not a reason to discard a wheel the user reports is now precise; no blanket anti-wheel rule. |
| [Design mechanics around controls](https://www.gamedeveloper.com/design/thinking-gameplay-mechanics-by-taking-into-account-players-controls) | Background motivation for designing the course around available touch actions. | Not quantitative steering evidence; no control-system rewrite follows from the essay. |
| [Crytek / GPU Gems 3: vegetation animation](https://developer.nvidia.com/gpugems/gpugems3/part-iii-rendering/chapter-16-vegetation-procedural-animation-and-shading-crysis) | Apply coarse bounded, position-phased whole-tree bending about a ground pivot in a bounded roadside sample; `foliage=still` retains a stable comparison. | Adapt conceptually to 2D atlas batches. Separate leaf detail and multi-segment branch motion are deferred because the current paintings have no separated layers. Do not import the GPU shader pipeline or pretend every tree has physical branches. |
| [Treiber: Intelligent Driver Model](https://mtreiber.de/MicroApplet/IDM.html) | Deferred as a full policy replacement; use documented speed/gap/closing-speed vocabulary to audit current following behavior. | Existing traffic already has local following; uncalibrated arcade units must not receive real-world constants blindly. |
| [Treiber/Helbing: MOBIL](https://mtreiber.de/MicroApplet/MOBIL.html) and [publication](https://mtreiber.de/publications/MOBIL.pdf) | Deferred implementation; reference safety/incentive separation and a threshold against pointless lane hopping. | This proof does not claim calibrated IDM/MOBIL traffic. Driver personality still needs bounded, readable player response. |

## Existing Cannonball research carried forward

| Source | Application / disposition |
| --- | --- |
| [Holm, Skovhus and Kraus 2017](https://eudl.eu/doi/10.1007/978-3-319-55834-9_14), [earlier interpretation](perceived-speed-milestone.md) | Compare geometric FOV, near-field references and altitude independently. Do not assume blur improves speed; direct PDF access timed out in this iteration, so preserve access limitations and do not invent thresholds. |
| [Sandin et al. 2016 sensory cues](https://proceedings.driving-simulation.org/proceeding/dsc-2016/effects-of-sensory-cues-on-perceived-simulated-speed/) | Compare coherent engine/road sound on/off. Task-dependent simulator findings do not mean louder always feels faster. |
| [2025 visual/acoustic-flow paper](https://www.sciencedirect.com/science/article/pii/S1369847825000543) | Background only: abstract found, full text inaccessible. No quantitative prescription used. |
| [Autodesk vehicle control properties](https://help.autodesk.com/cloudhelp/ENU/Stingray-Help/stingray_help/creating_gameplay/physics/vehicle_physics_properties.html) | Retain separate input rise/fall and speed-dependent limits as options; preserve prompt response and signed pose progression. Constants remain tuning hypotheses. |
| [Friston et al. low-latency study](https://discovery.ucl.ac.uk/id/eprint/1471049/) | Distinguish input latency from progressive vehicle/pose response. Pointing/path-steering tasks do not prescribe a racing pose duration. |
| [Unity Position Composer](https://docs.unity3d.com/Packages/com.unity.cinemachine@3.1/manual/CinemachinePositionComposer.html), [PhysX vehicles](https://nvidia-omniverse.github.io/PhysX/physx/5.6.1/docs/Vehicles.html) | Retain separate composition, lookahead and sprung-response concepts. No Unity/PhysX dependency or calibrated four-wheel model claimed. |
| [Cannonball rewrite curve implementation](https://github.com/djyt/cannonball/blob/master/src/main/engine/oferrari.cpp), [control manual](https://github.com/djyt/cannonball/wiki/Cannonball-Manual), [SEGA OutRun manual](https://www.sega.jp/mdmini2/en/assets/manual/pdf/EU_OutRun.pdf) | Existing [gentle-curve research](lane-following-assist.md) remains separately tracked. Preserve road-relative offset and deliberate inputs; never turn drift cancellation into lane-center attraction. No copied source/assets or claim of official SEGA source code. |
| [Motion/art filtering research](motion-art.md), [renderer audit](renderer-audit.md), [Wasm comparison](wasm-benchmark.md), [course/camera research](course-camera.md), [rolling/chase research](rolling-chase-suspension.md) | Preserve all original source links and scope through the register. Actual backing pixels, frame pacing, shared projection and coherent anchors remain requirements. Do not treat a compiler switch, blur, logical resolution or tests as proof of visual success. |

## Comparison and acceptance contract

The next proof retains earlier query comparisons and adds only documented options: `motion=velocity` (presentation168 versus `hyperspeed`132), `touch=travel` (160 CSS-pixel full-scale tangential travel), `slope=legacy` (old steep cells), and `foliage=still` (no tree sway). The new depth mesh targets330 course units with conservative traffic preview at least320; terrain occlusion remains separate. Actual speed physics is unchanged. Seeded admission repeats build/overtake/release beats and never deletes existing traffic to meet a lower capacity.
Baseline touch, normalized-touch comparison if delivered, speed variants and stable
body/chase controls must be independently identifiable in telemetry. Every course
chapter is replayable so subtle differences can be reviewed without repeating the
intro. Keep geometry/physics/seed fixed when attributing a result to presentation.

Report useful preview distance and estimated preview time alongside the speed
preset; camera/pose pitch, contact anchors and transition states alongside car
animation; collision/near-miss and gap measures alongside encounter density; and
render work/backing pixels/p95/p99 alongside cadence. A crest can legitimately
hide traffic, so geometric draw range is not a guarantee of visible hazard time.
Record such occlusion separately from hard draw-boundary clipping.

Automated checks establish finite bounded geometry, shared coordinates, input
ownership, settling, stable replay and regression protection. Browser injection
is emulated input. Physical-phone grip, precise thumb travel, comfort, audible
mix, perceived speed and challenge still require the user's moving review. Keep
production acceptance tasks open and never describe local publishing as live
Google/Cloudflare deployment.
