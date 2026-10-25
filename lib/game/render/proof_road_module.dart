import 'dart:math' as math;

/// A short NPC-only joining lane, sampled in the same road coordinate system as
/// the main ribbon. This is geometry, not a selectable route-graph connection.
class ProofJoiningLane {
  static const period = 36000.0, start = 2400.0, length = 5600.0;
  static double progress(double z) => ((z % period) - start) / length;
  static bool visible(double z) => progress(z) >= 0 && progress(z) <= 1;

  /// Includes the gore between the main road and joining pavement. Padding is
  /// the sprite's half footprint, not just its trunk/anchor point.
  static bool overlapsScenery(double z, double lateral, double halfFootprint) {
    if (!visible(z)) return false;
    return lateral + halfFootprint >= .95 &&
        lateral - halfFootprint <= center(z) + halfWidth(z) + .2;
  }

  static double center(double z) {
    final t = progress(z).clamp(0.0, 1.0);
    final smooth = t * t * (3 - 2 * t);
    return 2.6 - smooth * 1.85;
  }

  static double halfWidth(double z) {
    final t = progress(z).clamp(0.0, 1.0);
    return .34 * math.min(1.0, (1 - t) * 5);
  }
}
