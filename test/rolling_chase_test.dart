import 'package:cannonball/game/proof_course.dart';
import 'package:cannonball/game/proof_car.dart';
import 'package:cannonball/game/race.dart';
import 'package:cannonball/game/render/proof_camera.dart';
import 'package:cannonball/game/render/proof_suspension.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sprung body cues respond to load and settle consistently across frame rates', () {
    ProofSuspension run(int hz) {
      final s = ProofSuspension();
      for (var i = 0; i < 2 * hz; i++) {
        s.update(
          speedRatio: 1,
          acceleration: 12,
          steering: .5,
          gradeRate: 0,
          quiet: false,
          dt: 1 / hz,
          impact: i == 0,
        );
      }
      return s;
    }

    final a = run(60), b = run(120);
    expect(a.roll, lessThan(-.008));
    expect(a.pitch, greaterThan(.01));
    expect(a.roll, closeTo(b.roll, 1e-7));
    expect(a.heave, closeTo(b.heave, 1e-7));
    for (var i = 0; i < 120; i++) {
      a.update(
        speedRatio: 0,
        acceleration: 0,
        steering: 0,
        gradeRate: 0,
        quiet: false,
        dt: 1 / 60,
      );
    }
    expect(a.roll.abs(), lessThan(.0001));
    expect(a.pitch.abs(), lessThan(.0001));
    a.update(
      speedRatio: 1,
      acceleration: -40,
      steering: 1,
      gradeRate: 1,
      quiet: true,
      dt: 1 / 60,
      impact: true,
    );
    expect([a.roll, a.pitch, a.heave], [0, 0, 0]);
  });

  test(
    'chase rises with speed, braking settles it lower, response is time based',
    () {
      ProofChaseResponse run(
        int hz, {
        bool brake = false,
        bool stable = false,
      }) {
        final c = ProofChaseResponse();
        for (var i = 0; i < hz; i++) {
          c.update(
            speedRatio: 1,
            steering: .5,
            braking: brake,
            recovering: false,
            stable: stable,
            dt: 1 / hz,
          );
        }
        return c;
      }

      final a = run(60), b = run(120);
      expect(a.ground, lessThan(.86));
      expect(a.ground, closeTo(b.ground, 1e-8));
      expect(a.lateralLook, closeTo(b.lateralLook, 1e-8));
      expect(run(60, brake: true).ground, greaterThan(a.ground));
      expect(run(60, stable: true).lateralLook, 0);
      expect(
        run(60, stable: true).ground,
        closeTo(ProofCamera.playerGround, .001),
      );
    },
  );
  test(
    'shared terrain rollers have multiple crests, dips and continuous joins',
    () {
      expect(ProofCourse.rollingElevationAt(840), greaterThan(1200));
      expect(ProofCourse.rollingElevationAt(1380), lessThan(-1000));
      expect(ProofCourse.rollingElevationAt(1895), greaterThan(1700));
      for (final s in [590.0, 1090.0, 1140.0, 1620.0, 1650.0, 2140.0]) {
        expect(
          (ProofCourse.rollingElevationAt(s + .001) -
                  ProofCourse.rollingElevationAt(s - .001))
              .abs(),
          lessThan(.01),
        );
      }
      expect(
        ProofCourse.rollingElevationAt(5700),
        0,
        reason: 'bridge geometry stays authored',
      );
      expect(
        ProofCourse.rollingElevationAt(6400),
        0,
        reason: 'tunnel stays authored',
      );
    },
  );
  test('dense initial stream has more cars, deterministic stagger and no three-wide wall', () {
    RaceController make() => RaceController()
      ..start(
        proofCar,
        seed: 731,
        testCourse: true,
        reactiveTraffic: true,
        denseTraffic: true,
      );
    final a = make(), b = make();
    expect(a.traffic.length, 10);
    expect(
      a.traffic.map((t) => t.position).toList(),
      b.traffic.map((t) => t.position).toList(),
    );
    for (final car in a.traffic) {
      expect(
        a.traffic.where((t) => (t.position - car.position).abs() < 32).length,
        lessThanOrEqualTo(2),
      );
    }
    a.dispose();
    b.dispose();
  });
}
