## ADDED Requirements

### Requirement: Radio programme of wordless songs
The soundtrack SHALL be a radio programme of original, instrumental (wordless)
upbeat songs of 60 to 120 seconds grouped into fictional stations by genre,
with at least three songs each for pop, rock, metal, jazz, latin and folk.
Prompts SHALL describe genre traits only and SHALL NOT name artists or songs.

#### Scenario: choosing a station
- **WHEN** the listener tunes through the stations
- **THEN** each station plays its own genres and no song has lyrics

### Requirement: Traceable mastered songs
Each shipped song SHALL trace to its workflow, models, prompt, seed and output
hashes, and SHALL be normalised to -16 LUFS integrated with a true peak at or
below -1 dBTP measured on the encoded file.

#### Scenario: adding a song
- **WHEN** a builder adds a song entry and renders its candidates
- **THEN** the pick, its reason and the encoded file's measurements are
  recorded and the catalog includes the song without hand editing

### Requirement: Radio transitions
Songs SHALL change through a hard radio cut: tuning buzz, an interjection
(station ident, presenter line or state-derived report), tuning buzz, then a
different song. The programme SHALL avoid recently played songs and lines,
prefer stations eligible for the current region, announce a station change
with that station's ident, and never leave silence while the next song
buffers.

#### Scenario: song ends
- **WHEN** a song finishes during a run
- **THEN** buzz, an interjection and buzz play and a song that was not among
  the recent ones starts

#### Scenario: urgent report
- **WHEN** a closure, worksite, snow or rain report is issued mid-song
- **THEN** the song pauses in place for buzz, the captioned report and buzz,
  then the same song resumes at the same position; non-urgent reports wait
  for the next break and expire if it is far away

### Requirement: Station cadence
Every song SHALL end in a programme break, and the programme SHALL change
station roughly every one to two songs: a station visit plays between one and
a single tunable maximum (default two) songs before an eligible different
station is chosen, unless that would replay a recent song. Songs longer than
the configured maximum SHALL fade into the break at a phrase boundary and SHALL
play for at least 60 seconds.

#### Scenario: station visit ends
- **WHEN** a station has played its drawn number of songs (at most the cadence)
- **THEN** the next break tunes to a different eligible station with its ident

#### Scenario: gapless break
- **WHEN** the current song enters its last 20 seconds
- **THEN** the next song buffers on a second media element and the break's
  clips are already decoded, and a stream that is still not ready is covered
  by static rather than silence

### Requirement: Radio playback lifecycle
Songs SHALL stream rather than be fully decoded, and only the next song SHALL
be loaded ahead. Only listener mute, station skip, pause and hidden tabs
SHALL affect playback, and resuming SHALL continue the same song at the same
position. The programme SHALL fall back to the prepared score when it cannot
load.

#### Scenario: listener pause
- **WHEN** the listener pauses and later resumes
- **THEN** the same song continues from where it was paused

### Requirement: Continuous demo soundtrack
The programme SHALL be one continuous soundtrack from the first garage gesture
to the end of the demo. The departure, level advances, manual level selection,
chapter replays, restarts and the completion screen SHALL NOT stop, restart or
re-select the current song; they MAY only queue a report for the next break.

#### Scenario: level change
- **WHEN** the sequence advances, or the listener selects a level, replays a
  chapter or restarts
- **THEN** the current song continues without a gap from the same position

#### Scenario: garage to road
- **WHEN** the listener takes the keys in the garage
- **THEN** the radio comes on and plays unbroken through the departure into
  the first level

