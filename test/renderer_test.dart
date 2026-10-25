import 'package:cannonball/game/race.dart';
import 'package:cannonball/game/render/proof_art.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('proof presentation restarts when a same-seed run is reset', () {
    final race = RaceController()..start(cars.last, seed: 731);
    final game = RaceGame(controller: race, proofMode: true);
    for (var i = 0; i < 210; i++) {
      game.update(.1);
    }
    expect(game.proofStage, 'GREEN COUNTRY');
    race.start(cars.last, seed: 731);
    game.update(.1);
    expect(game.proofStage, 'CITY EDGE');
    expect(race.elapsed, closeTo(.1, .00001));
    race.dispose();
  });

  test('zero-time layout updates are excluded from timing counters', () {
    final race = RaceController()..start(cars.last, seed: 731);
    final game = RaceGame(controller: race, proofMode: true);
    game.update(0);
    game.update(double.nan);
    expect(game.updateCount, 0);
    game.update(1 / 60);
    expect(game.updateCount, 1);
    expect(game.updateCpuMicros, greaterThanOrEqualTo(0));
    expect(race.elapsed, closeTo(1 / 60, .000001));
    race.dispose();
  });

  test('art can be disposed safely before loading and more than once', () {
    final art = ProofArt();
    expect(art.dispose, returnsNormally);
    expect(art.dispose, returnsNormally);
  });

  test(
    'optical presets preserve simulation and avoid mid-run scenery jumps',
    () {
      final classicRace = RaceController()..start(_s2000, seed: 731);
      final fastRace = RaceController()..start(_s2000, seed: 731);
      final classic = RaceGame(controller: classicRace, proofMode: true)
        ..setSpeedPreset('classic');
      final fast = RaceGame(controller: fastRace, proofMode: true);
      for (var i = 0; i < 600; i++) {
        classic.update(1 / 60);
        fast.update(1 / 60);
      }
      expect(fastRace.elapsed, classicRace.elapsed);
      expect(fastRace.worldDistance, classicRace.worldDistance);
      expect(fastRace.speed, classicRace.speed);
      expect(
        fast.presentationDistance,
        greaterThan(classic.presentationDistance),
      );
      final before = fast.presentationDistance;
      fast.setSpeedPreset('classic');
      fast.update(1 / 60);
      expect((fast.presentationDistance - before).abs(), lessThan(60));
      expect(fast.visualFlowScale, RaceGame.visualSpeedScale);
      classicRace.dispose();
      fastRace.dispose();
    },
  );

  test(
    'authored pose anchors preserve wheel contact without resizing poses',
    () {
      expect(ProofArt.carGround, [416, 412, 415, 372, 400, 404]);
      expect(ProofArt.carCenter.length, ProofArt.carGround.length);
      expect(ProofArt.sceneryGround.take(6), [512, 512, 512, 478, 449, 451]);
      expect(ProofArt.sceneryGround.length, 10);
    },
  );
}

// A local art-test vehicle avoids altering production car IDs or server rules.
const _s2000 = CarSpec(
  id: 's2000',
  name: 'S2000',
  year: 2000,
  description: 'Renderer test',
  color: 0xffe23426,
  topSpeed: 155,
  handling: 1.15,
  acceleration: 35,
  unlockHint: '',
);
