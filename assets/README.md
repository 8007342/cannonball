# Asset production

Bulk assets wait for an approved camera/rendering proof and style guide.
Proposed packs: cars, road surfaces and lane markings, biome ground tiles,
vegetation, skyline layers, landmark props, cones and barriers, UI, story,
music stems/sound banks, radio voice and captions.

Every pack needs a versioned manifest: asset ID, region/state tags, dimensions,
pivot, scale, atlas coordinates, collision footprint (separate from visible
sprite), lighting/palette reference, source/license, generation prompt/reference
where applicable, and memory budget. Existing generated artwork is review
material, not approval for bulk production.

## Current original/provided assets

- Garage/key/car and racing visuals include original procedural Canvas
  compositions in lib/ui/painters.dart and lib/game/race_game.dart, plus generated
  proof art under proof/, proof-next/, milestone/ and roadside-pass/. These are
  illustrative review packs, not approved final raster sprite sheets or a
  geographically verified atlas. Prompts and manifests live beside each pack.
- WebAudio and Python note patterns/arrangements are original. The reproducible
  score renderer is tool/audio/compose.py; it emits MIDI, MP3 and catalog data.
  Prepared short presenter lines are rendered by tool/audio/voices.py using the
  stock Kokoro v1.0 model, then encoded and catalogued. The model files live
  outside the repo; see assets/audio/SCORE_NOTES.md for provenance and setup.
  These are listening drafts; production regional music and radio performances
  still need review. Browser speech remains a fallback.
- Noto Sans variable font: assets/fonts/NotoSans.ttf, from Fedora's
  google-noto-vf package (upstream Google Noto). SIL Open Font License retained
  in assets/fonts/OFL.txt. It is bundled so core UI does not need a font CDN.
- The user explicitly selected the white roof-off 2019 Stingray as the final
  car reference; its procedural representation is not a sourced GM photograph.
