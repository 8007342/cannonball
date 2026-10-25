import 'package:cannonball/game/race.dart';
import 'package:cannonball/game/traffic.dart';
import 'package:flutter_test/flutter_test.dart';

TrafficCar car(
  int id,
  double z,
  double x,
  double speed, {
  TrafficProfile profile = TrafficProfile.ordinary,
}) => TrafficCar(
  id: id,
  position: z,
  x: x,
  cruiseSpeed: speed,
  color: 0xffffffff,
  truck: false,
  changeAt: 100,
  profile: profile,
);

void step(
  ReactiveTraffic policy,
  List<TrafficCar> cars,
  double time, {
  double playerZ = -1000,
  double playerX = 1.5,
  double playerSpeed = 100,
  double lateralSpeed = 0,
}) {
  policy.tick(
    cars: cars,
    dt: 1 / 60,
    time: time,
    playerPosition: playerZ,
    playerX: playerX,
    playerSpeed: playerSpeed,
    playerLateralSpeed: lateralSpeed,
    distanceScale: .52,
  );
}

void main() {
  test('a close lateral pass makes a bounded smooth flinch then recovers', () {
    final policy = ReactiveTraffic();
    final npc = car(1, 20, .55, 85);
    final cars = [npc];
    step(
      policy,
      cars,
      0,
      playerZ: 0,
      playerX: .1,
      playerSpeed: 160,
      lateralSpeed: 1,
    );
    expect(policy.reactions, 1);
    expect(npc.reactionIntensity, greaterThan(0));
    expect(npc.reactionOffset, greaterThan(0));
    expect(npc.reactionOffset, lessThan(.01));
    for (var i = 1; i < 60; i++) {
      step(policy, cars, i / 60, playerZ: 0, playerX: .1, playerSpeed: 160);
      expect(npc.reactionOffset.abs(), lessThanOrEqualTo(.12));
    }
    expect(
      policy.reactions,
      1,
      reason: 'sustained proximity cannot retrigger every frame',
    );
    for (var i = 60; i < 240; i++) {
      step(policy, cars, i / 60);
    }
    expect(npc.reactionOffset.abs(), lessThan(.001));
  });
  test(
    'fast followers brake behind slower leaders without random lane motion',
    () {
      final policy = ReactiveTraffic();
      final follower = car(1, 0, 0, 100), leader = car(2, 80, 0, 40);
      step(policy, [follower, leader], 0);
      expect(follower.braking, isTrue);
      expect(follower.currentSpeed, lessThan(100));
      expect(follower.targetX, isNull);
      expect(follower.x, 0);
    },
  );
  test(
    'panic braking propagates to a following driver through observed gaps',
    () {
      final policy = ReactiveTraffic();
      final startled = car(1, 5, 0, 90, profile: TrafficProfile.cautious),
          following = car(2, -115, 0, 100);
      final cars = [startled, following];
      step(
        policy,
        cars,
        0,
        playerZ: 0,
        playerX: .27,
        playerSpeed: 160,
        lateralSpeed: -1,
      );
      expect(startled.braking, isTrue);
      expect(startled.reactionIntensity, 1);
      final prior = following.currentSpeed;
      for (var i = 1; i < 20; i++) {
        step(policy, cars, i / 60, playerZ: 20, playerX: .27, playerSpeed: 160);
      }
      expect(following.braking, isTrue);
      expect(following.currentSpeed, lessThan(prior));
    },
  );
  test(
    'secondary contact produces a bounded incident with an incident cooldown',
    () {
      final policy = ReactiveTraffic();
      final cars = [car(1, 0, 0, 120), car(2, 5, 0, 20)];
      step(policy, cars, 0);
      expect(policy.incidents, 1);
      expect(cars.every((c) => c.incidentSeconds > 0 && c.braking), isTrue);
      for (var i = 1; i < 50; i++) {
        step(policy, cars, i / 60);
      }
      expect(policy.incidents, 1);
      expect(
        cars.every((c) => c.currentSpeed >= 0 && c.x.abs() <= .81),
        isTrue,
      );
    },
  );
  test('lane changes have a passing motive and maintain a cooldown', () {
    final policy = ReactiveTraffic();
    final follower = car(1, 0, 0, 100)..changeAt = 0;
    final leader = car(2, 75, 0, 35);
    final cars = [follower, leader];
    step(policy, cars, 0);
    expect(follower.targetX, isNotNull);
    final target = follower.targetX;
    for (var i = 1; i < 60; i++) {
      step(policy, cars, i / 60);
      expect(follower.targetX, target);
    }
    expect(follower.laneCenter, 0, reason: 'signals precede the lateral move');
  });
  test(
    'reactive fixed-step schedules are deterministic and launch is opt-in',
    () {
      final slow = RaceController()
        ..start(cars.last, seed: 731, reactiveTraffic: true, launchSpeed: 110);
      final fast = RaceController()
        ..start(cars.last, seed: 731, reactiveTraffic: true, launchSpeed: 110);
      expect(slow.speed, 110);
      for (var i = 0; i < 900; i++) {
        slow.tick(1 / 30);
      }
      for (var i = 0; i < 3600; i++) {
        fast.tick(1 / 120);
      }
      expect(slow.elapsed, fast.elapsed);
      expect(slow.playerX, fast.playerX);
      expect(slow.speed, fast.speed);
      expect(
        slow.traffic
            .map(
              (c) => [
                c.id,
                c.position,
                c.x,
                c.currentSpeed,
                c.profile,
                c.reactionIntensity,
              ],
            )
            .toList(),
        fast.traffic
            .map(
              (c) => [
                c.id,
                c.position,
                c.x,
                c.currentSpeed,
                c.profile,
                c.reactionIntensity,
              ],
            )
            .toList(),
      );
      expect(slow.trafficReactionCount, fast.trafficReactionCount);
      slow.start(cars.first, seed: 731);
      expect(slow.reactiveTrafficEnabled, isFalse);
      expect(slow.speed, 0);
      expect(slow.trafficReactionCount, 0);
    },
  );
}
