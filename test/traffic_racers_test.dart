import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:cannonball/game/proof_car.dart';
import 'package:cannonball/game/race.dart';
import 'package:cannonball/game/traffic.dart';
import 'package:cannonball/game/traffic_policy/racer_observation.dart';
import 'package:cannonball/game/traffic_policy/racer_policy.dart';
import 'package:cannonball/game/traffic_policy/racer_policy_loader.dart';
import 'package:cannonball/game/traffic_policy/sha256.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const bundlePath = 'assets/traffic/racer-policy.json';

RacerPolicy loadPolicy() {
  final result = RacerPolicy.tryParse(File(bundlePath).readAsStringSync());
  expect(result.error, isNull);
  return result.policy!;
}

TrafficCar npc(
  int id,
  double z,
  double x,
  double speed, {
  bool truck = false,
}) => TrafficCar(
  id: id,
  position: z,
  x: x,
  cruiseSpeed: speed,
  color: 0xffffffff,
  truck: truck,
  changeAt: 1e9,
);

TrafficCar racer(
  int id,
  double z,
  double x,
  double speed, {
  double cap = 155,
}) => TrafficCar(
  id: id,
  position: z,
  x: x,
  cruiseSpeed: speed,
  color: 0xffffffff,
  truck: false,
  changeAt: 0,
  profile: TrafficProfile.racer,
  modelId: 'pony_coupe',
  racerCap: cap,
);

class RunStats {
  int racerOverlaps = 0, playerOverlaps = 0, laneViolations = 0;
  double maxLateralStep = 0;
}

/// Steps a pure ReactiveTraffic world with a player holding speed and lane.
RunStats simulate(
  ReactiveTraffic traffic,
  List<TrafficCar> cars, {
  required double seconds,
  double playerSpeed = 110,
  double playerX = 0,
  double Function(double time)? playerXAt,
  int? closedLane,
  double closureStart = double.infinity,
  double closureEnd = double.infinity,
  void Function(double time, double playerZ)? onStep,
}) {
  const dt = 1 / 60;
  final run = RunStats();
  var playerZ = 0.0;
  final steps = (seconds / dt).round();
  for (var step = 0; step < steps; step++) {
    final time = step * dt;
    final px = playerXAt?.call(time) ?? playerX;
    final before = {for (final c in cars) c.id: c.laneCenter};
    traffic.tick(
      cars: cars,
      dt: dt,
      time: time,
      playerPosition: playerZ,
      playerX: px,
      playerLateralSpeed: 0,
      playerSpeed: playerSpeed,
      distanceScale: .52,
      closedLane: closedLane,
      closureStart: closureStart,
      closureEnd: closureEnd,
    );
    playerZ += playerSpeed * .52 * dt;
    for (final c in cars.where((c) => c.isRacer)) {
      run.maxLateralStep = math.max(
        run.maxLateralStep,
        (c.laneCenter - before[c.id]!).abs(),
      );
      if (c.x.abs() > .81) run.laneViolations++;
      for (final o in cars) {
        if (!identical(o, c) &&
            (o.position - c.position).abs() < 10 &&
            (o.x - c.x).abs() < .2) {
          run.racerOverlaps++;
        }
      }
      if ((playerZ - c.position).abs() < 24 && (px - c.x).abs() < .22) {
        run.playerOverlaps++;
      }
    }
    onStep?.call(time, playerZ);
  }
  return run;
}

List<TrafficCar> slowTraffic() => [
  npc(1, 120, 0, 70),
  npc(2, 260, -.65, 76),
  npc(3, 330, .65, 68, truck: true),
  npc(4, 480, 0, 80),
  npc(5, 640, -.65, 72),
  npc(6, 700, .65, 82),
];

void main() {
  tearDown(RacerPolicyStore.reset);

  test('sha256 matches the FIPS test vector', () {
    expect(
      sha256Hex(Uint8List.fromList(utf8.encode('abc'))),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });

  test('bundled classifier loads with Rust/Dart encoder and logit parity', () {
    final policy = loadPolicy();
    final bundle =
        jsonDecode(File(bundlePath).readAsStringSync()) as Map<String, dynamic>;
    expect(policy.modelId, startsWith('racer-policy-v1-'));
    expect(policy.inputSize, racerObservationSize);
    expect(policy.paramCount, bundle['paramCount']);
    final fixtures = bundle['fixtures'] as List;
    expect(fixtures.length, greaterThanOrEqualTo(5));
    final actions = <int>{};
    for (final fixture in fixtures.cast<Map<String, dynamic>>()) {
      final scene = RacerScene.fromJson(fixture['scene']);
      final observation = encodeRacerObservation(scene);
      expect(observation, [
        for (final v in fixture['observation'] as List) (v as num).toDouble(),
      ]);
      final mask = racerSafetyMask(scene);
      expect(mask, fixture['mask']);
      expect(ruleRacerAction(scene, mask), fixture['ruleAction']);
      final logits = policy.logits(observation);
      final expected = fixture['logits'] as List;
      for (var i = 0; i < logits.length; i++) {
        expect(logits[i], closeTo((expected[i] as num).toDouble(), 1e-12));
      }
      actions.add(policy.decide(observation, mask));
    }
    expect(
      actions.length,
      greaterThanOrEqualTo(3),
      reason: 'fixtures cover several actions',
    );
    final training = bundle['training'] as Map<String, dynamic>;
    expect(training['heldoutAccuracy'], greaterThan(.85));
  });

  test('incompatible or tampered bundles fall back to rules', () async {
    final text = File(bundlePath).readAsStringSync();
    final bundle = jsonDecode(text) as Map<String, dynamic>;
    String variant(void Function(Map<String, dynamic>) edit) {
      final copy = jsonDecode(text) as Map<String, dynamic>;
      edit(copy);
      return jsonEncode(copy);
    }

    final weights = base64Decode(bundle['weights'] as String);
    final flipped = Uint8List.fromList(weights)..[17] ^= 0x40;
    final cases = {
      'schema': variant((b) => b['observationSchema'] = 'other-v9'),
      'actions': variant((b) => b['actions'] = ['keep', 'left', 'right']),
      'format': variant((b) => b['format'] = 'atrapa-dense-v1'),
      'checksum': variant((b) => b['weights'] = base64Encode(flipped)),
      'shape': variant((b) => (b['layers'] as List).first['inputs'] = 23),
      'fixture': variant(
        (b) => ((b['fixtures'] as List).first as Map)['action'] = 99,
      ),
      'garbage': '{not json',
    };
    for (final entry in cases.entries) {
      final result = RacerPolicy.tryParse(entry.value);
      expect(result.isReady, isFalse, reason: entry.key);
      expect(result.error, isNotNull);
    }
    final missing = await RacerPolicyStore.load(bundle: _EmptyBundle());
    expect(missing.isReady, isFalse);
    expect(RacerPolicyStore.shared, isNull);
    expect(RacerPolicyStore.status, startsWith('fallback rules'));
    final controller = RaceController()
      ..start(proofCar, seed: 11, reactiveTraffic: true, launchSpeed: 80);
    expect(controller.racerPolicyId, 'rules');
    controller.dispose();
  });

  test('safety mask blocks occupied, closed and player lanes', () {
    RacerScene scene({
      List<RacerOther> others = const [],
      double playerZ = -900,
      double playerX = 0,
      int? closedLane,
      bool changing = false,
      double laneCenter = 0,
    }) => RacerScene(
      z: 0,
      x: laneCenter,
      laneCenter: laneCenter,
      speed: 140,
      cruise: 140,
      changing: changing,
      others: others,
      playerZ: playerZ,
      playerX: playerX,
      playerSpeed: 110,
      closedLane: closedLane,
      closureStart: 200,
      closureEnd: 800,
    );
    final open = racerSafetyMask(scene(playerX: 1.5));
    expect(open, [true, true, true, true, true]);
    // A car alongside on the left; a car signalling into the right lane.
    final busy = racerSafetyMask(
      scene(
        playerX: 1.5,
        others: const [RacerOther(5, -.65, 120), RacerOther(15, 0.0, 120, .65)],
      ),
    );
    expect(busy[racerLeft], isFalse);
    expect(busy[racerRight], isFalse);
    expect(busy[racerAccelerate], isFalse, reason: 'merging car is 15 ahead');
    expect(busy[racerKeep] && busy[racerBrake], isTrue);
    // The player gets a wide berth.
    expect(
      racerSafetyMask(scene(playerZ: 50, playerX: .65))[racerRight],
      isFalse,
    );
    expect(racerSafetyMask(scene(closedLane: 2))[racerRight], isFalse);
    final midMove = racerSafetyMask(scene(changing: true, playerX: 1.5));
    expect(midMove[racerLeft] || midMove[racerRight], isFalse);
    expect(racerSafetyMask(scene(laneCenter: -.65))[racerLeft], isFalse);
    // Fuzz: the masked decision never picks a disallowed action.
    final policy = loadPolicy();
    final random = math.Random(5);
    for (var i = 0; i < 2000; i++) {
      final s = RacerScene(
        z: 0,
        x: racerLanes[i % 3],
        laneCenter: racerLanes[i % 3],
        speed: 60 + random.nextDouble() * 100,
        cruise: 130 + random.nextDouble() * 20,
        changing: false,
        others: [
          for (var j = 0; j < 8; j++)
            RacerOther(
              random.nextDouble() * 600 - 200,
              racerLanes[random.nextInt(3)],
              50 + random.nextDouble() * 70,
            ),
        ],
        playerZ: random.nextDouble() * 400 - 200,
        playerX: racerLanes[random.nextInt(3)],
        playerSpeed: 80 + random.nextDouble() * 70,
      );
      final mask = racerSafetyMask(s);
      expect(mask[policy.decide(encodeRacerObservation(s), mask)], isTrue);
      expect(mask[ruleRacerAction(s, mask)], isTrue);
    }
  });

  for (final learned in [true, false]) {
    final label = learned ? 'learned' : 'rule fallback';
    test('$label racers weave past traffic and the player without overlap', () {
      final traffic = ReactiveTraffic(
        racerPolicy: learned ? loadPolicy() : null,
      );
      final fast = racer(9, -200, .65, 142);
      final cars = [fast, ...slowTraffic()];
      final run = simulate(traffic, cars, seconds: 40);
      expect(fast.position, greaterThan(40 * 110 * .52), reason: 'passed us');
      expect(fast.racerLaneChanges, greaterThanOrEqualTo(2), reason: 'weaves');
      expect(run.racerOverlaps, 0);
      expect(run.playerOverlaps, 0);
      expect(run.laneViolations, 0);
      expect(
        run.maxLateralStep,
        lessThanOrEqualTo(racerLateralRate / 60 + 1e-9),
        reason: 'continuous moves, no teleporting',
      );
      expect(traffic.incidents, 0);
      expect(traffic.racerDecisions, greaterThan(150));
      expect(traffic.policyDecisions, learned ? traffic.racerDecisions : 0);
    });
  }

  test('racers stay safe across randomized dense traffic', () {
    final policy = loadPolicy();
    var overlaps = 0, playerOverlaps = 0, changes = 0;
    for (var seed = 0; seed < 24; seed++) {
      final random = math.Random(seed);
      final cars = <TrafficCar>[
        racer(100, -150 - random.nextDouble() * 100, racerLanes[seed % 3], 140),
      ];
      for (var i = 0; i < 12; i++) {
        final z = 80 + i * 70 + random.nextDouble() * 30;
        cars.add(
          npc(
            i,
            z,
            racerLanes[random.nextInt(3)],
            60 + random.nextDouble() * 40,
          )..changeAt = random.nextDouble() * 6,
        );
      }
      final run = simulate(
        ReactiveTraffic(racerPolicy: seed.isEven ? policy : null),
        cars,
        seconds: 30,
        playerSpeed: 100 + random.nextDouble() * 40,
        playerX: racerLanes[random.nextInt(3)],
      );
      overlaps += run.racerOverlaps;
      playerOverlaps += run.playerOverlaps;
      changes += cars.first.racerLaneChanges;
    }
    expect(overlaps, 0);
    expect(playerOverlaps, 0);
    expect(changes, greaterThan(24));
  });

  test('a passed racer chases hard and sometimes re-passes', () {
    final traffic = ReactiveTraffic(racerPolicy: loadPolicy());
    final fast = racer(2, 60, -.65, 132, cap: 155);
    var boosted = false;
    var topSpeed = 0.0;
    var aheadAgainAfterPass = false;
    var passed = false;
    simulate(
      traffic,
      [fast],
      seconds: 30,
      playerSpeed: 140,
      onStep: (time, playerZ) {
        boosted |= fast.boosting;
        topSpeed = math.max(topSpeed, fast.currentSpeed);
        if (fast.passedByPlayer > 0) passed = true;
        if (passed && fast.position > playerZ) aheadAgainAfterPass = true;
      },
    );
    expect(fast.passedByPlayer, greaterThanOrEqualTo(1));
    expect(boosted, isTrue);
    expect(topSpeed, greaterThan(140), reason: 'accelerates past cruise');
    expect(topSpeed, lessThanOrEqualTo(155 + 5));
    // id 2 + first pass => (2 + 1) % 3 == 0: this racer tries to re-pass.
    expect(aheadAgainAfterPass, isTrue);
  });

  test('racers merge out of a construction closure before it starts', () {
    final traffic = ReactiveTraffic(racerPolicy: loadPolicy());
    final fast = racer(3, 0, .65, 140);
    final cars = [fast, npc(1, 150, 0, 80), npc(2, 400, -.65, 75)];
    var inside = 0;
    simulate(
      traffic,
      cars,
      seconds: 20,
      playerSpeed: 90,
      playerX: -1.5,
      closedLane: 1,
      closureStart: 600,
      closureEnd: 1300,
      onStep: (_, _) {
        if (fast.position > 600 &&
            fast.position < 1300 &&
            (fast.x - .65).abs() < .2) {
          inside++;
        }
      },
    );
    expect(inside, 0);
    expect(fast.position, greaterThan(1300));
  });

  test('controller traffic has a wide speed mix and rare sporty racers', () {
    final cruise = <TrafficProfile, List<double>>{};
    final seen = <int>{};
    var racers = 0, total = 0;
    for (final seed in [3, 17, 731, 4242]) {
      final controller = RaceController()
        ..start(
          proofCar,
          seed: seed,
          reactiveTraffic: true,
          testCourse: true,
          denseTraffic: true,
          launchSpeed: 90,
        );
      for (var i = 0; i < 60 * 120; i++) {
        controller.tick(1 / 60);
        if (controller.finished) break;
        for (final car in controller.traffic) {
          if (!seen.add(seed * 100000 + car.id)) continue;
          total++;
          cruise.putIfAbsent(car.profile, () => []).add(car.cruiseSpeed);
          if (car.isRacer) {
            racers++;
            expect(car.truck, isFalse);
            expect(car.modelId, isNotNull);
            expect(
              car.cruiseSpeed / proofCar.topSpeed,
              inInclusiveRange(.88, .97),
            );
          }
        }
      }
      controller.dispose();
    }
    final all = cruise.values.expand((v) => v).toList()..sort();
    expect(total, greaterThan(60));
    expect(all.first, lessThan(66), reason: 'slow trucks/cautious drivers');
    final nonRacer = [
      for (final e in cruise.entries)
        if (e.key != TrafficProfile.racer) ...e.value,
    ];
    expect(nonRacer.reduce(math.max), greaterThan(100));
    expect(racers / total, inInclusiveRange(.02, .12));
  });

  test('racer traffic is deterministic at 30 and 120 Hz with the policy', () {
    RacerPolicyStore.shared = loadPolicy();
    List<Object> state(RaceController c) => [
      c.racerPolicyId,
      c.racerDecisionCount,
      for (final car in c.traffic) ...[
        car.id,
        car.position,
        car.x,
        car.currentSpeed,
        car.profile,
        car.racerAction,
        car.racerLaneChanges,
      ],
    ];
    final slow = RaceController()
      ..start(proofCar, seed: 4242, reactiveTraffic: true, launchSpeed: 90);
    final fast = RaceController()
      ..start(proofCar, seed: 4242, reactiveTraffic: true, launchSpeed: 90);
    for (var i = 0; i < 30 * 90; i++) {
      slow.tick(1 / 30);
    }
    for (var i = 0; i < 120 * 90; i++) {
      fast.tick(1 / 120);
    }
    expect(slow.racerPolicyId, startsWith('racer-policy-v1-'));
    expect(slow.racerDecisionCount, greaterThan(0));
    expect(state(slow), state(fast));
    slow.dispose();
    fast.dispose();
  });

  test('racer decisions are cheap enough for mobile frames', () {
    final policy = loadPolicy();
    final bundle =
        jsonDecode(File(bundlePath).readAsStringSync()) as Map<String, dynamic>;
    final scenes = [
      for (final f in (bundle['fixtures'] as List).cast<Map<String, dynamic>>())
        RacerScene.fromJson(f['scene']),
    ];
    final watch = Stopwatch()..start();
    var decisions = 0;
    while (watch.elapsedMilliseconds < 300) {
      for (final s in scenes) {
        policy.decide(encodeRacerObservation(s), racerSafetyMask(s));
        decisions++;
      }
    }
    final perSecond = decisions / (watch.elapsedMicroseconds / 1e6);
    // ignore: avoid_print
    print(
      'dart racer decisions/s (VM, encode+mask+forward): ${perSecond.round()}',
    );
    // Two racers at 5 decisions/s each need 10/s; demand five orders more.
    expect(perSecond, greaterThan(10000));
  });
}

class _EmptyBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      throw StateError('Unable to load asset: $key');
}
