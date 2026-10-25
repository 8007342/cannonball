import 'package:cannonball/game/race.dart';
import 'package:cannonball/game/proof_car.dart';
import 'package:flutter_test/flutter_test.dart';

RaceController course(double start, double x) => RaceController()
  ..start(
    proofCar,
    seed: 731,
    testCourse: true,
    courseStartDistance: start,
    launchSpeed: 150,
  )
  ..digitalSteering = true
  ..playerX = x;

void main() {
  test('hysteresis retains its state inside the transition band', () {
    // Find a shared-terrain position in the threshold band, without assuming
    // any single authored key or level-specific slope.
    final race = course(120, .24);
    var middle = 0.0;
    for (var s = 450.0; s < 650; s += .1) {
      final c = race.proofTerrain.curvatureAt(s).abs();
      if (c > .0219 && c < .0221) {
        middle = s;
        break;
      }
    }
    expect(middle, greaterThan(0));
    void hold(double position, int steps) {
      for (var i = 0; i < steps; i++) {
        race.courseStartDistance = position - race.worldDistance;
        race.tick(1 / 60);
      }
    }

    hold(middle, 18);
    expect(race.effectiveSteering.abs(), greaterThan(.001));
    hold(800, 18);
    expect(race.effectiveSteering.abs(), lessThan(1e-10));
    hold(middle, 18);
    expect(race.effectiveSteering.abs(), lessThan(1e-10));
    hold(120, 18);
    hold(middle, 18);
    expect(race.effectiveSteering.abs(), greaterThan(.001));
    race.dispose();
  });

  test('gentle road preserves every offset while actual wheel corrects', () {
    for (final x in [-.65, 0.0, .24, .65]) {
      final race = course(120, x);
      for (var i = 0; i < 60; i++) {
        race.tick(1 / 60);
      }
      expect(race.playerX, closeTo(x, 1e-10));
      expect(race.effectiveSteering, greaterThan(0));
      expect(race.steering, 0);
      race.dispose();
    }
  });
  test('strong bend requires active steering after assistance releases', () {
    final race = course(800, .24);
    for (var i = 0; i < 60; i++) {
      race.tick(1 / 60);
    }
    expect(race.playerX, lessThan(.21));
    expect(race.effectiveSteering, closeTo(0, 1e-10));
    race.dispose();
  });
  test('intentional steering overrides cruising without a center target', () {
    for (final sign in [-1.0, 1.0]) {
      final race = course(120, .24)..steering = sign;
      race.tick(.1);
      expect((race.playerX - .24) * sign, greaterThan(.01));
      race.dispose();
    }
  });
  test(
    'fixed steering response agrees at 60 and 120 Hz and releases quickly',
    () {
      final a = course(120, .24)..steering = 1;
      final b = course(120, .24)..steering = 1;
      for (var i = 0; i < 24; i++) {
        a.tick(1 / 60);
      }
      for (var i = 0; i < 48; i++) {
        b.tick(1 / 120);
      }
      expect(a.playerX, closeTo(b.playerX, 1e-10));
      expect(a.effectiveSteering, closeTo(b.effectiveSteering, 1e-10));
      a.steering = 0;
      a.tick(.18);
      expect(a.effectiveSteering.abs(), lessThan(.05));
      a.dispose();
      b.dispose();
    },
  );
}
