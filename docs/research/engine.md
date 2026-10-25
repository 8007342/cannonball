# Cannonball engine and platform research

Research checked 2026-10-25. Recommendations below are design proposals, not claims that a performance prototype has already validated them.

## Rendering approach

Use Flutter for menus, profile, settings, and accessible UI; use one Flame game canvas for the race. Flame exposes Flutter Canvas rendering, sprites, layers, and shaders ([Flame rendering](https://docs.flame-engine.org/latest/flame/rendering/rendering.html)). Its camera offers fixed-resolution and adaptive viewports, with HUD components independent of world movement ([camera documentation](https://docs.flame-engine.org/latest/flame/camera.html)).

**Recommendation:** build an OutRun-style segmented road renderer first. Represent road segments with distance, elevation, curvature, lane widths, surface, exits, and scenery references. Project segment endpoints into screen space, render road strips back to front, and scale depth-sorted billboard sprites. Keep collision and traffic simulation in road coordinates, independent of screen projection. This supports hills, valleys, curved ramps, forks, weather, and rapid authored scenery changes without requiring a full 3D engine.

Mode 7 is useful inspiration, but a single affine ground plane is not a complete renderer for these requirements. A perspective floor can be approximated using different affine transforms per scanline; hills, stacked overpasses, and vertical architecture require additional geometry or layers. The original author-maintained [Tonc Mode 7 tutorial](https://gbadev.net/tonc/mode7.html) explains this planar projection; its [extended example](https://github.com/gbadev-org/tonc/blob/master/content/mode7ex.md) adds camera projection and depth-scaled sprites. Our inference: use a hybrid of projected road strips, billboard art, and layered bridges rather than literal hardware emulation.

Crossing stacked roads needs explicit elevation, occlusion masks, and collision separation. A freeway interchange must be modeled as a route graph with visible route ownership; a backdrop painting alone cannot support independently navigable crossing roads. Start with diverge/rejoin branches; prove one stacked crossing before promising complex multilevel flyovers.

## Runtime model

- Fixed simulation step with interpolated presentation; seed all ranked randomness. Do not advance physics by arbitrary frame deltas or use wall-clock changes as race time.
- Separate route graph, current road stream, traffic simulation, collision/recovery, race clock, input adapters, pacing director, presentation, audio, and persistence.
- Version route data, physics, vehicle balance, content manifests, and seeds together. A run receipt should record those versions and its route decisions.
- Generate bounded road/scenery chunks ahead of the player. Preload both candidate branches before the decision point, discard safely after commitment, and retain enough history for crash recovery.
- Declare content in validated data: road shape, lane connectivity, surface grip, construction windows, NPC-only exits, scenery sockets, weather, radio triggers, checkpoints, landmarks, and secret-car unlock conditions.
- Never randomly seal all reachable paths, hide a closure beyond braking distance, or spawn a mandatory collision. Validate every generated section for at least one traversable corridor under the current vehicle/weather envelope.
- Keep local racing independent of login, asset network requests, and cloud save completion. Queue synchronization and radio preparation asynchronously.

These are proposed architecture requirements. Flame supplies the game loop and rendering primitives; it does not automatically supply this racing simulation or a content director.

## Speed, traffic, and crash presentation

Use lane markings, roadside parallax, engine pitch, close but readable traffic, near-miss effects, and rapid environment movement to preserve perceived speed. Traffic can cruise at substantial world speed while the player retains enough relative speed for overtaking. Require earlier readable lane changes rather than forcing prolonged crawling.

NPCs need desired speed, route intent, indicators, lane-change anticipation, safe-gap checks, and deterministic conflict resolution. Clearly block NPC-only exits with barriers. Trucks changing tires and lane closures need cones and advance signs, with clear collision boundaries. Recovery should select a verified clear location in the intended route and provide a short protection window; blindly resetting to geometric road center could place the player inside traffic or a closed lane.

Tune crash slowdown, flip duration, timer penalty, checkpoint allowance, and recovery protection together. The exact values require the design interview and playtesting.

## Tilt, steering wheel, and landscape

Device orientation access requires HTTPS and may require a permission request triggered directly by a user action ([W3C Device Orientation and Motion](https://www.w3.org/TR/orientation-event/)). Implement feature detection, explicit enable/recalibrate, a dead zone, low-pass filtering, adjustable sensitivity, landscape-axis normalization, and a no-events timeout that offers touch steering. Test real iPhone and Android devices; desktop emulation cannot establish sensor reliability.

Interpretation of the requested touch control: a giant steering wheel lies in the screen plane, closer to the viewer than the game camera. Most of its circle sits outside the display, so the player sees translucent rim arcs at the left/right edges and an unobstructed transparent center. Dragging the rim steers. This is an overlay, independent of the player-car sprite and road camera. Keep the input capture area generous even if the visible rim is thin. Confirm whether drags should rotate the virtual wheel around an off-screen hub, or simply map horizontal movement to steering. Two simultaneous contacts must allow braking and steering without either gesture stealing the other.

Keep horizon roll independent of physical steering input. Default proposal: stable horizon; optional subtle, capped, damped roll based on simulated cornering with a reduced-motion setting. Phone roll should not directly rotate the whole canvas, HUD, or sensor coordinate frame. Confirm the intended roll direction with a short prototype because “head resisting force” can be interpreted in opposite ways.

Landscape is an essential gameplay layout. Request it in native platform configuration and the web manifest, attempt fullscreen/landscape lock from a user gesture where supported, and show a rotate-device screen if the browser remains portrait. Browser orientation lock can impose fullscreen/installed-app conditions and can reject; a web app cannot guarantee system-level landscape on every device ([W3C Screen Orientation](https://www.w3.org/TR/screen-orientation/)). Pause simulation and clock when gameplay loses visibility or becomes unplayable; define separately whether such a run remains eligible for ranked play.

Small top controls can look subtle while retaining large touch targets and readable focus/active states. Steering toggle, mute, profile, and pause must not depend on tiny low-opacity hit regions. Profile must not unexpectedly steal control during a race.

## Music, speech, and uninterrupted transitions

Web MIDI exchanges note/controller messages with MIDI devices; MIDI messages are not audio ([W3C Web MIDI](https://www.w3.org/TR/webmidi/)). Do not depend on a hardware MIDI synthesizer or MIDI permission to play the soundtrack. Use an internal synthesizer with licensed soundfont/samples, or pre-rendered synchronized stems as a compatibility fallback. Web Audio provides synthesis, processing, and scheduled playback ([Web Audio specification](https://www.w3.org/TR/webaudio/)). Evaluate the actual Dart/web audio bridge and browser latency in a spike before selecting a package.

Use city/biome themes and intensity layers, change at musical bar boundaries, duck music under radio, and apply independent music/effects/voice volumes. Avoid creating oscillators or decoding large samples on every frame. Include a simple fallback stereo mix if live synthesis cannot meet the device budget.

Audio startup must be connected to player interaction. Chrome can suspend an AudioContext created before user interaction until it is resumed ([Chrome autoplay policy](https://developer.chrome.com/blog/autoplay/)). Treat selecting the first keys/start as the audio unlock action; mute must persist and resumption after backgrounding must be tested.

Browser speech synthesis voices may be local or remote, with platform-dependent availability and latency ([Web Speech specification](https://webaudio.github.io/web-speech-api/)). Recommendation: ship or cache a curated library of approved radio phrases, and use runtime TTS as an optional fallback for unanticipated combinations. Generate upcoming reports before their trigger. Every consequential advisory also needs a short subtitle and roadside visual cue. Do not wait for TTS/network completion to move the car.

Radio content must describe the actual seeded near-future route state. Schedule advance warning using time-to-decision, not just a fixed distance. Expire stale reports after a branch choice; prioritize closures/hazards over flavor; never queue several long reports across a gate. Distinguish present city weather from the forecast for the next region. Nebraska sunshine followed by Colorado snow should make geographic and temporal sense.

Treat “loading screens between levels without interruption” as moving transition corridors: scenery blends, title cards, radio, hints, and asynchronous prefetch while controls remain live. A blocking full-screen loading panel cannot preserve uninterrupted driving. Long narrative cutscenes belong before a run or after completion, or must have a clearly agreed playable/autodrive treatment.

## Art and compositing contract

Flame can cache images and batch sprites from atlases ([images and SpriteBatch](https://docs.flame-engine.org/latest/flame/rendering/images.html)); layers can pre-render static content ([layers](https://docs.flame-engine.org/latest/flame/rendering/layers.html)). Proposal:

1. Approve camera height, focal length, horizon, player-car screen footprint, virtual resolution, and palette before mass asset generation.
2. Each vehicle sheet uses one coherent design, fixed camera/light, transparent background, shared wheel-ground anchor, frame bounds, scale reference, and explicit metadata. Include rear flat/uphill/downhill, gentle/hard left/right, skid, damage, flip sequence, and recovery. Mirror only where asymmetry allows it.
3. Export scenery as modular foreground/midground/far silhouettes, vegetation, sign assemblies, buildings, lane markings, cone/barrier kits, bridge decks/supports, weather overlays, and ground textures. Assign biome/city/season tags and physical footprints.
4. Keep source artwork separate from runtime atlases. Record provenance, generation settings, licenses, palette, pivot, collision footprint, depth layer, and allowed scale range. Manually check edges, perspective, duplicated landmarks, and consistency before packing.
5. Build a contact-sheet review and a drive-through test scene before generating hundreds of assets. Generated concept art is not automatically a production sprite sheet; clean-up and frame alignment are budgeted work.
6. Separate artistic randomness from gameplay randomness so changing a cactus texture does not alter traffic or ranked outcomes.

Use a coherent graphic style with strong vehicle/road contrast. Offer a stable rendering mode that avoids heavy bloom, screen shake, and weather occlusion. Real-time full-screen shaders remain optional until profiling supports them; Flutter warns that saveLayer and excessive opacity can incur costly offscreen rendering ([Flutter performance guidance](https://docs.flutter.dev/perf/best-practices)).

## Validation plan before production art

Target 60 fps initially, with an adjustable render density/draw distance. Profile release/profile builds on representative older iPhone Safari, midrange Android Chrome, and desktop browsers; debug performance is not representative ([Flutter rendering performance](https://docs.flutter.dev/perf/rendering-performance)). Define the actual minimum supported devices with the user.

The first driving spike should demonstrate: a hill and curve; traffic overtaking; simultaneous steering/braking; a readable fork and closure; a bridge occlusion case; checkpoint extension; safe crash/reset; prefetch through a biome transition; music/radio ducking; sensor refusal fallback; portrait/background interruption. Collect frame-time percentiles, memory after repeated transitions, initial download size, input latency, sensor reliability, and audio continuity. Set measurable budgets after this baseline rather than promising throughput from desktop results.

## Design interview questions

- Pixel art, clean illustrated sprites, or painted retro realism? What reference images define acceptable detail and saturation?
- What decade/world is this: period 1980s, modern, or a playful mixture? Fictional car brands or recognizable models?
- Chase-camera height and car size? Visible interior/wheel with an external rear-view car intentionally stylized, or should the rim be understood purely as a control overlay?
- Should the touch rim rotate geometrically or behave as a horizontal drag control? Spring-to-center or persistent wheel angle? Which finger/region brakes?
- Stable horizon by default, optional small roll, or roll as the default? Which direction should it feel when turning left?
- Full-run duration and shortest session? Number/length of stages, time allowance, crash penalties, and whether retry preserves a seed?
- Should a route choice affect distance, traffic, weather, difficulty, discoveries, or all of these? Can every car reach every secret?
- Are cutscenes skippable; can they happen during racing? Are transitions always player-driven, or is short autodrive acceptable?
- Is the music an actual synthesizer requirement or is a MIDI-authored soundtrack with layered rendered stems acceptable? Voice identity, accent, languages, subtitles, and radio humor boundaries?
- Which devices/browsers must launch support, and is installation/native packaging planned alongside the website?
