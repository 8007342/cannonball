import 'dart:async';

import 'package:flutter/material.dart';

import '../app/wheel_input.dart';

class WheelControl extends StatefulWidget {
  const WheelControl({
    super.key,
    required this.onSteer,
    required this.onBrake,
    required this.visible,
  });
  final ValueChanged<double> onSteer;
  final ValueChanged<bool> onBrake;
  final bool visible;
  @override
  State<WheelControl> createState() => _WheelControlState();
}

class _WheelControlState extends State<WheelControl> {
  final Map<int, double> _angles = {};
  final Map<int, double> _turns = {};
  final Set<int> _brakes = {};
  Timer? _brakeRelease;
  double _turn = 0;
  void _down(PointerDownEvent e, WheelGeometry g) {
    if (widget.visible && g.onRim(e.localPosition)) {
      _angles[e.pointer] = g.angle(e.localPosition);
      _turns[e.pointer] = _turn;
    } else {
      _brakeRelease?.cancel();
      _brakes.add(e.pointer);
      widget.onBrake(true);
    }
  }

  void _move(PointerMoveEvent e, WheelGeometry g) {
    final previous = _angles[e.pointer];
    if (previous == null) {
      return;
    }
    final next = g.angle(e.localPosition);
    _turns[e.pointer] =
        ((_turns[e.pointer] ?? 0) +
                WheelGeometry.angleDelta(previous, next) / .85)
            .clamp(-1, 1);
    _angles[e.pointer] = next;
    setState(
      () => _turn = _turns.values.reduce((a, b) => a + b) / _turns.length,
    );
    widget.onSteer(_turn);
  }

  void _up(int pointer) {
    final wasSteering = _angles.remove(pointer) != null;
    if (wasSteering) {
      _turns.remove(pointer);
      if (_turns.isEmpty) {
        setState(() => _turn = 0);
        widget.onSteer(0);
      } else {
        // Rebase remaining fingers on the current wheel position. Lifting one
        // finger must not jump to another finger's old accumulated angle.
        for (final id in _turns.keys.toList()) {
          _turns[id] = _turn;
        }
      }
    }
    final wasBraking = _brakes.remove(pointer);
    if (wasBraking && _brakes.isEmpty) {
      _brakeRelease?.cancel();
      _brakeRelease = Timer(const Duration(milliseconds: 140), () {
        if (mounted) {
          widget.onBrake(false);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant WheelControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible && !widget.visible) {
      _angles.clear();
      _turns.clear();
      _turn = 0;
      // The session resets steering when switching input mode. Calling it
      // during this build would notify listeners reentrantly.
    }
  }

  @override
  void dispose() {
    _brakeRelease?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final g = WheelGeometry(c.biggest);
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) => _down(e, g),
        onPointerMove: (e) => _move(e, g),
        onPointerUp: (e) => _up(e.pointer),
        onPointerCancel: (e) => _up(e.pointer),
        child: CustomPaint(
          painter: _WheelPainter(g, _turn, widget.visible),
          size: c.biggest,
        ),
      );
    },
  );
}

class _WheelPainter extends CustomPainter {
  _WheelPainter(this.geometry, this.turn, this.visible);
  final WheelGeometry geometry;
  final double turn;
  final bool visible;
  @override
  void paint(Canvas c, Size size) {
    if (!visible) {
      return;
    }
    c.drawCircle(
      geometry.center,
      geometry.radius,
      Paint()
        ..color = Colors.black.withValues(alpha: .20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 23,
    );
    c.drawCircle(
      geometry.center,
      geometry.radius,
      Paint()
        ..color = Colors.white.withValues(alpha: .22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13,
    );
    c.drawCircle(
      geometry.center,
      geometry.radius - 7,
      Paint()
        ..color = Colors.white.withValues(alpha: .13)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) =>
      old.turn != turn ||
      old.visible != visible ||
      old.geometry.size != geometry.size;
}
