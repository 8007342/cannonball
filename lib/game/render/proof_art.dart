import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// One small original art pack. Images are decoded once, never during drawing.
class ProofArt {
  ui.Image? carAtlas, environmentAtlas, backdrop;
  late ui.Image asphalt, meadow, cloud, shadow, bridge;
  final List<ui.Rect> carFrames = [];
  final List<ui.Rect> environmentFrames = [];
  String? error;
  bool _disposed = false;
  final List<ui.Image> _resources = [];
  static const carGround = [416.0, 412.0, 415.0, 372.0, 400.0, 404.0];
  static const carCenter = [262.0, 254.5, 252.0, 262.0, 256.0, 250.5];
  static const sceneryGround = [512.0, 512.0, 512.0, 478.0, 449.0, 451.0];
  bool get ready => carAtlas != null && environmentAtlas != null;

  Future<void> load() async {
    final results = await Future.wait([
      _load('assets/proof/car-atlas.png'),
      _load('assets/proof/scenery-atlas.png'),
      _load('assets/proof/hills.png', optional: true),
    ]);
    if (_disposed) return;
    carAtlas = results[0];
    environmentAtlas = results[1];
    backdrop = results[2];
    if (carAtlas != null) carFrames.addAll(_cells(carAtlas!));
    if (environmentAtlas != null) {
      environmentFrames.addAll(_cells(environmentAtlas!));
    }
    asphalt = _roadTexture();
    meadow = _groundTexture();
    cloud = _cloudTexture();
    shadow = _shadowTexture();
    bridge = _bridgeTexture();
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
  int count = 0;
  ui.Image? image;
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
  }) {
    if (image != atlas || count >= capacity) flush(canvas);
    image = atlas;
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
    canvas.drawRawAtlas(
      image!,
      Float32List.sublistView(transforms, 0, count * 4),
      Float32List.sublistView(rects, 0, count * 4),
      Int32List.sublistView(colors, 0, count),
      ui.BlendMode.modulate,
      null,
      paint,
    );
    count = 0;
  }
}
