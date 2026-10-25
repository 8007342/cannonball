import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/race.dart';

const gold = Color(0xFFEFC781);
const ink = Color(0xFF101A22);
const mutedInk = Color(0xFF9EACAA);

class GarageWood extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF352A24), Color(0xFF171A1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Offset.zero & size),
    );
    final random = math.Random(137);
    for (var plank = 0; plank < 9; plank++) {
      final y = size.height * plank / 8;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y + 5),
        Paint()
          ..color = Colors.black.withValues(alpha: .24)
          ..strokeWidth = 3,
      );
      for (var i = 0; i < 14; i++) {
        final gy = y + random.nextDouble() * size.height / 8;
        final path = Path()
          ..moveTo(0, gy)
          ..cubicTo(
            size.width * .3,
            gy - 9,
            size.width * .6,
            gy + 9,
            size.width,
            gy - 3,
          );
        canvas.drawPath(
          path,
          Paint()
            ..color = gold.withValues(alpha: .025 + random.nextDouble() * .025)
            ..style = PaintingStyle.stroke,
        );
      }
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.transparent, Colors.black.withValues(alpha: .55)],
          radius: 1,
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant GarageWood oldDelegate) => false;
}

class KeyArt extends CustomPainter {
  KeyArt({required this.color, required this.locked, required this.selected});
  final Color color;
  final bool locked, selected;
  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.translate(size.width / 2, size.height * .42);
    c.rotate(-.28);
    final paint = Paint()
      ..color = locked ? Colors.white12 : const Color(0xFFBDB7A2);
    c.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 34, height: 38),
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-5, 17, 10, 33),
        const Radius.circular(2),
      ),
      paint..style = PaintingStyle.fill,
    );
    c.drawRect(const Rect.fromLTWH(0, 31, 13, 7), paint);
    c.drawRect(const Rect.fromLTWH(0, 43, 10, 7), paint);
    final tag = Rect.fromLTWH(12, -8, 32, 24);
    c.drawRRect(
      RRect.fromRectAndRadius(tag, const Radius.circular(4)),
      Paint()..color = locked ? Colors.white10 : color,
    );
    if (!locked) {
      c.drawLine(
        const Offset(15, 9),
        const Offset(38, -4),
        Paint()
          ..color = Colors.black26
          ..strokeWidth = 2,
      );
    }
    if (selected) {
      c.drawCircle(
        Offset.zero,
        25,
        Paint()
          ..color = gold.withValues(alpha: .15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
    c.restore();
  }

  @override
  bool shouldRepaint(covariant KeyArt old) =>
      old.color != color || old.locked != locked || old.selected != selected;
}

/// Procedural rear-view garage emblem; final sprite pack remains reviewable.
class CarPreview extends CustomPainter {
  CarPreview(this.car);
  final CarSpec car;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height * .53);
    final scale = math.min(size.width / 180, size.height / 94);
    canvas.scale(scale);
    final body = Paint()..color = Color(car.color);
    canvas.drawOval(
      const Rect.fromLTWH(-76, 25, 152, 22),
      Paint()..color = Colors.black38,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-67, 8, 22, 28),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFF101418),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(45, 8, 22, 28),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFF101418),
    );
    final path = Path()
      ..moveTo(-65, 27)
      ..lineTo(-68, -2)
      ..lineTo(-51, -17)
      ..lineTo(-37, -43)
      ..lineTo(37, -43)
      ..lineTo(51, -17)
      ..lineTo(68, -2)
      ..lineTo(65, 27)
      ..close();
    canvas.drawPath(path, body);
    canvas.drawPath(
      Path()
        ..moveTo(-43, -17)
        ..lineTo(-32, -36)
        ..lineTo(32, -36)
        ..lineTo(43, -17)
        ..close(),
      Paint()..color = const Color(0xFF152B34),
    );
    if (car.id == 'corvette') {
      canvas.drawRect(
        const Rect.fromLTWH(-25, -37, 50, 17),
        Paint()..color = const Color(0xFF292326),
      );
      canvas.drawRect(
        const Rect.fromLTWH(-21, -32, 15, 12),
        Paint()..color = const Color(0xFF7A4B39),
      );
      canvas.drawRect(
        const Rect.fromLTWH(6, -32, 15, 12),
        Paint()..color = const Color(0xFF7A4B39),
      );
    }
    canvas.drawRect(
      const Rect.fromLTWH(-64, 4, 128, 21),
      Paint()..color = Colors.black26,
    );
    for (final x in [-55.0, 30.0]) {
      canvas.drawRect(
        Rect.fromLTWH(x, 6, 25, 7),
        Paint()..color = const Color(0xFFEE644A),
      );
    }
    canvas.drawRect(const Rect.fromLTWH(-14, 13, 28, 9), Paint()..color = gold);
    canvas.drawLine(
      const Offset(-59, -6),
      const Offset(59, -6),
      Paint()
        ..color = Colors.white30
        ..strokeWidth = 2,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CarPreview old) => old.car.id != car.id;
}

class RouteMapPainter extends CustomPainter {
  RouteMapPainter({required this.route, required this.fill});
  final List<Map<String, dynamic>> route;
  final double fill;
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Rect.fromLTWH(20, 12, size.width - 40, size.height - 34);
    Offset project(double lon, double lat) => Offset(
      bounds.left + (lon + 125) / 59 * bounds.width,
      bounds.top + (50 - lat) / 26 * bounds.height,
    );
    final outline = [
      [-124.7, 48.4],
      [-122.8, 48.4],
      [-117.0, 49.0],
      [-95.2, 49.0],
      [-89.4, 47.9],
      [-84.7, 46.5],
      [-82.7, 42.0],
      [-79.0, 43.0],
      [-73.0, 45.0],
      [-67.0, 47.3],
      [-67.0, 44.5],
      [-71.0, 41.3],
      [-74.0, 40.5],
      [-75.6, 35.2],
      [-80.2, 25.3],
      [-81.8, 24.8],
      [-83.0, 29.0],
      [-89.2, 29.0],
      [-94.7, 29.5],
      [-97.2, 25.9],
      [-103.0, 29.0],
      [-106.5, 31.8],
      [-111.0, 31.3],
      [-117.1, 32.5],
      [-120.7, 35.8],
      [-124.4, 40.5],
      [-124.7, 48.4],
    ];
    final land = Path();
    for (var i = 0; i < outline.length; i++) {
      final p = project(outline[i][0], outline[i][1]);
      if (i == 0) {
        land.moveTo(p.dx, p.dy);
      } else {
        land.lineTo(p.dx, p.dy);
      }
    }
    land.close();
    canvas.drawPath(land, Paint()..color = const Color(0xFF182B32));
    canvas.drawPath(
      land,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF43616A)
        ..strokeWidth = 1,
    );
    for (final edge in routeGraph.edges) {
      final a = routeGraph.node(edge.from);
      final b = routeGraph.node(edge.to);
      canvas.drawLine(
        project(a.lon, a.lat),
        project(b.lon, b.lat),
        Paint()
          ..color = const Color(0xFF4B6268)
          ..strokeWidth = 1.7,
      );
    }
    final lengths = route
        .map(
          (v) =>
              routeGraph.edge(v['edgeId'] as String).miles *
              (v['fraction'] as num).toDouble(),
        )
        .toList();
    final total = lengths.fold<double>(0, (a, b) => a + b);
    var left = total * fill;
    Offset? marker;
    for (var i = 0; i < route.length; i++) {
      final edge = routeGraph.edge(route[i]['edgeId'] as String);
      final a = routeGraph.node(edge.from);
      final b = routeGraph.node(edge.to);
      final fraction = (route[i]['fraction'] as num).toDouble();
      final shown = lengths[i] == 0
          ? 0.0
          : (left / lengths[i]).clamp(0.0, 1.0) * fraction;
      final begin = project(a.lon, a.lat),
          end = Offset.lerp(begin, project(b.lon, b.lat), shown)!;
      if (left > 0) {
        canvas.drawLine(
          begin,
          end,
          Paint()
            ..color = gold
            ..strokeWidth = 3.2
            ..strokeCap = StrokeCap.round,
        );
        marker = end;
      }
      left -= lengths[i];
    }
    if (marker != null) {
      canvas.drawCircle(marker, 5, Paint()..color = Colors.white);
      canvas.drawCircle(
        marker,
        9,
        Paint()..color = gold.withValues(alpha: .25),
      );
    }
    for (final node in routeGraph.nodes) {
      final p = project(node.lon, node.lat);
      canvas.drawCircle(p, 2.6, Paint()..color = const Color(0xFFADC2C2));
      if (node.id == 'ny' ||
          node.id == 'redondo' ||
          node.name.contains('Denver') ||
          node.name.contains('Chicago') ||
          node.name.contains('Omaha')) {
        final text = TextPainter(
          text: TextSpan(
            text: node.name,
            style: const TextStyle(
              color: Color(0xFFA5BABD),
              fontSize: 9,
              fontFamily: 'Cannonball',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(
          canvas,
          Offset(
            (p.dx - text.width / 2).clamp(0, size.width - text.width),
            p.dy + 7,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant RouteMapPainter old) =>
      old.fill != fill || old.route != route;
}
