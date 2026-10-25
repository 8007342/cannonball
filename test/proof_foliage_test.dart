import 'dart:ui' as ui;

import 'package:cannonball/game/render/proof_art.dart';
import 'package:cannonball/game/render/proof_foliage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('animated atlas transform leaves the tree ground pivot fixed', () async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 8, 8), ui.Paint());
    final picture = recorder.endRecording();
    final image = await picture.toImage(8, 8);
    final drawing = ui.PictureRecorder();
    final batch = BillboardBatch();
    batch.add(
      ui.Canvas(drawing),
      image,
      const ui.Rect.fromLTWH(0, 0, 8, 8),
      100,
      200,
      2,
      rotation: .012,
      pivotX: 8,
      pivotY: 16,
    );
    final t = batch.transforms;
    expect(t[0] * 4 - t[1] * 8 + t[2], closeTo(108, .0001));
    expect(t[1] * 4 + t[0] * 8 + t[3], closeTo(216, .0001));
    drawing.endRecording().dispose();
    picture.dispose();
    image.dispose();
  });
  test(
    'seeded spatial foliage motion is bounded, local and quiet on demand',
    () {
      for (var t = 0.0; t < 20; t += .1) {
        final angle = ProofFoliage.angle(time: t, position: 6500, depth: 1000);
        expect(angle.abs(), lessThanOrEqualTo(.012));
        expect(ProofFoliage.angle(time: t, position: 6500, depth: 20000), 0);
        expect(
          ProofFoliage.angle(time: t, position: 6500, depth: 1000, quiet: true),
          0,
        );
      }
      expect(
        ProofFoliage.angle(time: 2, position: 6500, depth: 1000),
        isNot(ProofFoliage.angle(time: 2, position: 8500, depth: 1000)),
      );
    },
  );
}
