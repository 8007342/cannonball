import 'scenic_scheduler.dart';
import 'scenic_zones.dart';

/// A surface sample: [base] drawn opaque, [overlay] drawn on top with
/// weight [t]. Weights are continuous in course distance, so cross-fades
/// have no seam when adjacent mesh strips evaluate them at shared edges.
class SurfaceSample {
  const SurfaceSample(this.base, [this.overlay, this.t = 0]);
  final String base;
  final String? overlay;
  final double t;
}

/// Ordered surface ids along course distance with per-boundary blends.
class SurfaceTrack {
  SurfaceTrack(this._starts, this._ids, this._blends);
  final List<double> _starts;
  final List<String> _ids;
  final List<double> _blends;

  static double _smooth(double t) => t * t * (3 - 2 * t);

  int _index(double s) {
    var i = 0;
    while (i + 1 < _starts.length && s >= _starts[i + 1]) {
      i++;
    }
    return i;
  }

  /// The transition (from, to) whose blend window contains [s], or the
  /// plain surface. Each boundary blends over a window centred on it.
  SurfaceSample at(double s) {
    final i = _index(s);
    // Leaving into the next segment?
    if (i + 1 < _starts.length) {
      final half = _blends[i + 1] / 2;
      if (s > _starts[i + 1] - half) {
        return SurfaceSample(
          _ids[i],
          _ids[i + 1],
          _smooth(((s - _starts[i + 1] + half) / (2 * half)).clamp(0.0, 1.0)),
        );
      }
    }
    if (i > 0) {
      final half = _blends[i] / 2;
      if (s < _starts[i] + half) {
        return SurfaceSample(
          _ids[i - 1],
          _ids[i],
          _smooth(((s - _starts[i] + half) / (2 * half)).clamp(0.0, 1.0)),
        );
      }
    }
    return SurfaceSample(_ids[i]);
  }

  /// Weight of [id] at [s] (for geometry blends such as shoulder width).
  double weight(String id, double s) {
    final sample = at(s);
    var w = 0.0;
    if (sample.base == id) w += 1 - sample.t;
    if (sample.overlay == id) w += sample.t;
    return w;
  }
}

/// Road, shoulder and ground surfaces for one level, from its zones and
/// bridge spans. Bridges switch to a deck with short abutment blends.
class RoadSurfaces {
  RoadSurfaces(LevelScenery scenery, ScenicPlan? plan) {
    final cuts = <(double, String, String, String?, double)>[];
    for (final zone in scenery.zones) {
      cuts.add((zone.start, zone.road, zone.shoulder, zone.ground, 60));
    }
    final spans =
        plan?.bridgeSpans ??
        [
          for (final p in scenery.setPieces)
            if (p.kind == SetPiece.bridge) (p.s, p.end ?? p.s + 200),
        ];
    for (final (a, b) in spans) {
      final after = scenery.zoneAt(b);
      cuts.add((a, 'bridge-deck', 'none', 'water', 10));
      cuts.add((b, after.road, after.shoulder, after.ground, 10));
      // Keep the zone that started inside the span from overriding the deck.
      cuts.removeWhere((c) => c.$1 >= a && c.$1 < b && c.$2 != 'bridge-deck');
    }
    cuts.sort((x, y) => x.$1.compareTo(y.$1));
    final starts = [for (final c in cuts) c.$1];
    // Neighbouring blend windows never overlap, so every s has one sample.
    final blends = [
      for (var i = 0; i < cuts.length; i++)
        [
          cuts[i].$5,
          if (i > 0) starts[i] - starts[i - 1],
          if (i + 1 < cuts.length) starts[i + 1] - starts[i],
        ].reduce((a, b) => a < b ? a : b),
    ];
    road = SurfaceTrack(starts, [for (final c in cuts) c.$2], blends);
    shoulder = SurfaceTrack(starts, [for (final c in cuts) c.$3], blends);
    ground = SurfaceTrack(starts, [
      for (final c in cuts) c.$4 ?? 'meadow',
    ], blends);
  }
  late final SurfaceTrack road, shoulder, ground;

  /// Shoulder half-width (road half-widths) per shoulder kind.
  static double shoulderWidth(String id) => switch (id) {
    'sidewalk' => 1.34,
    'grass' => 1.2,
    'none' => 1.0,
    _ => 1.14,
  };

  double shoulderWidthAt(double s) {
    final sample = shoulder.at(s);
    final a = shoulderWidth(sample.base);
    final o = sample.overlay;
    return o == null ? a : a + (shoulderWidth(o) - a) * sample.t;
  }

  /// 1 on a sidewalk, blending to 0 elsewhere; drives the curb line.
  double curbAt(double s) => shoulder.weight('sidewalk', s);
}
