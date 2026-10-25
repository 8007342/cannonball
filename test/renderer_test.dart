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
    'authored pose anchors preserve wheel contact without resizing poses',
    () {
      expect(ProofArt.carGround, [416, 412, 415, 372, 400, 404]);
      expect(ProofArt.carCenter.length, ProofArt.carGround.length);
      expect(ProofArt.sceneryGround, [512, 512, 512, 478, 449, 451]);
    },
  );
}
