import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('milestone artwork matches manifest and portal remains open', () async {
    final manifest = jsonDecode(
      await rootBundle.loadString('assets/milestone/manifest.json'),
    ) as Map<String, dynamic>;
    for (final key in ['cabin', 'hands', 'steering', 'roadProps']) {
      final spec = manifest[key] as Map<String, dynamic>;
      final bytes = await rootBundle.load('assets/milestone/${spec['file']}');
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final image = (await codec.getNextFrame()).image;
      try {
        expect(image.width, spec['width']);
        expect(image.height, spec['height']);
        if (key == 'cabin') {
          expect(image.width / image.height, closeTo(16 / 9, .01));
        } else {
          final rgba = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          int alpha(int x, int y) => rgba[(y * image.width + x) * 4 + 3];
          expect(alpha(0, 0), lessThan(4));
          if (key == 'roadProps') {
            expect(
              alpha(900, 850),
              0,
              reason: 'portal must reveal projected road',
            );
            expect(alpha(800, 800), 0);
            for (final raw in (spec['rectangles'] as Map).values) {
              final r = (raw as List).cast<int>();
              expect(r[0] + r[2], lessThanOrEqualTo(image.width));
              expect(r[1] + r[3], lessThanOrEqualTo(image.height));
              var opaque = 0;
              for (var y = r[1]; y < r[1] + r[3]; y += 8) {
                for (var x = r[0]; x < r[0] + r[2]; x += 8) {
                  if (alpha(x, y) >= 100) opaque++;
                }
              }
              expect(opaque, greaterThan(100));
            }
          } else {
            for (var cell = 0; cell < 6; cell++) {
              var opaque = 0;
              for (var y = 0; y < 512; y += 8) {
                for (var x = 0; x < 512; x += 8) {
                  if (alpha((cell % 3) * 512 + x, (cell ~/ 3) * 512 + y) >= 100)
                    opaque++;
                }
              }
              expect(opaque, greaterThan(200));
            }
          }
        }
      } finally {
        image.dispose();
        codec.dispose();
      }
    }
  });
}
