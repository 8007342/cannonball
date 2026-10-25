import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';

import '../app/wheel_input.dart';

class WheelControl extends StatefulWidget {
  const WheelControl({
    super.key,
    required this.onSteer,
    required this.onBrake,
    required this.visible,
    this.travelSteering = false,
    this.appliedSteering,
    this.steeringReader,
  });
  final ValueChanged<double> onSteer;
  final ValueChanged<bool> onBrake;
  final bool visible;

  /// Opt-in comparison; keep the already refined angular behavior by default.
  final bool travelSteering;

  /// Applied simulation angle, including road-following correction.
  final double? appliedSteering;

  /// Read once per animation frame, independently of the slower text HUD.
  final ValueGetter<double>? steeringReader;
  @visibleForTesting
  static Future<bool> prepareRimArtwork() async =>
      await (_WheelControlState._skinLoad ??= _WheelControlState._loadSkin()) !=
      null;
  @override
  State<WheelControl> createState() => _WheelControlState();
}

class _WheelControlState extends State<WheelControl>
    with SingleTickerProviderStateMixin {
  late final Ticker _feedback;
  double? _displayedSteering;
  final Map<int, double> _angles = {};
  final Map<int, double> _turns = {};
  final Set<int> _brakes = {};
  final Set<int> _neutral = {};
  Timer? _brakeRelease;
  double _turn = 0;
  ui.Image? _skin;
  static Future<ui.Image?>? _skinLoad;
  static Future<ui.Image?> _loadSkin() async {
    try {
      final data = await rootBundle.load('assets/controls/leather-rim.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _feedback = createTicker((_) {
      final value = widget.steeringReader?.call();
      if (widget.visible && value != _displayedSteering) {
        setState(() => _displayedSteering = value);
      }
    });
    if (widget.steeringReader != null) _feedback.start();
    (_skinLoad ??= _loadSkin()).then((image) {
      if (mounted && image != null) setState(() => _skin = image);
    });
  }

  void _down(PointerDownEvent e, WheelGeometry g) {
    if (widget.visible && g.onRim(e.localPosition)) {
      _angles[e.pointer] = g.angle(e.localPosition);
      _turns[e.pointer] = _turn;
    } else if (widget.visible && g.inSteeringGuard(e.localPosition)) {
      _neutral.add(e.pointer);
    } else {
      _brakeRelease?.cancel();
      _brakes.add(e.pointer);
      widget.onBrake(true);
    }
  }

  void _move(PointerMoveEvent e, WheelGeometry g) {
    if (_neutral.contains(e.pointer) &&
        widget.visible &&
        g.onRim(e.localPosition)) {
      _neutral.remove(e.pointer);
      _angles[e.pointer] = g.angle(e.localPosition);
      _turns[e.pointer] = _turn;
      return;
    }
    final previous = _angles[e.pointer];
    if (previous == null) {
      return;
    }
    final next = g.angle(e.localPosition);
    _turns[e.pointer] =
        ((_turns[e.pointer] ?? 0) +
                g.steeringDelta(previous, next, travel: widget.travelSteering))
            .clamp(-1, 1);
    _angles[e.pointer] = next;
    setState(
      () => _turn = _turns.values.reduce((a, b) => a + b) / _turns.length,
    );
    widget.onSteer(_turn);
  }

  void _up(int pointer) {
    _neutral.remove(pointer);
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
    if (widget.steeringReader == null) {
      _feedback.stop();
      _displayedSteering = null;
    } else if (!_feedback.isActive) {
      _feedback.start();
    }
    if (oldWidget.visible && !widget.visible) {
      _neutral.clear();
      _angles.clear();
      _turns.clear();
      _turn = 0;
      // The session resets steering when switching input mode. Calling it
      // during this build would notify listeners reentrantly.
    }
  }

  @override
  void dispose() {
    _feedback.dispose();
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
          painter: _WheelPainter(
            g,
            widget.steeringReader?.call() ?? widget.appliedSteering ?? _turn,
            widget.visible,
            _skin,
          ),
          size: c.biggest,
        ),
      );
    },
  );
}

class _WheelPainter extends CustomPainter {
  _WheelPainter(this.geometry, this.turn, this.visible, this.skin);
  final ui.Image? skin;
  // The shader and decoded image share app lifetime. Disposing a short-lived
  // shader invalidates its image handle on the web renderer.
  static ui.Image? _shaderImage;
  static ui.ImageShader? _cachedShader;
  final WheelGeometry geometry;
  final double turn;
  final bool visible;
  @override
  void paint(Canvas c, Size size) {
    if (!visible) {
      return;
    }
    // Paint is intentionally much wider than the hit band. Keep the approved
    // opening fixed and let leather continue all the way offscreen.
    final opening = Path();
    const segments = 96;
    for (var i = 0; i <= segments; i++) {
      final angle = i / segments * math.pi * 2;
      final point =
          geometry.center +
          Offset(math.cos(angle), math.sin(angle)) *
              geometry.innerPaintRadius(angle);
      if (i == 0) {
        opening.moveTo(point.dx, point.dy);
      } else {
        opening.lineTo(point.dx, point.dy);
      }
    }
    opening.close();
    final leather = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addPath(opening, Offset.zero);
    c.save();
    c.clipRect(Offset.zero & size);
    c.drawPath(
      leather,
      Paint()
        ..shader = ui.Gradient.radial(
          geometry.center,
          geometry.outerPaintRadius,
          const [Color(0x25332a25), Color(0x9950473d), Color(0xc7191716)],
          const [0, .72, 1],
        ),
    );
    if (skin != null) _paintSkin(c, skin!);
    c.drawPath(
      opening,
      Paint()
        ..color = Colors.white.withValues(alpha: .17)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    c.restore();
  }

  void _paintSkin(Canvas canvas, ui.Image image) {
    const segments = 96;
    final positions = <Offset>[], textures = <Offset>[], indices = <int>[];
    final colors = <Color>[];
    final sourceCenter = Offset(image.width / 2, image.height / 2);
    // The original leather strip fills the exterior while its inner stitching
    // follows exactly the previous opening; input geometry is never expanded.
    for (var i = 0; i <= segments; i++) {
      final angle = i / segments * math.pi * 2;
      for (var edge = 0; edge < 2; edge++) {
        final radius = edge == 0
            ? geometry.innerPaintRadius(angle)
            : geometry.outerPaintRadius;
        positions.add(
          geometry.center + Offset(math.cos(angle), math.sin(angle)) * radius,
        );
        final sourceAngle = angle - turn * .85;
        final sourceRadius = image.width * (edge == 0 ? .397 : .488);
        textures.add(
          sourceCenter +
              Offset(math.cos(sourceAngle), math.sin(sourceAngle)) *
                  sourceRadius,
        );
        colors.add(Color(edge == 0 ? 0x77ffffff : 0xaaffffff));
      }
      if (i < segments) {
        final n = i * 2;
        indices.addAll([n, n + 1, n + 2, n + 1, n + 3, n + 2]);
      }
    }
    final vertices = ui.Vertices(
      ui.VertexMode.triangles,
      positions,
      textureCoordinates: textures,
      colors: colors,
      indices: indices,
    );
    if (_shaderImage != image) {
      _cachedShader = ui.ImageShader(
        image,
        ui.TileMode.clamp,
        ui.TileMode.clamp,
        Float64List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
      );
      _shaderImage = image;
    }
    canvas.drawVertices(
      vertices,
      ui.BlendMode.modulate,
      Paint()..shader = _cachedShader,
    );
    vertices.dispose();
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) =>
      old.skin != skin ||
      old.turn != turn ||
      old.visible != visible ||
      old.geometry.size != geometry.size;
}
