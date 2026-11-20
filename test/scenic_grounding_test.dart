import 'dart:ui' as ui;

import 'package:cannonball/game/proof_car.dart';
import 'package:cannonball/game/proof_level.dart';
import 'package:cannonball/game/race.dart';
import 'package:cannonball/game/scenic/scenic_manifest.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

/// Crest, dip and hairpin samples on the exaggerated-relief levels.
const _samples = {
  'ohio': [880.0, 1080.0, 1640.0, 1850.0, 2600.0, 7000.0],
  'indiana': [550.0, 1175.0, 1640.0, 3550.0],
  'arizona': [1100.0, 1400.0, 2050.0, 2200.0, 3000.0],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'scenic sprites stand on drawn terrain on crests, dips and hairpins',
    () async {
      final race = RaceController();
      final game = RaceGame(controller: race, proofMode: true)
        ..recordAnchors = true;
      race.start(proofCar, seed: 1, testCourse: true, launchSpeed: 120);
      game.onGameResize(Vector2(1280, 720));
      await game.onLoad();
      expect(game.assetsReady, isTrue);
      var checked = 0, beyondMesh = 0;
      final failures = <String>[];
      for (final MapEntry(key: id, value: starts) in _samples.entries) {
        final level = ProofLevel.fromId(id);
        for (final start in starts) {
          race.start(
            proofCar,
            seed: level.seed,
            testCourse: true,
            launchSpeed: 110,
            courseStartDistance: start,
            level: level,
          );
          for (var frame = 0; frame < 12; frame++) {
            race.traffic.clear();
            game.update(1 / 30);
            final recorder = ui.PictureRecorder();
            game.render(ui.Canvas(recorder));
            recorder.endRecording().dispose();
            // The vista strip stands on the furthest ground, never above the
            // topmost ground line where it would float over a gap.
            expect(
              game.farGroundY,
              greaterThanOrEqualTo(game.groundTopY - .01),
            );
            expect(game.farGroundY, lessThanOrEqualTo(game.horizonY + .01));
            for (final a in game.scenicAnchors) {
              // Hidden behind a crest: nothing to ground.
              if (a.y >= a.clip - 1) continue;
              final where =
                  '$id@${start.round()} ${a.band.name} s=${a.s.round()}';
              final segment = game.groundSegmentAt(a.depth);
              if (segment == null) {
                failures.add('$where: no ground at depth ${a.depth.round()}');
                continue;
              }
              checked++;
              if (a.band == ScenicBand.far && a.depth > 60000) beyondMesh++;
              final low = segment.nearY, high = segment.farY;
              // Anchor lies on the projected terrain between its two samples,
              // and that stretch faces the camera, so ground is drawn under it.
              if (a.y > low + 2 || a.y < high - 2) {
                failures.add(
                  '$where: anchor ${a.y.toStringAsFixed(1)} off ground '
                  '${high.toStringAsFixed(1)}..${low.toStringAsFixed(1)}',
                );
              }
              if (a.y < game.groundTopY - 2) {
                failures.add('$where: anchor above the ground top');
              }
            }
          }
        }
      }
      expect(failures.take(10), isEmpty, reason: '${failures.length} failures');
      expect(checked, greaterThan(500));
      // Far sprites past the road mesh are covered too (they used to stand on
      // the horizon haze).
      expect(beyondMesh, greaterThan(20));
      game.onRemove();
      race.dispose();
    },
  );
}
