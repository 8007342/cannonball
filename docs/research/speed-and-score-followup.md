# Speed and score follow-up — 2026-10-25

The user again reports insufficient apparent forward speed, despite smooth
animation, and vegetation crossing the joining road. The next comparison changes
rendered distance per simulated metre from20.4 to36 (1.765×); previous `motion=arcade`
remains available, along with `classic` and `cruise`. `turbo` is the new proof
setting. Physics, elapsed time and recorded distance are unchanged. This is an
explicit visual exaggeration, not a conversion from real mph to surveyed geometry.

The spatial sample count and resolution budget remain bounded; frame-delta driven
motion remains mandatory. OutRun is an aesthetic reference, not evidence that we
should make motion depend on machine speed. SEGA's [official OutRun page](https://archives.sega.jp/3d/outrun/index.shtml)
provides a first-party visual reference. No undocumented original engine rate is
claimed.

[Lidestam et al., Speed perception affected by field of view](https://www.diva-portal.org/smash/get/diva2%3A1369670/FULLTEXT01.pdf)
report simulator experiments involving wider peripheral views and rhythmic
markings. These support testing optical-flow coverage and references; they do not
validate any specific multipliers in our chase-camera game. [Investigating the
influence of visuospatial stimuli on driver's speed perception](https://pmc.ncbi.nlm.nih.gov/articles/PMC10499724/)
is a laboratory study, not a racing-game balance prescription. Vehicle avoidance
and comfortable viewing still need moving human review; greater apparent speed
can reduce readability and increase aliasing.

Joining-road clearance now tests full sprite footprints, including foliage width,
against pavement and the intervening gore. This prevents trunks outside the lane
from leaving crowns covering it. Trees on the opposite side remain eligible.
The existing joining lane is still an NPC-only visual module, not a playable route.

Hill height is increased from920 to2200 presentation units, with a .18 pitch bound.
This is another deliberate arcade exaggeration; it is not real freeway grade.
Hand proportion, coherent canopy supports, surface drag and breakable props remain
pending. Those should be reviewed independently from music approval.

Audio source details: [score provenance](../../assets/audio/SCORE_NOTES.md).
Encoded loudness, true peaks, hashes and model provenance are recorded in
assets/audio/verification.json. Local checks verify playback/lifecycle and absence
of clipped encoded peaks; they do not establish listener preference or regional
accent authenticity. Headless browser playback has no audible speakers.
