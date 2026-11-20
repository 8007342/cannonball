import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import 'scenic_fallback.dart';
import 'scenic_manifest.dart';

/// A decoded surface texture and the real-world size of one tile.
class ScenicSurface {
  const ScenicSurface(this.image, this.tileM);
  final ui.Image image;
  final List<double> tileM;
}

/// Runtime scenic pack: the manifest, its decoded atlases and surface
/// textures. Falls back to the proof atlas (sprites) and procedural tiles
/// (surfaces) for anything the pack does not provide, so the game runs
/// before, during and after art generation.
class ScenicLibrary {
  ScenicLibrary._(this.manifest, this.usingFallback);

  ScenicManifest manifest;
  final bool usingFallback;
  final Map<String, ui.Image> _atlases = {};
  final Map<String, ScenicSurface> _surfaces = {};
  final List<ui.Image> _owned = [];
  String? warning;

  static const root = 'assets/scenic/';
  static const proceduralSurfaces = [
    'asphalt-fresh',
    'concrete',
    'brick',
    'gravel',
    'grass',
    'sidewalk',
    'bridge-deck',
    'water',
    'crop-rows',
  ];

  int get atlasCount => _atlases.length;

  /// Proof-art sprites kept while a growing pack lacks their slot.
  int supplemented = 0;

  /// Fallback sprites whose (band, kind, biome) slot no pack sprite fills,
  /// so a partial pack never leaves a band or biome empty. As the pack
  /// grows, the proof art drops out automatically.
  static List<ScenicSprite> supplement(
    List<ScenicSprite> pack,
    List<ScenicSprite> fallback,
  ) => [
    for (final f in fallback)
      if (!pack.any(
        (p) =>
            p.band == f.band &&
            p.kind == f.kind &&
            (p.biomes.isEmpty ||
                f.biomes.isEmpty ||
                f.biomes.every(p.biomes.contains)),
      ))
        f,
  ];
  bool hasSurface(String id) => _surfaces.containsKey(id);

  /// Mean colour (ARGB) of each measured surface texture: what its mip
  /// chain converges to in the distance. The renderer continues the
  /// textured ground beyond the mesh in this colour, so the far terrain
  /// meets the textured terrain without a seam.
  final Map<String, int> _means = {};
  int? meanColor(String id) => _means[id];

  /// Measures [meanColor] for every surface not yet measured.
  Future<void> measureSurfaces() async {
    for (final entry in _surfaces.entries.toList()) {
      if (_means.containsKey(entry.key)) continue;
      final image = entry.value.image;
      final data = await image.toByteData();
      if (data == null) continue;
      _means[entry.key] = meanOf(data, image.width * image.height);
    }
  }

  /// Average of opaque-weighted RGBA8 pixels, sampled on a sparse lattice.
  static int meanOf(ByteData rgba, int pixels) {
    final step = math.max(1, pixels ~/ 4096);
    var r = 0.0, g = 0.0, b = 0.0, weight = 0.0;
    for (var i = 0; i < pixels; i += step) {
      final a = rgba.getUint8(i * 4 + 3) / 255;
      r += rgba.getUint8(i * 4) * a;
      g += rgba.getUint8(i * 4 + 1) * a;
      b += rgba.getUint8(i * 4 + 2) * a;
      weight += a;
    }
    if (weight <= 0) return 0xff808080;
    int c(double v) => (v / weight).round().clamp(0, 255);
    return 0xff000000 | c(r) << 16 | c(g) << 8 | c(b);
  }

  ScenicSurface? surface(String id) => _surfaces[id];
  Iterable<String> get surfaceIds => _surfaces.keys;

  /// The atlas image for [id]; the fallback atlas resolves to [proofAtlas].
  ui.Image? atlas(String id, {ui.Image? proofAtlas}) =>
      id == ScenicFallback.atlas ? proofAtlas : _atlases[id];

  /// Registers an externally owned texture unless the pack provides one.
  void provide(String id, ui.Image image, List<double> tileM) =>
      _surfaces.putIfAbsent(id, () => ScenicSurface(image, tileM));

  static Future<ScenicLibrary> load({
    AssetBundle? bundle,
    bool businesses = true,
  }) async {
    final assets = bundle ?? rootBundle;
    ScenicManifest? manifest;
    String? warning;
    try {
      manifest = ScenicManifest.parse(
        await assets.loadString('${root}manifest.json', cache: false),
      );
    } on FormatException catch (error) {
      warning = 'scenic manifest invalid: ${error.message}';
    } catch (_) {
      // Missing manifest: the pack has not been generated yet.
    }
    final library = ScenicLibrary._(
      manifest ?? ScenicManifest.empty,
      manifest == null || manifest.sprites.isEmpty,
    )..warning = warning;
    if (manifest != null) {
      for (final atlas in manifest.atlases) {
        final image = await _decode(assets, '$root${atlas.file}');
        if (image == null) continue;
        library._atlases[atlas.id] = image;
        library._owned.add(image);
      }
      for (final texture in manifest.textures) {
        final image = await _decode(assets, '$root${texture.file}');
        if (image == null) continue;
        library._surfaces[texture.id] = ScenicSurface(image, texture.tileM);
        library._owned.add(image);
      }
      // Sprites whose atlas failed to decode are dropped, not drawn blank.
      final usable = [
        for (final s in manifest.sprites)
          if (library._atlases.containsKey(s.atlas)) s,
      ];
      final fallback = ScenicFallback.manifest(businesses: businesses);
      if (usable.isEmpty) {
        library.manifest = fallback;
      } else {
        final fill = supplement(usable, fallback.sprites);
        library.supplemented = fill.length;
        library.manifest = ScenicManifest(
          version: manifest.version,
          atlases: [...manifest.atlases, ...fallback.atlases],
          sprites: [...usable, ...fill],
          textures: manifest.textures,
        );
      }
    } else {
      library.manifest = ScenicFallback.manifest(businesses: businesses);
    }
    library._procedural();
    return library;
  }

  /// Test/tooling entry point with an already parsed manifest and images.
  static ScenicLibrary fromParts(
    ScenicManifest manifest,
    Map<String, ui.Image> atlases, {
    bool procedural = true,
  }) {
    final library = ScenicLibrary._(manifest, false);
    library._atlases.addAll(atlases);
    if (procedural) library._procedural();
    return library;
  }

  static Future<ui.Image?> _decode(AssetBundle bundle, String path) async {
    try {
      final data = await bundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  void _procedural() {
    for (final id in proceduralSurfaces) {
      if (_surfaces.containsKey(id)) continue;
      final (image, tile) = _paint(id);
      _owned.add(image);
      _surfaces[id] = ScenicSurface(image, tile);
    }
  }

  static (ui.Image, List<double>) _paint(String id) {
    const size = 256.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final random = math.Random(id.hashCode & 0xffff);
    final paint = ui.Paint();
    void fill(int color) => canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, size, size),
      paint..color = ui.Color(color),
    );
    void speckle(int count, List<int> colors, double radius) {
      for (var i = 0; i < count; i++) {
        paint.color = ui.Color(colors[i % colors.length]);
        canvas.drawCircle(
          ui.Offset(random.nextDouble() * size, random.nextDouble() * size),
          radius * (.4 + random.nextDouble()),
          paint,
        );
      }
    }

    void lines(double step, int color, double width, {bool vertical = false}) {
      paint
        ..color = ui.Color(color)
        ..strokeWidth = width;
      for (var p = 0.0; p < size; p += step) {
        canvas.drawLine(
          vertical ? ui.Offset(p, 0) : ui.Offset(0, p),
          vertical ? ui.Offset(p, size) : ui.Offset(size, p),
          paint,
        );
      }
    }

    late List<double> tile;
    switch (id) {
      case 'asphalt-fresh':
        fill(0xff3d4247);
        speckle(900, [0xff474d52, 0xff353a3e, 0xff545a5e], 1.1);
        tile = [6, 6];
      case 'concrete':
        fill(0xffb9b7ad);
        speckle(500, [0xffc4c2b8, 0xffaeaca2], 1.4);
        lines(128, 0xff8f8c82, 2.5);
        lines(128, 0xff96938a, 1.6, vertical: true);
        tile = [7.3, 7.3];
      case 'brick':
        fill(0xff9a5a44);
        for (var row = 0; row < 16; row++) {
          final y = row * 16.0, shift = row.isEven ? 0.0 : 16.0;
          for (var x = -32.0; x < size; x += 32) {
            paint.color = ui.Color(
              [0xffa8624a, 0xff94533e, 0xffb06c50][(row + x ~/ 32) % 3],
            );
            canvas.drawRect(
              ui.Rect.fromLTWH(x + shift + 1, y + 1, 30, 14),
              paint,
            );
          }
        }
        tile = [3.2, 3.2];
      case 'gravel':
        fill(0xffb7a585);
        speckle(1400, [0xffa08d6d, 0xffcdbd9c, 0xff8b7a5e, 0xffd8cbb0], 1.6);
        tile = [3, 3];
      case 'grass':
        fill(0xff7f9c54);
        speckle(1600, [0xff6d8a45, 0xff92ae62, 0xff5f7a3c], 1.5);
        tile = [3.5, 3.5];
      case 'sidewalk':
        fill(0xffcfcbbf);
        speckle(300, [0xffd9d5c9, 0xffc2beb2], 1.2);
        lines(64, 0xffa9a598, 1.8);
        lines(64, 0xffa9a598, 1.8, vertical: true);
        tile = [3, 3];
      case 'bridge-deck':
        fill(0xffa3a39b);
        speckle(600, [0xffb0b0a8, 0xff96968e], 1.3);
        lines(256, 0xff5f625f, 6);
        tile = [11, 9];
      case 'water':
        fill(0xff4f7f95);
        paint.strokeWidth = 2;
        for (var i = 0; i < 70; i++) {
          paint.color = ui.Color(i.isEven ? 0x66cfe6ee : 0x442b5868);
          final x = random.nextDouble() * size, y = random.nextDouble() * size;
          canvas.drawLine(ui.Offset(x, y), ui.Offset(x + 18, y), paint);
        }
        tile = [14, 14];
      case 'crop-rows':
        fill(0xff8fa456);
        for (var x = 0.0; x < size; x += 32) {
          paint.color = const ui.Color(0xff6f8a3e);
          canvas.drawRect(ui.Rect.fromLTWH(x, 0, 14, size), paint);
        }
        speckle(500, [0xffa3b765, 0xff5f7a35], 1.2);
        tile = [8, 8];
      default:
        fill(0xff808080);
        tile = [4, 4];
    }
    final picture = recorder.endRecording();
    final image = picture.toImageSync(size.toInt(), size.toInt());
    picture.dispose();
    return (image, tile);
  }

  void dispose() {
    for (final image in _owned) {
      image.dispose();
    }
    _owned.clear();
    _atlases.clear();
    _surfaces.clear();
    _means.clear();
  }
}
