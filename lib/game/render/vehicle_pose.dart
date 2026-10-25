import 'dart:math' as math;

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
    bool grounded = true,
  }) {
    if (recovering || (value.abs() > .9 && sustained > .5 && speed > 100)) {
      return VehiclePose(5, mirrored: value < 0);
    }
    if (value.abs() < .08) {
      // Existing slope cells exaggerate the viewpoint enough to read as a
      // wheelie. Grounded mode keeps the coherent rear pose and adds a small,
      // camera-relative cue through GroundedSlopePresentation instead.
      if (!grounded && grade > .045) return const VehiclePose(3);
      if (!grounded && grade < -.045) return const VehiclePose(4);
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

/// Camera-relative slope cues around a fixed tire-contact anchor. This is an
/// art-direction proxy, not wheel lift or a calibrated vehicle chassis.
///
/// The critically damped closed-form step follows the explained spring model in
/// Ryan Juckett's Damped Springs. Frequency and visual gain are local hypotheses.
class GroundedSlopePresentation {
  double relativePitch = 0;
  double _velocity = 0;
  int slopeBand = 0;

  /// Bounded fractional sprite-height change, under 2.4 percent at any grade.
  /// Apply about the tire contact point; the shadow stays on the ground plane.
  double get visualPitch =>
      .024 * (relativePitch * 5) / (1 + (relativePitch * 5).abs());

  void reset() {
    relativePitch = _velocity = 0;
    slopeBand = 0;
  }

  void update({
    required double grade,
    required double cameraPitch,
    required double dt,
    bool quiet = false,
  }) {
    if (quiet) {
      reset();
      return;
    }
    if (!grade.isFinite || !cameraPitch.isFinite || !dt.isFinite || dt <= 0) {
      return;
    }
    final target = (math.atan(grade) - cameraPitch).clamp(-.22, .22);
    const frequency = 14.0;
    final step = dt.clamp(0.0, .25);
    final displacement = relativePitch - target;
    final c = _velocity + frequency * displacement;
    final decay = math.exp(-frequency * step);
    relativePitch = target + (displacement + c * step) * decay;
    _velocity = (_velocity - frequency * c * step) * decay;

    // Hysteresis is diagnostic and available to future authored pose packs;
    // it never introduces a visible jump in the continuous grounded cue.
    if (slopeBand == 0) {
      if (relativePitch > .035) slopeBand = 1;
      if (relativePitch < -.035) slopeBand = -1;
    } else if (slopeBand > 0 && relativePitch < .020 ||
        slopeBand < 0 && relativePitch > -.020) {
      slopeBand = 0;
    }
  }
}
