import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Input geometry stays independent of the outward-filled painted rim.
class WheelGeometry {
  WheelGeometry(this.size);
  final Size size;
  Offset get center => Offset(size.width / 2, size.height / 2);
  double get strokeWidth => (size.height * .11).clamp(40.0, 52.0);
  double get inset => strokeWidth * 1.25;
  double get radius => math.max(size.height * .56, size.width / 2 - inset);
  double get touchHalfWidth => math.max(64.0, strokeWidth / 2 + 42);
  static const guardWidth = 32.0;

  /// Preserve the previous leather rim's inner edge, including its slight grip.
  /// Increasing paint coverage never moves this opening or any input target.
  double innerPaintRadius(double angle) {
    final grip = math.pow(math.cos(angle).abs(), 18).toDouble();
    return radius - strokeWidth * (.5 + grip * .04);
  }

  /// Enclose every viewport corner so the rim has no visible outer edge.
  double get outerPaintRadius => size.center(Offset.zero).distance + 2;

  /// The optional travel comparison uses a 160 logical-pixel tangential stroke
  /// to full steering. This is a playtest hypothesis, not a physical thumb size.
  double steeringDelta(double from, double to, {bool travel = false}) =>
      angleDelta(from, to) * (travel ? radius / 160 : 1 / .85);
  bool onRim(Offset point) =>
      ((point - center).distance - radius).abs() <= touchHalfWidth;
  bool inSteeringGuard(Offset point) {
    final edge = inset + touchHalfWidth + guardWidth;
    return ((point - center).distance - radius).abs() <=
            touchHalfWidth + guardWidth ||
        point.dx <= edge ||
        point.dx >= size.width - edge;
  }

  double angle(Offset point) =>
      math.atan2(point.dy - center.dy, point.dx - center.dx);
  static double angleDelta(double from, double to) {
    var delta = to - from;
    while (delta > math.pi) {
      delta -= math.pi * 2;
    }
    while (delta < -math.pi) {
      delta += math.pi * 2;
    }
    return delta;
  }
}
