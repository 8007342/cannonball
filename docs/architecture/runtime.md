# Proposed runtime boundaries

Status: design proposal. Only the Flutter shell and empty Flame game exist.

```mermaid
flowchart LR
  Input[Tilt / touch / keyboard] --> Sim[Fixed-step race simulation]
  Route[Versioned route graph + seed] --> Stream[Chunk streamer]
  Stream --> Sim
  Director[Bounded pacing director] --> Stream
  Sim --> View[Road projection + sprite compositor]
  Sim --> Audio[Music + radio scheduler]
  Sim --> Replay[Run receipt + input replay]
  Replay --> API[Same-origin Worker]
  API --> Progress[Durable account progress]
  API --> Board[Canonical Hall of Fame]
```

The simulation owns road-relative position, velocity, car handling, collisions,
traffic intentions, gate state and elapsed time. The renderer projects those
facts; it must not determine collision outcomes from sprite overlap. Separate
random streams control mechanics and decoration. A versioned seed plus input
stream supports reproducing runs, but determinism must be tested across target
platforms before choosing replay verification as the ranking authority.

Chunks carry lane connectivity, curvature/elevation, biome sockets, warning
windows, hazards, exits, checkpoints, audio cues and unlock triggers. Validate
reachable paths and passable lanes before activation. Prefetch candidate branches
and their assets before a fork; hold enough prior content for safe recovery.

The director operates within authored difficulty envelopes. It schedules build-up,
peaks and recovery; it cannot bypass warning distances or create impossible
closures. The global board deliberately mixes actual outcomes under varied cars,
routes and conditions. Do not disable adaptation or equalize cars for competition.

Flutter owns menus and accessible overlays. The wheel rim belongs above the game
view; utility buttons must remain reachable above its gesture surface. Sensor,
pointer and keyboard adapters normalize to the same steering/braking intent.
Profile actions during a run require a deliberate pause policy.

Region transitions are streaming boundaries, not blocking loading screens.
Audio, TTS, identity and cloud requests may never stall the simulation. Browser
backgrounding, portrait rotation and explicit pause need clock/eligibility policy.

Next proof: one hill/curve, a single fork, a bridge occlusion, a lane closure,
a traffic merge, a timed gate and safe crash recovery. Only then fix asset budgets
and commission final production sprite sheets.

## Finish state and geography

Persist the actual ordered edge traversal plus partial final edge, real-route
meters, simulated road coordinates, time, car and completion state. Real-route
distance and compressed gameplay distance must be separate fields; how to display
and count them awaits the distance decision. Never infer distance from screen
pixels or the duration of the recap animation.

At run end, freeze the receipt. A qualifying finish enters three-letter initials
first, then the US-map recap; other runs go directly to recap. The map displays
the possible game-route network as context and fills the actual traversed edges
in order, stopping at the failure endpoint for incomplete runs. Do not interpret
"all possible roads" as every road in the US. Route-choice timing, selected edges
and closure state must come from that run, not regenerate randomly for the recap.
