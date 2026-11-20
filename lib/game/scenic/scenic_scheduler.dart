import 'dart:math' as math;

import '../terrain/level_profiles.dart';
import 'scenic_bands.dart';
import 'scenic_manifest.dart';
import 'scenic_zones.dart';

/// 32-bit integer hashing that gives identical results on the Dart VM and
/// on the web (no products above 2^53).
class ScenicHash {
  static int _mul(int a, int b) =>
      ((a & 0xffff) * b + ((((a >>> 16) * b) & 0xffff) << 16)) & 0xffffffff;

  static int mix(int x) {
    x &= 0xffffffff;
    x ^= x >>> 16;
    x = _mul(x, 0x7feb352d);
    x ^= x >>> 15;
    x = _mul(x, 0x846ca68b);
    x ^= x >>> 16;
    return x;
  }

  static int combine(int a, int b) => mix(a ^ mix(b + 0x9e3779b9));
  static double unit(int seed, int a, [int b = 0, int c = 0]) =>
      combine(combine(combine(seed, a), b), c) / 4294967296.0;

  /// Smooth value noise in [0, 1].
  static double noise(int seed, double x) {
    final i = x.floor();
    final t = x - i;
    final a = unit(seed, i), b = unit(seed, i + 1);
    return a + (b - a) * t * t * (3 - 2 * t);
  }
}

class ScenicPlacement {
  const ScenicPlacement(
    this.s,
    this.side,
    this.offsetM,
    this.sprite,
    this.band, {
    this.phase = 0,
    this.setPiece = false,
  });
  final double s, offsetM, phase;
  final int side;
  final ScenicSprite sprite;
  final ScenicBand band;
  final bool setPiece;

  /// Signed lateral position in road half-widths from the road centre.
  double get lateral => ScenicScale.lateral(offsetM, side);
}

/// A sprite on the horizon strip; [position] is its strip fraction [0, 1).
class VistaSlot {
  const VistaSlot(this.sprite, this.position);
  final ScenicSprite sprite;
  final double position;
}

/// Precomputed, deterministic scenery for one level. Placement depends only
/// on (level seed, course distance, manifest), never on camera, frame rate
/// or optical-flow preset, so it is stable under preset changes and replays.
class ScenicPlan {
  ScenicPlan._(this.scenery, this.seed);

  factory ScenicPlan.build({
    required ScenicManifest manifest,
    required LevelScenery scenery,
    required int seed,
    LevelProfile? profile,
    bool Function(double s)? enclosed,
    double length = 9000,
  }) {
    final plan = ScenicPlan._(scenery, seed);
    plan._build(manifest, profile, enclosed ?? (_) => false, length);
    return plan;
  }

  final LevelScenery scenery;
  final int seed;
  final Map<ScenicBand, List<ScenicPlacement>> _bands = {
    for (final band in ScenicBand.values) band: [],
  };
  final List<List<VistaSlot>> zoneVistas = [];
  final List<(double, double)> bridgeSpans = [];

  /// Cell length (course units) per band.
  static const cell = {
    ScenicBand.near: 3.0,
    ScenicBand.mid: 6.0,
    ScenicBand.far: 30.0,
  };
  static const recency = 3;

  List<ScenicPlacement> placements(ScenicBand band) =>
      List.unmodifiable(_bands[band]!);

  /// Placements with `from <= s < to`, ordered by s.
  Iterable<ScenicPlacement> between(
    ScenicBand band,
    double from,
    double to,
  ) sync* {
    final list = _bands[band]!;
    var low = 0, high = list.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (list[mid].s < from) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    for (var i = low; i < list.length && list[i].s < to; i++) {
      yield list[i];
    }
  }

  bool onBridge(double s) {
    for (final (a, b) in bridgeSpans) {
      if (s >= a && s <= b) return true;
    }
    return false;
  }

  /// Road-only stretch: authored quiet zones plus deterministic breathing
  /// gaps inside busier zones.
  bool quietAt(double s) {
    final zone = scenery.zoneAt(s);
    return zone.quiet || ScenicHash.noise(seed ^ 0x51ed, s / 650) < .2;
  }

  /// Density envelope (placements per 100 course units per side): zone peak
  /// times soft zone-edge ramps and slow breathing. Quiet stretches keep
  /// only sparse near furniture.
  double density(ScenicBand band, double s) {
    final zone = scenery.zoneAt(s);
    final peak = switch (band) {
      ScenicBand.near => zone.near,
      ScenicBand.mid => zone.mid,
      ScenicBand.far => zone.far,
      ScenicBand.vista => 0.0,
    };
    final edge = math.min(s - zone.start, zone.end - s);
    final ramp = (edge / 80).clamp(0.0, 1.0);
    final breathe = .35 + .65 * ScenicHash.noise(seed ^ band.index, s / 420);
    // Far scenery is a slow reveal: half as many slots, breathing.
    if (band == ScenicBand.far) return peak * (.25 + .25 * breathe);
    final quiet = quietAt(s);
    if (quiet && band == ScenicBand.mid) return 0;
    final base = peak * (.3 + .7 * ramp) * breathe;
    return quiet ? base * .35 : base;
  }

  void _build(
    ScenicManifest manifest,
    LevelProfile? profile,
    bool Function(double) enclosed,
    double length,
  ) {
    for (final piece in scenery.setPieces) {
      if (piece.kind == SetPiece.bridge) {
        bridgeSpans.add((piece.s, piece.end ?? piece.s + 200));
      }
    }
    final candidateCache =
        <(int, ScenicBand, bool), List<(ScenicSprite, double)>>{};
    List<(ScenicSprite, double)> candidates(
      int zoneIndex,
      ScenicBand band,
      bool quiet,
    ) => candidateCache.putIfAbsent((zoneIndex, band, quiet), () {
      final zone = scenery.zones[zoneIndex];
      final weights = <ScenicSprite, double>{};
      zone.weights.forEach((group, weight) {
        if (quiet &&
            !(group.startsWith('furniture') || group.startsWith('sign'))) {
          return;
        }
        final hits = manifest.query(
          band: band,
          group: group,
          biomes: zone.biomes,
        );
        for (final sprite in hits) {
          weights[sprite] = (weights[sprite] ?? 0) + weight / hits.length;
        }
      });
      // Structures that belong to bridges are placed by set pieces only.
      weights.removeWhere((s, _) => s.tags.contains('bridge'));
      return [for (final e in weights.entries) (e.key, e.value)];
    });

    for (final band in [ScenicBand.near, ScenicBand.mid, ScenicBand.far]) {
      final step = cell[band]!;
      final (lowM, highM) = ScenicScale.range(band);
      for (final side in const [-1, 1]) {
        final recent = <String>[];
        var blockedUntil = -1.0;
        for (var i = 0; i * step < length; i++) {
          final s0 = i * step;
          final key = band.index * 2 + (side + 1) ~/ 2;
          final u = ScenicHash.unit(seed, key, i);
          final s = s0 + u * step * .9;
          if (s < blockedUntil || enclosed(s)) continue;
          if (band != ScenicBand.far && onBridge(s)) continue;
          final p = density(band, s) * step / 100;
          if (ScenicHash.unit(seed, key, i, 1) >= p) continue;
          final zoneIndex = scenery.indexAt(s);
          final quiet = band == ScenicBand.near && quietAt(s);
          final pool = candidates(zoneIndex, band, quiet);
          if (pool.isEmpty) continue;
          final sprite = _pick(pool, recent, ScenicHash.unit(seed, key, i, 2));
          recent.add(sprite.id);
          if (recent.length > recency) recent.removeAt(0);
          final v = ScenicHash.unit(seed, key, i, 3);
          final shaped = switch (band) {
            ScenicBand.mid => v * v,
            ScenicBand.far => math.pow(v, 1.6).toDouble(),
            _ => v,
          };
          final clearance = band == ScenicBand.far
              ? 0.0
              : sprite.worldWidthM / 2 + .4;
          final offset = math.max(lowM + (highM - lowM) * shaped, clearance);
          final phase = ScenicHash.unit(seed, key, i, 4);
          if (band == ScenicBand.far && sprite.kind == 'animal') {
            // Grazing animals appear as small herds in the nearer far band,
            // where they read as animals rather than specks.
            final herd = 2 + (ScenicHash.unit(seed, key, i, 5) * 3).floor();
            final base = lowM + 110 * v;
            for (var n = 0; n < herd; n++) {
              final animal = n == 0
                  ? sprite
                  : _pick(
                      pool.where((e) => e.$1.kind == 'animal').toList(),
                      const [],
                      ScenicHash.unit(seed, key, i, 10 + n),
                    );
              _bands[band]!.add(
                ScenicPlacement(
                  s + (ScenicHash.unit(seed, key, i, 20 + n) - .5) * 24,
                  side,
                  base + (ScenicHash.unit(seed, key, i, 30 + n) - .5) * 30,
                  animal,
                  band,
                  phase: ScenicHash.unit(seed, key, i, 40 + n),
                ),
              );
            }
            continue;
          }
          if (sprite.hasTag('fence') || sprite.hasTag('run')) {
            // Fences and hedges form short continuous runs.
            final count = 3 + (ScenicHash.unit(seed, key, i, 5) * 7).floor();
            final spacing = ScenicScale.courseUnits(sprite.worldWidthM) * .96;
            for (var n = 0; n < count; n++) {
              final at = s + n * spacing;
              if (enclosed(at) || onBridge(at)) break;
              _bands[band]!.add(
                ScenicPlacement(at, side, offset, sprite, band, phase: phase),
              );
              blockedUntil = at + spacing;
            }
            continue;
          }
          _bands[band]!.add(
            ScenicPlacement(s, side, offset, sprite, band, phase: phase),
          );
        }
      }
    }
    _setPieces(manifest);
    if (profile != null) _curveSigns(manifest, profile, enclosed, length);
    for (final list in _bands.values) {
      list.sort((a, b) => a.s.compareTo(b.s));
    }
    _vistas(manifest);
  }

  static ScenicSprite _pick(
    List<(ScenicSprite, double)> pool,
    List<String> recent,
    double u,
  ) {
    final exclude = pool.length > recent.length
        ? recent.toSet()
        : recent.skip(recent.length - pool.length + 1).toSet();
    var total = 0.0;
    for (final (sprite, weight) in pool) {
      if (!exclude.contains(sprite.id)) total += weight;
    }
    var target = u * total;
    for (final (sprite, weight) in pool) {
      if (exclude.contains(sprite.id)) continue;
      target -= weight;
      if (target <= 0) return sprite;
    }
    return pool
        .lastWhere((e) => !exclude.contains(e.$1.id), orElse: () => pool.last)
        .$1;
  }

  ScenicSprite? _find(
    ScenicManifest manifest,
    List<String> groups,
    List<String> biomes,
    int salt, {
    List<ScenicBand> bands = const [ScenicBand.far, ScenicBand.mid],
  }) {
    for (final band in bands) {
      for (final group in groups) {
        final hits = manifest.query(band: band, group: group, biomes: biomes);
        if (hits.isNotEmpty) {
          return hits[(ScenicHash.unit(seed, salt, hits.length) * hits.length)
              .floor()
              .clamp(0, hits.length - 1)];
        }
      }
    }
    return null;
  }

  void _add(ScenicSprite sprite, double s, int side, double offsetM, int salt) {
    // Anything placed beyond the mid band streams with the far window.
    final band =
        offsetM >= ScenicScale.range(ScenicBand.far).$1 ||
            sprite.band == ScenicBand.vista
        ? ScenicBand.far
        : sprite.band;
    _bands[band]!.add(
      ScenicPlacement(
        s,
        side,
        offsetM,
        sprite,
        band,
        phase: ScenicHash.unit(seed, salt, 7),
        setPiece: true,
      ),
    );
  }

  void _herd(
    ScenicManifest manifest,
    SetPiece piece,
    List<String> biomes,
    double offset,
    int salt,
    int count,
  ) {
    for (var n = 0; n < count; n++) {
      final animal = _find(
        manifest,
        const ['animal/cattle', 'animal'],
        biomes,
        salt + n,
      );
      if (animal == null) return;
      final ds = (ScenicHash.unit(seed, salt, n, 1) - .5) * 70;
      final dm = (ScenicHash.unit(seed, salt, n, 2) - .5) * 50;
      _add(
        animal,
        piece.s + ds,
        piece.side,
        math.max(40, offset + dm),
        salt + n,
      );
    }
  }

  void _setPieces(ScenicManifest manifest) {
    var salt = 9000;
    for (final zone in scenery.zones) {
      for (final piece in zone.setPieces) {
        salt += 97;
        final offset = piece.offsetM ?? 180;
        switch (piece.kind) {
          case SetPiece.farmstead:
            final barn = _find(
              manifest,
              const [
                'structure/barn',
                'structure/farmstead',
                'structure/house',
              ],
              zone.biomes,
              salt,
            );
            if (barn != null) _add(barn, piece.s, piece.side, offset, salt);
            final silo = _find(
              manifest,
              const ['structure/silo'],
              zone.biomes,
              salt + 1,
            );
            if (silo != null) {
              _add(silo, piece.s + 18, piece.side, offset + 22, salt + 1);
            }
            final house = _find(
              manifest,
              const ['structure/house'],
              zone.biomes,
              salt + 2,
            );
            if (house != null && house != barn) {
              _add(house, piece.s - 26, piece.side, offset - 12, salt + 2);
            }
            for (var n = 0; n < 3; n++) {
              final tree = _find(
                manifest,
                const ['tree'],
                zone.biomes,
                salt + 3 + n,
              );
              if (tree != null) {
                _add(
                  tree,
                  piece.s - 40 + n * 38,
                  piece.side,
                  offset + 45,
                  salt + 3 + n,
                );
              }
            }
            _herd(manifest, piece, zone.biomes, offset - 55, salt + 10, 4);
          case SetPiece.grazing:
            _herd(
              manifest,
              piece,
              zone.biomes,
              offset,
              salt,
              3 + (ScenicHash.unit(seed, salt) * 5).floor(),
            );
          case SetPiece.waterTower:
            final tower = _find(
              manifest,
              const ['structure/water-tower', 'structure/silo'],
              zone.biomes,
              salt,
            );
            if (tower != null) _add(tower, piece.s, piece.side, offset, salt);
          case SetPiece.village:
            for (var n = 0; n < 5; n++) {
              final house = _find(
                manifest,
                const ['structure/house', 'structure/business'],
                zone.biomes,
                salt + n,
                bands: const [ScenicBand.mid],
              );
              if (house != null) {
                _add(
                  house,
                  piece.s + n * 28,
                  piece.side,
                  9 + n % 2 * 6,
                  salt + n,
                );
              }
            }
          case SetPiece.bridge:
            final end = piece.end ?? piece.s + 200;
            // Bridge sprites are side elevations drawn as camera-facing
            // billboards: placed at the deck edge, a 27-36 m panel covers the
            // whole carriageway (an arch wall across the road). The deck
            // itself is the textured surface with procedural parapets; the
            // structures stand as neighbouring crossings up- and downstream,
            // seen side-on from the deck as the real ones would be.
            final pool = [
              for (final band in const [ScenicBand.near, ScenicBand.mid])
                ...manifest.query(
                  band: band,
                  group: 'structure/bridge',
                  biomes: zone.biomes,
                ),
            ];
            if (pool.isEmpty) break;
            final first =
                (ScenicHash.unit(seed, salt, pool.length) * pool.length)
                    .floor()
                    .clamp(0, pool.length - 1);
            _add(pool[first], piece.s + (end - piece.s) * .3, -1, 34, salt + 3);
            if (pool.length > 1 && end - piece.s > 150) {
              _add(
                pool[(first + 1) % pool.length],
                piece.s + (end - piece.s) * .75,
                1,
                42,
                salt + 4,
              );
            }
        }
      }
    }
  }

  /// Course units before a hairpin's demand begins where its warning and
  /// chevron signs stand.
  static const hairpinSignOffsets = [200.0, 130.0, 80.0, 35.0];

  void _curveSigns(
    ScenicManifest manifest,
    LevelProfile profile,
    bool Function(double) enclosed,
    double length,
  ) {
    final signs = manifest.query(band: ScenicBand.near, group: 'sign/curve');
    final pool = signs.isNotEmpty
        ? signs
        : manifest.query(band: ScenicBand.near, group: 'sign/warning');
    if (pool.isEmpty) return;
    var inside = false;
    for (var s = 0.0; s < length; s += 2) {
      final demand = profile.cornerDemandAt(s);
      final now = demand.abs() > 1;
      if (now && !inside && s > 120 && !enclosed(s - 110)) {
        final sprite = pool[(s ~/ 2) % pool.length];
        // An advance warning, then a run of chevrons on the outside of the
        // bend up to its entry: at top speed the first is ~2.5 s out.
        for (final before in hairpinSignOffsets) {
          if (enclosed(s - before)) continue;
          _bands[ScenicBand.near]!.add(
            ScenicPlacement(
              s - before,
              demand > 0 ? -1 : 1,
              .9,
              sprite,
              ScenicBand.near,
              setPiece: true,
            ),
          );
        }
      }
      inside = now;
    }
  }

  void _vistas(ScenicManifest manifest) {
    for (var z = 0; z < scenery.zones.length; z++) {
      final zone = scenery.zones[z];
      var pool = <ScenicSprite>[];
      for (final group in zone.vistaGroups) {
        pool = manifest.query(
          band: ScenicBand.vista,
          group: group,
          biomes: zone.biomes,
        );
        if (pool.isNotEmpty) break;
      }
      if (pool.isEmpty) {
        pool = manifest.query(band: ScenicBand.vista, biomes: zone.biomes);
      }
      if (pool.isEmpty) pool = manifest.query(band: ScenicBand.vista);
      final slots = <VistaSlot>[];
      if (pool.isNotEmpty) {
        // Eight overlapping panels on the wrapped strip: with feathered sides
        // and the ground-haze foot they read as one continuous horizon.
        const count = 8;
        String? last;
        for (var n = 0; n < count; n++) {
          var pick =
              pool[(ScenicHash.unit(seed, 4000 + z, n) * pool.length)
                  .floor()
                  .clamp(0, pool.length - 1)];
          if (pick.id == last && pool.length > 1) {
            pick = pool[(pool.indexOf(pick) + 1) % pool.length];
          }
          last = pick.id;
          slots.add(
            VistaSlot(
              pick,
              (n + ScenicHash.unit(seed, 4100 + z, n) * .35) / count,
            ),
          );
        }
      }
      zoneVistas.add(slots);
    }
  }
}
