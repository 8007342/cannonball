import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import 'paint_palette.dart';

/// One small original art pack. Images are decoded once, never during drawing.
class ProofArt {
  ui.Image? carAtlas, environmentAtlas, backdrop, trafficAtlas, turnAtlas;
  final List<ui.Rect> turnFrames = [], coursePropFrames = [];
  final List<double> turnGround = [], turnCenter = [];
  bool get coursePropsReady => coursePropFrames.isNotEmpty;
  List<double> groundAnchors = List.of(carGround),
      centerAnchors = List.of(carCenter);
  late ui.Image asphalt, meadow, cloud, shadow, bridge;
  final List<ui.Rect> carFrames = [];
  final List<ui.Rect> environmentFrames = [];
  String? error;
  bool _disposed = false;
  final List<ui.Image> _resources = [];
  static const carGround = [416.0, 412.0, 415.0, 372.0, 400.0, 404.0];
  static const carCenter = [262.0, 254.5, 252.0, 262.0, 256.0, 250.5];
  static const markerFrame = ui.Rect.fromLTWH(224, 1068, 64, 458);
  static const coneFrame = ui.Rect.fromLTWH(660, 1162, 216, 364);
  static const lampFrame = ui.Rect.fromLTWH(1230, 1094, 142, 432);
  static const sceneryGround = [512.0, 512.0, 512.0, 478.0, 449.0, 451.0];
  bool get ready => carAtlas != null && environmentAtlas != null;

  Future<void> load({bool s2000 = false, bool course = false}) async {
    final results = await Future.wait([
      _load(
        s2000
            ? 'assets/proof-next/s2000-atlas.png'
            : 'assets/proof/car-atlas.png',
      ),
      _load('assets/proof/scenery-atlas.png'),
      _load('assets/proof/hills.png', optional: true),
      course
          ? _load('assets/milestone/road-props.png')
          : Future<ui.Image?>.value(null),
      course
          ? _load('assets/milestone/turn-atlas.png')
          : Future<ui.Image?>.value(null),
    ]);
    if (_disposed) return;
    carAtlas = results[0];
    environmentAtlas = results[1];
    backdrop = results[2];
    turnAtlas = results[4];
    if (turnAtlas != null) {
      turnFrames.addAll(_cells(turnAtlas!));
      final data = await turnAtlas!.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (data != null) {
        final bytes = data.buffer.asUint8List();
        for (final rect in turnFrames) {
          var left = 512, right = 0, bottom = 0;
          for (var y = 0; y < 512; y++) {
            for (var x = 0; x < 512; x++) {
              if (bytes[((y + rect.top.toInt()) * turnAtlas!.width +
                              x +
                              rect.left.toInt()) *
                          4 +
                      3] <
                  100)
                continue;
              left = math.min(left, x);
              right = math.max(right, x);
              bottom = math.max(bottom, y);
            }
          }
          turnGround.add(bottom.toDouble());
          turnCenter.add((left + right) / 2);
        }
      }
    }
    if (carAtlas != null) {
      carFrames.addAll(_cells(carAtlas!));
      if (s2000) await _measureAnchors();
      await _trafficPalette(redBody: s2000);
    }
    if (environmentAtlas != null) {
      environmentFrames.addAll(_cells(environmentAtlas!));
      _cacheRoadFurniture(results[3]);
    }
    asphalt = _roadTexture();
    meadow = _groundTexture();
    cloud = _cloudTexture();
    shadow = _shadowTexture();
    bridge = _bridgeTexture();
  }

  void _cacheRoadFurniture(ui.Image? props) {
    final source = environmentAtlas!;
    // Keep the six authored source rectangles unchanged. The third row shares
    // their GPU atlas, allowing depth-ordered scenery/furniture to stay batched.
    environmentAtlas = _record(1536, props == null ? 1536 : 2048, (canvas) {
      final paint = ui.Paint()..isAntiAlias = true;
      canvas.drawImage(source, ui.Offset.zero, paint);
      if (props != null) {
        canvas.drawImage(props, const ui.Offset(0, 1024), paint);
        return;
      }
      canvas.save();
      canvas.translate(0, 1024);
      // Reflector post: same 120-unit basis as the previous live geometry.
      const x = 256.0, y = 500.0, w = 120.0;
      paint.color = const ui.Color(0xfff1e8c9);
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          const ui.Rect.fromLTWH(x - w * .22, y - w * 3.8, w * .44, w * 3.8),
          const ui.Radius.circular(w * .1),
        ),
        paint,
      );
      paint.color = const ui.Color(0xff45534b);
      canvas.drawRect(
        const ui.Rect.fromLTWH(x - w * .23, y - w * 3.2, w * .46, w * .8),
        paint,
      );
      paint.color = const ui.Color(0xffffb65a);
      canvas.drawRect(
        const ui.Rect.fromLTWH(x - w * .17, y - w * 3.05, w * .34, w * .43),
        paint,
      );
      // Cone: 180-unit basis, grounded at local 768,500.
      final cone = ui.Path()
        ..moveTo(768, 140)
        ..lineTo(660, 500)
        ..lineTo(876, 500)
        ..close();
      paint.color = const ui.Color(0xfff39b47);
      canvas.drawPath(cone, paint);
      paint.color = const ui.Color(0xffffedcb);
      canvas.drawRect(const ui.Rect.fromLTWH(714, 338, 108, 45), paint);
      // Lamp: 150-unit basis, grounded at local 1360,500.
      final lamp = ui.Path()
        ..moveTo(1360, 500)
        ..lineTo(1360, 138.8)
        ..quadraticBezierTo(1360, 80, 1292.5, 80)
        ..lineTo(1252, 80);
      paint
        ..color = const ui.Color(0xff556b69)
        ..strokeWidth = 8.25
        ..style = ui.PaintingStyle.stroke;
      canvas.drawPath(lamp, paint);
      paint
        ..style = ui.PaintingStyle.fill
        ..color = const ui.Color(0xffe4e6ca);
      canvas.drawOval(const ui.Rect.fromLTWH(1232.5, 72.5, 48, 15), paint);
      canvas.restore();
    });
    _resources.remove(source);
    source.dispose();
    if (props != null) {
      // Explicit nonuniform source bounds from the actual generated sheet.
      coursePropFrames.addAll(const [
        ui.Rect.fromLTWH(105, 1064, 365, 450),
        ui.Rect.fromLTWH(590, 1154, 565, 355),
        ui.Rect.fromLTWH(1280, 1059, 110, 450),
        ui.Rect.fromLTWH(0, 1549, 575, 335),
        ui.Rect.fromLTWH(590, 1584, 655, 400),
        ui.Rect.fromLTWH(1270, 1544, 225, 475),
      ]);
      _resources.remove(props);
      props.dispose();
    }
  }

  Future<void> _measureAnchors() async {
    final image = carAtlas!;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return;
    final bytes = data.buffer.asUint8List();
    groundAnchors = [];
    centerAnchors = [];
    for (final rect in carFrames) {
      var left = rect.width.toInt(), right = 0, bottom = 0;
      for (var y = 0; y < rect.height.toInt(); y++) {
        for (var x = 0; x < rect.width.toInt(); x++) {
          final alpha =
              bytes[((y + rect.top.toInt()) * image.width +
                          x +
                          rect.left.toInt()) *
                      4 +
                  3];
          if (alpha < 100) continue;
          left = math.min(left, x);
          right = math.max(right, x);
          bottom = math.max(bottom, y);
        }
      }
      groundAnchors.add(bottom.toDouble());
      centerAnchors.add((left + right) / 2);
    }
  }

  Future<void> _trafficPalette({required bool redBody}) async {
    if (_disposed || carAtlas == null) return;
    // Traffic sprites only need a 256px source cell. Eight paint variants share
    // one 2048x256 atlas, avoiding eight full six-pose GPU sheets and state churn.
    final flat = _record(256, 256, (canvas) {
      canvas.drawImageRect(
        carAtlas!,
        carFrames.first,
        const ui.Rect.fromLTWH(0, 0, 256, 256),
        ui.Paint()..filterQuality = ui.FilterQuality.low,
      );
    });
    final data = await flat.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null || _disposed) return;
    final source = data.buffer.asUint8List();
    final pixels = Uint8List(2048 * 256 * 4);
    for (var variant = 0; variant < PaintPalette.colors.length; variant++) {
      final colored = Uint8List.fromList(source);
      PaintPalette.recolor(
        colored,
        256,
        256,
        PaintPalette.colors[variant],
        redBody: redBody,
      );
      for (var row = 0; row < 256; row++) {
        pixels.setRange(
          (row * 2048 + variant * 256) * 4,
          (row * 2048 + (variant + 1) * 256) * 4,
          colored,
          row * 256 * 4,
        );
      }
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: 2048,
      height: 256,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();
    if (_disposed) {
      frame.image.dispose();
      return;
    }
    trafficAtlas = frame.image;
    _resources.add(frame.image);
  }

  Future<ui.Image?> _load(String path, {bool optional = false}) async {
    try {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (_disposed) {
        frame.image.dispose();
        return null;
      }
      _resources.add(frame.image);
      return frame.image;
    } catch (exception) {
      if (!optional) error = 'Could not load the cartoon art pack: $path';
      return null;
    }
  }

  List<ui.Rect> _cells(ui.Image image) {
    final w = image.width / 3, h = image.height / 2;
    return List.generate(
      6,
      (i) => ui.Rect.fromLTWH((i % 3) * w, (i ~/ 3) * h, w, h),
    );
  }

  ui.Image _record(int width, int height, void Function(ui.Canvas) draw) {
    final recorder = ui.PictureRecorder();
    draw(ui.Canvas(recorder));
    final picture = recorder.endRecording();
    final image = picture.toImageSync(width, height);
    picture.dispose();
    _resources.add(image);
    return image;
  }

  ui.Image _roadTexture() => _record(512, 512, (canvas) {
    final paint = ui.Paint()..color = const ui.Color(0xff66727b);
    canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 512, 512), paint);
    final random = math.Random(41);
    for (var i = 0; i < 9000; i++) {
      final x = random.nextDouble() * 512, y = random.nextDouble() * 512;
      paint.color =
          (i.isEven ? const ui.Color(0xffd0d2c9) : const ui.Color(0xff1d3445))
              .withValues(alpha: random.nextDouble() * .15);
      canvas.drawRect(
        ui.Rect.fromLTWH(
          x,
          y,
          1 + random.nextDouble() * 2,
          .8 + random.nextDouble() * 2,
        ),
        paint,
      );
    }
    // Soft, irregular tire wear belongs to the asphalt tile, not screen space.
    for (final lane in [85.0, 256.0, 427.0]) {
      for (final offset in [-26.0, 26.0]) {
        final rect = ui.Rect.fromLTWH(lane + offset - 8, 0, 16, 512);
        paint.shader = ui.Gradient.linear(
          ui.Offset(rect.left, 0),
          ui.Offset(rect.right, 0),
          [
            const ui.Color(0x001b3342),
            const ui.Color(0x241b3342),
            const ui.Color(0x001b3342),
          ],
        );
        canvas.drawRect(rect, paint);
      }
    }
    paint.shader = null;
  });

  ui.Image _groundTexture() => _record(256, 256, (canvas) {
    final paint = ui.Paint()..color = const ui.Color(0xffd3d6b6);
    canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 256, 256), paint);
    final random = math.Random(17);
    for (var i = 0; i < 2400; i++) {
      final x = random.nextDouble() * 256, y = random.nextDouble() * 256;
      paint.color =
          (i % 3 == 0 ? const ui.Color(0xfff4e6aa) : const ui.Color(0xff697f53))
              .withValues(alpha: .12 + random.nextDouble() * .25);
      canvas.drawOval(
        ui.Rect.fromCenter(
          center: ui.Offset(x, y),
          width: 1 + random.nextDouble() * 6,
          height: 1 + random.nextDouble() * 3,
        ),
        paint,
      );
    }
  });

  ui.Image _cloudTexture() => _record(384, 150, (canvas) {
    final paint = ui.Paint()..isAntiAlias = true;
    for (final layer in [0, 1]) {
      for (var i = 0; i < 11; i++) {
        final x = 32.0 + i * 30;
        final y = 91.0 - math.sin(i / 10 * math.pi) * 42 + layer * 4;
        final radius = 19.0 + math.sin(i * 2.31).abs() * 23;
        paint.color = layer == 0
            ? const ui.Color(0x22a7bfd0)
            : const ui.Color(0xcffff9e8);
        canvas.drawOval(
          ui.Rect.fromCenter(
            center: ui.Offset(x, y),
            width: radius * 2.4,
            height: radius * 1.8,
          ),
          paint,
        );
      }
    }
  });

  ui.Image _shadowTexture() => _record(128, 48, (canvas) {
    final paint = ui.Paint()
      ..shader = ui.Gradient.radial(const ui.Offset(64, 24), 64, [
        const ui.Color(0x8530443d),
        const ui.Color(0x0030443d),
      ]);
    canvas.save();
    canvas.translate(0, 24);
    canvas.scale(1, .34);
    canvas.translate(0, -24);
    canvas.drawOval(const ui.Rect.fromLTWH(0, -40, 128, 128), paint);
    canvas.restore();
  });

  ui.Image _bridgeTexture() => _record(1024, 480, (canvas) {
    final wall = ui.Path()
      ..fillType = ui.PathFillType.evenOdd
      ..addRect(const ui.Rect.fromLTWH(0, 92, 1024, 388))
      ..moveTo(170, 481)
      ..lineTo(170, 300)
      ..cubicTo(170, 110, 854, 110, 854, 300)
      ..lineTo(854, 481)
      ..close();
    final paint = ui.Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.linear(
        const ui.Offset(0, 80),
        const ui.Offset(0, 480),
        [const ui.Color(0xffc8b795), const ui.Color(0xff8d8772)],
      );
    canvas.drawPath(wall, paint);
    canvas.save();
    canvas.clipPath(wall);
    paint.shader = null;
    final random = math.Random(61);
    for (var row = 0; row < 13; row++) {
      for (var col = -1; col < 13; col++) {
        final rect = ui.Rect.fromLTWH(
          col * 88.0 + (row.isEven ? 0 : 44),
          94 + row * 33.0,
          84,
          29,
        );
        paint.color = ui.Color.lerp(
          const ui.Color(0xffd4c39a),
          const ui.Color(0xff9b9681),
          random.nextDouble(),
        )!;
        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(rect, const ui.Radius.circular(3)),
          paint,
        );
        paint.color = const ui.Color(0x40766858);
        canvas.drawLine(
          rect.bottomLeft,
          rect.bottomRight,
          paint..strokeWidth = 2,
        );
      }
    }
    canvas.restore();
    final arch = ui.Path()
      ..moveTo(170, 480)
      ..lineTo(170, 300)
      ..cubicTo(170, 110, 854, 110, 854, 300)
      ..lineTo(854, 480);
    paint
      ..color = const ui.Color(0xffe4cf9b)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 25;
    canvas.drawPath(arch, paint);
    paint
      ..color = const ui.Color(0xff786f5b)
      ..strokeWidth = 5;
    canvas.drawPath(arch, paint);
    paint.style = ui.PaintingStyle.fill;
    paint.color = const ui.Color(0xff676f67);
    canvas.drawRect(const ui.Rect.fromLTWH(0, 76, 1024, 21), paint);
    paint.color = const ui.Color(0xffd9d4b6);
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        const ui.Rect.fromLTWH(0, 68, 1024, 11),
        const ui.Radius.circular(3),
      ),
      paint,
    );
    for (var i = 0; i < 26; i++) {
      paint.color = const ui.Color(0xff65746e);
      canvas.drawRect(ui.Rect.fromLTWH(i * 41.0, 22, 6, 47), paint);
      paint.color = const ui.Color(0xffd2ceb1);
      canvas.drawRect(ui.Rect.fromLTWH(i * 41.0, 22, 2, 47), paint);
    }
    paint.color = const ui.Color(0xff859087);
    canvas.drawRect(const ui.Rect.fromLTWH(0, 20, 1024, 7), paint);
    canvas.drawRect(const ui.Rect.fromLTWH(0, 43, 1024, 4), paint);
  });

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final image in _resources) {
      image.dispose();
    }
    _resources.clear();
  }
}

/// Mutable batch buffers avoid allocating a Path per leaf/building/car detail.
/// Flush at atlas/depth boundaries; never reorder objects to obtain a batch.
class BillboardBatch {
  BillboardBatch({this.capacity = 256})
    : transforms = Float32List(capacity * 4),
      rects = Float32List(capacity * 4),
      colors = Int32List(capacity);
  final int capacity;
  final Float32List transforms, rects;
  final Int32List colors;
  int count = 0, drawCalls = 0;
  ui.Image? image;
  ui.BlendMode colorBlend = ui.BlendMode.modulate;
  final ui.Paint paint = ui.Paint()
    ..filterQuality = ui.FilterQuality.low
    ..isAntiAlias = true;

  void add(
    ui.Canvas canvas,
    ui.Image atlas,
    ui.Rect source,
    double x,
    double y,
    double scale, {
    int color = 0xffffffff,
    ui.BlendMode blend = ui.BlendMode.modulate,
  }) {
    if (image != atlas || colorBlend != blend || count >= capacity)
      flush(canvas);
    image = atlas;
    colorBlend = blend;
    final i = count * 4;
    transforms[i] = scale;
    transforms[i + 1] = 0;
    transforms[i + 2] = x;
    transforms[i + 3] = y;
    rects[i] = source.left;
    rects[i + 1] = source.top;
    rects[i + 2] = source.right;
    rects[i + 3] = source.bottom;
    colors[count] = color;
    count++;
  }

  void flush(ui.Canvas canvas) {
    if (count == 0 || image == null) return;
    drawCalls++;
    canvas.drawRawAtlas(
      image!,
      Float32List.sublistView(transforms, 0, count * 4),
      Float32List.sublistView(rects, 0, count * 4),
      Int32List.sublistView(colors, 0, count),
      colorBlend,
      null,
      paint,
    );
    count = 0;
  }
}
