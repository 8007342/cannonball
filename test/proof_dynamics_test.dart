import 'package:cannonball/game/proof_dynamics.dart';
import 'package:cannonball/game/proof_car.dart';
import 'package:cannonball/game/race.dart';
import 'package:flutter_test/flutter_test.dart';

double acceleration(double speed, {double steer = 0, double rate = 0}) =>
    ProofDynamics.acceleration(
      speed: speed,
      topSpeed: 155,
      engineAcceleration: 42,
      steering: steer,
      steeringRate: rate,
      grade: 0,
    );

void main() {
  test('launch takes time and acceleration tapers near the limit', () {
    var speed = 0.0;
    for (var i = 0; i < 360; i++) {
      speed += acceleration(speed) / 60;
    }
    expect(speed, inInclusiveRange(55, 75));
    expect(acceleration(150), lessThan(acceleration(60) * .15));
    expect(acceleration(150), greaterThan(0));
  });
  test(
    'gentle steady steering preserves thrust, hard corrections bleed speed',
    () {
      expect(acceleration(150, steer: .1), acceleration(150));
      expect(acceleration(150, steer: 1), lessThan(-8));
      expect(acceleration(150, steer: .1, rate: 5), lessThan(0));
    },
  );
  test('proof traffic starts staggered and remains deterministic', () {
    RaceController create() =>
        RaceController()
          ..start(proofCar, seed: 731, testCourse: true, reactiveTraffic: true);
    final a = create(), b = create();
    expect(a.speed, 0);
    expect(a.traffic.length, 4);
    expect(a.traffic.first.position, inInclusiveRange(95, 120));
    for (var i = 1; i < a.traffic.length; i++) {
      expect(
        a.traffic[i].position - a.traffic[i - 1].position,
        greaterThan(60),
      );
    }
    expect(
      a.traffic.map((t) => t.position).toList(),
      b.traffic.map((t) => t.position).toList(),
    );
    for (var i = 0; i < 600; i++) {
      a.tick(1 / 60);
      b.tick(1 / 60);
    }
    expect(a.worldDistance, b.worldDistance);
    expect(
      a.traffic.map((t) => t.position).toList(),
      b.traffic.map((t) => t.position).toList(),
    );
    a.dispose();
    b.dispose();
  });
}
