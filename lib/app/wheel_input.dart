import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// A transparent-center wheel with full-height, inset thumb-sized side arcs.
class WheelGeometry {
  WheelGeometry(this.size);
  final Size size;
  Offset get center => Offset(size.width / 2, size.height / 2);
  double get strokeWidth => (size.height * .11).clamp(40.0, 52.0);
  double get inset => strokeWidth * 1.25;
  double get radius => math.max(size.height * .56, size.width / 2 - inset);
  double get touchHalfWidth => math.max(64.0, strokeWidth / 2 + 42);
  static const guardWidth = 32.0;
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
