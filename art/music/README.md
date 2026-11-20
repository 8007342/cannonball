# Cannonball radio programme

The in-car radio plays **wordless** (instrumental) original songs and joins them
with hard radio cuts:

```
song -> tuning buzz -> interjection -> tuning buzz -> another song
```

The interjection is a station ident or presenter banter, or — when the game has
something useful to say — a state-derived traffic/weather/closure report from
`lib/platform/proof_radio.dart`. There are no musical crossfades: the buzz masks
every cut, the way a real dial does.

| File | What it is |
| --- | --- |
| `radio-songs.json` | Song family spec: stations, every song's genre, tempo, key, mood, instrument tags, seed, duration, plus the shared `common_tags` (`instrumental, no vocals, no singing, wordless…`), `[instrumental]` lyrics and mastering targets. |
| `workflows/acestep15-radio-song.json` | Committed ACE-Step 1.5 text-to-music ComfyUI workflow (XL turbo DiT, Qwen 0.6B + 4B encoders, ACE 1.5 VAE; all Apache-2.0). Node 5 = prompt/bpm/key/duration, node 7 = latent seconds, nodes titled `$seed` take the seed. |
| `radio-interjections.json` | Original presenter lines per station (ident/banter) and network spots, with Kokoro voice and language; Spanish lines carry an English caption. |
| `radio-renders.json` | Render log: studio job, exact prompt, candidate seeds + FLAC sha256, metrics, the pick and why, and the shipped MP3's sha256/loudness. |

Tools live in `tool/audio/`: `radiokit/` (Go; candidate analysis, pick,
mastering, buzz synthesis, catalog, verification — shells out to ffmpeg) and
`interjections.py` (Python only because the Kokoro ONNX runner needs it).
Runtime: `web/radio_programme.js` (sequencer + player), wired in
`web/platform_bridge.js`. Generated audio lands in `assets/audio/music/`.

## Add a song in 3 steps

1. **Spec it.** Append an entry to `songs` in `radio-songs.json`: a new `id`,
   `title`, `genre`, an existing `station`, `bpm`, `key`, `mood`, instrument
   `tags` (genre traits only — never name an artist, band, song, game or
   composer), a fresh `seed` and a `duration` between 60 and 120 seconds.
2. **Render two candidates.** Print the request with
   `radiokit jobs | grep '"<id>"'` and pass its `workflow`, `count` (2) and
   `overrides` to the host tool `studio.run_workflow` (one job at a time; the
   GPU queue is shared). Then copy the outputs out of the ephemeral studio
   folder: `radiokit ingest <id> /work/tmp/imagegen/studio/<job>`.
3. **Pick, master, publish.** `radiokit analyse <id> && radiokit master <id>
   && radiokit catalog && radiokit verify`. Listen to both candidates; if the
   metric pick is wrong, add `"pick": <seed>` to the song entry and rerun
   `analyse`/`master`. Commit the spec, `radio-renders.json`, the MP3,
   `assets/audio/catalog.json` and `assets/audio/radio-verification.json`.

Build radiokit once: `cd tool/audio/radiokit && go build -o
~/.cache/tillandsias-project/bin/radiokit .` and run it from the repository
root (`go test ./...` covers its DSP and parsing).

## Interjections and buzz

- Lines: edit `radio-interjections.json`, then render raw speech with
  `python3 -I tool/audio/interjections.py` from a venv holding `kokoro-onnx
  0.4.7`, `numpy`, `soundfile` (model files `kokoro-v1.0.onnx`,
  `voices-v1.0.bin` from the kokoro-onnx `model-files-v1.1` release, kept in
  `~/.cache/tillandsias-project/cannonball-audio/models/`, never committed).
  `radiokit voices` applies the radio band (210 Hz–5.2 kHz, presence lift,
  5:1 compression, soft clip) and masters to -16 LUFS.
- Buzz: `radiokit buzz` synthesizes eight deterministic dial sweeps (resonant
  band sweeping through pink hiss, heterodyne whistles, static crackle and
  80–250 ms band-limited fragments of our own songs) and masters them to
  -18 LUFS. Edit `buzzBank` in `tool/audio/radiokit/buzz.go` to change them.

`radiokit all` reruns analyse → master → voices → buzz → catalog → verify.

## Mastering and verification targets

| Kind | Format | Loudness | Peak |
| --- | --- | --- | --- |
| Song | MP3 192 kbps CBR, 48 kHz stereo | -16 LUFS ±1 (two-pass loudnorm, linear) | ≤ -1.0 dBTP after encoding |
| Interjection | MP3 96 kbps, 48 kHz mono | -16 LUFS ±1.5 | ≤ -1.0 dBTP |
| Buzz | MP3 160 kbps, 48 kHz stereo | -18 LUFS ±3 | ≤ -1.0 dBTP |

MP3 is used because every target browser decodes and streams it through
`<audio>`, including Safari on iOS; Opus/WebM support in Safari depends on the
OS version, and the existing pipeline already ships MP3.
`radiokit verify` decodes every catalogued file, measures BS.1770 loudness and
4x-oversampled true peak with ffmpeg's `ebur128`, checks codec, rate,
channels, duration, bitrate, station coverage and the 120 MB audio budget, and
writes `assets/audio/radio-verification.json`.

## Provenance and licences

- Music: ACE-Step 1.5 (Comfy-Org/ACE-Step-1.5 repackage, Apache-2.0); exact
  model sha256 values are in the studio provenance sidecars and summarised in
  `radio-renders.json`. Prompts describe genre traits only.
- Voices: Kokoro v1.0 (hexgrad/Kokoro-82M, Apache-2.0) via kokoro-onnx (MIT);
  stock voices, no cloning.
- Picks are metric-based (clipping runs, lead silence, dropouts, quiet share,
  energy consistency, loudness range). **Listening review is still pending**:
  metrics cannot hear accidental vocalise, off-genre takes or weak endings.

## Runtime behaviour (web/radio_programme.js)

**One continuous programme for the whole demo.** The radio comes on with the
first gesture in the garage (taking the keys, any tap or key press; browsers
refuse audio before a gesture) and stays on air through the departure, all six
levels (automatic advance or Q–Y), chapter replays (1–8), Backspace restarts
and the completion / "drive it again" screen. Those paths never stop, restart
or re-roll the current song: the programme has its own audio bus and its own
hold, separate from the gameplay pause that silences the engine. Only the
listener's mute, station skip (**N** / radio button) and pause (**P**, hidden
tab) affect it, and pause resumes the same song at the same position.

- **Cadence — the one tunable:** `STATION_CADENCE` at the top of
  `web/radio_programme.js` (default **2**). Every song ends in a programme
  break, and each station visit plays 1..`STATION_CADENCE` songs (drawn at
  random when the dial lands) before the programme tunes to another eligible
  station, so it moves roughly every 1–2 songs. `1` changes station at every
  break. Avoiding a recent repeat still wins over the cadence. A catalog may
  override it with `rules.maxSongsPerStation`; the shipped catalog does not.
- Stations carry genres and regions; the region (`City`, `Forest`,
  `Mountain`) narrows the eligible stations at the next natural break only. The
  programme never replays one of the last `rules.recentSongs` songs while an
  alternative exists and announces every station change with that station's
  ident.
- Long songs: anything past `maxSongSeconds` (150 s) fades into the buzz at the
  last 8-bar phrase boundary, never under 60 s. The shipped songs (73–98 s)
  play in full.
- No gaps: two reused `<audio>` elements alternate (both unlocked in the first
  gesture). The next song starts buffering on the spare element during the
  current song's last `preloadSeconds` (20 s), so the break reuses that
  stream; all buzz clips are decoded when the radio first comes on and each
  break's presenter clip is precached during the song. A stream that is still
  not ready holds quiet looping static instead of silence; repeated failures
  fall back to the legacy prepared score / synthesized music.
- Reports: level-start reports (weather, traffic) are queued for the next
  natural break (latest wins, expire after 100 s). Urgent gameplay reports
  that appear mid-level (a closure or worksite) cut in: the song pauses in
  place, buzz → report → buzz, then the same song resumes at the same
  position.
- Debugging: `CannonballPlatform.audioSnapshot().programme` reports the
  state, current song id, `position`, `src`, the preloaded next song, the
  station run/cadence and a `log` of the last breaks, preloads, bulletins,
  pauses and resumes.
