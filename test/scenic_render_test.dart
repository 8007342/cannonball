import 'dart:ui' as ui;

import 'package:cannonball/game/proof_car.dart';
import 'package:cannonball/game/proof_level.dart';
import 'package:cannonball/game/race.dart';
import 'package:cannonball/game/render/surface_meshes.dart';
import 'package:cannonball/game/scenic/scenic_manifest.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('steep near-camera surface strips are split to limit affine kinks', () {
    expect(SurfaceMeshes.columns(100, 100), 1);
    expect(SurfaceMeshes.columns(105, 100), 1);
    expect(SurfaceMeshes.columns(133, 100), 4);
    expect(SurfaceMeshes.columns(118, 100), 2);
    expect(SurfaceMeshes.columns(10, 0), 1);
  });

  test('course renderer streams banded scenery within draw budgets', () async {
    final race = RaceController();
    final game = RaceGame(controller: race, proofMode: true);
    race.start(
      proofCar,
      seed: 731,
      testCourse: true,
      reactiveTraffic: true,
      launchSpeed: 150,
    );
    game.onGameResize(Vector2(1280, 720));
    await game.onLoad();
    expect(game.assetsReady, isTrue);
    final report = <String>[];
    for (final level in ProofLevel.all) {
      var maxBatches = 0, maxSprites = 0, maxFar = 0, maxSurface = 0;
      var farSeen = 0;
      for (final start in [300.0, 1100.0, 2500.0, 3600.0, 5500.0, 5800.0]) {
        race.start(
          proofCar,
          seed: level.seed,
          testCourse: true,
          reactiveTraffic: true,
          launchSpeed: 150,
          courseStartDistance: start,
          level: level,
        );
        for (var frame = 0; frame < 20; frame++) {
          game.update(1 / 30);
          final recorder = ui.PictureRecorder();
          game.render(ui.Canvas(recorder));
          recorder.endRecording().dispose();
          maxBatches = [
            maxBatches,
            game.lastBillboardBatches,
          ].reduce((a, b) => a > b ? a : b);
          maxSprites = [
            maxSprites,
            game.lastSpriteCount,
          ].reduce((a, b) => a > b ? a : b);
          maxFar = [
            maxFar,
            game.lastFarSpriteCount,
          ].reduce((a, b) => a > b ? a : b);
          maxSurface = [
            maxSurface,
            game.lastSurfaceDraws,
          ].reduce((a, b) => a > b ? a : b);
          farSeen += game.lastFarSpriteCount;
        }
      }
      expect(game.scenicPlan, isNotNull);
      expect(game.scenicPlan!.scenery.id, level.id);
      expect(maxFar, lessThanOrEqualTo(RaceGame.maxFarScenic));
      if (level.id != 'chicago') {
        expect(farSeen, greaterThan(0), reason: level.id);
      }
      // Overlap-safe atlas grouping (BillboardBatch) keeps this well below
      // one draw per sprite; Chicago peaked at 85 before it, ~59 after.
      expect(maxBatches, lessThan(70), reason: level.id);
      expect(maxSurface, inInclusiveRange(3, 12), reason: level.id);
      expect(
        game.scenicPlan!.placements(ScenicBand.mid),
        isNotEmpty,
        reason: level.id,
      );
      report.add(
        '${level.id}: batches<=$maxBatches sprites<=$maxSprites '
        'far<=$maxFar surfaceDraws<=$maxSurface',
      );
    }
    // ignore: avoid_print
    print(report.join('\n'));
    game.onRemove();
    race.dispose();
  });
}
