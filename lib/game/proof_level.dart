import 'dart:math' as math;

import 'proof_course.dart';
import 'route.dart';

/// Illustrative review packs, not surveyed road corridors or final campaign art.
class ProofLevel {
  const ProofLevel(
    this.id,
    this.name,
    this.key,
    this.seed, {
    this.night = 0,
    this.sunset = 0,
    this.wet = 0,
    this.autumn = false,
    this.canopy = false,
    this.urban = false,
    this.treeFrame = 0,
    this.sceneryStride = 1,
    this.hills = 1,
    this.curves = 1,
    this.variation = 0,
    this.lampSpacing = 0,
    this.weather = RaceWeather.clear,
    this.ground = 0xff94b66d,
  });
  final String id, name, key;
  final int seed, treeFrame, sceneryStride, ground;
  final double night, sunset, wet, hills, curves, variation, lampSpacing;
  final bool autumn, canopy, urban;
  final RaceWeather weather;

  static const all = [
    ProofLevel(
      'hudson',
      'Hudson daylight',
      'Q',
      731,
      urban: true,
      canopy: true,
      lampSpacing: 90,
    ),
    ProofLevel(
      'indiana',
      'Indiana golden canopy',
      'W',
      811,
      autumn: true,
      canopy: true,
      sunset: .85,
      wet: .45,
      hills: .72,
      curves: .8,
      variation: 1,
      ground: 0xff9f8550,
    ),
    ProofLevel(
      'iowa',
      'Iowa prairie sunset',
      'E',
      923,
      sunset: 1,
      hills: .45,
      curves: .55,
      variation: 2,
      sceneryStride: 4,
      ground: 0xffb6a06a,
      lampSpacing: 180,
    ),
    ProofLevel(
      'ohio',
      'Ohio wooded night',
      'R',
      1041,
      night: 1,
      canopy: true,
      hills: .9,
      curves: .95,
      variation: 3,
      lampSpacing: 120,
      ground: 0xff678278,
    ),
    ProofLevel(
      'chicago',
      'Chicago rain after dark',
      'T',
      1163,
      night: 1,
      wet: 1,
      urban: true,
      hills: .35,
      curves: .7,
      variation: 4,
      lampSpacing: 38,
      weather: RaceWeather.rain,
      ground: 0xff687a7b,
    ),
    ProofLevel(
      'arizona',
      'Arizona desert dusk',
      'Y',
      1291,
      night: .22,
      sunset: .85,
      hills: 1.25,
      curves: 1.1,
      variation: 5,
      treeFrame: 2,
      sceneryStride: 3,
      ground: 0xffb39672,
    ),
  ];
  static ProofLevel fromId(String? id) =>
      all.firstWhere((level) => level.id == id, orElse: () => all.first);

  /// Wooded portions have a gentle entry/exit and respect clear structural spans.
  double canopyAt(double s) {
    if (!canopy || (s > 5450 && s < 6820) || (urban && s < 600)) return 0;
    if (s >= 5000 && s <= 5450) {
      return math.min((s - 5000) / 100, (5450 - s) / 100).clamp(0.0, 1.0);
    }
    final phase = (s + variation * 71) % 1800;
    if (phase < 400 || phase > 1450) return 0;
    final edge = math.min((phase - 400) / 180, (1450 - phase) / 180);
    return edge.clamp(0.0, 1.0);
  }
}

/// One source for controller demand and renderer elevation/center coordinates.
class ProofTerrain {
  ProofTerrain(this.level) {
    var heading = 0.0, center = 0.0;
    centers.add(0);
    for (var i = 1; i <= 2400; i++) {
      final curvature = curvatureAt((i - .5) * 5);
      center += heading * 5 + curvature * 12.5;
      heading += curvature * 5;
      centers.add(center);
    }
  }
  final ProofLevel level;
  final List<double> centers = [];
  double curvatureAt(double s) =>
      ProofCourse.curvatureAt(s) * level.curves +
      (level.variation == 0 || s < 420
          ? 0
          : math.sin((s - 420) / (310 + level.variation * 23)) *
                .003 *
                math.min(1, (s - 420) / 200));
  double centerAt(double s) {
    if (s <= 0) return 0;
    final index = (s / 5).floor().clamp(0, centers.length - 2);
    final fraction = (s / 5 - index).clamp(0.0, 1.0);
    return centers[index] + (centers[index + 1] - centers[index]) * fraction;
  }

  double elevationAt(double s) =>
      ProofCourse.elevationAt(s) * level.hills +
      (level.variation == 0
          ? 0
          : math.sin(s / (180 + level.variation * 41)) *
                math.sin(s / 850) *
                180 *
                level.hills);
  double gradeAt(double s, double scale) =>
      (elevationAt(s + 5) - elevationAt(s - 5)) / (10 * scale);
  double pitchAt(double s, double scale) =>
      ((elevationAt(s + 60) - elevationAt(s - 60)) / (120 * scale) * 1.8).clamp(
        -.24,
        .24,
      );
}
