import 'dart:math' as math;

/// A bounded main-bend cue, using the GPU Gems/Ranitas separation of motion by
/// scale. Ground pivots stay fixed; separated painted leaf detail is deferred.
class ProofFoliage {
  static double angle({
    required double time,
    required double position,
    required double depth,
    bool quiet = false,
  }) {
    if (quiet) return 0;
    final phase = position * .0017;
    final gust = .5 + .5 * math.sin(time * .43 - position * .00018);
    final near = (1 - depth / 18000).clamp(0.0, 1.0);
    return (.004 + .008 * gust) * math.sin(time * 1.8 + phase) * near;
  }
}
