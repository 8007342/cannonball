# Tasks

## 1. Assets
- [x] 1.1 Song family spec, ACE-Step workflow, two candidates per song
- [x] 1.2 Metric pick with logged reasons and provenance (sha256, seed, prompt)
- [x] 1.3 Kokoro station idents/banter with radio-band processing
- [x] 1.4 Deterministic tuning-buzz synthesis
- [x] 1.5 Mastering and decoded verification within the audio budget
- [ ] 1.6 Listening pass (stray vocals, endings, genre fit); pin picks

## 2. Runtime
- [x] 2.1 Sequencer: stations, regions, recent-repeat avoidance, idents
- [x] 2.2 Streamed playback with buzz-masked hard cuts and static hold
- [x] 2.3 Urgent reports cut in; others queue and expire
- [x] 2.4 Pause/mute/hidden, station skip, level-change continuity
- [ ] 2.5 Physical-device validation (iOS Safari, Android Chrome)
- [x] 2.6 One continuous programme: garage gesture to completion; level
      advance/select, chapter replay, restart and replay never cut the song;
      own audio bus and listener hold; pause resumes in place
- [x] 2.7 Cadence constant (station change every 1–2 songs), phrase-boundary
      trim for long songs, next-song preload on a spare element in the last
      20 s, static cover for slow loads
- [x] 2.8 Urgent mid-level bulletins return to the same song position;
      level-start reports queue for the next break
- [ ] 2.9 Listening pass of the continuous programme on a physical device
