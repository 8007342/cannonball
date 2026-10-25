import 'dart:math' as math;

/// Arcade test tuning, not a calibrated vehicle powertrain. Units are mph/s.
class ProofDynamics {
  static double acceleration({
    required double speed,
    required double topSpeed,
    required double engineAcceleration,
    required double steering,
    required double steeringRate,
    required double grade,
  }) {
    final ratio = (speed / topSpeed).clamp(0.0, 1.0);
    final thrust =
        engineAcceleration * .28 * math.max(.045, 1 - math.pow(ratio, 2.2));
    final scrub =
        math.pow(math.max(0, steering.abs() - .15), 2) * 19 * ratio * ratio;
    final correction = math.min(steeringRate.abs(), 6) * .45 * ratio * ratio;
    return thrust - scrub - correction - grade.clamp(-.25, .25) * 12;
  }
}
