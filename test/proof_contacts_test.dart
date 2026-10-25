import 'package:cannonball/game/proof_contacts.dart';
import 'package:cannonball/game/proof_car.dart';
import 'package:cannonball/game/race.dart';
import 'package:flutter_test/flutter_test.dart';

bool touch(
  ProofCollisionGate gate, {
  int id = 1,
  double x = 0,
  double toX = 0,
  double z = 0,
  double toZ = 0,
  double dt = 1 / 60,
}) => gate.update(
  id: id,
  dt: dt,
  fromForward: z,
  toForward: toZ,
  fromLateral: x,
  toLateral: toX,
  halfDepth: 3,
  halfWidth: .18,
);

RaceController proof({double start = 0, double speed = 100}) => RaceController()
  ..start(
    proofCar,
    seed: 731,
    testCourse: true,
    reactiveTraffic: true,
    launchSpeed: speed,
    courseStartDistance: start,
  )
  ..traffic.clear();
TrafficCar npc(double gap, double speed) => TrafficCar(
  id: 999,
  position: gap,
  x: 0,
  cruiseSpeed: speed,
  color: 0xffffffff,
  truck: false,
  changeAt: 9999,
);

void main() {
  test('swept overlap requires forward and lateral slabs at the same time', () {
    final interval = ProofCollisionGate.overlapInterval(
      fromForward: 10,
      toForward: -10,
      fromLateral: 0,
      toLateral: 0,
      halfDepth: 3,
      halfWidth: .18,
    )!;
    expect(interval.$1, closeTo(.35, 1e-9));
    expect(interval.$2, closeTo(.65, 1e-9));
    expect(
      ProofCollisionGate.overlapInterval(
        fromForward: 10,
        toForward: -10,
        fromLateral: .2,
        toLateral: .2,
        halfDepth: 3,
        halfWidth: .18,
      ),
      isNull,
    );
  });
  test(
    'brief overlap can be corrected and does not leave a delayed ghost hit',
    () {
      final gate = ProofCollisionGate();
      expect(touch(gate), isFalse);
      expect(touch(gate), isFalse);
      expect(touch(gate, toX: .5), isFalse);
      expect(touch(gate, x: .5, toX: .5), isFalse);
      expect(
        touch(gate),
        isFalse,
        reason: 'reentry starts a fresh grace window',
      );
      expect(touch(gate), isFalse);
      expect(touch(gate), isTrue);
    },
  );
  test('partial-step contact uses actual overlap time, not whole frames', () {
    final gate = ProofCollisionGate();
    expect(touch(gate, z: 6, toZ: 0, dt: .04), isFalse); // .02s inside
    expect(touch(gate, dt: .02), isFalse); // .04s total
    expect(touch(gate, dt: .01), isTrue); // .05s total
    gate.clear();
    expect(touch(gate, z: 10, toZ: -10, dt: .1), isFalse); // complete .03s pass
    expect(touch(gate), isFalse);
  });
  test('a car visibly ahead does not trigger the old broad ghost collider', () {
    final race = proof();
    race.traffic.add(npc(18, 100));
    race.tick(1 / 60);
    expect(race.recovering, isFalse);
    expect(race.crashes, 0);
    race.dispose();
  });
  test('sustained actual rear overlap still crashes after the short grace', () {
    final race = proof();
    race.traffic.add(npc(1, 100));
    race.tick(1 / 60);
    expect(race.recovering, isFalse);
    race.tick(1 / 60);
    expect(race.recovering, isFalse);
    race.tick(1 / 60);
    expect(race.recovering, isTrue);
    expect(race.crashes, 1);
    race.dispose();
  });
  test('marked closed lane is not an invisible solid obstacle in proof', () {
    final race = proof(start: 4400);
    race.playerX = .65;
    race.tick(1 / 60);
    expect(race.inLaneClosure, isTrue);
    expect(race.recovering, isFalse);
    expect(race.crashes, 0);
    race.dispose();
  });
  test('cones scatter exactly once and flights expire without crashing', () {
    final race = proof(start: 4120, speed: 95);
    race.playerX = 1;
    race.tick(1 / 60);
    expect(race.coneHitCount, 1);
    expect(race.coneFlights.length, 1);
    expect(race.isConeHit(race.coneFlights.first.cone.id), isTrue);
    expect(race.recovering, isFalse);
    race.tick(1 / 60);
    expect(race.coneHitCount, 1);
    expect(race.coneFlights.first.age, greaterThan(0));
    // Stop steering through the construction line; existing flight fades out.
    race.playerX = -.65;
    for (var i = 0; i < 90; i++) {
      race.tick(1 / 60);
    }
    expect(race.coneFlights, isEmpty);
    expect(race.crashes, 0);
    race.dispose();
  });
}
