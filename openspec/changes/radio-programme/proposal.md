# Proposal

## Why
The user asked for dynamic radio between races moments: several wordless,
upbeat songs per genre (pop, rock, metal, jazz, latin, folk and extras) joined
the way a real dial joins them — song, tuning buzz, an interjection, tuning
buzz, another song — instead of the three looping score studies. The sibling
demon_attack project showed that ACE-Step on the local studio produces such
assets quickly; this project does not need its musical transitions.

## What Changes
- Add a radio song family spec, a committed ACE-Step 1.5 text-to-music
  workflow, a render/pick log with provenance and a local Go tool (radiokit)
  for candidate analysis, mastering, buzz synthesis, catalog and verification.
- Add Kokoro-voiced station idents, banter and network spots per fictional
  station, processed to a radio band.
- Extend `assets/audio/catalog.json` with a backward-compatible `programme`
  block (stations, songs, buzz, interjections, rules).
- Add a streamed radio programme player/sequencer in the browser bridge:
  region/station-aware choice, no recent repeats, hard cuts masked by buzz,
  urgent state-derived reports cut in, others wait for the break, pause/mute,
  station skip, continuity across level changes, fallback to the old score.

## Capabilities
### Modified Capabilities
- `audio`: adds the radio programme requirements below.

## Impact
`art/music/`, `tool/audio/`, `assets/audio/` (≈60 MB of MP3 within the 120 MB
audio budget), `web/radio_programme.js`, `web/platform_bridge.js`,
`web/index.html`, `lib/platform/*`, `lib/ui/visual_proof.dart`. No remote
builds; models stay outside the repository. Listening and physical-device
(iOS Safari) review remain open.
