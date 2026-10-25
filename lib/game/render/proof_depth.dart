import 'dart:math' as math;

/// Keep near-road detail while extending preview as optical flow increases.
/// The fixed mesh count bounds submission work; terrain may still hide traffic.
class ProofDepth {
  static const segments = 180;
  static const nearStep = 170.0;
  static const previewDistance = 330.0;
  static double far(double flowScale) =>
      math.max(nearStep * segments, previewDistance * flowScale + 900);

  static double sample(int index, double flowScale) {
    final i = index.clamp(0, segments + 1);
    final fraction = i / segments;
    final extension = far(flowScale) - nearStep * segments;
    return nearStep * i + extension * fraction * fraction;
  }

  static double preview(double flowScale) =>
      (sample(segments - 2, flowScale) - 560) / flowScale;

  /// Clip fixed world-space dashes to a mesh strip. Changing tessellation must
  /// never change stripe length or move a stripe with the camera.
  static Iterable<(double, double)> dashes(double from, double to) sync* {
    const period = 850.0, length = 510.0;
    for (var i = (from / period).floor(); i * period < to; i++) {
      final start = math.max(from, i * period);
      final end = math.min(to, i * period + length);
      if (end > start) yield (start, end);
    }
  }
}
