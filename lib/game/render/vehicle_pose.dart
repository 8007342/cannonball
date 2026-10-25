/// Sprite choice is independent of the sprite sheet and camera. A skid has a
/// direction: sharing one unmirrored frame for both signs hides right steering.
class VehiclePose {
  const VehiclePose(
    this.frame, {
    this.mirrored = false,
    this.turnSheet = false,
  });
  final int frame;
  final bool mirrored, turnSheet;

  static VehiclePose select({
    required double steering,
    required double speed,
    required double grade,
    bool recovering = false,
  }) {
    if (recovering || (steering.abs() > .87 && speed > 100)) {
      return VehiclePose(5, mirrored: steering < 0);
    }
    if (steering < -.16) return const VehiclePose(1);
    if (steering > .16) return const VehiclePose(2);
    if (grade > .075) return const VehiclePose(3);
    if (grade < -.075) return const VehiclePose(4);
    return const VehiclePose(0);
  }
}

/// Frame-rate-independent visible steering progression. It begins responding
/// immediately, distinguishes held gentle demand, and requires sustained load
/// before presenting a skid. These timings are hypotheses for human playtests.
class SteeringPresentation {
  double value = 0, sustained = 0;
  void reset() {
    value = 0;
    sustained = 0;
  }

  void update(double target, double dt) {
    if (!dt.isFinite || dt <= 0) return;
    target = target.isFinite ? target.clamp(-1.0, 1.0) : 0;
    final step = dt.clamp(0.0, .25);
    final rate = target == 0 ? 11.0 : 5.0;
    final previous = value;
    value += (target - value).clamp(-rate * step, rate * step);
    if (target.abs() > .86 && previous * target >= 0) {
      sustained += step;
    } else {
      sustained = 0;
    }
  }

  VehiclePose pose({
    required double speed,
    required double grade,
    bool recovering = false,
  }) {
    if (recovering || (value.abs() > .9 && sustained > .5 && speed > 100)) {
      return VehiclePose(5, mirrored: value < 0);
    }
    if (value.abs() < .08) {
      if (grade > .045) return const VehiclePose(3);
      if (grade < -.045) return const VehiclePose(4);
      return const VehiclePose(0);
    }
    final strength = value.abs() < .42
        ? 0
        : value.abs() < .78
        ? 1
        : 2;
    return VehiclePose(strength * 2 + (value > 0 ? 1 : 0), turnSheet: true);
  }
}
