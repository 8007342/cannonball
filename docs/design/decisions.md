# Design decision register

## Confirmed by the initial brief

- Cannonball; arcade speed; NY Red Ball Garage → Portofino in Redondo Beach.
- Flutter, Flame, OpenSpec; prepare Cloudflare Pages + Workers on cannonball.tlatoani.net.
- Landscape mobile, auto acceleration, hold-to-brake, optional tilt and an oversized
  translucent wheel-rim touch fallback; persistent small utility controls.
- Multiple stages, several timed gates, alternate roads, advance construction
  guidance, lane closures, traffic merges and secret-backroad car unlocks.
- Region-specific scenery, landmarks, weather, radio and synthesized musical themes.
- Google sign-in with durable unlocks; global Top100 by total completion time,
  three-wheel initials entry, car and time displayed.
- Garage wooden box with starter keys and a shabby keychain; car animation sheets;
  storyboards, story, hints and cutscenes; uninterrupted driving between stages.

## Proposed, awaiting design confirmation

- Projected road strips + billboard sprites with explicit elevation and occlusion.
- Stable horizon default with optional subtle cornering roll.
- Moving transition corridors rather than compulsory loading panels.
- Dedicated Cannonball Google web client, optionally in the same Cloud project.
- Same-origin API Worker + Pages; SQLite Durable Objects for authoritative records.
- Fixed-step seeded simulation and bounded director; ranking verification approach
  still needs a determinism and cost proof.

## Open

The interview is in interview.md. Highest-impact decisions: style/era and audience,
full-run duration, exact wheel gesture, camera, ranked fairness, car balance,
route compression, native launch scope, guest mode and story tone.
