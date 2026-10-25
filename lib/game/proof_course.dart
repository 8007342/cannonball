import 'dart:math' as math;

/// Authored arcade test geometry, not a geographically verified corridor.
/// Coordinates are simulation-distance units; lateral/elevation values are
/// presentation units. Increasing optical flow never stretches its bend radii.
class ProofCourse {
  static const length = 7600.0;
  static const sampleStep = 5.0;
  static const _curves = <(double, double)>[
    (0, 0),
    (500, 0),
    (650, .005),
    (1050, .005),
    (1250, -.006),
    (1650, -.006),
    (1900, .004),
    (2150, .004),
    (2400, .002),
    (2800, .002),
    (3100, -.004),
    (3450, -.004),
    (3700, 0),
    (12000, 0),
  ];
  static final List<double> _centers = _integrate();

  static List<double> _integrate() {
    final result = <double>[0];
    var heading = 0.0, center = 0.0;
    for (var i = 1; i <= 2400; i++) {
      final bend = curvatureAt((i - .5) * sampleStep);
      center += heading * sampleStep + bend * sampleStep * sampleStep * .5;
      heading += bend * sampleStep;
      result.add(center);
    }
    return List.unmodifiable(result);
  }

  static double curvatureAt(double distance) {
    final s = distance.clamp(0.0, 12000.0);
    for (var i = 1; i < _curves.length; i++) {
      final a = _curves[i - 1], b = _curves[i];
      if (s <= b.$1) {
        final t = (s - a.$1) / (b.$1 - a.$1);
        final smooth = t * t * (3 - 2 * t);
        return a.$2 + (b.$2 - a.$2) * smooth;
      }
    }
    return 0;
  }

  static double centerAt(double distance) {
    if (distance <= 0) return 0;
    final index = (distance / sampleStep).floor().clamp(0, _centers.length - 2);
    final t = ((distance - index * sampleStep) / sampleStep).clamp(0.0, 1.0);
    return _centers[index] + (_centers[index + 1] - _centers[index]) * t;
  }

  static double _rise(double s, double start, double end) {
    final t = ((s - start) / (end - start)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  static double elevationAt(double s) =>
      920 * _rise(s, 2200, 2850) -
      920 * _rise(s, 3250, 4000) +
      100 * _rise(s, 5450, 5650) -
      100 * _rise(s, 5800, 6000);

  /// Bounded steering load comes from the same authored curve as projection.
  static double steeringLoadAt(double s) =>
      (curvatureAt(s) * 55).clamp(-.4, .4);
  static double tunnelAt(double s) =>
      (_rise(s, 6050, 6160) - _rise(s, 6660, 6820)).clamp(0.0, 1.0);
  static String sectionAt(double s) => switch (s) {
    < 600 => 'OPEN STRAIGHT',
    < 2100 => 'SWEEPING S BENDS',
    < 3200 => 'CLIMB AND CURVE',
    < 4200 => 'CREST AND DESCENT',
    < 5000 => 'WORKSITE',
    < 5550 => 'TREE CANOPY',
    < 6050 => 'BRIDGE',
    < 6820 => 'TUNNEL',
    _ => 'OPEN ROAD',
  };

  /// A fixed sequence indexed from its authored origin. Culling cannot move
  /// retained cones with the camera or change their spatial identities.
  static Iterable<double> fixedPositions({
    required double origin,
    required double spacing,
    required double near,
    required double far,
    double? end,
  }) sync* {
    if (!origin.isFinite ||
        !spacing.isFinite ||
        spacing <= 0 ||
        !near.isFinite ||
        !far.isFinite ||
        far <= near)
      return;
    final first = math.max(0, ((near - origin) / spacing).ceil());
    final limit = math.min(far, end ?? far);
    for (var index = first; origin + index * spacing < limit; index++) {
      yield origin + index * spacing;
    }
  }
}
