# Cannonball design research

Research date: 2026-10-25. The brief is authoritative; proposals below remain design decisions until answered in the interview. Source-derived observations and Cannonball proposals are separated. This is a foundation research pass, not a verified route atlas or a completed art bible.

## What “Valve Game Flow” means

There are two complementary references, with different authors and purposes:

- **GameFlow** is the 2005 model by Penelope Sweetser and Peta Wyeth, not Valve. Its eight evaluation dimensions are concentration, challenge, player skills, control, clear goals, feedback, immersion, and social interaction. Its initial evaluation used expert reviews of two real-time strategy games; it is a useful review lens, not a guarantee of enjoyment for a racing game. [Original paper](https://www.valuesatplay.org/wp-content/uploads/2007/09/sweetser.pdf), [DOI](https://doi.org/10.1145/1077246.1077253).
- **Valve's AI Director** is relevant to replayability and dramatic pacing. Michael Booth's 2009 presentation describes build-up, sustained peak, peak fade, and relaxation. Crucially, the published system changes threat frequency/pacing rather than difficulty amplitude. Cannonball must distinguish pacing adaptation from its separately requested difficulty progression. [Valve slides, particularly pp. 77–91](https://cdn.akamai.steamstatic.com/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf).
- Valve also published work on empirical playtesting and connecting art direction to gameplay. Those are separate references for the usability and visual review process; do not attribute every proposed menu rule to the Director. [Playtesting presentation](https://cdn.fastly.steamstatic.com/apps/valve/2009/GDC2009_ValvesApproachToPlaytesting.pdf), [art direction presentation](https://cdn.fastly.steamstatic.com/apps/valve/2008/GameFest08_ArtInSource.pdf), [publication catalog](https://www.valvesoftware.com/en/publications).

## Proposed application to Cannonball

These are design inferences and measurable project requirements, not quotations or claims that Valve prescribes a particular racing design.

| Area | Cannonball rule | Review evidence |
| --- | --- | --- |
| Concentration | Keep the road center clear; show one actionable radio/hint message at a time. | Players notice merges and hazards while reading; no missed turns caused by overlay. |
| Challenge and skills | Introduce a mechanic alone, rehearse it, then combine it with known mechanics. | Novices can explain why they crashed and improve on retry. |
| Control | Auto-accelerate; brake deliberately; calibrate tilt; preserve an immediate touch fallback. | Input latency, missed touch counts, steering error by device. |
| Goals and feedback | Show countdown, next gate, route commitment, added time, and crash penalty clearly. | Players distinguish remaining time from total elapsed leaderboard time. |
| Immersion | Regional scenery, radio, weather and music form one coherent stage identity. | Players recognize region changes without opening a map. |
| Social interaction | The initial social loop is the worldwide Hall of Fame; no multiplayer is assumed. | Players understand ranks and the role of cars, routes and luck. |
| Menus | Wooden key box is the garage/car selection metaphor; starting a run remains immediate. | First-session start time, discoverability of locked and unlocked keys. |
| Interactive elements | Steering rim, braking, pause and top toggles have distinct hit regions. | Two-thumb testing, edge gestures, and simultaneous steering/braking. |

Separate **speed sensation** from **hazard intensity**. A recovery interval can retain a high forward speed, brisk road markings, parallax, engine sound and sweeping turns, while reducing required lane changes and decision density. High traffic need not mean a slow jam: controlled relative speeds and visible escape gaps can preserve the weaving rhythm. Avoid long featureless recovery sections.

Proposed director inputs: recent collision severity, time-to-collision distribution, near misses, steering reversal rate, brake duration, visibility, current countdown pressure, and upcoming route decisions. Use a bounded state machine and cooldowns rather than unconstrained random spawning. Start with authored timing, then tune using playtests; do not assume one stress metric accurately measures emotion.

Complexity progression should be authored by stage: gentle curves → traffic overtakes → merges → hills → lane closures → forks → combined hazards/weather. The pacing director schedules optional encounters within the approved stage envelope. It must not alter physics, grant invisible time, or suddenly close the player's chosen route. Difficulty changes should be communicated through the radio before they matter.

## Randomness and the Hall of Fame — resolved direction

User decision, 2026-10-25: unequal runs are the intended arcade experience. Record whichever route, car, traffic and random conditions the player receives. Better unlocked cars should improve future attempts; routes deliberately differ in distance and complexity. The earlier proposal for an equalized ranked mode is withdrawn. Keep one global Top100 ordered by actual elapsed time. No common seed, car parity, route normalization or separate competition mode is required.

Record a run's ruleset version, content version, seed, car, route edge sequence, gate sequence, elapsed time, penalties, completion status and verification result. Use a monotonic simulation clock; countdown extensions must never subtract elapsed time. Consider one best result per account, deterministic tie order, and whether a new three-letter entry replaces that user's old entry. Three-letter labels are display names, not globally unique identities.

Server acceptance must validate completion and plausible timing; a browser-supplied score alone cannot create a trustworthy worldwide record. Replay validation and the exact backend design belong in the implementation proposal. Offline play may unlock locally but cannot automatically qualify an unverifiable run for ranked placement.

## Routes and regional identity

The endpoint hotel's own history identifies the Red Ball Garage in Manhattan and the former Portofino Inn in Redondo Beach as the endpoints. This supports the premise; it does not establish one mandatory route. [Hotel history](https://www.hotelportofino.com/cannonball-run/).

Use a compressed directed route graph, not a claim to simulate every real mile. Nodes are cities, stage boundaries and decision points; edges are road corridors with direction, biome, elevation profile, gate budget, traffic profile, scenic beats, supported weather and closure alternatives. Every edge must lead to the finish or visibly rejoin another route. Local NPC-only exits must be distinguished from playable forks.

Candidate corridors for map design, **not yet a verified connected turn-by-turn route**:

| Corridor | Design purpose | Verification still needed |
| --- | --- | --- |
| Manhattan → NJ/PA → I-80 corridor | Garage departure, dense eastern city/wooded-road contrast | Actual departure roads, river crossing, signed westbound connections. |
| I-80 across Midwest → Iowa/Nebraska | Urban bypasses, prairie, farm traffic and big sky | Chosen cities, specific interchange and landmark sightlines. |
| Western Nebraska → I-76 → Denver → I-70 mountain corridor | Matches requested Nebraska-to-Colorado transition | Exact junction sequence, passes, tunnel/grade representation. |
| I-70 west through Utah → I-15 → Southern California | Canyon/desert progression and destination approach | Corridor continuity, selected junctions and final Redondo roads. |
| Central/southern alternative via I-70 / I-44 / I-40 corridors | Materially different route/weather strategy | All connectors, approved stage count, scenic detours and merge points. |

Use the [FHWA route log and finder](https://www.fhwa.dot.gov/planning/national_highway_system/interstate_highway_system/routefinder/) for route/state/city coverage. Detailed production verification should use official state maps, not guessed exit numbers. Nebraska provides [maps and travel resources](https://dot.nebraska.gov/travel/); Colorado's [OTIS](https://dtdapps.codot.gov/otis) provides highway attributes, GIS data and road imagery. CDOT identifies the [I-70 mountain corridor](https://www.codot.gov/travel/i70mountain) as a setting requiring attention to changing conditions. Dynamic fictional race conditions should not masquerade as live road advice.

Use the [EPA ecoregion maps and descriptions](https://www.epa.gov/eco-research/ecoregions-north-america) to establish biome boundaries rather than switching scenery at every state line. Each chosen corridor needs a location sheet: road geometry, elevation, season, vegetation, built forms, reference provenance, readable landmarks and reviewed local jokes.

Example ecology checks: [Mojave National Preserve](https://www.nps.gov/moja/learn/nature/plants.htm) describes creosote, yuccas, Joshua trees and changes with elevation; avoid distributing iconic cacti indiscriminately. [Tallgrass Prairie National Preserve](https://www.nps.gov/tapr/learn/nature/plants-at-the-preserve.htm) is a useful prairie reference, but is not evidence that every Nebraska roadside is tallgrass prairie. Check the actual selected subregion before asset placement. Regional knowledge must constrain procedural asset weights.

## Closures, merges and traffic grammar

FHWA describes advance warning, transition/taper, activity/buffer and termination areas in temporary traffic control. That real-world sequence makes a useful visual grammar for cones and blocked lanes. [FHWA incident guidance](https://ops.fhwa.dot.gov/publications/fhwahop08057/50.htm). Adapt spacing to game speed and reaction time; real-world engineering distances are not automatically appropriate for compressed arcade roads.

Proposed invariants:

- Announce closures before the last safe decision point using visual signs/cones plus optional radio; never depend on hearing.
- Commit branch availability before the player reaches its warning horizon. No closure changes after commitment.
- Ensure a reachable legal lane or diversion through every generated situation, including overlapping NPC maneuvers.
- Traffic follows bounded cruising speeds, signals lane changes, checks gaps, and merges through authored connectors. Never teleport into the immediate driving corridor.
- Use separated road geometry, chevrons or barriers for NPC exits; playable secret paths need a consistent discoverable clue even if they lack highway signs.
- Grade-separated interchanges require explicit height/occlusion representation; a convincing flyover is more demanding than drawing a flat fork.
- A disabled shoulder truck has an advance warning beat and a guaranteed avoidance window. Crashes reset to a safe reachable track position, not inside traffic, cones or a gate.

## Narrative, sound and asset dependencies

The requested opening is a wooden garage box with only one old key set and a cheap keychain. The world is now confirmed as present-day; the keys’ owner, meaning, starting car and tone remain unanswered. A proposed storyboard sequence is: box/keys → take key → reveal starter car → garage departure → first gate → first route choice → first regional radio handoff → finish reveal → possible Top100 initials → return to box with new key. These are candidate beats, not approved scenes.

During a run, a stage boundary should be a streamed transition: audio/radio, a brief readable title, scenery blend and advance route advice while driving continues. A loading screen that stops the car conflicts with “never interrupt gameplay”; ask whether actual loading screens belong only before/after runs. Preload the next possible branches before the decision; reserve a graceful fallback corridor if data is late.

Radio cues should be selected from actual upcoming run events: region welcome, traffic warning, closure, weather forecast, route choice, gate urgency and recovery. Use concise event templates with lead times and expiration, captions and a priority queue. Example requested contrast: a cheerful Nebraska welcome followed later by a Colorado snow warning. Treat this as authored weather, not an assertion of current conditions. Dynamic music should share a tempo/key transition plan; speech ducks music and never overlaps another actionable announcement.

Before generating a large asset set, approve one engine-compatible style sheet and one test car. Define reference resolution, pixel density, perspective, horizon, palette, light direction, shadow plane, collision silhouette, sprite anchor and atlas padding. Car reference matrix: rear flat/uphill/downhill; gentle/hard left/right turns; left/right slide; crash impact, flip sequence and recovery. Do not mirror asymmetric markings blindly. Define visible-wheel animation, brake lights and effects separately from body sprites. Environment kits need road-edge seams, distance LODs, skyline layers and tile/composite attachment rules.

## Proposed research-driven review gates

1. Greybox one hill, curve, traffic overtake, closure and two-branch junction on target mobile browsers.
2. Confirm rim-wheel control through a diagram and simultaneous brake test before finalizing its art.
3. Approve a starter-car/road/biome sample at gameplay scale before batch asset generation.
4. Observe novices without coaching; measure first-run comprehension, crash causes, route-sign recognition and motion comfort.
5. Test whether a recovery interval still feels fast; tune hazard frequency independently of vehicle speed.
6. Preserve the intentional unequal-run policy while resolving timing, persistence and duplicate-safe result recording.
7. Verify chosen roads, ecology and landmarks per region before finalizing the route atlas.

## Present-day data and 10–15 minute compression — confirmed follow-up

The world now uses present-day geography, not period-1980s roads. As checked on
2026-10-25, the FHWA route log explicitly describes Interstate status as of January
2025. CDOT OTIS announces an October 2026 update with roadway/traffic data for
calendar 2025. "Current" must therefore mean the latest reviewed source snapshot,
with its data year recorded; it must not imply that every exit is verified today.
Use state DOT maps/road inventories and official landmark pages for production
corridors, recording retrieval date, dataset year, license and connector checks.
The route candidates above remain research candidates, not a completed road atlas.

Compress uneventful distance while retaining actual connectivity, junction order,
city order, recognizable approach silhouettes and selected landmarks. Each edge
needs source geometry, real-world distance, simplified display geometry, simulated
driving length, stage budget, lane/connectivity metadata and placement references.
A route's real miles must not be mistaken for the distance the car literally
travels at its displayed speed over 10–15 minutes. Distance presentation is an
open question; do not silently choose an odometer model.

The post-run map contains the game's possible route network, highlights the
actual edge sequence and fills progress along it. Repeated/partial edges must
follow the recorded traversal; a failed run stops at the actual reached point.
Top100 qualification sends the player to initials first, then this recap. Store
time, distance and car with the result. Whether the table also displays distance
is separate from the requirement to save it.
