import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _DecodedAsset {
  _DecodedAsset(this.width, this.height, this.pixels);
  final int width;
  final int height;
  final Uint8List pixels;

  int alpha(int x, int y) => pixels[(y * width + x) * 4 + 3];

  List<int> subjectBounds(int left, int top) {
    var x0 = 512, y0 = 512, x1 = 0, y1 = 0;
    for (var y = 0; y < 512; y++) {
      for (var x = 0; x < 512; x++) {
        if (alpha(left + x, top + y) < 100) continue;
        if (x < x0) x0 = x;
        if (y < y0) y0 = y;
        if (x >= x1) x1 = x + 1;
        if (y >= y1) y1 = y + 1;
      }
    }
    return [x0, y0, x1, y1];
  }

  double fraction(
    int left,
    int top,
    int regionWidth,
    int regionHeight,
    bool Function(int alpha) matches, {
    bool Function(int x, int y)? sample,
  }) {
    var count = 0;
    var total = 0;
    for (var y = 0; y < regionHeight; y++) {
      for (var x = 0; x < regionWidth; x++) {
        if (sample != null && !sample(x, y)) continue;
        total++;
        if (matches(alpha(left + x, top + y))) count++;
      }
    }
    return count / total;
  }
}

Future<_DecodedAsset> _decode(String path) async {
  final bytes = await rootBundle.load(path);
  final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
  try {
    expect(
      codec.frameCount,
      1,
      reason: '$path must be a static packed texture',
    );
    final frame = await codec.getNextFrame();
    try {
      final rgba = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      expect(rgba, isNotNull, reason: '$path must expose decoded RGBA');
      return _DecodedAsset(
        frame.image.width,
        frame.image.height,
        rgba!.buffer.asUint8List(),
      );
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const atlases = [
    'assets/proof/car-atlas.png',
    'assets/proof/scenery-atlas.png',
  ];
  const backdrop = 'assets/proof/hills.png';

  test('manifest describes valid atlas cells, names and anchors', () async {
    final manifest = jsonDecode(
      await rootBundle.loadString('assets/proof/manifest.json'),
    ) as Map<String, dynamic>;
    expect(manifest['version'], 'cartoon-proof-1');
    for (final key in ['car', 'scenery']) {
      final atlas = manifest[key] as Map<String, dynamic>;
      expect(atlas['width'], atlas['columns'] * atlas['cellWidth']);
      expect(atlas['height'], atlas['rows'] * atlas['cellHeight']);
      final names = atlas[key == 'car' ? 'poses' : 'cells'] as List;
      expect(names.length, atlas['columns'] * atlas['rows']);
      expect(names.toSet().length, names.length);
      expect(
        names,
        key == 'car'
            ? [
                'rear-flat',
                'rear-left',
                'rear-right',
                'rear-uphill',
                'rear-downhill',
                'rear-skid',
              ]
            : [
                'broadleaf-tree',
                'pine',
                'palm',
                'brick-apartment',
                'roadside-shop',
                'flowering-shrub',
              ],
      );
      final anchor =
          atlas[key == 'car' ? 'requestedAnchorInCell' : 'anchorInCell']
              as List;
      expect(anchor.length, 2);
      expect(anchor[0], inInclusiveRange(0, atlas['cellWidth']));
      expect(anchor[1], inInclusiveRange(0, atlas['cellHeight']));
      final decoded = await _decode('assets/proof/${atlas['file']}');
      expect(
        [decoded.width, decoded.height],
        [atlas['width'], atlas['height']],
      );
      if (key == 'car') {
        final anchors = atlas['observedAnchorsPerPose'] as List;
        final baselines = atlas['observedGroundYPerPose'] as List;
        expect(anchors.length, names.length);
        expect(baselines.length, names.length);
        for (var index = 0; index < names.length; index++) {
          final bounds = decoded.subjectBounds(
            (index % 3) * 512,
            (index ~/ 3) * 512,
          );
          expect(anchors[index], [
            (bounds[0] + bounds[2]) / 2,
            bounds[3],
          ], reason: '${names[index]} anchor metadata is stale');
          expect(baselines[index], bounds[3]);
        }
      }
    }
    final hills = manifest['backdrop'] as Map<String, dynamic>;
    final decoded = await _decode('assets/proof/${hills['file']}');
    expect([decoded.width, decoded.height], [hills['width'], hills['height']]);
  });

  test('proof images are registered in the Flutter asset bundle', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    for (final path in [...atlases, backdrop, 'assets/proof/manifest.json']) {
      expect(manifest.listAssets(), contains(path));
      expect((await rootBundle.load(path)).lengthInBytes, greaterThan(1000));
    }
  });

  for (final path in atlases) {
    test('$path contains six usable cutouts in isolated 512px cells', () async {
      final asset = await _decode(path);
      expect([asset.width, asset.height], [1536, 1024]);
      for (var row = 0; row < 2; row++) {
        for (var column = 0; column < 3; column++) {
          final label = '$path cell ($column,$row)';
          final visible = asset.fraction(
            column * 512,
            row * 512,
            512,
            512,
            (alpha) => alpha >= 32,
          );
          final solid = asset.fraction(
            column * 512,
            row * 512,
            512,
            512,
            (alpha) => alpha >= 200,
          );
          final clearBorder = asset.fraction(
            column * 512,
            row * 512,
            512,
            512,
            (alpha) => alpha <= 8,
            sample: (x, y) => x < 8 || x >= 504 || y < 8 || y >= 504,
          );
          if (const bool.fromEnvironment('REPORT_PROOF_ASSET_METRICS')) {
            // ignore: avoid_print
            print(
              '$label visible=${(visible * 100).toStringAsFixed(1)}% solid=${(solid * 100).toStringAsFixed(1)}% clearBorder=${(clearBorder * 100).toStringAsFixed(1)}% bounds=${asset.subjectBounds(column * 512, row * 512)}',
            );
          }
          // Alpha, not hidden RGB, determines whether a matte was exported.
          // A max alpha of 254 is valid; requiring 255 would reject good assets.
          expect(visible, greaterThan(.10), reason: '$label is empty or faint');
          expect(visible, lessThan(.90), reason: '$label has an opaque matte');
          expect(
            solid,
            greaterThan(.08),
            reason: '$label has no solid subject',
          );
          expect(
            clearBorder,
            greaterThan(.70),
            reason: '$label bleeds into the adjacent cell or retains its matte',
          );
        }
      }
    });
  }

  test('hills backdrop has wide framing and transparent sky', () async {
    final asset = await _decode(backdrop);
    expect([asset.width, asset.height], [2172, 724]);
    expect(asset.width / asset.height, 3);
    final clearSky = asset.fraction(0, 0, asset.width, 180, (a) => a <= 8);
    final solidGround = asset.fraction(
      0,
      asset.height - 120,
      asset.width,
      120,
      (a) => a >= 200,
    );
    final visible = asset.fraction(
      0,
      0,
      asset.width,
      asset.height,
      (a) => a >= 32,
    );
    expect(
      clearSky,
      greaterThan(.98),
      reason: 'sky must composite over the game',
    );
    expect(
      solidGround,
      greaterThan(.90),
      reason: 'ground must cover the horizon',
    );
    expect(visible, inExclusiveRange(.25, .80));
    if (const bool.fromEnvironment('REPORT_PROOF_ASSET_METRICS')) {
      // ignore: avoid_print
      print(
        'hills clearSky=${(clearSky * 100).toStringAsFixed(1)}% solidGround=${(solidGround * 100).toStringAsFixed(1)}% visible=${(visible * 100).toStringAsFixed(1)}%',
      );
    }
  });
}
