import 'dart:typed_data';

import 'package:cannonball/game/render/paint_palette.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'paint mask excludes glass, tires, rear lamps and center brake lamp',
    () {
      expect(PaintPalette.isPaint(210, 35, 25, .5, .7, redBody: true), isTrue);
      expect(
        PaintPalette.isPaint(210, 35, 25, .2, .58, redBody: true),
        isFalse,
      );
      expect(
        PaintPalette.isPaint(210, 35, 25, .8, .58, redBody: true),
        isFalse,
      );
      expect(
        PaintPalette.isPaint(210, 35, 25, .5, .51, redBody: true),
        isFalse,
      );
      expect(PaintPalette.isPaint(210, 35, 25, .5, .3, redBody: true), isFalse);
      expect(PaintPalette.isPaint(25, 25, 25, .5, .7, redBody: true), isFalse);
    },
  );

  test('recolor preserves alpha and nonpaint pixels byte for byte', () {
    const w = 10, h = 10;
    final pixels = Uint8List(w * h * 4);
    void pixel(int x, int y, List<int> rgba) =>
        pixels.setRange((y * w + x) * 4, (y * w + x) * 4 + 4, rgba);
    List<int> read(int x, int y) =>
        pixels.sublist((y * w + x) * 4, (y * w + x) * 4 + 4);
    pixel(5, 7, [210, 35, 25, 254]);
    pixel(2, 5, [240, 25, 15, 254]);
    pixel(5, 3, [50, 70, 80, 254]);
    pixel(5, 8, [0, 0, 0, 0]);
    PaintPalette.recolor(pixels, w, h, 0xff468bb5, redBody: true);
    expect(read(5, 7), [70, 139, 181, 254]);
    expect(read(2, 5), [240, 25, 15, 254]);
    expect(read(5, 3), [50, 70, 80, 254]);
    expect(read(5, 8), [0, 0, 0, 0]);
  });
}
