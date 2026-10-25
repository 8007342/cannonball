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
  static double height(String preset, double projection) =>
      (playerGround - horizon(preset)) * 560 / (projection * .70);

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
