import 'dart:math' as math;

/// Authoritative construction props shared by collision and presentation.
class ProofCone {
  const ProofCone({
    required this.id,
    required this.courseDistance,
    required this.lateral,
    this.width = 52,
  });
  final int id;
  final double courseDistance, lateral, width;
}

/// A short bounded cosmetic flight, never a second collidable obstacle.
class ConeFlight {
  ConeFlight({
    required this.cone,
    required this.lateralVelocity,
    required this.forwardVelocity,
  });
  final ProofCone cone;
  final double lateralVelocity, forwardVelocity;
  double age = 0;
  static const lifetime = 1.2;
}

/// Swept small-body contacts with a short opportunity to finish an evasive move.
/// This is arcade forgiveness, not a rigid-body response or calibrated car model.
class ProofCollisionGate {
  static const graceSeconds = .05;
  final Map<int, double> _contactSeconds = {};

  void clear() => _contactSeconds.clear();
  void retain(Set<int> ids) =>
      _contactSeconds.removeWhere((id, _) => !ids.contains(id));

  /// Fractional part of the step within both lateral and forward slabs.
  static (double, double)? overlapInterval({
    required double fromForward,
    required double toForward,
    required double fromLateral,
    required double toLateral,
    required double halfDepth,
    required double halfWidth,
  }) {
    var enter = 0.0, exit = 1.0;
    for (final axis in [
      (fromForward, toForward, halfDepth),
      (fromLateral, toLateral, halfWidth),
    ]) {
      final delta = axis.$2 - axis.$1;
      if (delta.abs() < 1e-10) {
        if (axis.$1.abs() >= axis.$3) return null;
      } else {
        final a = (-axis.$3 - axis.$1) / delta;
        final b = (axis.$3 - axis.$1) / delta;
        enter = math.max(enter, math.min(a, b));
        exit = math.min(exit, math.max(a, b));
        if (exit <= enter) return null;
      }
    }
    return (enter, exit);
  }

  bool update({
    required int id,
    required double dt,
    required double fromForward,
    required double toForward,
    required double fromLateral,
    required double toLateral,
    required double halfDepth,
    required double halfWidth,
  }) {
    final interval = overlapInterval(
      fromForward: fromForward,
      toForward: toForward,
      fromLateral: fromLateral,
      toLateral: toLateral,
      halfDepth: halfDepth,
      halfWidth: halfWidth,
    );
    if (interval == null) {
      _contactSeconds.remove(id);
      return false;
    }
    final previous = interval.$1 > 1e-8 ? 0.0 : (_contactSeconds[id] ?? 0);
    final seconds = previous + (interval.$2 - interval.$1) * dt;
    if (interval.$2 < 1 - 1e-8) {
      _contactSeconds.remove(id);
    } else {
      _contactSeconds[id] = seconds;
    }
    // At very high closing speeds, 50ms can span the entire projected car.
    // Keep time to correct a graze, but commit a full rear impact by its center
    // crossing rather than after both sprites have already passed through.
    final closingPerStep = (toForward - fromForward).abs();
    final grace = closingPerStep < 1e-10
        ? graceSeconds
        : math.min(graceSeconds, halfDepth * dt / closingPerStep);
    return seconds + 1e-9 >= grace;
  }
}
