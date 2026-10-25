import 'package:cannonball/game/proof_level.dart';
import 'package:cannonball/game/proof_car.dart';
import 'package:cannonball/game/race.dart';
import 'package:cannonball/game/render/proof_art.dart';
import 'package:cannonball/game/render/proof_lighting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'six distinct packs generate reproducible shared terrain and conditions',
    () {
      final shapes = <String>{};
      final race = RaceController();
      for (final level in ProofLevel.all) {
        final a = ProofTerrain(level), b = ProofTerrain(level);
        final samples = [
          for (var s = 600.0; s < 7000; s += 137)
            (a.curvatureAt(s), a.elevationAt(s)),
        ];
        shapes.add(samples.toString());
        expect(samples, [
          for (var s = 600.0; s < 7000; s += 137)
            (b.curvatureAt(s), b.elevationAt(s)),
        ]);
        race.start(
          proofCar,
          testCourse: true,
          reactiveTraffic: true,
          seed: level.seed,
          level: level,
        );
        expect(race.weather, level.weather);
        expect(race.proofLevel.id, level.id);
        expect(
          race.curveAt(1500),
          closeTo((a.curvatureAt(1500) * 55).clamp(-.4, .4), 1e-12),
        );
        for (var s = 2.0; s < 7600; s += 5) {
          expect(
            (a.elevationAt(s + .001) - a.elevationAt(s - .001)).abs(),
            lessThan(.05),
          );
        }
      }
      expect(shapes.length, 6);
      expect(ProofLevel.fromId('bad'), ProofLevel.all.first);
      race.dispose();
    },
  );
  test('canopy requires woodland metadata and structural clearance', () {
    for (final level in ProofLevel.all) {
      for (var s = 0.0; s < 7600; s += 10) {
        expect(level.canopyAt(s), inInclusiveRange(0, 1));
        if (!level.canopy || s > 5450 && s < 6820) {
          expect(level.canopyAt(s), 0);
        }
      }
    }
    expect(ProofLevel.all[1].canopyAt(900), 1);
    expect(ProofLevel.all[1].canopyAt(5200), 1);
  });
  test(
    'prepared asset variants stay bounded over repeated level selections',
    () async {
      final art = ProofArt();
      await art.load(s2000: true, course: true);
      expect(art.ready, isTrue);
      final pixels = art.levelAssetPixels;
      for (var i = 0; i < 30; i++) {
        for (final level in ProofLevel.all) {
          expect(art.environmentFor(level), isNotNull);
        }
      }
      expect(art.levelAssetCount, 3);
      expect(art.levelAssetPixels, pixels);
      expect(
        art.environmentFor(ProofLevel.all[1]),
        isNot(same(art.environmentFor(ProofLevel.all.first))),
      );
      art.dispose();
    },
  );
  test('beam response has soft local falloff and bounded signed steering', () {
    expect(ProofLighting.beam(-1, 0, 0), 0);
    expect(ProofLighting.beam(27000, 0, 0), 0);
    expect(
      ProofLighting.beam(5000, 0, 0),
      greaterThan(ProofLighting.beam(18000, 0, 0)),
    );
    expect(ProofLighting.beam(5000, 3, 0), 0);
    final light = ProofLighting();
    for (var i = 0; i < 60; i++) {
      light.update(1, 1 / 60);
    }
    expect(light.aim, inInclusiveRange(.6, .65));
    expect(
      ProofLighting.beam(10000, .45, light.aim),
      greaterThan(ProofLighting.beam(10000, -.45, light.aim)),
    );
    final dark = ProofLighting.material(0xffffffff, 1, 0);
    final lit = ProofLighting.material(0xffffffff, 1, 1);
    expect(lit & 255, greaterThan(dark & 255));
    light.reset();
    expect(light.aim, 0);
  });
  test(
    'light trails decay by time, bound sources and clear at discontinuities',
    () {
      final history = LightHistory();
      for (var i = 0; i < 1200; i++) {
        history.record(1, i / 120, const Offset(1, 2));
        expect(history.sources[1]!.length, lessThanOrEqualTo(12));
      }
      history.record(1, 0, const Offset(1, 2));
      expect(history.sources[1]!.length, 1);
      for (var i = 0; i < 100; i++) {
        history.record(i, 0, const Offset(1, 2));
      }
      expect(history.sources.length, lessThanOrEqualTo(64));
      history.record(1, 0, const Offset(1, 2), quiet: true);
      expect(history.sources.containsKey(1), isFalse);
      history.clear();
      expect(history.sources, isEmpty);
    },
  );
}
