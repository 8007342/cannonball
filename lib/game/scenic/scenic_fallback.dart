import 'scenic_manifest.dart';

/// Maps the existing proof scenery atlas (resolved per level at draw time,
/// so autumn/dry material variants still apply) into manifest terms. Used
/// whenever `assets/scenic/manifest.json` is absent or has no sprites.
class ScenicFallback {
  static const atlas = 'proof-environment';

  static const _ground = [512.0, 512.0, 512.0, 478.0, 449.0, 451.0];

  /// The oak (frame 0) canopy overhangs its cell; see ProofArt.oakOverhang.
  static List<double> _cell(int i) => i < 6
      ? [(i % 3) * 512.0, (i ~/ 3) * 512.0, i == 0 ? 572 : 512, 512]
      : [((i - 6) % 2) * 512.0, 2048 + ((i - 6) ~/ 2) * 512.0, 512, 512];

  static ScenicSprite _sprite(
    String id,
    int frame,
    ScenicBand band,
    String kind,
    double widthM,
    List<String> biomes, {
    List<String> tags = const [],
    double sway = 0,
  }) => ScenicSprite(
    id: id,
    atlas: atlas,
    rect: _cell(frame),
    anchor: [256, frame < 6 ? _ground[frame] : 506],
    worldWidthM: widthM,
    band: band,
    kind: kind,
    biomes: biomes,
    tags: [...tags, 'proof-frame-$frame'],
    sway: sway,
  );

  static ScenicManifest manifest({bool businesses = true}) {
    const green = ['farm', 'forest', 'town', 'river', 'plains'];
    return ScenicManifest(
      version: 'proof-fallback',
      atlases: const [ScenicAtlas(atlas, '', 1536, 3072)],
      sprites: [
        // 9.5 m over the widened 572 px frame keeps the original 8.5 m / 512 px.
        _sprite('oak', 0, ScenicBand.mid, 'tree', 9.5, green, sway: 1),
        _sprite('pine', 1, ScenicBand.mid, 'tree', 7, [
          'forest',
          'river',
          'town',
        ], sway: 1),
        _sprite('palm', 2, ScenicBand.mid, 'tree', 7, ['desert'], sway: 1),
        _sprite('shrub', 5, ScenicBand.near, 'shrub', 2.8, const []),
        _sprite('roadside-pine', 1, ScenicBand.near, 'tree', 5, [
          'forest',
          'river',
        ], sway: 1),
        _sprite(
          'brick-block',
          3,
          ScenicBand.mid,
          'structure',
          12,
          ['town', 'city'],
          tags: ['building', 'house'],
        ),
        _sprite(
          'service-station',
          4,
          ScenicBand.mid,
          'structure',
          13,
          ['town', 'city', 'desert', 'plains'],
          tags: ['business'],
        ),
        if (businesses)
          for (var i = 6; i < 10; i++)
            _sprite(
              'business-${i - 5}',
              i,
              ScenicBand.mid,
              'structure',
              11,
              ['town', 'city'],
              tags: ['business'],
            ),
        _sprite(
          'oak-line',
          0,
          ScenicBand.far,
          'tree',
          16,
          green,
          tags: ['tree-line'],
        ),
        _sprite(
          'pine-line',
          1,
          ScenicBand.far,
          'tree',
          13,
          ['forest', 'river'],
          tags: ['tree-line'],
        ),
        _sprite('far-palm', 2, ScenicBand.far, 'tree', 12, ['desert']),
      ],
      textures: const [],
    );
  }
}
