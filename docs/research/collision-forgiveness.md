# Proof collision forgiveness and soft construction props

## Observed cause, not a speculative physics-engine bug

The proof used the legacy traffic contact depths23/30 simulation units while
rendering those units at84 presentation units each (and now132 in the new camera
comparison). A car could therefore trigger a crash while its rear sprite remained
far ahead. Separately, the entire marked closed lane was treated as a solid
invisible obstacle between4300–4920, independently of visible cones. These are
concrete code mismatches; the observed "ghost car" reports do not establish an
engine collision bug or unseen NPC duplication.

The renderer and simulation now share the presentation scale. Proof traffic
contact half-depth is280/scale (car) or350/scale (truck), with lateral thresholds
.18/.22. Compared with the approximate combined sprite half-widths.266/.298,
this permits a small visual overlap before a hard impact. The geometry is an
arcade tuning choice, not a surveyed car footprint or a universally correct
pixel-to-metres relationship. Fixed-step snapshots are swept through forward and
lateral slabs jointly, so different-axis overlaps at different times cannot
produce a false collision.

A continuous overlap of up to50ms commits the crash. At high relative speed,
the window is capped by the time to traverse one contact half-depth: a full
same-lane rear impact must commit around body-center crossing rather than become
intangible or trigger a crash after separation. A shorter graze can be corrected and
is discarded when contact ends; it never triggers a delayed crash after escape.
Time actually inside the swept slab counts, rather than rounding partial contact
to a whole frame. Sustained rear impacts still crash. Recovery/protection clears
pending contacts and stale NPC identities are removed from the contact map.
Legacy full-run receipt physics keep their previous rules.

## What the research supports

[Maddy Thorson, Celeste & Forgiveness](https://www.mattmakesgames.com/articles/celeste_and_forgiveness/index.html)
is the original developer explanation of timing/position forgiveness, including
coyote time and corner correction. It supports deliberately favoring player
intent around boundaries. It does not prescribe racing collision shapes or50ms
car-contact grace. This proof transfers the design principle, not Celeste's jump
mechanic or timing constants.

[Erin Catto, Continuous Collision, GDC2013](https://box2d.org/files/ErinCatto_ContinuousCollision_GDC2013.pdf)
explains missed events between discrete snapshots, time-of-impact alternatives,
and how speculative contacts may cause apparent invisible collisions. Our proof
uses a simple exact linear swept-box interval because it has a small number of
road-aligned actors; it does not add speculative forces or claim to implement the
full Box2D solver. [Box2D's collision documentation](https://box2d.org/documentation/md_collision.html)
provides the primary shape-casting/time-of-impact context. No Box2D dependency was
added. The term "ghost collision" in that engine's chain-segment discussion is
not proof of the cause of our game's reported symptom.

## Cones and renderer contract

Construction cones have stable shared identities, course distances4120..<4920 at
9-unit spacing and a180-unit entry taper from the closed side's lateral1 to.44.
The renderer reads `controller.proofCones` and omits `isConeHit(id)`. A swept actual
cone contact creates one `ConeFlight`; it scrubs0.4mph and never starts a crash.
There is no solid lane-wide collider in proof construction areas. Road crews and
solid barriers can be authored as separate visible hard obstacles in a later pass.

`ConeFlight` exposes `cone`, `age`, `lateralVelocity` (road lateral units/second)
and `forwardVelocity` (simulation distance/second). The renderer converts
`cone.courseDistance + forwardVelocity*age` through its usual course projection,
adds lateral velocity, and may use an arc/spin. Flights expire at1.2s, at most24
are retained, and they never become additional colliders. Restart clears hit IDs
and flights. Joining-road decorative cones remain non-solid until their own
identities are brought into the shared prop model.

## Evidence and limits

`test/proof_contacts_test.dart` verifies swept timing, corrective grazes, no stale
hit after escape, actual sustained impact, no crash from a merely marked closed
lane, no broad distant NPC hit, one-shot cone flight and flight expiration.
Legacy/game/reactive-traffic suites also pass locally. Human moving review must
still tune collider overlap,50ms grace, cue clarity and clip/occlusion. This does
not add pixel-perfect collision against arbitrary trees, lamps or buildings.

## Hyperspeed follow-up

End-to-end tests run155mph against0/5/30mph NPCs at132presentation scale and
several initial distance/frame phases. The original fixed50ms window nearly
covered the entire53ms stopped-car contact interval; one phase produced a
late crash after the end-of-step snapshots had separated. The adaptive cap
reduces that maximum-closing case to about26ms. Sustained low-relative-speed
contacts retain50ms, corrective grazes still clear their pending timer, and
full fast rear overlaps crash while the end-of-step bodies still overlap.
The cap is another arcade hypothesis; no new claim of realistic collision
response or validated comfort follows from these automated tests.
