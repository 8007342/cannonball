import 'dart:math' as math;

/// Tiny sprung sprite cues, not a calibrated chassis or independently rigged wheels.
class ProofSuspension {
  double roll = 0, pitch = 0, heave = 0;
  double _rollVelocity = 0, _pitchVelocity = 0, _heaveVelocity = 0;
  void reset() {
    roll = pitch = heave = 0;
    _rollVelocity = _pitchVelocity = _heaveVelocity = 0;
  }

  void update({
    required double speedRatio,
    required double acceleration,
    required double steering,
    required double gradeRate,
    required bool quiet,
    required double dt,
    bool impact = false,
  }) {
    if (quiet) {
      reset();
      return;
    }
    if (!dt.isFinite || dt <= 0) return;
    if (impact) _heaveVelocity = (_heaveVelocity + 5).clamp(-12, 12);
    final speed = speedRatio.clamp(0.0, 1.0);
    final load = (acceleration / 12).clamp(-1.0, 1.0);
    final targetRoll = -steering.clamp(-1.0, 1.0) * speed * speed * .022;
    final targetPitch = load * .018;
    final targetHeave = (load * .7 + gradeRate * 2).clamp(-1.5, 1.5);
    var remaining = dt.clamp(0.0, .25);
    while (remaining > 1e-9) {
      final step = math.min(remaining, 1 / 120);
      _rollVelocity += (190 * (targetRoll - roll) - 20 * _rollVelocity) * step;
      _pitchVelocity +=
          (150 * (targetPitch - pitch) - 18 * _pitchVelocity) * step;
      _heaveVelocity +=
          (180 * (targetHeave - heave) - 17 * _heaveVelocity) * step;
      roll += _rollVelocity * step;
      pitch += _pitchVelocity * step;
      heave += _heaveVelocity * step;
      remaining -= step;
    }
    roll = roll.clamp(-.03, .03);
    pitch = pitch.clamp(-.025, .025);
    heave = heave.clamp(-2.5, 2.5);
  }
}
