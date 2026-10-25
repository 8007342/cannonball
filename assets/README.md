# Asset production

Bulk assets wait for an approved camera/rendering proof and style guide.
Proposed packs: cars, road surfaces and lane markings, biome ground tiles,
vegetation, skyline layers, landmark props, cones and barriers, UI, story,
music stems/sound banks, radio voice and captions.

Every pack needs a versioned manifest: asset ID, region/state tags, dimensions,
pivot, scale, atlas coordinates, collision footprint (separate from visible
sprite), lighting/palette reference, source/license, generation prompt/reference
where applicable, and memory budget. No generated imagery is commissioned yet.

## Current original/provided assets

- Garage/key/car and racing visuals are original procedural Canvas compositions
  in lib/ui/painters.dart and lib/game/race_game.dart. They are a first playable
  visual pass, not approved final raster sprite sheets.
- WebAudio note patterns/arrangements are original in web/platform_bridge.js.
  There is no external sound bank or prerecorded production radio library yet.
- Noto Sans variable font: assets/fonts/NotoSans.ttf, from Fedora's
  google-noto-vf package (upstream Google Noto). SIL Open Font License retained
  in assets/fonts/OFL.txt. It is bundled so core UI does not need a font CDN.
- The user explicitly selected the white roof-off 2019 Stingray as the final
  car reference; its procedural representation is not a sourced GM photograph.
