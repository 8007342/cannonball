import 'dart:math' as math;

import 'scenic_manifest.dart';

/// Metric mapping for scenery. The road's 1100-unit half-width is a
/// 5.5 m half carriageway, so lateral presentation units are 200 per metre.
/// One course unit is about .86 m (155 mph = 80.6 course units/s); at the
/// default velocity flow (168 world units per course unit) forward world
/// units are ~195 per metre, matching the lateral scale.
class ScenicScale {
  static const roadHalfWidthUnits = 1100.0;
  static const roadHalfWidthM = 5.5;
  static const unitsPerMetre = roadHalfWidthUnits / roadHalfWidthM;
  static const metresPerCourseUnit = .86;

  /// Signed lateral position in road half-widths for an offset from the edge.
  static double lateral(double offsetM, int side) =>
      side * (1 + offsetM / roadHalfWidthM);

  static double widthUnits(double worldWidthM) => worldWidthM * unitsPerMetre;

  static double courseUnits(double metres) => metres / metresPerCourseUnit;

  /// Offset range from the road edge, metres.
  static (double, double) range(ScenicBand band) => switch (band) {
    ScenicBand.near => (.6, 6),
    ScenicBand.mid => (6, 60),
    ScenicBand.far => (60, 600),
    ScenicBand.vista => (600, 20000),
  };

  /// How far ahead (course units) each band streams. Near/mid ride the road
  /// mesh; far objects appear long before the mesh reaches them.
  static double ahead(ScenicBand band, double meshAheadCourse) =>
      switch (band) {
        ScenicBand.near || ScenicBand.mid => meshAheadCourse,
        ScenicBand.far => math.max(meshAheadCourse, farAheadCourse),
        ScenicBand.vista => double.infinity,
      };
  static const farAheadCourse = 1500.0;

  /// Artistic size boost for far-band sprites only. Positions (and so the
  /// parallax rate) stay metric; a 17 m barn 300 m out would otherwise be
  /// a few pixels on a phone through the wide proof lens.
  static const farSizeBoost = 1.7;

  /// Far objects use reduced peak opacity so they read as atmospheric depth.
  static double peakOpacity(ScenicBand band) => switch (band) {
    ScenicBand.far => .9,
    ScenicBand.vista => .8,
    _ => 1,
  };
}

/// Pinhole parallax shared by the renderer's projection: a point at lateral
/// `x` units and forward depth `z` world units lands `projection * x / z`
/// half-screens from the vanishing point. Its screen velocity while the
/// camera advances at `speed` world units/s is `offset * speed / z`, so at
/// the same screen position a far object moves `zNear / zFar` as fast.
class ScenicParallax {
  static double screenOffset(
    double lateralUnits,
    double depth,
    double projection,
    double halfScreen,
  ) => depth <= 0
      ? double.infinity
      : projection * lateralUnits / depth * halfScreen;

  static double screenVelocity(
    double lateralUnits,
    double depth,
    double speed,
    double projection,
    double halfScreen,
  ) => depth <= 0
      ? double.infinity
      : projection * lateralUnits * speed / (depth * depth) * halfScreen;

  /// Horizon-layer offset for an infinitely distant layer: the camera looks
  /// along the road, so the layer shifts opposite the absolute road heading.
  static double vistaOffset(
    double heading,
    double projection,
    double halfScreen,
  ) => -projection * heading * halfScreen;
}
