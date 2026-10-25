import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'second proof paintings and atlases are bundled at their declared size',
    () async {
      for (final name in [
        'garage-wall',
        'garage-exterior',
        's2000-atlas',
        'entry-atlas',
      ]) {
        final data = await rootBundle.load('assets/proof-next/$name.png');
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        final image = frame.image;
        try {
          expect((image.width, image.height), (1536, 1024), reason: name);
          if (!name.endsWith('atlas')) continue;
          final rgba = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          expect(rgba[3], lessThan(4), reason: '$name has real transparency');
          for (var cell = 0; cell < 6; cell++) {
            var solid = 0;
            var clear = 0;
            for (var y = 0; y < 512; y += 4) {
              for (var x = 0; x < 512; x += 4) {
                final alpha =
                    rgba[(((cell ~/ 3) * 512 + y) * 1536 +
                                (cell % 3) * 512 +
                                x) *
                            4 +
                        3];
                if (alpha >= 100) solid++;
                if (alpha < 4) clear++;
              }
            }
            expect(
              solid,
              greaterThan(500),
              reason: '$name cell $cell has artwork',
            );
            expect(
              clear,
              greaterThan(50),
              reason: '$name cell $cell has a transparent margin',
            );
          }
        } finally {
          image.dispose();
          codec.dispose();
        }
      }
    },
  );
}
