# Cannonball design interview

Status: partially answered; confirmed answers below supersede the initial question wording. The user has already chosen Flutter, Flame, OpenSpec, Cloudflare Workers/Pages, the Cannonball name and cross-country arcade premise. Do not ask those again. Work through these in rounds; record answers and resulting spec decisions here. Recommended defaults are proposals, not consent.

## Confirmed answers — 2026-10-25

- Successful coast-to-coast run: **10–15 minutes**.
- World: **present-day real roads, intersections, cities and landmarks**, with research provenance and compression to playable scale.
- Art: **mixed pixelated styling with diffused edges**; research motion stability and speed before finalizing sheets. Desktop gets higher-resolution variants; mobile gets appropriate packs.
- Wheel: oversized transparent center and translucent cropped rim confirmed; angular dragging. Right-edge up / left-edge down steers left. Right-edge down / left-edge up steers right. Tapping outside the wheel brakes; holding sustains it. Auto acceleration is continuous otherwise.
- Horizon: mostly flat with subtle lean, somewhat stronger with motion controls; tune natural response for both input modes.
- Hall of Fame: **one luck-driven Top100**; car advantages and differences in distance, traffic, complexity and randomness are deliberate. No equalized competition mode.
- Finish: qualifying Top100 runs enter initials first and save **time, distance and car**, then a US route-map recap fills progress along the route traveled. Other runs go directly to recap.
- Flow: minimal loading, continuous driving until the run ends.
- Delivery: **web only**, mobile first, desktop supported; URL access sufficient, PWA installation optional. No native Android/iOS plan.
- Identity: reuse Arabiya’s public client ID with an exact authorized Cannonball origin; live registration pending confirmation.

## Next focused decisions

1. Wheel directions are resolved as clockwise/right and counterclockwise/left. Return-to-center tuning is still open.
2. Distance: show real-world route miles while compressing driving to 10–15 minutes, or count game-world distance? Proposed: real-route miles, clearly presented as arcade compression.
3. Starter car and keys: what sort of beater, who owned it, and what drives the trip?
4. Failed run: show reached position on the same recap map, then offer immediate retry?
5. Current geography is confirmed; do traffic/weather remain game-generated rather than fetching live conditions?

## Original interview reference

Answered items below are retained for traceability and marked resolved. Work only
through unanswered items; do not re-ask the same design choices.

## Round 1 — define the experience

1. Who is the primary player: casual mobile players, arcade racers, car enthusiasts, or a mix? What age range and content tone should shape the game?
2. **Resolved:** successful runs target 10–15 minutes.
3. **Resolved:** present-day world data and real geography; retro pixel styling.
4. What is the dominant mood: sunny road-trip adventure, scrappy comic caper, tense endurance race, or another mix? Name two visual/audio references besides OutRun.
5. What motivates this driver to cross the country, and who owned the first shabby keychain? Is the player a named character, an anonymous driver, or choosing a character?
6. What should the first car feel like: underpowered lovable beater, heavy old sedan, nimble compact, or something else? Are all cars fictional designs?
7. Does a run fail immediately when the countdown expires? Should a casual continuation/checkpoint restart exist, and could it ever remain leaderboard-eligible?
8. Which milestone matters for the first playable slice: handling feel, one complete mini-run, garage story, or polished art? Proposed first slice: one car, one biome, traffic, gate and fork.

## Round 2 — confirm the steering wheel precisely

Current interpretation: the camera is behind the car. An enormous translucent steering wheel occupies the nearest overlay plane, larger than the screen. Its center is completely invisible; only cropped arcs of the rim are visible around the field of view. Dragging the rim steers the car; it is not a small dashboard wheel.

9. **Resolved:** oversized transparent-center rim overlay confirmed. Exact cropping can be tested visually.
10. **Resolved:** angular wheel-like dragging; clockwise steers right and counterclockwise steers left. Outside taps/holds brake.
11. When a finger is lifted, does steering spring to center, slowly return, or retain its angle?
12. **Resolved:** touching outside the wheel brakes. Verify simultaneous input and utility-button exclusions.
13. Should the brake only reduce speed, or also help induce a controlled slide? Is there a minimum moving speed?
14. For tilt, should the player roll the device like a steering wheel, or tilt it left/right from a calibrated neutral posture? Is calibration automatic at run start, with a manual recalibrate action?
15. **Resolved direction:** mostly flat with subtle lean, somewhat stronger under motion controls. Strength/damping need a prototype; retain comfort settings.
16. Should arrow keys steer smoothly like a held wheel? Is gamepad support wanted at launch?
17. Top controls requested: tilt toggle, mute, profile and pause. Should tapping any of these pause the run? Does opening profile during a run always pause it?
18. Is a portrait “rotate your phone” gate acceptable where a browser cannot force landscape? What should happen if orientation changes mid-run?

## Round 3 — pacing, challenge and crashes

19. What makes driving satisfying: threading tight gaps, drifting curves, choosing routes, memorizing roads, or reacting to changing conditions? Rank the top three.
20. What does “always fast” mean after braking or crashing: brief slowdowns with strong recovery, or a near-constant apparent speed even when mechanics penalize time?
21. How punishing is contact: scrape slows you, rear-end crash, spin, flip, or escalating by impact speed/angle?
22. How long can a flip and reset take? Can the player steer during recovery? Should the clock keep running throughout?
23. May the pacing director reduce hazard density after repeated mistakes, while preserving speed? Should changes be visible as radio information?
24. Does stage difficulty increase every run, with distance, with unlocked cars, or with demonstrated skill? Which changes must never happen invisibly?
25. Are weather effects primarily visual, or do rain/snow change grip, braking and visibility? Should night/fog be included at launch?
26. How much warning should hazards give: forgiving readable arcade windows or demanding expert reactions? Are there accessibility assists?
27. Are there police/rival racers, or only civilian traffic and environmental hazards? They are not assumed from the Cannonball premise.
28. Do near misses, drifts or clean gates earn time, score, unlock progress, or purely audiovisual celebration?

## Round 4 — country, route graph and secrets

29. Which cities and landmarks are essential? Which states/regions can be compressed or omitted?
30. Is Nebraska → Colorado mandatory on every run, or one branch among several?
31. Do you prefer a small authored route graph with variable encounters, or many procedural roads constrained by researched regional kits?
32. How many meaningful route choices should a full run contain? Should paths rejoin after each stage or remain separate for several stages?
33. At a fork, should signs describe destination, traffic, weather, difficulty and/or estimated distance? How much information should remain uncertain?
34. Can a route be fully closed before the run, or can closures change while approaching if sufficiently warned? Proposed rule: freeze it before its first warning.
35. Should secret backroads require deliberate off-ramp discovery, an obvious physical gap, a rumor/radio clue, or repeated exploration? How obscure is fair?
36. Must secret routes still be plausible drivable roads? Can they trade finish time for a permanent car unlock?
37. Are lane closures and breakdowns gentle variation or major set pieces? Any requested freeway interchanges or bypasses?
38. How literal should landmarks be: roadside silhouettes, compressed recognizable views, or detours that drive past them? Do you have local puns we should include or avoid?
39. Should road conditions be entirely fictional/seeded, or is any real weather/traffic integration desired? Recommended first version: authored conditions.

## Round 5 — timing and arcade records

40. Does “total time” mean real elapsed time from departure to destination, including crash animations and penalties? Proposed: yes; pause handling still needs agreement.
41. How should pause/backgrounding affect a run submitted to the Hall of Fame: freeze, continue elapsed time, invalidate rank, or allow a limited pause budget?
42. Are gates fixed for a route, and is spare countdown carried across stages? How generous should the first few gates be?
43. **Resolved:** shared unpredictable arcade table. Actual run conditions count; no equalized mode.
44. **Resolved:** better unlocked cars enable better runs in the same Top100; car parity is not required.
45. Should the Top100 contain one best run per player or multiple runs by the same person? Is it permanent, seasonal, or both?
46. What breaks equal-time ties? Proposed deterministic order: elapsed milliseconds, then earliest verified finish.
47. Are initials A–Z only? Can players revise them later? Should we filter a small list of abusive combinations?
48. Is choosing initials done only after verification confirms Top100 entry? If another player pushes them out during entry, should their submitted name still be saved with their personal best?
49. **Partly resolved:** save initials, car, time and distance. Initials first for Top100, then US-map progress recap; whether distance is visible on the table remains open.
50. Should assisted runs, retries and offline runs qualify? How much server-side replay verification is worth the infrastructure cost?

## Round 6 — progression, sign-in and persistence

51. Can guests play immediately and later attach their unlocks to Google? Proposed: yes; signing in should not block the first race.
52. On a new device, which data must restore: cars, discovered paths, achievements, settings, personal bests, story progress, unfinished run?
53. If local and remote progress differ, should car discoveries merge? How should conflicting ongoing runs be handled?
54. Can cars unlock through secrets only, or also finishes, achievements and distance? How many launch cars and secret cars are envisioned?
55. Should the wooden box gradually fill with distinct keychains, and can touching a key preview the car before starting?
56. Is Google the sole sign-in method? Should account deletion be available in Profile? Three-letter public labels still leave private account/save data to manage.
57. **Resolved follow-up:** reuse Arabiya’s public client ID with exact Cannonball origin registration.
58. Should there be purchases/ads at all? None are assumed. This influences progression and art scope.

## Round 7 — art bible and asset pipeline

59. **Resolved direction:** mixed pixelated art with diffused edges. Reference resolution, palette and exact softness need motion comparisons.
60. Should colors feel sun-bleached 1980s, saturated arcade neon, filmic natural, or region-dependent? Are there must-have colors or visual motifs?
61. How large is the player car on screen, and how far above/behind it is the chase camera? Should it bob with hills and speed?
62. Should cars visibly show body roll, suspension, damage, brake lights, smoke and tire marks? Which can be procedural effects rather than sprite variants?
63. Car sprite matrix requested: rear flat/uphill, gentle/hard turns, slides and crash/flip. Do you also want downhill views and different weather/night lighting?
64. Are cars inspired by recognizable real models, or fully fictional? Any particular body types, eras, silhouettes or colors?
65. What belongs in the first region kit: skyline, garage street, roadside buildings, vegetation, signs and traffic? Which landmark should be the style proof?
66. Should generated art be visibly handmade/stylized or aim for strict sprite consistency? Who approves the single sample sheet before mass generation?
67. How much visual randomness is acceptable in towns versus authored landmark compositions? Are repeated roadside patterns undesirable or part of the arcade look?
68. Should weather palette swaps and day/night be composited dynamically or require authored asset variants?
69. Are we creating original logos/brands for gas stations, trucks, radio and roadside jokes?

## Round 8 — storyboards and uninterrupted transitions

70. What happens when the first key is selected: hand reaches into box, key sound and fade, instant car reveal, or a brief animated scene?
71. Is there dialogue or a companion? Is the driver ever visible? What is the narrative goal beyond the finish time?
72. Do cutscenes occur only before/after runs, or can short in-engine events play while the player retains control?
73. **Resolved:** minimal loading and continuous driving until the run ends. Use moving transitions for radio, hints and scenery.
74. What should happen if the next region cannot load in time: keep driving a seamless transition corridor, pause with a message, or another approach?
75. How should hints appear: roadside signs, radio speech with captions, subtle HUD text, a garage journal, or a mix?
76. Are hints contextual to recent mistakes, randomized from a regional pool, or scheduled tutorials? Can experienced players reduce them?
77. What should a finish feel like: big arcade celebration, quiet ocean arrival, story payoff, or all three in sequence?
78. What should a failed run show, and how quickly should it allow retry with the same car/route seed?

## Round 9 — soundtrack, radio and speech

79. Describe the musical identity: synthwave, jazz fusion, chiptune, regional styles, or combinations. Which instruments are essential?
80. Does “MIDI synthesizer” mean real-time generated note patterns, authored MIDI tracks with dynamic layering, or reactive arrangements of composed motifs?
81. Should regional songs preserve one tempo for transitions, or change tempo at planned handoffs? Can intensity add/remove layers independently of the city theme?
82. Is the radio host comic, reassuring, deadpan, urgent, or a small cast? Preferred accent/languages and examples of personality?
83. Is consistent voice quality more important than unlimited text? We can compare pre-rendered TTS clips, device voices and a hybrid after the browser audio prototype.
84. Must all actionable radio information have captions/icons? Proposed: yes. Can ambient banter be muted separately from traffic advice and music?
85. How frequent should radio announcements be, and how much silence is desirable? Can the host repeat a missed warning?
86. Should forecast advice always be accurate, occasionally playful but truthful, or deliberately unreliable? Proposed: actionable advice is reliable.
87. Do you want user-selectable stations, or one adaptive station that changes identity across the country?

## Round 10 — delivery and playtesting

88. **Resolved scope:** web only, mobile first and desktop supported. Which minimum phones/browser versions should define performance checks?
89. **Resolved installation:** URL access is sufficient; PWA installation optional. Offline behavior remains open.
90. What is the minimum acceptable frame rate and oldest device target? Proposed target: consistent 60 fps with a lower-detail fallback, to be validated.
91. Are you comfortable with anonymous gameplay metrics for tuning, or should early playtests use local recordings/manual observation only?
92. Who will be the first testers, and what would make you call the first slice successful?
93. Which decisions should you review personally before implementation: controls, route graph, storyboards, car designs, music examples, Hall of Fame recording rules?
94. What launch scope would you prefer to cut first if performance/art scope grows: cars, routes, weather variety, cutscenes or audio richness?

## Decision log

2026-10-25: captured the confirmed answers above in specs for racing, controls, world, art and progress; corrected browser-only scope and the unequal-run Top100 policy throughout project docs. Pixel-art motion and camera lean research requested. Right-steer mapping was subsequently confirmed; implementation now proceeds under playable-road-trip.

## Next slice after the smooth cartoon proof

Confirmed feedback: technology provisionally accepted; forward movement feels too
slow; high-speed turn pose is wrong; palette-varied traffic, local radio accents
and cute incidental details are desired.

Focused next choices (recommendations, not decisions):
- Begin the authored vertical slice at Red Ball Garage, with a brief NYC escape
  into open road, or tune on an open-highway test corridor first? Recommend the
  highway handling test before adding dense city departure geometry.
- What is the starter car: battered compact, old station wagon, or something
  specific? Final Corvette remains unchanged.
- Radio tone: affectionate local humor, straight traffic reporting with occasional
  jokes, or heightened arcade comedy? Recommend warm local humor with clear advice.
