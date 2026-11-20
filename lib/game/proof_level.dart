import 'dart:math' as math;

import 'proof_course.dart';
import 'route.dart';
import 'terrain/level_profiles.dart';

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

  /// `hills`/`curves` describe the level's relative character for review
  /// metadata; geometry now comes from its own `LevelProfile`.
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
/// Each level owns its authored profile (see [LevelProfile]); Hudson keeps
/// the reviewed shared course exactly.
class ProofTerrain {
  ProofTerrain(this.level) : profile = LevelProfile.forId(level.id) {
    var heading = 0.0, center = 0.0;
    centers.add(0);
    for (var i = 1; i <= 2400; i++) {
      final curvature =
          visualCurvature(curvatureAt((i - .5) * 5)) * ProofCourse.lateralScale;
      center += heading * 5 + curvature * 12.5;
      heading += curvature * 5;
      centers.add(center);
    }
  }
  final ProofLevel level;
  final LevelProfile profile;
  final List<double> centers = [];
  double curvatureAt(double s) => profile.curvatureAt(s);

  /// Drawn hairpins bend harder than their metric curvature: a faithful
  /// projection of a 140 m bend shifts the road only ~60-90 px by the time
  /// it reaches the horizon, so hairpins read as gentle sweepers. The part
  /// above [LevelProfile.cornerThreshold] is amplified; ordinary bends (and
  /// the whole legacy Hudson course) are unchanged. Render-only: the
  /// controller's demand still uses [curvatureAt].
  static const hairpinVisualGain = 2.2;
  static double visualCurvature(double c) {
    final excess = c.abs() - LevelProfile.cornerThreshold;
    return excess <= 0 ? c : c + excess * hairpinVisualGain * c.sign;
  }

  /// Render-space road centre (lateral world units), from [visualCurvature].
  double centerAt(double s) {
    if (s <= 0) return 0;
    final index = (s / 5).floor().clamp(0, centers.length - 2);
    final fraction = (s / 5 - index).clamp(0.0, 1.0);
    return centers[index] + (centers[index + 1] - centers[index]) * fraction;
  }

  /// Simulation elevation (controller grade and speed). Never exaggerated.
  double elevationAt(double s) => profile.elevationAt(s);

  /// 0..1 share of the level's [LevelProfile.relief] the renderer applies.
  /// Comfort mode lowers it so crests and dips stay readable but gentler.
  double reliefScale = 1;

  /// Render-space elevation: the road, ground, scenery, traffic, lights and
  /// the camera all use this so everything stays grounded on the slope.
  double visualElevationAt(double s) =>
      profile.visualElevationAt(s, reliefScale);

  /// Extra centrifugal demand of hairpins (half-widths/s at top speed).
  double cornerDemandAt(double s) => profile.cornerDemandAt(s);
  String sectionAt(double s) => profile.sectionAt(s);

  /// Render-space grade (visual elevation) for the grounded car pose.
  double gradeAt(double s, double scale) =>
      (visualElevationAt(s + 5) - visualElevationAt(s - 5)) / (10 * scale);

  /// Camera pitch follows the render-space grade through a soft limit, so a
  /// steep exaggerated climb never saturates into a hard snap at a crest.
  /// It follows less than the road rises, which leaves crests, walls and
  /// valleys visible instead of levelling them out.
  static const maxPitch = .26, pitchFollow = 1.1;
  double pitchAt(double s, double scale) {
    if (!scale.isFinite || scale <= 0) return 0;
    final grade =
        (visualElevationAt(s + 60) - visualElevationAt(s - 60)) / (120 * scale);
    // Unexaggerated levels (Hudson's reviewed baseline, flat Chicago) keep
    // the original linear follow and clamp exactly.
    if (profile.relief == 1 && profile.riseRelief == 1) {
      return (grade * 1.8).clamp(-.24, .24);
    }
    final x = grade * pitchFollow / maxPitch;
    if (!x.isFinite) return 0;
    // tanh without dart:math's missing helper.
    final e = math.exp(-2 * x.abs().clamp(0.0, 20.0));
    return maxPitch * x.sign * (1 - e) / (1 + e);
  }
}
