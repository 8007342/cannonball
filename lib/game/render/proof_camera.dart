import 'dart:math' as math;

/// Proof camera composition and distance camouflage. All values are authored
/// arcade hypotheses; none are a measured OutRun lens or universal optimum.
class ProofCamera {
  static const playerGround = .876;
  static double horizon(String preset) => switch (preset) {
    'baseline' => .30,
    'wide' => .48,
    _ => 2 / 3,
  };

  /// Move the camera down when lowering the horizon, preserving car size and
  /// screen contact rather than pushing the car out of frame.
  static double height(
    String preset,
    double projection, {
    double ground = playerGround,
  }) => (ground - horizon(preset)) * 560 / (projection * .70);

  /// A low camera has less vertical preview room. Compress only camera pitch;
  /// actual terrain still uses the shared elevation profile and occlusion.
  static double pitch(double gradePitch, String preset) =>
      gradePitch * (preset == 'flow' ? .48 : .70);

  static double distanceOpacity(double depth, double far) {
    final t = ((far - depth) / (far * .24)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  /// Quantized opacity preserves large depth-ordered atlas batches.
  static int opacityByte(double depth, double far) =>
      (distanceOpacity(depth, far) * 8).round() * 255 ~/ 8;
}

/// Composition response moves the entire projected world, never just the car art.
class ProofChaseResponse {
  double ground = .925, lateralLook = 0;
  void reset() {
    ground = .925;
    lateralLook = 0;
  }

  void update({
    required double speedRatio,
    required double steering,
    required bool braking,
    required bool recovering,
    required bool stable,
    required double dt,
  }) {
    if (stable) {
      ground = ProofCamera.playerGround;
      lateralLook = 0;
      return;
    }
    final speed = speedRatio.clamp(0.0, 1.0);
    final targetGround = stable
        ? ProofCamera.playerGround
        : (.925 -
                  .077 * speed * speed +
                  (braking ? .018 * speed : 0) +
                  (recovering ? .025 : 0))
              .clamp(.838, .93);
    final targetLook = stable ? 0.0 : steering.clamp(-1.0, 1.0) * speed * .018;
    final blend = 1 - math.exp(-5 * dt.clamp(0.0, .25));
    ground += (targetGround - ground) * blend;
    lateralLook += (targetLook - lateralLook) * blend;
  }
}

/// Road heading is sampled only from road geometry. Camera look translation
/// must never enter the derivative or it becomes a steering-driven yaw.
class ProofRoadFrame {
  ProofRoadFrame({
    required double roadCenter,
    required double roadAhead,
    required double lookOffset,
    double sampleDistance = 20,
  }) : origin = roadCenter + lookOffset,
       heading = (roadAhead - roadCenter) / sampleDistance;
  final double origin, heading;
  double lateralOffset(double worldX, double depth) =>
      worldX - origin - heading * depth;
}
