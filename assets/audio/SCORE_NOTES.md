# Cannonball original soundtrack studies — 2026-10-25

These are original compositions authored for this project, not transcriptions,
remixes, sampled records or imitations of named performers. All instrumental
waveforms and percussion are synthesized by `tool/audio/compose.py`. Each piece
has 64 bars: introduction (8), verse (16), lift (8), chorus (16), breakdown (8),
final hook (8). Chord inversions, two-bar melodic question/answer, octave lifts,
syncopated bass, stereo arpeggios, drum fills, tempo delays and short reverb taps
replace the previous eight-note oscillator loop. This is a first listening draft,
not an assertion that production music has been approved.

- **Redline Sunrise**: 148 BPM, A-minor synthpop, detuned lead, seventh chords,
  octave bass, bright FM plucks and four-on-the-floor drums. City eligibility.
- **Orange Cone Cumbia**: 140 BPM, D-minor electronic cumbia study, syncopated bass,
  offbeat chord plucks, conga/cowbell patterns. Forest eligibility is a proof
  placeholder, not a claim that all forest regions share a musical culture.
- **Overpass Afterburn**: 156 BPM, E-minor arcade rock, synthesized power chords,
  eighth-note bass and an octave-up hook. Mountain eligibility.

MIDI files preserve bass, pad, lead, pluck, guitar and drums on separate tracks.
General MIDI programs approximate roles; a DAW's instruments will sound different
from these custom synthesized mixes. The score/render source is deterministic.
Mixes target -16 LUFS and -1.5 dBTP before MP3 encoding; inspect encoded peaks
before final mastering. MP3 is chosen for broad web decoding. One decoded score
and at most two reports are cached; original model weights are not shipped.

## Reproduce

Create a Python venv outside `/tmp` (the forge's `/tmp` is only 256 MB), install
`tool/audio/requirements.txt`, then run `python tool/audio/compose.py`.
`imageio-ffmpeg` supplies a local encoder binary. No remote build is involved.
The MIDI is editable independently of the renderer. Runtime currently selects
three composed station tracks; arbitrary live music generation and complete
regional genres remain future work.

## Prepared radio voice provenance

Original scripts are in `lib/platform/proof_radio.dart`. `tool/audio/voices.py`
renders them using stock Kokoro v1.0 synthetic voices `am_michael`, `af_heart`,
`am_fenrir`, at 1.06 speed, with restrained band limiting and loudness processing.
No individual has been voice-cloned for this project. These are draft presenters,
not verified New York, Nebraska or Colorado accents or final dramatic readings.
The browser's device speech remains a failure fallback.

Model: [hexgrad/Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M), Apache-2.0.
Runner: [kokoro-onnx](https://github.com/thewh1teagle/kokoro-onnx), MIT.
Download `kokoro-v1.0.onnx` and `voices-v1.0.bin` from the runner's official
`model-files-v1.1` release into `~/.cache/cannonball-audio/`, then run
`python tool/audio/voices.py` after composing. The runner's speed dtype mismatch
is adapted to the model's input metadata in the render script. No model weights
or inference engine are downloaded by the game. Review model card acknowledgments
and third-party licenses before a final distribution.

Technical references: [W3C AudioBufferSourceNode](https://webaudio.github.io/web-audio-api/#AudioBufferSourceNode)
for audio-clock buffered playback, and [Stanford sound synthesis notes](https://theory.stanford.edu/~blynn/sound/karplusstrong.html)
for physical-model alternatives considered. Current guitar uses additive decaying
harmonics and saturation, not a recorded guitar or a Karplus–Strong implementation.

Model download SHA256 values and rendered-file measurements are recorded in
`verification.json`. Rendered reports are selected by exact source script text;
unknown/new text falls back to device speech until its prepared pack is rebuilt.
