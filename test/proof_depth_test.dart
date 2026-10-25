import 'package:cannonball/game/render/proof_depth.dart';
import 'package:cannonball/game/proof_encounters.dart';
import 'package:cannonball/game/proof_car.dart';
import 'package:cannonball/game/race.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'release admission keeps live actors and defers new births above budget',
    () {
      final race = RaceController()
        ..start(
          proofCar,
          seed: 731,
          reactiveTraffic: true,
          testCourse: true,
          denseTraffic: true,
        );
      for (var i = 0; i < 10; i++) {
        race.traffic.add(
          TrafficCar(
            id: 100 + i,
            position: 600 + i * 100,
            x: .65,
            cruiseSpeed: 80,
            color: 0xffffffff,
            truck: false,
            changeAt: 100,
          ),
        );
      }
      final ids = race.traffic.map((car) => car.id).toSet();
      for (var i = 0; i < 60; i++) {
        race.tick(1 / 60);
      }
      expect(race.proofEncounterPhase, 'release');
      expect(race.traffic.map((car) => car.id).toSet(), ids);
      race.dispose();
    },
  );
  test('world dash coverage does not depend on adaptive strip boundaries', () {
    double length(double a, double b) =>
        ProofDepth.dashes(a, b).fold(0.0, (sum, d) => sum + d.$2 - d.$1);
    final whole = length(305, 2900);
    expect(
      whole,
      closeTo(length(305, 633) + length(633, 1287) + length(1287, 2900), 1e-9),
    );
    expect(ProofDepth.dashes(509, 851).toList(), [
      (509.0, 510.0),
      (850.0, 851.0),
    ]);
  });
  test(
    'higher flow preserves preview with a fixed mesh and fine near detail',
    () {
      for (final scale in [12.0, 36.0, 84.0, 132.0, 168.0]) {
        expect(ProofDepth.preview(scale), greaterThanOrEqualTo(320));
        expect(ProofDepth.sample(1, scale), lessThan(172));
        var previous = 0.0;
        for (var i = 1; i <= ProofDepth.segments; i++) {
          final next = ProofDepth.sample(i, scale);
          expect(next, greaterThan(previous));
          previous = next;
        }
      }
    },
  );
  test(
    'traffic pressure has bounded recovery beats without deleting actors',
    () {
      final budgets = [
        for (var s = 0.0; s < 2200; s += 20) ProofEncounterBudget.at(s),
      ];
      expect(budgets.map((b) => b.phase).toSet(), {
        'release',
        'build',
        'overtake',
      });
      for (final b in budgets) {
        expect(b.capacity, inInclusiveRange(12, 22));
        expect(b.interval, greaterThanOrEqualTo(.7));
      }
      expect(
        ProofEncounterBudget.at(0).interval,
        greaterThan(ProofEncounterBudget.at(700).interval),
      );
      expect(ProofEncounterBudget.at(1100).phase, 'release');
    },
  );
}
