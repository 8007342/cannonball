import 'package:cannonball/game/proof_course.dart';
import 'package:cannonball/game/proof_car.dart';
import 'package:cannonball/game/race.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('authored sample exposes both bend directions and a climb/descent', () {
    expect(ProofCourse.curvatureAt(850), greaterThan(.004));
    expect(ProofCourse.curvatureAt(1450), lessThan(-.005));
    expect(ProofCourse.elevationAt(3000), greaterThan(850));
    expect(ProofCourse.elevationAt(4100), closeTo(0, .01));
    expect(ProofCourse.steeringLoadAt(2500).abs(), greaterThan(.05));
    expect(
      ProofCourse.elevationAt(2510),
      greaterThan(ProofCourse.elevationAt(2500)),
    );
    expect(ProofCourse.sectionAt(5300), 'TREE CANOPY');
    expect(ProofCourse.tunnelAt(6400), closeTo(1, .001));
    expect(ProofCourse.tunnelAt(6900), 0);
  });

  test('visible bend does not collapse to a straight local tangent', () {
    const s = 700.0, ahead = 450.0;
    final heading =
        (ProofCourse.centerAt(s + 1) - ProofCourse.centerAt(s - 1)) / 2;
    final deviation =
        ProofCourse.centerAt(s + ahead) -
        ProofCourse.centerAt(s) -
        heading * ahead;
    expect(deviation.abs(), greaterThan(1000));
  });

  test('cone culling preserves world identities while camera advances', () {
    List<double> visible(double near) => ProofCourse.fixedPositions(
      origin: 120,
      spacing: 230,
      near: near,
      far: 1800,
      end: 1600,
    ).toList();
    expect(visible(200).first, 350);
    expect(visible(220).first, 350);
    expect(visible(370), visible(200).skip(1).toList());
    expect(
      ProofCourse.fixedPositions(origin: 0, spacing: 0, near: 0, far: 10),
      isEmpty,
    );
  });

  test(
    'chapter offset starts a fresh local attempt without forged route mileage',
    () {
      final race = RaceController()
        ..start(
          proofCar,
          seed: 731,
          reactiveTraffic: true,
          testCourse: true,
          courseStartDistance: 4200,
          launchSpeed: 110,
        );
      expect(race.elapsed, 0);
      expect(race.worldDistance, 0);
      expect(race.distanceMiles, 0);
      expect(race.courseDistance, 4200);
      expect(race.remaining, greaterThan(120));
      expect(race.closureStart, 100);
      race.tick(.2);
      expect(
        race.worldDistance - race.edgeDistance + race.closureStart,
        closeTo(100, .001),
      );
      expect(race.courseDistance - race.worldDistance, 4200);
      race.dispose();
    },
  );

  test('actual proof steering responds immediately but ramps magnitude', () {
    final race = RaceController()
      ..start(proofCar, seed: 731, testCourse: true, launchSpeed: 110);
    race.steering = 1;
    race.tick(1 / 60);
    expect(race.effectiveSteering, greaterThan(0));
    expect(race.effectiveSteering, lessThan(.12));
    final first = race.playerX;
    race.tick(.15);
    expect(race.effectiveSteering, greaterThan(.8));
    expect(race.playerX, greaterThan(first));
    race.start(proofCar, seed: 731);
    race.steering = 1;
    expect(race.effectiveSteering, 1, reason: 'legacy behavior stays direct');
    race.dispose();
  });
  test(
    'grade pitches the horizon while leaving the player ground anchor fixed',
    () {
      final climb = ProofCourse.pitchAt(2500, 20.4);
      final descent = ProofCourse.pitchAt(3600, 20.4);
      expect(climb, greaterThan(.1));
      expect(descent, lessThan(-.1));
      expect(ProofCourse.pitchShift(climb, 560), 0);
      expect(ProofCourse.pitchShift(descent, 560), 0);
      expect(ProofCourse.pitchShift(climb, 100000), greaterThan(.1));
      expect(ProofCourse.pitchShift(descent, 100000), lessThan(-.1));
    },
  );

  test('tunnel modules suppress outdoor vegetation until the exit', () {
    expect(ProofCourse.vegetationAllowedAt(6000), isTrue);
    expect(ProofCourse.vegetationAllowedAt(6100), isFalse);
    expect(ProofCourse.vegetationAllowedAt(6400), isFalse);
    expect(ProofCourse.vegetationAllowedAt(6810), isFalse);
    expect(ProofCourse.vegetationAllowedAt(6900), isTrue);
  });
}
