import 'dart:ui' as ui;

import 'package:cannonball/game/render/proof_art.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'atlas haze preserves opaque sprites and transparent surroundings',
    () async {
      final sourceRecorder = ui.PictureRecorder();
      ui.Canvas(sourceRecorder).drawRect(
        const ui.Rect.fromLTWH(0, 0, 1, 1),
        ui.Paint()..color = const ui.Color(0xffff0000),
      );
      final picture = sourceRecorder.endRecording();
      final source = await picture.toImage(2, 1);
      picture.dispose();
      try {
        for (final fog in [0x00c0d0e0, 0x80c0d0e0]) {
          final recorder = ui.PictureRecorder();
          final canvas = ui.Canvas(recorder);
          final batch = BillboardBatch();
          batch.add(
            canvas,
            source,
            const ui.Rect.fromLTWH(0, 0, 2, 1),
            0,
            0,
            1,
            color: fog,
            blend: ui.BlendMode.dstATop,
          );
          batch.flush(canvas);
          final scene = recorder.endRecording();
          final output = await scene.toImage(2, 1);
          scene.dispose();
          try {
            final pixels = (await output.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!.buffer.asUint8List();
            expect(
              pixels[3],
              255,
              reason: 'haze must not ghost the car or trees',
            );
            expect(
              pixels[7],
              0,
              reason: 'haze must not reveal rectangular sprite bounds',
            );
            if (fog >> 24 == 0) {
              expect(pixels.take(3), [255, 0, 0]);
            } else {
              expect(pixels[1], greaterThan(50));
              expect(pixels[2], greaterThan(50));
            }
          } finally {
            output.dispose();
          }
        }
      } finally {
        source.dispose();
      }
    },
  );
}
