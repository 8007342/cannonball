import 'dart:convert';
import 'dart:io';

import 'package:cannonball/game/render/surface_meshes.dart';
import 'package:cannonball/game/scenic/scenic_bands.dart';
import 'package:cannonball/game/scenic/scenic_zones.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest = jsonDecode(
    File('assets/scenic/manifest.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final tiles = {
    for (final t in manifest['textures'] as List)
      t['id'] as String: (t['tileM'] as List).cast<num>(),
  };

  test('road detail reads at real-world scale', () {
    // Worn asphalt cracks span roughly the whole tile; a lane is ~3.6 m.
    expect(tiles['asphalt-worn']![0], lessThanOrEqualTo(3));
    // Pavers and cobbles are hand-sized, not half a metre.
    expect(tiles['brick']![0], lessThanOrEqualTo(2));
    expect(tiles['cobblestone']![0], lessThanOrEqualTo(2));
    // Concrete: two slabs per tile, each a lane wide and ~4.5 m long.
    expect(tiles['concrete']![0] / 2, closeTo(3.6, .2));
    expect(tiles['concrete']![1] / 2, closeTo(4.5, .5));
  });

  test('concrete joints fall on the lane lines', () {
    final slab = tiles['concrete']![0] / 2;
    // Dashed lane lines sit at lateral ±.333 road half-widths.
    for (final side in [-1.0, 1.0]) {
      final metres =
          side * .333 * ScenicScale.roadHalfWidthM + SurfaceMeshes.laneOffsetM;
      final phase = (metres / slab) % 1;
      expect(phase < .05 || phase > .95, isTrue, reason: 'joint phase $phase');
    }
  });

  test('worn asphalt is used sparingly and over a sound base', () {
    var worn = 0, all = 0;
    for (final level in LevelScenery.all) {
      for (final zone in level.zones) {
        all++;
        if (zone.road == 'asphalt-worn') worn++;
      }
    }
    expect(worn, greaterThan(0));
    expect(worn / all, lessThan(.2));
    expect(SurfaceMeshes.underlays['asphalt-worn']?.$1, 'asphalt-fresh');
  });
}
