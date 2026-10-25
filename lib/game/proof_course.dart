import 'dart:math' as math;

/// Authored arcade test geometry, not a geographically verified corridor.
/// Coordinates are simulation-distance units; lateral/elevation values are
/// presentation units. Increasing optical flow never stretches its bend radii.
class ProofCourse {
  static const length = 7600.0;
  static const sampleStep = 5.0;
  // Lateral presentation units differ from course-distance units. Keep bends
  // readable at the velocity preset without increasing steering-force saturation.
  static const lateralScale = 6.0;
  // Gentle sweeps, tightening bends and reversals are deliberately interleaved.
  // The bridge, worksite and tunnel retain their existing chapter positions.
  static const _curves = <(double, double)>[
    (0, 0),
    (100, .001),
    (240, .001),
    (340, -.0025),
    (420, -.0025),
    (540, .00075),
    (650, .006),
    (850, .009),
    (1040, .0025),
    (1220, -.001),
    (1450, -.010),
    (1650, -.0035),
    (1850, .001),
    (2050, .008),
    (2250, .001),
    (2420, -.0025),
    (2660, .002),
    (2850, .0085),
    (3080, -.0015),
    (3330, -.009),
    (3550, -.002),
    (3750, .001),
    (3980, .006),
    (4200, 0),
    (4430, -.001),
    (4670, -.0025),
    (4900, 0),
    (5140, .007),
    (5420, .001),
    (5600, -.0015),
    (5860, -.0015),
    (6060, .00075),
    (6300, .002),
    (6520, -.002),
    (6780, -.00075),
    (6960, .001),
    (7210, .008),
    (7420, -.0015),
    (7600, 0),
    (12000, 0),
  ];
  static final List<double> _centers = _integrate();

  static List<double> _integrate() {
    final result = <double>[0];
    var heading = 0.0, center = 0.0;
    for (var i = 1; i <= 2400; i++) {
      final bend = curvatureAt((i - .5) * sampleStep) * lateralScale;
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
        // Arcade emphasis makes bends readable within the short projected view.
        return (a.$2 + (b.$2 - a.$2) * smooth) * 8;
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

  // Compact, smooth rise/dip pairs vary crest timing without a repetitive wave.
  static const _rollers = <(double, double, double)>[
    (40, 290, 140),
    (310, 570, -220),
    (590, 1090, 1300),
    (1140, 1620, -1100),
    (1650, 2140, 1800),
    (2670, 3140, 950),
    (3570, 4160, -1200),
    (4210, 4430, -190),
    (4430, 4820, 900),
    (4830, 5000, -250),
    (5010, 5380, 700),
    (2150, 2430, -450),
    (3180, 3490, 650),
    (5410, 5700, 450),
    (5740, 6020, -500),
    (6120, 6360, 300),
    (6450, 6730, -350),
    (6870, 7160, -680),
    (7160, 7500, 1050),
  ];
  static double rollingElevationAt(double s) {
    var height = 0.0;
    for (final (start, end, amplitude) in _rollers) {
      if (s <= start || s >= end) continue;
      final wave = math.sin(math.pi * (s - start) / (end - start));
      height += amplitude * wave * wave;
    }
    return height;
  }

  static double elevationAt(double s) =>
      rollingElevationAt(s) +
      800 * _rise(s, 100, 260) -
      800 * _rise(s, 340, 520) +
      7000 * _rise(s, 2200, 2850) -
      7000 * _rise(s, 3250, 4000) +
      100 * _rise(s, 5450, 5650) -
      100 * _rise(s, 5800, 6000);

  /// Local slope in projected-world units. The same flow scale expands road
  /// distance, so it must also be present in this derivative. This is a slope,
  /// not an angle; use atan(grade) before comparing it with camera pitch.
  static double gradeAt(double distance, double flowScale) {
    if (!distance.isFinite || !flowScale.isFinite || flowScale <= 0) return 0;
    const halfSpan = 2.5;
    return (elevationAt(distance + halfSpan) -
            elevationAt(distance - halfSpan)) /
        (2 * halfSpan * flowScale);
  }

  /// View pitch follows road grade. The camera trail remains the player's
  /// invariant ground point while the far horizon moves visibly on grades.
  static double pitchAt(double distance, double flowScale) {
    if (!flowScale.isFinite || flowScale <= 0) return 0;
    final grade =
        (elevationAt(distance + 60) - elevationAt(distance - 60)) /
        (120 * flowScale);
    return (grade * 1.8).clamp(-.24, .24);
  }

  static double pitchShift(double pitch, double depth, {double trail = 560}) =>
      depth > 0 ? pitch * (1 - trail / depth) : 0;
  static bool vegetationAllowedAt(double distance) =>
      distance < 6050 || distance > 6820;

  /// Bounded steering load comes from the same authored curve as projection.
  static double steeringLoadAt(double s) => (curvatureAt(s) * 8).clamp(-.4, .4);
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
        far <= near) {
      return;
    }
    final first = math.max(0, ((near - origin) / spacing).ceil());
    final limit = math.min(far, end ?? far);
    for (var index = first; origin + index * spacing < limit; index++) {
      yield origin + index * spacing;
    }
  }
}
