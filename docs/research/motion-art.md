# Pixel art, smooth movement, and camera lean

Web-only research, checked 2026-10-25. This supplements `engine.md`; it does not add native-platform launch requirements. User direction: pixelated art with gently diffused edges, a predominantly flat horizon with subtle lean, and a somewhat stronger lean when motion steering is enabled.

## Art direction and motion are separate controls

Preserve deliberate pixel clusters, readable silhouettes, and limited palette ramps in source art. Gently soften the final reconstruction of those pixels rather than painting every sprite as a blurry object. Roads, traffic, cones, route signs, and brake cues must remain distinguishable at speed. HUD text and touch targets need independent sharp rendering.

Spatial sampling affects jagged edges and detail when scaling; temporal aliasing appears as flicker, crawling, strobing, or wheels appearing to rotate incorrectly over successive frames. Bilinear filtering softens spatial edges, but does not by itself solve temporal undersampling. NVIDIA's author research identifies sampling density and band-limiting as the foundation and discusses blur/ghosting introduced by reconstruction ([Adaptive Temporal Antialiasing](https://research.nvidia.com/sites/default/files/pubs/2018-08_Adaptive-Temporal-Antialiasing/adaptive-temporal-antialiasing-preprint.pdf)); [CMU graphics teaching material](https://www.cs.cmu.edu/afs/cs/academic/class/15462-s09/www/lec/13/lec13.pdf) explains temporal sampling and motion integration.

Recommendation: stable frame pacing, continuous interpolated transforms, appropriately filtered distant detail, and coherent animation frame selection come before any optional motion blur. Blanket Gaussian blur would soften hazards while leaving frame-time stutter and wrong animation timing intact. Speed streaks can be decorative peripheral effects; they must not be described as temporal antialiasing.

## Sprite filtering and atlases

Flutter documents nearest-neighbor (`none`), bilinear (`low`), mipmapped filtering (`medium`), and bicubic (`high`) with different scaling tradeoffs ([FilterQuality](https://api.flutter.dev/flutter/dart-ui/FilterQuality.html)). Candidate baseline: bilinear for gently enlarged nearby sprites, medium for sprites shrinking dramatically toward the horizon, and nearest-neighbor only as an intentional comparison mode. These are prototype candidates, not a promise of identical rendering across all web backends.

Keep low-resolution source art clean, then tune diffusion in screen-space terms. Avoid baking broad halos into every source pixel: those halos expand with the car and contaminate neighboring atlas cells. Flutter notes that filtered sampling can reach outside a source rectangle ([drawImageRect](https://api.flutter.dev/flutter/dart-ui/Canvas/drawImageRect.html)). Pack atlases with duplicated edge texels/extrusion and gutters sized for the actual filter footprint and downscale levels; test transparency against both bright snow and dark asphalt. Do not assume a fixed one-pixel gutter handles every scale.

Use identical pivots, ground contacts, physical scale, frame bounds, and padding across vehicle views. Flame supports atlas batching and timed sprite animations ([Flame image/animation documentation](https://docs.flame-engine.org/latest/flame/rendering/images.html)). State-driven rear/uphill/turn/skid frames should be selected from smoothed simulation state, with hysteresis to stop flickering at thresholds. Wheel/engine animation advances by distance or engine state as appropriate, not by “one sprite frame per display frame.” Impact/flip sequences use elapsed simulation time. Do not crossfade every pose indiscriminately: it can create double outlines; author intermediate poses where the silhouette changes substantially.

One especially relevant web caveat: Flutter's own July 2026 change fixes web atlas filtering that previously ignored the selected quality in a backend ([Flutter engine commit](https://dart.googlesource.com/external/github.com/flutter/flutter/+/914195c536e1bfcaa86f892b37589563e324be8a)). Verify the project's pinned Flutter release contains the fix, or test the specific renderer rather than assuming `drawAtlas` and individual sprite draws match.

## Mobile and desktop resolution tiers

Use one art language and camera contract across devices. Separate source-art resolution, logical viewport, backing render resolution, device pixel ratio, and final display size; they are not interchangeable. A high-DPI phone should not automatically render the race at its full physical pixel count.

Prototype race-canvas tiers around 640×360, 960×540, and 1280×720 equivalents, adapted to the actual landscape aspect ratio without stretching. These are candidate measurement points, not approved shipping requirements. Keep HUD layout in logical screen units with adequate touch targets. On ultrawide screens preserve road-camera visibility rules and use the extra width deliberately rather than revealing off-route artifacts. Desktop can select a higher render tier without adding microscopic details that change reaction time or concealment.

Deliver only needed biome/vehicle atlases, preload the next route alternatives, and cap decoded texture memory. A 2× image in each dimension costs roughly 4× the raw pixel storage. Choose initial tier from measured capability and viewport; adapt only with hysteresis and at a stable transition so resolution does not visibly pump during a corner. Quality changes must not alter physics, obstacle positions, route opportunities, or the run's difficulty. Profile on real mobile browsers, including warm sustained sessions; Flutter advises profile-mode measurement rather than judging debug builds ([rendering performance](https://docs.flutter.dev/perf/rendering-performance)).

## Camera lean and comfort

The accepted design target is a predominantly flat horizon with small, smooth roll, somewhat stronger under motion steering. Keep camera roll a presentation effect independent of steering physics, and leave HUD and touch controls screen-aligned. Filter sensor noise in the input adapter and derive the visual lean from a separately damped signal. Distinguish phone orientation, car body roll, camera roll, and the world horizon angle; those have different signs depending on camera conventions.

No cited source establishes one universally “natural” roll direction for a third-person pseudo-3D racing game on a handheld screen. Driver head posture depends on anticipation and context, and it does not uniquely determine how a chase camera should roll. Do not declare inward or outward bank correct without user review. Produce mirrored left-turn comparisons with labeled camera/horizon behavior and select the felt result.

Apple recommends keeping the horizon aligned and camera changes predictable in its [vision and motion design presentation](https://developer.apple.com/videos/play/wwdc2023/10078/). Microsoft warns that unexpected virtual self-motion can cause discomfort in [its comfort guidance](https://learn.microsoft.com/en-us/windows/mixed-reality/design/comfort). Both discuss immersive/spatial contexts. Applying their caution to a browser racing game is an inference, not direct evidence for a particular roll angle or a ban on all 2D-game lean.

Candidate comparison settings: 0°; gentle roll capped near 1–2°; motion-control roll capped near 3–4°, with smooth onset and recovery. These figures are proposed test settings, not research-derived safety thresholds or final tuning. Test both signs, independently adjustable gain, and an immediate “steady horizon” option. Respect reduced-motion preferences by defaulting to zero additional roll/shake, while retaining user choice. Do not multiply raw sensor roll directly into camera roll: physically tilting the phone already changes its relationship to the real horizon, and additional view rotation may amplify or oppose that perceived motion.

## Prototype review checklist

- Compare nearest, bilinear, and medium filtering on the same art and seeded run; watch moving video, not only screenshots.
- Test slow scale changes toward the horizon, lane markings, guardrails, distant vegetation, truck grills, cones, transparent sprite edges, and car-wheel animation for shimmer or bleeding.
- Compare intentional diffused pixels against blanket blur; check whether players recognize hazards and route signs equally early.
- Record frame-time distributions and perceived steering latency at each canvas tier on Safari/iPhone, Chrome/Android, and desktop. Include resize, browser UI expansion, background/resume, and sustained thermal load.
- Verify simulation interpolation stays smooth at 60/90/120 Hz and that lower frame rates do not change timers, traffic, or pose timing. Stable 60 fps is the first goal, not a claim that every device sustains it.
- Show flat/gentle/stronger-motion lean side by side through the same left/right corners. Ask about direction, stability, eyestrain, and control precision. Include participants prone to motion discomfort and permit stopping immediately.
- Keep crest pitch distinct from roll; test curves during hills and crashes without combining excessive shake, lean, blur, and weather occlusion.
- Confirm the chosen diffused-edge look and lean on the smallest supported phone before generating the production car/biome sets.
