import 'dart:math' as math;

import '../proof_course.dart';

/// A bend with a flat curvature plateau and smoothstep entry/exit ramps.
/// Curvature uses ProofTerrain units (the controller's gentle/tight
/// hysteresis thresholds are .018/.026; hairpins exceed
/// [LevelProfile.cornerThreshold]).
class Bend {
  const Bend(this.start, this.end, this.curvature, {this.ramp = 50});
  final double start, end, curvature, ramp;

  double at(double s) {
    if (s <= start || s >= end) return 0;
    final r = math.min(ramp, (end - start) / 2);
    final t = math.min((s - start) / r, (end - s) / r).clamp(0.0, 1.0);
    return curvature * t * t * (3 - 2 * t);
  }
}

/// A sin² hump (positive) or dip (negative). Maximum slope is
/// `height * pi / (end - start)` elevation units per course unit.
class Hill {
  const Hill(this.start, this.end, this.height);
  final double start, end, height;

  double at(double s) {
    if (s <= start || s >= end) return 0;
    final wave = math.sin(math.pi * (s - start) / (end - start));
    return height * wave * wave;
  }
}

/// A smoothstep level change that persists after [end] (climbs/descents).
class Rise {
  const Rise(this.start, this.end, this.height);
  final double start, end, height;

  double at(double s) {
    final t = ((s - start) / (end - start)).clamp(0.0, 1.0);
    return height * t * t * (3 - 2 * t);
  }
}

/// Character tags are descriptive review metadata, not gameplay switches.
enum TerrainCharacter { baseline, rolling, calm, hairpins, city, mountain }

/// Per-level authored road geometry. Structural chapters (worksite
/// 4120-4920, canopy 5000-5450, bridge 5450-6050, tunnel 6050-6820) keep
/// their shared positions so chapter replay keys and cones stay valid; the
/// dramatic hairpins and crests live between them.
class LevelProfile {
  const LevelProfile({
    required this.id,
    required this.character,
    this.bends = const [],
    this.hills = const [],
    this.rises = const [],
    this.sections = const [],
    this.legacy = false,
  });
  final String id;
  final TerrainCharacter character;
  final List<Bend> bends;
  final List<Hill> hills;
  final List<Rise> rises;

  /// Upper bounds and labels for the level's own opening chapters.
  final List<(double, String)> sections;

  /// Hudson keeps the reviewed shared course exactly.
  final bool legacy;

  /// Curvature magnitude above which a bend adds centrifugal demand that the
  /// steering authority cannot hold at top speed. Every legacy bend is below.
  static const cornerThreshold = .1;

  /// Lateral demand (road half-widths per second at top speed) per curvature
  /// unit above the threshold. A .26 hairpin demands 3.0 while the S2000's full
  /// steering authority at top speed is 1.28 * 1.35 = 1.73, and 1.29 at 70%.
  static const cornerGain = 18.75;

  double curvatureAt(double s) {
    if (legacy) return ProofCourse.curvatureAt(s);
    var c = 0.0;
    for (final bend in bends) {
      c += bend.at(s);
    }
    return c;
  }

  double elevationAt(double s) {
    if (legacy) return ProofCourse.elevationAt(s);
    var h = 0.0;
    for (final hill in hills) {
      h += hill.at(s);
    }
    for (final rise in rises) {
      h += rise.at(s);
    }
    return h;
  }

  /// Signed extra lateral demand of a hairpin, zero for ordinary bends.
  double cornerDemandAt(double s) {
    final c = curvatureAt(s);
    final excess = c.abs() - cornerThreshold;
    return excess <= 0 ? 0 : excess * cornerGain * c.sign;
  }

  String sectionAt(double s) {
    for (final (limit, label) in sections) {
      if (s < limit) return label;
    }
    return ProofCourse.sectionAt(s);
  }

  static LevelProfile forId(String id) =>
      all.firstWhere((p) => p.id == id, orElse: () => all.first);

  static const all = [hudson, indiana, iowa, ohio, chicago, arizona];

  static const hudson = LevelProfile(
    id: 'hudson',
    character: TerrainCharacter.baseline,
    legacy: true,
  );

  /// Rolling farmland with frequent sweepers; one tight bend needs full lock.
  static const indiana = LevelProfile(
    id: 'indiana',
    character: TerrainCharacter.rolling,
    bends: [
      Bend(450, 700, .04, ramp: 80),
      Bend(800, 1050, -.06, ramp: 80),
      Bend(1150, 1400, .07, ramp: 80),
      Bend(1500, 1700, -.035, ramp: 70),
      Bend(1850, 2150, .05, ramp: 90),
      Bend(2300, 2500, -.08, ramp: 70),
      Bend(2600, 2800, .06, ramp: 70),
      Bend(3000, 3350, -.045, ramp: 100),
      Bend(3500, 3660, .15, ramp: 45),
      Bend(3800, 4000, -.05, ramp: 60),
      Bend(4150, 4900, .012, ramp: 150),
      Bend(5000, 5420, -.04, ramp: 100),
      Bend(6100, 6780, .015, ramp: 150),
      Bend(6900, 7150, .07, ramp: 70),
      Bend(7250, 7500, -.06, ramp: 70),
    ],
    hills: [
      Hill(100, 450, 600),
      Hill(500, 900, -900),
      Hill(950, 1400, 1500),
      Hill(1450, 1850, -1200),
      Hill(1900, 2350, 1600),
      Hill(2400, 2800, -1000),
      Hill(2850, 3300, 1400),
      Hill(3350, 3800, -1300),
      Hill(3850, 4150, 700),
      Hill(4250, 4700, -500),
      Hill(5000, 5400, 500),
      Hill(6850, 7250, 1200),
      Hill(7250, 7600, -900),
    ],
    sections: [
      (600, 'COUNTY LINE'),
      (2200, 'ROLLING SWEEPERS'),
      (3400, 'GOLDEN HILLS'),
      (4100, 'TIGHT LEFT-RIGHT'),
    ],
  );

  /// Calm prairie: long straights and long low swells.
  static const iowa = LevelProfile(
    id: 'iowa',
    character: TerrainCharacter.calm,
    bends: [
      Bend(1600, 2000, .012, ramp: 150),
      Bend(3400, 3800, -.014, ramp: 150),
      Bend(4300, 4800, .01, ramp: 200),
      Bend(5050, 5400, -.012, ramp: 120),
      Bend(6300, 6700, .01, ramp: 150),
      Bend(7100, 7500, -.012, ramp: 150),
    ],
    hills: [
      Hill(0, 900, 500),
      Hill(1000, 2200, -700),
      Hill(2300, 3500, 900),
      Hill(3600, 4800, -600),
      Hill(6850, 7600, 700),
    ],
    sections: [
      (1600, 'LONG STRAIGHT'),
      (3400, 'PRAIRIE SWELLS'),
      (4100, 'SECTION ROADS'),
    ],
  );

  /// Wooded hill country: hairpin pairs, blind crests, a switchback climb.
  static const ohio = LevelProfile(
    id: 'ohio',
    character: TerrainCharacter.hairpins,
    bends: [
      Bend(420, 620, .03, ramp: 60),
      Bend(680, 880, -.05, ramp: 60),
      Bend(1000, 1160, .26, ramp: 35),
      Bend(1240, 1400, -.25, ramp: 35),
      Bend(1500, 1700, .04, ramp: 60),
      Bend(1960, 2110, -.22, ramp: 35),
      Bend(2200, 2380, .07, ramp: 50),
      Bend(2560, 2720, .28, ramp: 35),
      Bend(2820, 2980, -.27, ramp: 35),
      Bend(3150, 3300, .12, ramp: 40),
      Bend(3420, 3560, -.24, ramp: 35),
      Bend(3700, 3880, .06, ramp: 50),
      Bend(4150, 4900, -.015, ramp: 150),
      Bend(5000, 5420, .035, ramp: 100),
      Bend(6100, 6780, .018, ramp: 150),
      Bend(6900, 7060, -.26, ramp: 35),
      Bend(7180, 7340, .24, ramp: 35),
      Bend(7700, 9000, .02, ramp: 200),
    ],
    hills: [
      Hill(150, 500, 900),
      Hill(520, 900, -1100),
      Hill(1660, 2040, 2500),
      Hill(2950, 3250, 1800),
      Hill(4200, 4700, 500),
      Hill(6850, 7150, -1200),
      Hill(7250, 7600, 1800),
    ],
    rises: [Rise(2350, 2900, 5500), Rise(3250, 3900, -5500)],
    sections: [
      (950, 'WOODED ROLL'),
      (1500, 'HAIRPIN PAIR'),
      (2150, 'BLIND CREST'),
      (3050, 'SWITCHBACK CLIMB'),
      (4100, 'DESCENT HAIRPIN'),
    ],
  );

  /// Flat grid with short sharp city corners; light braking in the rain.
  static const chicago = LevelProfile(
    id: 'chicago',
    character: TerrainCharacter.city,
    bends: [
      Bend(600, 700, .18, ramp: 25),
      Bend(1100, 1200, -.17, ramp: 25),
      Bend(1700, 1800, .2, ramp: 25),
      Bend(2400, 2500, -.15, ramp: 25),
      Bend(3000, 3120, .19, ramp: 25),
      Bend(3600, 3700, -.18, ramp: 25),
      Bend(4150, 4900, -.012, ramp: 150),
      Bend(5000, 5420, .02, ramp: 100),
      Bend(6100, 6780, .012, ramp: 150),
      Bend(7000, 7100, .18, ramp: 25),
      Bend(7350, 7450, -.16, ramp: 25),
    ],
    hills: [
      Hill(1300, 1600, 250),
      Hill(2700, 3000, -200),
      Hill(4300, 4600, 200),
      Hill(6900, 7200, 300),
    ],
    sections: [(4100, 'CITY GRID')],
  );

  /// Desert pass: switchbacks on a long climb, a blind summit, a hairpin at
  /// the foot of a fast descent and a final switchback pair.
  static const arizona = LevelProfile(
    id: 'arizona',
    character: TerrainCharacter.mountain,
    bends: [
      Bend(700, 900, .045, ramp: 60),
      Bend(1080, 1230, .27, ramp: 35),
      Bend(1330, 1480, -.28, ramp: 35),
      Bend(1580, 1720, .2, ramp: 35),
      Bend(2160, 2310, -.3, ramp: 35),
      Bend(2450, 2600, .14, ramp: 40),
      Bend(3330, 3480, .26, ramp: 35),
      Bend(3620, 3800, -.08, ramp: 50),
      Bend(3900, 4060, .05, ramp: 50),
      Bend(4150, 4900, .015, ramp: 150),
      Bend(5000, 5420, -.03, ramp: 100),
      Bend(6100, 6780, -.018, ramp: 150),
      Bend(6900, 7050, .27, ramp: 35),
      Bend(7150, 7300, -.27, ramp: 35),
      Bend(7420, 7560, .2, ramp: 35),
    ],
    hills: [
      Hill(200, 600, 700),
      Hill(1850, 2230, 2600),
      Hill(3900, 4200, -600),
      Hill(4400, 4800, 400),
    ],
    rises: [
      Rise(1000, 1750, 7000),
      Rise(2700, 3300, -7000),
      Rise(6850, 7450, 5000),
    ],
    sections: [
      (1000, 'DESERT STRAIGHT'),
      (1800, 'SWITCHBACK CLIMB'),
      (2400, 'BLIND SUMMIT'),
      (3300, 'FAST DESCENT'),
      (4100, 'CANYON HAIRPIN'),
    ],
  );
}
