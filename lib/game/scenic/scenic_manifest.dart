import 'dart:convert';

/// Depth bands measured from the road edge (design.md runtime contract).
enum ScenicBand { near, mid, far, vista }

ScenicBand? scenicBandFromName(String? name) => switch (name) {
  'near' => ScenicBand.near,
  'mid' => ScenicBand.mid,
  'far' => ScenicBand.far,
  'vista' => ScenicBand.vista,
  _ => null,
};

class ScenicAtlas {
  const ScenicAtlas(this.id, this.file, this.width, this.height);
  final String id, file;
  final int width, height;
}

/// One packed sprite. `rect` and `anchor` are atlas pixels; `anchor` is the
/// ground contact point relative to the rect origin.
class ScenicSprite {
  const ScenicSprite({
    required this.id,
    required this.atlas,
    required this.rect,
    required this.anchor,
    required this.worldWidthM,
    required this.band,
    required this.kind,
    this.biomes = const [],
    this.tags = const [],
    this.frames = const [],
    this.sway = 0,
    this.collides = false,
    this.nightEmissive,
  });
  final String id, atlas, kind;
  final List<double> rect, anchor;
  final double worldWidthM, sway;
  final ScenicBand band;
  final List<String> biomes, tags, frames;
  final bool collides;
  final String? nightEmissive;

  bool get animated => frames.length > 1;

  /// Explicit tags, or a token of the id ("barn-red-gambrel" is a barn).
  bool hasTag(String tag) => tags.contains(tag) || id.split('-').contains(tag);

  /// Matches "kind" or "kind/tag" group keys.
  bool matchesGroup(String group) {
    final slash = group.indexOf('/');
    if (slash < 0) return kind == group || hasTag(group);
    return kind == group.substring(0, slash) &&
        hasTag(group.substring(slash + 1));
  }

  bool inBiome(String biome) => biomes.isEmpty || biomes.contains(biome);
}

class ScenicTexture {
  const ScenicTexture(this.id, this.file, this.kind, this.tileM);
  final String id, file, kind;
  final List<double> tileM;
}

/// Parsed `assets/scenic/manifest.json`. Unknown fields are ignored and
/// malformed entries are skipped, so a partially generated pack still loads.
class ScenicManifest {
  ScenicManifest({
    required this.version,
    required this.atlases,
    required this.sprites,
    required this.textures,
  }) : _byId = {for (final s in sprites) s.id: s};
  final String version;
  final List<ScenicAtlas> atlases;
  final List<ScenicSprite> sprites;
  final List<ScenicTexture> textures;
  final Map<String, ScenicSprite> _byId;

  static final empty = ScenicManifest(
    version: 'none',
    atlases: const [],
    sprites: const [],
    textures: const [],
  );

  bool get isEmpty => sprites.isEmpty && textures.isEmpty;
  ScenicSprite? sprite(String id) => _byId[id];
  ScenicTexture? texture(String id) {
    for (final t in textures) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Sprites in [band] matching any [group]. Biomes are tried in order; when
  /// none matches, biome is relaxed rather than leaving the band empty.
  List<ScenicSprite> query({
    required ScenicBand band,
    String? group,
    List<String> biomes = const [],
  }) {
    final inBand = sprites
        .where(
          (s) => s.band == band && (group == null || s.matchesGroup(group)),
        )
        .toList();
    for (final biome in biomes) {
      final hits = inBand.where((s) => s.inBiome(biome)).toList();
      if (hits.isNotEmpty) return hits;
    }
    return biomes.isEmpty ? inBand : const [];
  }

  /// Frame sprites for animation, the sprite itself when it has none.
  List<ScenicSprite> framesOf(ScenicSprite sprite) {
    if (!sprite.animated) return [sprite];
    final frames = [for (final id in sprite.frames) ?_byId[id]];
    return frames.isEmpty ? [sprite] : frames;
  }

  static ScenicManifest parse(String source) {
    final root = jsonDecode(source);
    if (root is! Map) throw const FormatException('manifest is not an object');
    List<double> numbers(Object? value, int length) {
      if (value is! List || value.length < length) return const [];
      final out = <double>[];
      for (final v in value.take(length)) {
        if (v is! num || !v.isFinite) return const [];
        out.add(v.toDouble());
      }
      return out;
    }

    List<String> strings(Object? value) =>
        value is List ? [for (final v in value) ?(v is String ? v : null)] : [];

    final atlases = <ScenicAtlas>[];
    for (final a in (root['atlases'] as List?) ?? const []) {
      if (a is! Map || a['id'] is! String || a['file'] is! String) continue;
      atlases.add(
        ScenicAtlas(
          a['id'] as String,
          a['file'] as String,
          (a['width'] as num?)?.toInt() ?? 0,
          (a['height'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    final atlasIds = {for (final a in atlases) a.id};
    final sprites = <ScenicSprite>[];
    for (final s in (root['sprites'] as List?) ?? const []) {
      if (s is! Map || s['id'] is! String || s['atlas'] is! String) continue;
      final rect = numbers(s['rect'], 4);
      final band = scenicBandFromName(s['band'] as String?);
      final width = s['worldWidthM'];
      if (rect.isEmpty ||
          rect[2] <= 0 ||
          rect[3] <= 0 ||
          band == null ||
          width is! num ||
          width <= 0 ||
          !atlasIds.contains(s['atlas'])) {
        continue;
      }
      final anchor = numbers(s['anchor'], 2);
      sprites.add(
        ScenicSprite(
          id: s['id'] as String,
          atlas: s['atlas'] as String,
          rect: rect,
          anchor: anchor.isEmpty ? [rect[2] / 2, rect[3]] : anchor,
          worldWidthM: width.toDouble(),
          band: band,
          kind: (s['kind'] as String?) ?? 'structure',
          biomes: strings(s['biomes']),
          tags: strings(s['tags']),
          frames: strings(s['frames']),
          sway: (s['sway'] as num?)?.toDouble() ?? 0,
          collides: s['collides'] == true,
          nightEmissive: s['nightEmissive'] as String?,
        ),
      );
    }
    final textures = <ScenicTexture>[];
    for (final t in (root['textures'] as List?) ?? const []) {
      if (t is! Map || t['id'] is! String || t['file'] is! String) continue;
      final tile = numbers(t['tileM'], 2);
      textures.add(
        ScenicTexture(
          t['id'] as String,
          t['file'] as String,
          (t['kind'] as String?) ?? 'road',
          tile.isEmpty || tile.any((v) => v <= 0) ? const [7, 7] : tile,
        ),
      );
    }
    return ScenicManifest(
      version: (root['version'] as String?) ?? 'unknown',
      atlases: atlases,
      sprites: sprites,
      textures: textures,
    );
  }
}
