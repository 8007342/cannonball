# Cannonball design interview

Status: unanswered design questions, prepared from the initial brief and research. The user has already chosen Flutter, Flame, OpenSpec, Cloudflare Workers/Pages, the Cannonball name and cross-country arcade premise. Do not ask those again. Work through these in rounds; record answers and resulting spec decisions here. Recommended defaults are proposals, not consent.

## Round 1 — define the experience

1. Who is the primary player: casual mobile players, arcade racers, car enthusiasts, or a mix? What age range and content tone should shape the game?
2. How long should a successful NY-to-California run take in real play time: roughly 10–15, 20–30, 45–60 minutes, or another duration?
3. Is the setting specifically the 1980s, contemporary America with retro presentation, or an intentionally mixed era?
4. What is the dominant mood: sunny road-trip adventure, scrappy comic caper, tense endurance race, or another mix? Name two visual/audio references besides OutRun.
5. What motivates this driver to cross the country, and who owned the first shabby keychain? Is the player a named character, an anonymous driver, or choosing a character?
6. What should the first car feel like: underpowered lovable beater, heavy old sedan, nimble compact, or something else? Are all cars fictional designs?
7. Does a run fail immediately when the countdown expires? Should a casual continuation/checkpoint restart exist, and could it ever remain leaderboard-eligible?
8. Which milestone matters for the first playable slice: handling feel, one complete mini-run, garage story, or polished art? Proposed first slice: one car, one biome, traffic, gate and fork.

## Round 2 — confirm the steering wheel precisely

Current interpretation: the camera is behind the car. An enormous translucent steering wheel occupies the nearest overlay plane, larger than the screen. Its center is completely invisible; only cropped arcs of the rim are visible around the field of view. Dragging the rim steers the car; it is not a small dashboard wheel.

9. Is that interpretation correct? Should visible rim arcs be at the left/right edges only, around the bottom too, or all four edges?
10. Should touch steering use angular dragging around the implied wheel center, horizontal displacement, or relative dragging from anywhere? Does the wheel rotate under the finger?
11. When a finger is lifted, does steering spring to center, slowly return, or retain its angle?
12. Is holding any non-rim part of the screen the brake, or do you want a dedicated invisible/low-opacity brake zone? Can two thumbs steer and brake simultaneously?
13. Should the brake only reduce speed, or also help induce a controlled slide? Is there a minimum moving speed?
14. For tilt, should the player roll the device like a steering wheel, or tilt it left/right from a calibrated neutral posture? Is calibration automatic at run start, with a manual recalibrate action?
15. Should the default horizon remain flat, with optional subtle head lean, or should motion lean be on by default? How strong is the maximum acceptable lean? Proposed comfort setting: zero roll by default.
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

## Round 5 — timing and competition

40. Does “total time” mean real elapsed time from departure to destination, including crash animations and penalties? Proposed: yes; pause handling still needs agreement.
41. How should pause/backgrounding affect a ranked run: freeze, continue elapsed time, invalidate rank, or allow a limited pause budget?
42. Are gates fixed for a route, and is spare countdown carried across stages? How generous should the first few gates be?
43. Random closures/weather/adaptation affect finish times. Do you want a separate reproducible ranked ruleset, rotating daily seed, or one shared unpredictable arcade table? This is the largest unresolved fairness decision.
44. Are faster unlockable cars intended to dominate the same Top100, or should cars have comparable performance with different handling? Is a supplementary per-car view welcome?
45. Should the Top100 contain one best run per player or multiple runs by the same person? Is it permanent, seasonal, or both?
46. What breaks equal-time ties? Proposed deterministic order: elapsed milliseconds, then earliest verified finish.
47. Are initials A–Z only? Can players revise them later? Should we filter a small list of abusive combinations?
48. Is choosing initials done only after verification confirms Top100 entry? If another player pushes them out during entry, should their submitted name still be saved with their personal best?
49. Should the finish table show exactly initials, car and time, with rank numbering, or also route/season badges?
50. Should assisted runs, retries and offline runs qualify? How much server-side replay verification is worth the infrastructure cost?

## Round 6 — progression, sign-in and persistence

51. Can guests play immediately and later attach their unlocks to Google? Proposed: yes; signing in should not block the first race.
52. On a new device, which data must restore: cars, discovered paths, achievements, settings, personal bests, story progress, unfinished run?
53. If local and remote progress differ, should car discoveries merge? How should conflicting ongoing runs be handled?
54. Can cars unlock through secrets only, or also finishes, achievements and distance? How many launch cars and secret cars are envisioned?
55. Should the wooden box gradually fill with distinct keychains, and can touching a key preview the car before starting?
56. Is Google the sole sign-in method? Should account deletion be available in Profile? Three-letter public labels still leave private account/save data to manage.
57. Do you prefer reusing the existing Google Cloud project with a separate Cannonball OAuth client, or administratively separating the game? Deployment research will explain the technical options.
58. Should there be purchases/ads at all? None are assumed. This influences progression and art scope.

## Round 7 — art bible and asset pipeline

59. Choose the rendering language: crisp pixel sprites, painted retro illustration, clean low-resolution pre-rendered sprites, or another style. What reference resolution should guide the first comparison?
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
73. You requested loading screens and no gameplay interruptions. Is the intent to use radio/title/scenery transitions during driving, reserving actual loading screens for garage/start/end?
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

88. Which phones/browsers must work first? Are native Android/iOS builds in scope now or after web?
89. Is an installable offline-capable PWA wanted? Which functionality must survive losing connection mid-run?
90. What is the minimum acceptable frame rate and oldest device target? Proposed target: consistent 60 fps with a lower-detail fallback, to be validated.
91. Are you comfortable with anonymous gameplay metrics for tuning, or should early playtests use local recordings/manual observation only?
92. Who will be the first testers, and what would make you call the first slice successful?
93. Which decisions should you review personally before implementation: controls, route graph, storyboards, car designs, music examples, ranked rules?
94. What launch scope would you prefer to cut first if performance/art scope grows: cars, routes, weather variety, cutscenes or audio richness?

## Decision log

No answers have been recorded yet. For each round add: date, answers, accepted defaults, explicitly deferred questions, affected OpenSpec capabilities, and any prototype needed before deciding.
