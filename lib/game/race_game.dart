import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import 'race_controller.dart';
import 'route.dart';

class _Palette {
  const _Palette(
    this.sky,
    this.horizon,
    this.far,
    this.ground,
    this.grass,
    this.tree,
  );
  final Color sky, horizon, far, ground, grass, tree;
  static _Palette forBiome(Biome biome) => switch (biome) {
    Biome.city => const _Palette(
      Color(0xff658d9b),
      Color(0xffffd2a0),
      Color(0xff586d76),
      Color(0xff858f73),
      Color(0xff7a8d68),
      Color(0xff405f57),
    ),
    Biome.forest => const _Palette(
      Color(0xff84b4bf),
      Color(0xfff3d8a7),
      Color(0xff668e85),
      Color(0xffaaa77b),
      Color(0xff7a9566),
      Color(0xff365e51),
    ),
    Biome.prairie => const _Palette(
      Color(0xff86b8c5),
      Color(0xffffe3af),
      Color(0xffa4ac87),
      Color(0xffcfb876),
      Color(0xffb4ae70),
      Color(0xff688164),
    ),
    Biome.mountain => const _Palette(
      Color(0xff7d9eae),
      Color(0xffe8d9c2),
      Color(0xff73848c),
      Color(0xff9b9b88),
      Color(0xff7b8e7e),
      Color(0xff3c5e58),
    ),
    Biome.canyon => const _Palette(
      Color(0xff94b2b7),
      Color(0xffffd4a0),
      Color(0xffb87963),
      Color(0xffc89168),
      Color(0xffb48d67),
      Color(0xff7d7757),
    ),
    Biome.desert => const _Palette(
      Color(0xff898fa9),
      Color(0xffffb985),
      Color(0xffb6817d),
      Color(0xffd5ad7c),
      Color(0xffc49c71),
      Color(0xff7c805b),
    ),
    Biome.coast => const _Palette(
      Color(0xff739ead),
      Color(0xffffc399),
      Color(0xff7c999b),
      Color(0xffd4bc91),
      Color(0xffa4ad79),
      Color(0xff496f60),
    ),
  };
  static _Palette lerp(_Palette a, _Palette b, double t) => _Palette(
    Color.lerp(a.sky, b.sky, t)!,
    Color.lerp(a.horizon, b.horizon, t)!,
    Color.lerp(a.far, b.far, t)!,
    Color.lerp(a.ground, b.ground, t)!,
    Color.lerp(a.grass, b.grass, t)!,
    Color.lerp(a.tree, b.tree, t)!,
  );
}

class _Projection {
  const _Projection(this.x, this.y, this.width, this.z);
  final double x, y, width, z;
}

class _Strip {
  const _Strip(this.near, this.far, this.index, this.worldPosition, this.clip);
  final _Projection near, far;
  final int index;
  final double worldPosition, clip;
}

/// Original procedural preview artwork. Production sprite sheets and exact
/// landmark sightlines remain an explicit art/geography acceptance task.
/// Collision and route logic live entirely in RaceController.
class RaceGame extends FlameGame {
  RaceGame({required this.controller});
  final RaceController controller;
  static const double _width = 1000, _height = 560, _roadWidth = 1100;
  final Paint _paint = Paint()..isAntiAlias = false;
  final Map<String, TextPainter> _textCache = {};
  double _cameraZ = 0, _cameraY = 0, _cameraCenter = 0, _tangent = 0;
  _Palette get _palette {
    final next = _Palette.forBiome(controller.currentEdge.biome);
    return controller.previousBiome == null
        ? next
        : _Palette.lerp(
            _Palette.forBiome(controller.previousBiome!),
            next,
            controller.regionBlend,
          );
  }

  @override
  Color backgroundColor() => const Color(0xff86b0b9);
  @override
  void update(double dt) {
    super.update(dt);
    controller.tick(dt);
  }

  void _rect(Canvas c, double x, double y, double w, double h, Color color) {
    _paint.color = color;
    c.drawRect(
      Rect.fromLTWH(
        x.roundToDouble(),
        y.roundToDouble(),
        w.ceilToDouble(),
        h.ceilToDouble(),
      ),
      _paint,
    );
  }

  void _poly(Canvas c, List<Offset> points, Color color) {
    _paint.color = color;
    final path = Path()..addPolygon(points, true);
    c.drawPath(path, _paint);
  }

  void _label(
    Canvas c,
    String text,
    double x,
    double y, {
    double fontSize = 12,
    Color color = const Color(0xfffff1cf),
    bool centered = false,
  }) {
    final key = '$text/$fontSize/${color.toARGB32()}';
    if (_textCache.length > 120) _textCache.clear();
    final painter = _textCache.putIfAbsent(
      key,
      () => TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: 'Cannonball',
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: color,
            height: 1.1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
    painter.paint(c, Offset(centered ? x - painter.width / 2 : x, y));
  }

  _Projection _project(double z, {double lateral = 0}) {
    final relative = math.max(1.0, z - _cameraZ);
    final scale = .9 / relative;
    final center = controller.centerAt(z) - _cameraCenter - _tangent * relative;
    final x =
        _width * .5 +
        scale *
            (center +
                lateral * _roadWidth -
                controller.playerX * _roadWidth * .55) *
            _width *
            .5;
    final y =
        _height * .38 +
        scale * (_cameraY - controller.elevationAt(z)) * _height * .6;
    return _Projection(x, y, scale * _roadWidth * _width * .5, relative);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (size.x <= 0 || size.y <= 0) return;
    canvas.save();
    canvas.scale(size.x / _width, size.y / _height);
    final p = _palette;
    _drawSky(canvas, p);
    canvas.save();
    canvas.translate(_width / 2, _height * .4);
    canvas.rotate(controller.cameraLean);
    canvas.translate(-_width / 2, -_height * .4);
    _cameraZ = controller.worldDistance - 850;
    _cameraY = controller.elevationAt(controller.worldDistance) + 650;
    _cameraCenter = controller.centerAt(_cameraZ);
    _tangent = (controller.centerAt(_cameraZ + 10) - _cameraCenter) / 10;
    _drawLandscape(canvas, p);
    _drawRoad(canvas, p);
    _drawPlayer(canvas);
    canvas.restore();
    _drawWeather(canvas);
    if (controller.speed > 105 && !controller.recovering) _drawSpeed(canvas);
    canvas.restore();
  }

  void _drawSky(Canvas c, _Palette p) {
    final rect = const Rect.fromLTWH(0, 0, _width, _height);
    final gradient = ui.Gradient.linear(
      const Offset(0, 0),
      const Offset(0, _height * .55),
      [p.sky, p.horizon],
      [0, 1],
    );
    c.drawRect(rect, Paint()..shader = gradient);
    final sunset = controller.weather == RaceWeather.sunset;
    _paint
      ..color = (sunset ? const Color(0xffffe2a9) : const Color(0xffffecc5))
          .withValues(alpha: .85)
      ..isAntiAlias = true;
    c.drawCircle(
      Offset(sunset ? 780 : 770, sunset ? 167 : 103),
      sunset ? 42 : 29,
      _paint,
    );
    _paint.isAntiAlias = false;
    for (var i = 0; i < 6; i++) {
      final x = (i * 217.0 + controller.worldDistance * .007) % 1270 - 130;
      final y = 58.0 + (i % 3) * 32;
      final color = const Color(0xffffedd7).withValues(alpha: .36);
      _rect(c, x, y, 94, 9, color);
      _rect(c, x + 19, y - 7, 52, 8, color);
      _rect(c, x - 22, y + 8, 135, 6, color);
    }
    // A restrained warm horizon keeps the road/car silhouette readable.
    _rect(c, 0, 210, _width, 20, p.horizon.withValues(alpha: .3));
  }

  void _drawLandscape(Canvas c, _Palette p) {
    final biome = controller.currentEdge.biome;
    final mountain =
        biome == Biome.mountain ||
        biome == Biome.canyon ||
        biome == Biome.desert;
    final shift = controller.centerAt(controller.worldDistance) * .018;
    for (var layer = 0; layer < 2; layer++) {
      final points = <Offset>[const Offset(-80, 300)];
      for (var i = 0; i <= 18; i++) {
        final x = i * 72.0 - 100 - shift * (layer + 1);
        final ridge = mountain
            ? math.sin(i * 1.7 + layer) * 38 + math.sin(i * 2.9) * 20
            : math.sin(i * 1.3 + layer) * 11;
        points.add(Offset(x, 225 - layer * 7 - ridge - (mountain ? 22 : 0)));
      }
      points.add(const Offset(1200, 320));
      _poly(c, points, Color.lerp(p.horizon, p.far, .48 + layer * .22)!);
    }
    if (biome == Biome.mountain) {
      for (var i = 0; i < 6; i++) {
        final x = i * 196.0 - 50 - shift;
        _poly(c, [
          Offset(x, 217),
          Offset(x + 61, 142 + i % 2 * 22),
          Offset(x + 135, 220),
        ], p.far);
        _poly(c, [
          Offset(x + 40, 168 + i % 2 * 17),
          Offset(x + 61, 142 + i % 2 * 22),
          Offset(x + 91, 177 + i % 2 * 12),
          Offset(x + 69, 169 + i % 2 * 19),
          Offset(x + 58, 180 + i % 2 * 14),
        ], const Color(0xffe0e0ce));
      }
    }
    if (biome == Biome.city) {
      for (var i = 0; i < 30; i++) {
        final x = i * 42.0 - 90 - shift * .7;
        final h = 25.0 + ((i * 137) % 73);
        _rect(c, x, 237 - h, 31, h, p.far);
        for (var j = 0; j < 3; j++) {
          _rect(
            c,
            x + 5 + j * 8,
            244 - h,
            3,
            h * .65,
            const Color(0xffe5c795).withValues(alpha: .45),
          );
        }
      }
    }
    _rect(c, -40, 250, 1080, 350, p.ground);
    if (biome == Biome.coast) {
      _rect(c, 0, 242, 500, 100, const Color(0xff6d9d9d));
      for (var i = 0; i < 7; i++) {
        _rect(
          c,
          0,
          246 + i * 11,
          470,
          2,
          const Color(0xffc4c9ae).withValues(alpha: .5),
        );
      }
    }
    // Gateway Arch is a distant regional cue, not a claimed roadside sightline.
    if (controller.currentEdge.to == 'st-louis') {
      final arch = Path()
        ..moveTo(732, 248)
        ..cubicTo(740, 128, 822, 128, 830, 248);
      c.drawPath(
        arch,
        Paint()
          ..color = const Color(0xffd3cbc1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5,
      );
    }
  }

  void _quad(
    Canvas c,
    _Projection a,
    _Projection b,
    double left,
    double right,
    Color color,
  ) => _poly(c, [
    Offset(a.x + a.width * left, a.y),
    Offset(a.x + a.width * right, a.y),
    Offset(b.x + b.width * right, b.y),
    Offset(b.x + b.width * left, b.y),
  ], color);

  void _drawRoad(Canvas c, _Palette p) {
    const segment = 100.0;
    final base = (_cameraZ / segment).floor();
    final strips = <_Strip>[];
    var clip = _height + 100.0;
    for (var i = 1; i < 94; i++) {
      final z = (base + i) * segment;
      final near = _project(z), far = _project(z + segment);
      if (near.y <= far.y || far.y >= clip) continue;
      strips.add(_Strip(near, far, base + i, z, clip));
      clip = math.min(clip, far.y);
    }
    for (final strip in strips.reversed) {
      final a = strip.near, b = strip.far;
      final alternate = strip.index % 4 < 2;
      c.save();
      c.clipRect(Rect.fromLTWH(-300, 0, 1600, strip.clip.clamp(0, 700)));
      _poly(c, [
        Offset(-200, a.y),
        Offset(1200, a.y),
        Offset(1200, b.y),
        Offset(-200, b.y),
      ], alternate ? p.ground : p.grass);
      _quad(
        c,
        a,
        b,
        -1.16,
        1.16,
        alternate ? const Color(0xffe7d7ae) : const Color(0xffba7b66),
      );
      _quad(
        c,
        a,
        b,
        -1,
        1,
        alternate ? const Color(0xff5b6060) : const Color(0xff5e6261),
      );
      _quad(c, a, b, -.97, -.945, const Color(0xffeadcb7));
      _quad(c, a, b, .945, .97, const Color(0xffeadcb7));
      if (strip.index % 5 < 3) {
        _quad(c, a, b, -.339, -.326, const Color(0xffe9dcc0));
        _quad(c, a, b, .326, .339, const Color(0xffe9dcc0));
      }
      // A visible divergent shoulder frames the physical steering commitment.
      final edgeZ =
          controller.edgeDistance +
          strip.worldPosition -
          controller.worldDistance;
      if (controller.nextChoices.length > 1 &&
          edgeZ > controller.currentEdge.length - 600 &&
          edgeZ < controller.currentEdge.length + 500) {
        final spread =
            ((edgeZ - controller.currentEdge.length + 600) / 1100).clamp(0, 1) *
            .7;
        _quad(c, a, b, 1, 1 + spread, const Color(0xff77746a));
        if (strip.index % 3 == 0) {
          _quad(
            c,
            a,
            b,
            1 + spread - .025,
            1 + spread,
            const Color(0xffe5d7ae),
          );
        }
      }
      c.restore();
    }
    // Painter's order plus each strip's forward hill clip hides props and cars
    // behind crests instead of rendering them through elevated road surfaces.
    for (final strip in strips.reversed) {
      final a = strip.near;
      if (a.z < 400 || a.y > _height + 180) continue;
      c.save();
      c.clipRect(Rect.fromLTWH(-250, 0, 1500, strip.clip.clamp(0, 740)));
      if (strip.index % 6 == 0) {
        final side = strip.index % 12 == 0 ? -1.0 : 1.0;
        final pos = _project(
          strip.worldPosition,
          lateral: side * (1.38 + (strip.index % 3) * .27),
        );
        _drawProp(c, pos, p, strip.index);
      }
      if (strip.index % 8 == 0) {
        for (final side in [-1.0, 1.0]) {
          final pos = _project(strip.worldPosition, lateral: side * 1.12);
          final h = pos.width * .11;
          _rect(
            c,
            pos.x - 2,
            pos.y - h,
            math.max(2, pos.width * .009),
            h,
            const Color(0xffece2c4),
          );
          _rect(
            c,
            pos.x - 2,
            pos.y - h,
            math.max(2, pos.width * .009),
            h * .2,
            const Color(0xffd0a16c),
          );
        }
      }
      final edgeZ =
          controller.edgeDistance +
          strip.worldPosition -
          controller.worldDistance;
      if (controller.closedLane != null &&
          edgeZ > controller.closureStart - 250 &&
          edgeZ < controller.closureEnd &&
          strip.index % 2 == 0) {
        final taper = ((edgeZ - controller.closureStart + 250) / 250).clamp(
          0,
          1,
        );
        final lane = controller.closedLane!;
        _drawCone(
          c,
          _project(strip.worldPosition, lateral: lane * (1 - .56 * taper)),
        );
      }
      for (final car in controller.traffic) {
        if (car.position >= strip.worldPosition &&
            car.position < strip.worldPosition + 100) {
          final pos = _project(car.position, lateral: car.x);
          if (pos.y <= strip.clip + 10) {
            _drawCar(
              c,
              pos.x,
              pos.y,
              pos.width * .19,
              Color(car.color),
              truck: car.truck,
              signal: car.signaling ? (car.targetX! > car.x ? 1 : -1) : 0,
              blink: (controller.elapsed * 4).floor() % 2 == 0,
            );
          }
        }
      }
      c.restore();
    }
    _drawSigns(c);
    _drawBridge(c);
  }

  void _drawProp(Canvas c, _Projection pos, _Palette p, int index) {
    final s = pos.width * .40;
    if (s < 2) return;
    final x = pos.x, y = pos.y;
    final biome = controller.currentEdge.biome;
    _paint.color = const Color(0xff313f37).withValues(alpha: .17);
    c.drawOval(
      Rect.fromCenter(
        center: Offset(x + s * .2, y),
        width: s * .95,
        height: s * .13,
      ),
      _paint,
    );
    switch (biome) {
      case Biome.city:
        final h = s * (1.1 + (index % 3) * .4);
        _rect(c, x - s * .38, y - h, s * .75, h, p.tree);
        _rect(c, x - s * .43, y - h - 7, s * .85, 9, const Color(0xffb5a181));
        for (var floor = 1; floor < 5; floor++) {
          for (var col = 0; col < 3; col++) {
            _rect(
              c,
              x - s * .26 + col * s * .20,
              y - h + floor * h * .16,
              s * .09,
              h * .07,
              const Color(0xffd7bd8b),
            );
          }
        }
      case Biome.prairie:
        if (index % 18 == 0) {
          _rect(
            c,
            x - s * .55,
            y - s * .6,
            s * 1.1,
            s * .6,
            const Color(0xffa46957),
          );
          _poly(c, [
            Offset(x - s * .65, y - s * .6),
            Offset(x, y - s),
            Offset(x + s * .65, y - s * .6),
          ], const Color(0xff675e55));
          _rect(
            c,
            x - s * .12,
            y - s * .35,
            s * .24,
            s * .35,
            const Color(0xffd3b989),
          );
          _rect(
            c,
            x + s * .48,
            y - s * .9,
            s * .3,
            s * .9,
            const Color(0xffa8a799),
          );
        } else {
          _rect(c, x, y - s * .85, s * .035, s * .85, const Color(0xff8d8970));
          final angle = controller.elapsed * .35 + index;
          for (var arm = 0; arm < 3; arm++) {
            final a = angle + arm * math.pi * 2 / 3;
            _poly(c, [
              Offset(x, y - s * .85),
              Offset(
                x + math.cos(a) * s * .50,
                y - s * .85 + math.sin(a) * s * .50,
              ),
              Offset(
                x + math.cos(a + .2) * s * .17,
                y - s * .85 + math.sin(a + .2) * s * .17,
              ),
            ], const Color(0xffe4d9b7));
          }
        }
      case Biome.canyon:
        _poly(c, [
          Offset(x - s * .65, y),
          Offset(x - s * .46, y - s * .5),
          Offset(x - s * .37, y - s * .9),
          Offset(x + s * .22, y - s * .95),
          Offset(x + s * .45, y - s * .4),
          Offset(x + s * .7, y),
        ], p.far);
        _rect(
          c,
          x - s * .3,
          y - s * .57,
          s * .6,
          s * .06,
          const Color(0xffdcaa7f),
        );
      case Biome.desert:
        // Mojave Joshua-tree silhouettes, not saguaro cacti.
        _rect(
          c,
          x - s * .04,
          y - s * .9,
          s * .08,
          s * .9,
          const Color(0xff796b51),
        );
        for (final side in [-1.0, 1.0]) {
          _rect(
            c,
            x + side * s * .21,
            y - s * .67,
            s * .06,
            s * .35,
            const Color(0xff796b51),
          );
          _rect(
            c,
            x + math.min(0, side * s * .21),
            y - s * .36,
            s * .25,
            s * .07,
            const Color(0xff796b51),
          );
          _poly(c, [
            Offset(x + side * s * .24, y - s * .88),
            Offset(x + side * s * .24 - s * .22, y - s * .61),
            Offset(x + side * s * .24 + s * .22, y - s * .65),
          ], p.tree);
        }
        _poly(c, [
          Offset(x, y - s * 1.12),
          Offset(x - s * .24, y - s * .83),
          Offset(x + s * .24, y - s * .84),
        ], p.tree);
      case Biome.coast:
        _poly(c, [
          Offset(x - s * .03, y),
          Offset(x + s * .08, y - s * 1.1),
          Offset(x + s * .14, y - s * 1.1),
          Offset(x + s * .04, y),
        ], const Color(0xff88745a));
        for (var leaf = 0; leaf < 5; leaf++) {
          final a = -math.pi + leaf * .65;
          _poly(c, [
            Offset(x + s * .1, y - s * 1.1),
            Offset(
              x + s * .1 + math.cos(a) * s * .67,
              y - s * 1.1 + math.sin(a) * s * .3,
            ),
            Offset(
              x + s * .1 + math.cos(a) * s * .42,
              y - s * 1.1 + math.sin(a) * s * .55,
            ),
          ], p.tree);
        }
      case Biome.forest:
      case Biome.mountain:
        _rect(
          c,
          x - s * .05,
          y - s * .6,
          s * .1,
          s * .6,
          const Color(0xff766950),
        );
        for (var tier = 0; tier < 3; tier++) {
          final top = y - s * 1.3 + tier * s * .26;
          final width = s * (.37 + tier * .12);
          _poly(c, [
            Offset(x, top),
            Offset(x - width, top + s * .58),
            Offset(x + width, top + s * .58),
          ], tier % 2 == 0 ? p.tree : Color.lerp(p.tree, p.grass, .25)!);
          if (controller.weather == RaceWeather.snow) {
            _poly(c, [
              Offset(x, top),
              Offset(x - width * .36, top + s * .21),
              Offset(x + width * .36, top + s * .21),
            ], const Color(0xffdfdfcb));
          }
        }
    }
  }

  void _drawCone(Canvas c, _Projection p) {
    final w = p.width * .035;
    _rect(c, p.x - w, p.y - w * .13, w * 2, w * .2, const Color(0xff544d43));
    _poly(c, [
      Offset(p.x, p.y - w * 2.6),
      Offset(p.x - w * .75, p.y),
      Offset(p.x + w * .75, p.y),
    ], const Color(0xffed9962));
    _rect(
      c,
      p.x - w * .40,
      p.y - w * 1.2,
      w * .8,
      w * .35,
      const Color(0xffffe5b3),
    );
  }

  void _drawSigns(Canvas c) {
    if (controller.approachingFork) {
      final distance = controller.distanceToFork;
      final z = controller.worldDistance + distance;
      final pos = _project(z);
      if (pos.z > 450 && pos.z < 2100) {
        final scale = (pos.width / 400).clamp(.30, 1.10);
        c.save();
        c.translate(pos.x, pos.y - pos.width * .75);
        c.scale(scale);
        _rect(c, -270, 0, 7, 330, const Color(0xff8b958b));
        _rect(c, 263, 0, 7, 330, const Color(0xff8b958b));
        _rect(c, -275, -6, 550, 8, const Color(0xffc7c5a8));
        for (var i = 0; i < 2; i++) {
          final edge = controller.nextChoices[i];
          final closed = edge.id == controller.closedBranchId;
          final x = -258 + i * 263.0;
          _rect(
            c,
            x,
            4,
            248,
            76,
            closed ? const Color(0xff9c6752) : const Color(0xff386f61),
          );
          _rect(c, x + 4, 8, 240, 1, const Color(0xffd8e0be));
          final road = edge.secret
              ? 'OLD ROAD · ? KEY'
              : edge.road.split(' · ').first;
          _label(
            c,
            road.length > 25 ? '${road.substring(0, 23)}…' : road,
            x + 124,
            17,
            fontSize: 13,
            centered: true,
          );
          _label(
            c,
            closed
                ? 'ROAD CLOSED'
                : controller.graph
                      .node(edge.to)
                      .name
                      .split(' · ')
                      .first
                      .toUpperCase(),
            x + 124,
            38,
            fontSize: 12,
            centered: true,
          );
          _label(
            c,
            i == 0 ? 'KEEP LEFT' : 'KEEP RIGHT',
            x + 124,
            59,
            fontSize: 11,
            centered: true,
            color: closed ? const Color(0xffffd3ad) : const Color(0xffe9dfaf),
          );
        }
        c.restore();
      }
    }
    final toGate = controller.nextGateMiles * RouteGraph.unitsPerMile;
    if (toGate < 1200) {
      final pos = _project(controller.worldDistance + toGate);
      final scale = (pos.width / 430).clamp(.1, 1.5);
      if (pos.z > 350) {
        c.save();
        c.translate(pos.x, pos.y);
        c.scale(scale);
        _rect(c, -435, -330, 12, 330, const Color(0xffdcc28a));
        _rect(c, 423, -330, 12, 330, const Color(0xffdcc28a));
        _rect(c, -435, -330, 870, 45, const Color(0xffe6bd76));
        for (var i = 0; i < 39; i++) {
          _rect(c, -435 + i * 23, -330, 12, 8, const Color(0xff536860));
        }
        _label(
          c,
          'TIME GATE  +45',
          0,
          -318,
          fontSize: 22,
          color: const Color(0xff374e4c),
          centered: true,
        );
        c.restore();
      }
    }
    // Shoulder works sign is visible before cones reach the driving corridor.
    if (controller.closedLane != null) {
      final ahead = controller.closureStart - controller.edgeDistance;
      if (ahead > 0 && ahead < 1300) {
        final pos = _project(
          controller.worldDistance + ahead - 250,
          lateral: 1.25,
        );
        final s = pos.width * .15;
        _rect(
          c,
          pos.x - 2,
          pos.y - s * 2.3,
          4,
          s * 2.3,
          const Color(0xffb9b3a0),
        );
        _poly(c, [
          Offset(pos.x, pos.y - s * 3.1),
          Offset(pos.x + s, pos.y - s * 2.1),
          Offset(pos.x, pos.y - s * 1.1),
          Offset(pos.x - s, pos.y - s * 2.1),
        ], const Color(0xffe8ad62));
        if (s > 22) {
          _label(
            c,
            'WORK',
            pos.x,
            pos.y - s * 2.27,
            fontSize: s * .32,
            color: const Color(0xff4e4f44),
            centered: true,
          );
        }
      }
    }
  }

  void _drawBridge(Canvas c) {
    // Explicit deck/screen-height ordering, rather than a skyline-only bridge.
    if (controller.currentEdge.biome != Biome.city &&
        controller.currentEdge.biome != Biome.prairie) {
      return;
    }
    final bridgeZ = (controller.worldDistance / 9200).floor() * 9200 + 5200;
    final ahead = bridgeZ - controller.worldDistance;
    if (ahead < -500 || ahead > 2800) return;
    final pos = _project(bridgeZ.toDouble());
    if (pos.z <= 300) return;
    final w = pos.width * 1.8, height = pos.width * .72;
    _rect(
      c,
      pos.x - w,
      pos.y - height,
      w * 2,
      height * .17,
      const Color(0xff87938b),
    );
    _rect(
      c,
      pos.x - w,
      pos.y - height,
      w * 2,
      height * .035,
      const Color(0xffd3cbb0),
    );
    _rect(
      c,
      pos.x - w * .81,
      pos.y - height,
      w * .1,
      height,
      const Color(0xff7b877e),
    );
    _rect(
      c,
      pos.x + w * .71,
      pos.y - height,
      w * .1,
      height,
      const Color(0xff7b877e),
    );
    for (var i = 0; i < 19; i++) {
      _rect(
        c,
        pos.x - w + i * w * .111,
        pos.y - height - height * .1,
        w * .009,
        height * .1,
        const Color(0xffb9bca4),
      );
    }
  }

  void _drawCar(
    Canvas c,
    double x,
    double y,
    double width,
    Color body, {
    bool truck = false,
    bool player = false,
    bool corvette = false,
    int signal = 0,
    bool blink = false,
  }) {
    final w = width,
        h =
            w *
            (truck
                ? 1.04
                : corvette
                ? .55
                : .67);
    c.save();
    c.translate(x, y);
    if (player) {
      final turn = controller.steering.clamp(-1.0, 1.0);
      c.skew(-turn * .08, 0);
      if (controller.recovering) {
        final p = controller.recoveryProgress;
        c.translate(
          0,
          -math.sin(p * math.pi) *
              (controller.crashPose == CrashPose.flip ? 85 : 18),
        );
        c.rotate(
          p * math.pi * (controller.crashPose == CrashPose.flip ? 2 : 1.2),
        );
      }
    }
    _paint.color = const Color(0xff252f2d).withValues(alpha: .28);
    c.drawOval(
      Rect.fromCenter(
        center: Offset(w * .04, 0),
        width: w * 1.24,
        height: h * .25,
      ),
      _paint,
    );
    _rect(c, -w * .48, -h * .46, w * .18, h * .5, const Color(0xff273735));
    _rect(c, w * .30, -h * .46, w * .18, h * .5, const Color(0xff273735));
    _poly(c, [
      Offset(-w * .49, -h * .12),
      Offset(-w * .43, -h * .73),
      Offset(-w * .31, -h),
      Offset(w * .31, -h),
      Offset(w * .43, -h * .73),
      Offset(w * .49, -h * .12),
    ], body);
    _rect(
      c,
      -w * .45,
      -h * .38,
      w * .90,
      h * .27,
      Color.lerp(body, const Color(0xff273c38), .17)!,
    );
    if (truck) {
      _rect(c, -w * .40, -h * 1.2, w * .80, h * 1.05, const Color(0xffe2d9bd));
      _rect(
        c,
        -w * .36,
        -h * 1.15,
        w * .72,
        h * .93,
        Color.lerp(body, const Color(0xffe2d9bd), .6)!,
      );
      _rect(
        c,
        -w * .012,
        -h * 1.15,
        w * .024,
        h * .93,
        const Color(0xff989d8d),
      );
    } else if (corvette) {
      // Open black cabin and two seats; no opaque targa panel crosses the roof.
      _poly(c, [
        Offset(-w * .29, -h * .92),
        Offset(w * .29, -h * .92),
        Offset(w * .34, -h * .55),
        Offset(-w * .34, -h * .55),
      ], const Color(0xff263b3d));
      _rect(c, -w * .25, -h * .84, w * .18, h * .20, const Color(0xff8d715c));
      _rect(c, w * .07, -h * .84, w * .18, h * .20, const Color(0xff8d715c));
      _rect(c, -w * .30, -h * .98, w * .60, h * .055, const Color(0xffece7d7));
      _poly(c, [
        Offset(-w * .40, -h * .55),
        Offset(-w * .15, -h * .61),
        Offset(w * .15, -h * .61),
        Offset(w * .40, -h * .55),
        Offset(w * .44, -h * .36),
        Offset(-w * .44, -h * .36),
      ], body);
      _rect(c, -w * .44, -h * .36, w * .88, h * .04, const Color(0xff9fa9a0));
    } else {
      _poly(c, [
        Offset(-w * .29, -h * .91),
        Offset(w * .29, -h * .91),
        Offset(w * .36, -h * .56),
        Offset(-w * .36, -h * .56),
      ], const Color(0xff476065));
      _poly(c, [
        Offset(-w * .25, -h * .87),
        Offset(w * .18, -h * .87),
        Offset(w * .30, -h * .73),
        Offset(-w * .28, -h * .73),
      ], const Color(0xff8fa6a3));
      _rect(
        c,
        -w * .32,
        -h * .52,
        w * .64,
        h * .035,
        Color.lerp(body, const Color(0xffffe6b2), .45)!,
      );
    }
    final brake = player && controller.braking;
    final lamp = brake ? const Color(0xffff6c48) : const Color(0xffb85c49);
    _rect(c, -w * .41, -h * .31, w * (corvette ? .19 : .22), h * .12, lamp);
    _rect(
      c,
      w * (corvette ? .22 : .19),
      -h * .31,
      w * (corvette ? .19 : .22),
      h * .12,
      lamp,
    );
    if (corvette) {
      _rect(c, -w * .30, -h * .31, w * .025, h * .12, body);
      _rect(c, w * .30, -h * .31, w * .025, h * .12, body);
    }
    _rect(c, -w * .42, -h * .10, w * .84, h * .065, const Color(0xffb8b9a5));
    _rect(c, -w * .11, -h * .22, w * .22, h * .105, const Color(0xffe8d9b7));
    _rect(c, -w * .07, -h * .19, w * .14, h * .025, const Color(0xff64736c));
    if (signal != 0 && blink) {
      _rect(
        c,
        signal < 0 ? -w * .43 : w * .33,
        -h * .32,
        w * .10,
        h * .13,
        const Color(0xffffc969),
      );
    }
    c.restore();
  }

  void _drawPlayer(Canvas c) {
    final x = _width * .5 + controller.playerX * 245;
    final bob =
        math.sin(controller.worldDistance * .07) *
        math.min(1.7, controller.speed / 80);
    final y = _height * .84 + bob;
    if (controller.protection > 0 &&
        (controller.elapsed * 9).floor() % 2 == 0) {
      return;
    }
    if (controller.speed > 55) {
      final slip =
          controller.steering.abs() > .75 ||
          controller.playerX.abs() > 1 ||
          controller.recovering;
      if (slip) {
        for (var i = 0; i < 4; i++) {
          _paint.color = const Color(0xffded4b8)
              .withValues(alpha: .24 - i * .04);
          c.drawOval(
            Rect.fromCenter(
              center: Offset(x + (i.isEven ? -1 : 1) * (49 + i * 8), y + i * 6),
              width: 20 + i * 8,
              height: 12 + i * 4,
            ),
            _paint,
          );
        }
      }
    }
    _drawCar(
      c,
      x,
      y,
      121,
      Color(controller.car.color),
      player: true,
      corvette: controller.car.id == 'corvette',
    );
    if (controller.speed > 35 && !controller.recovering) {
      _rect(
        c,
        x - 40,
        y + 2,
        2,
        8,
        const Color(0xfff8d99a).withValues(alpha: .2),
      );
      _rect(
        c,
        x + 38,
        y + 2,
        2,
        8,
        const Color(0xfff8d99a).withValues(alpha: .2),
      );
    }
  }

  void _drawWeather(Canvas c) {
    final weather = controller.weather;
    if (weather == RaceWeather.clear || weather == RaceWeather.sunset) return;
    if (weather == RaceWeather.rain) {
      _rect(
        c,
        0,
        0,
        _width,
        _height,
        const Color(0xff526b7b).withValues(alpha: .10),
      );
    }
    final snow = weather == RaceWeather.snow;
    for (var i = 0; i < (snow ? 45 : 58); i++) {
      final x =
          (i * 127.0 +
              math.sin(i.toDouble()) * 70 +
              controller.elapsed * (snow ? 17 : 70)) %
          _width;
      final y = (i * 67.0 + controller.elapsed * (snow ? 49 : 360)) % _height;
      if (snow) {
        _rect(
          c,
          x,
          y,
          i % 3 + 1,
          i % 3 + 1,
          const Color(0xfff4edda).withValues(alpha: .7),
        );
      } else {
        _paint
          ..color = const Color(0xffd9e6db).withValues(alpha: .30)
          ..strokeWidth = 1;
        c.drawLine(Offset(x, y), Offset(x - 5, y + 12), _paint);
      }
    }
  }

  void _drawSpeed(Canvas c) {
    for (var i = 0; i < 9; i++) {
      final side = i.isEven ? -1 : 1;
      final phase = (controller.worldDistance * .004 + i * .237) % 1;
      final y = 300 + phase * 250;
      final x = 500 + side * (310 + phase * 240);
      _paint
        ..color = const Color(0xffffedce).withValues(alpha: .08)
        ..strokeWidth = 1.5;
      c.drawLine(Offset(x, y), Offset(x + side * 23, y + 26), _paint);
    }
  }
}
