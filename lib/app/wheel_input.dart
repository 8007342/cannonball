import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// A full oversized circle centered on the viewport. Side arcs are cropped.
class WheelGeometry {
  WheelGeometry(this.size);
  final Size size;
  Offset get center => Offset(size.width / 2, size.height / 2);
  double get radius =>
      math.sqrt(size.width * size.width / 4 + size.height * size.height * .12);
  bool onRim(Offset point) => ((point - center).distance - radius).abs() < 42;
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
