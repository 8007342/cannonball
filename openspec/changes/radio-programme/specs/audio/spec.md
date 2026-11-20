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
- **THEN** the song is cut at once for buzz, the captioned report and buzz;
  non-urgent reports wait for the next break and expire if it is far away

### Requirement: Radio playback lifecycle
Songs SHALL stream rather than be fully decoded, and only the next song SHALL
be loaded ahead. The programme SHALL respect pause, mute and hidden tabs,
offer a listener station skip, keep playing across level changes, and fall
back to the prepared score when the programme cannot load.

#### Scenario: level change
- **WHEN** the sequence advances to the next level
- **THEN** the current song continues without a gap
