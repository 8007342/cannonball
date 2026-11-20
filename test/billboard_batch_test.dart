import 'dart:ui' as ui;

import 'package:cannonball/game/render/proof_art.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> _solid(int argb) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = ui.Color(argb),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(4, 4);
  picture.dispose();
  return image;
}

Future<List<int>> _pixels(void Function(ui.Canvas) draw) async {
  final recorder = ui.PictureRecorder();
  draw(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(40, 4);
  picture.dispose();
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  image.dispose();
  return data.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const cell = ui.Rect.fromLTWH(0, 0, 4, 4);

  test('separate sprites from alternating atlases share batches', () async {
    final red = await _solid(0xffff0000), blue = await _solid(0xff0000ff);
    final batch = BillboardBatch();
    final pixels = await _pixels((canvas) {
      for (var i = 0; i < 6; i++) {
        batch.add(canvas, i.isEven ? red : blue, cell, i * 6.0, 0, 1);
      }
      batch.flush(canvas);
    });
    expect(batch.drawCalls, 2);
    for (var i = 0; i < 6; i++) {
      final p = (i * 6 + 1) * 4;
      expect(pixels[p], i.isEven ? 255 : 0, reason: 'sprite $i red');
      expect(pixels[p + 2], i.isEven ? 0 : 255, reason: 'sprite $i blue');
    }
    red.dispose();
    blue.dispose();
  });

  test('overlapping sprites keep painter order across atlases', () async {
    final red = await _solid(0xffff0000), blue = await _solid(0xff0000ff);
    final batch = BillboardBatch();
    // red, then blue over it, then red over that blue: the last red must win
    // where it overlaps, so it may not join the first red batch.
    final pixels = await _pixels((canvas) {
      batch.add(canvas, red, cell, 0, 0, 1);
      batch.add(canvas, blue, cell, 2, 0, 1);
      batch.add(canvas, red, cell, 4, 0, 1);
      batch.flush(canvas);
    });
    expect(batch.drawCalls, 3);
    expect(pixels[3 * 4], 0, reason: 'blue over first red');
    expect(pixels[3 * 4 + 2], 255);
    expect(pixels[5 * 4], 255, reason: 'last red over blue');
    expect(pixels[5 * 4 + 2], 0);
    red.dispose();
    blue.dispose();
  });
}
