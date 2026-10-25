import 'dart:convert';
import 'dart:math' as math;

import 'package:cannonball/game/race.dart';
import 'package:flutter_test/flutter_test.dart';

void advance(RaceController race, double seconds, {double frame = 1 / 60}) {
  for (var i = 0; i < (seconds / frame).round(); i++) {
    race.tick(frame);
  }
}

/// A reactive test driver uses only the same steering and brake inputs as a
/// player. No clock edits, position teleporting or deleted traffic during runs.
void drive(RaceController race, {Set<String> preferredEdges = const {}}) {
  while (!race.finished && race.elapsed < 1400) {
    var target = 0.0;
    final nearby = race.traffic
        .where(
          (t) =>
              t.position - race.worldDistance > -70 &&
              t.position - race.worldDistance < 390,
        )
        .toList();
    final options = [-.65, 0.0, .65];
    bool safe(double x) {
      final closureAhead =
          race.closedLane != null &&
          race.edgeDistance > race.closureStart - 350 &&
          race.edgeDistance < race.closureEnd + 80;
      if (closureAhead && (x - race.closedLane! * .65).abs() < .3) return false;
      return nearby.every(
        (t) =>
            (t.x - x).abs() > .31 &&
            (t.targetX == null || (t.targetX! - x).abs() > .31),
      );
    }

    final clear = options.where(safe).toList()
      ..sort(
        (a, b) => ((a - race.playerX).abs() + a.abs() * .10).compareTo(
          (b - race.playerX).abs() + b.abs() * .10,
        ),
      );
    if (clear.isNotEmpty) target = clear.first;
    if (race.approachingFork && race.distanceToFork < 300) {
      final choices = race.nextChoices;
      final preferred = choices
          .where(
            (e) => preferredEdges.contains(e.id) && e.id != race.closedBranchId,
          )
          .firstOrNull;
      if (preferred != null) {
        target = preferred == choices.first ? -.50 : .50;
      } else if (race.closedBranchId == choices.first.id) {
        target = .50;
      } else {
        target = -.50;
      }
    }
    final ratio = race.speed / race.car.topSpeed;
    final grip = race.weather == RaceWeather.snow
        ? .82
        : race.weather == RaceWeather.rain
        ? .91
        : 1.0;
    race.steering =
        ((target - race.playerX) * 4 +
            race.curveAt(race.worldDistance) * ratio * ratio * .23) /
        (race.car.handling * grip * (.2 + ratio * 1.15));
    race.steering = race.steering.clamp(-1, 1);
    race.braking =
        clear.isEmpty &&
        nearby.any((t) => t.position - race.worldDistance < 210);
    race.tick(1 / 60);
  }
}

void main() {
  test(
    'all authored corridors reach the Pacific and have sensible metadata',
    () {
      final ids = routeGraph.nodes.map((n) => n.id).toSet();
      expect(ids.length, routeGraph.nodes.length);
      bool reaches(String node, Set<String> ancestors) {
        if (node == 'redondo') return true;
        expect(
          ancestors.contains(node),
          isFalse,
          reason: 'graph cycle at $node',
        );
        final outgoing = routeGraph.outgoing(node);
        return outgoing.isNotEmpty &&
            outgoing.every((e) => reaches(e.to, {...ancestors, node}));
      }

      for (final edge in routeGraph.edges) {
        expect(ids.contains(edge.from) && ids.contains(edge.to), isTrue);
        expect(edge.miles, greaterThan(0));
        expect(edge.road, isNotEmpty);
        expect(reaches(edge.to, {}), isTrue);
      }
      expect(reaches('ny', {}), isTrue);
    },
  );

  test('fixed-step simulation gives identical state across frame rates', () {
    final a = RaceController()..start(cars.first, seed: 731);
    final b = RaceController()..start(cars.first, seed: 731);
    advance(a, 70, frame: 1 / 30);
    advance(b, 70, frame: 1 / 120);
    expect(a.elapsed, b.elapsed);
    expect(a.distanceMiles, closeTo(b.distanceMiles, 1e-9));
    expect(a.playerX, closeTo(b.playerX, 1e-9));
    expect(a.remaining, closeTo(b.remaining, 1e-9));
    expect(a.crashes, b.crashes);
    expect(
      a.traffic.map((t) => [t.id, t.position, t.x]),
      b.traffic.map((t) => [t.id, t.position, t.x]),
    );
  });

  test('auto acceleration, braking and pause respect the race clock', () {
    final race = RaceController()..start(cars.first, seed: 1);
    advance(race, 4);
    expect(race.speed, greaterThan(80));
    race.braking = true;
    advance(race, .5);
    expect(race.speed, lessThan(60));
    final elapsed = race.elapsed,
        miles = race.distanceMiles,
        countdown = race.remaining;
    race.paused = true;
    advance(race, 10);
    expect(race.elapsed, elapsed);
    expect(race.distanceMiles, miles);
    expect(race.remaining, countdown);
    race.paused = false;
    race.braking = false;
    advance(race, 1);
    expect(race.elapsed, closeTo(elapsed + 1, 1e-8));
    expect(race.speed, greaterThan(60));
  });

  test('notifications are bounded and nonfinite input cannot poison state', () {
    final race = RaceController()..start(cars.first, seed: 1);
    var updates = 0;
    race.addListener(() => updates++);
    race.steering = double.nan;
    race.tick(double.infinity);
    advance(race, 1, frame: 1 / 120);
    expect(updates, inInclusiveRange(19, 20));
    expect(race.playerX.isFinite, isTrue);
    expect(race.elapsed, closeTo(1, 1e-8));
  });

  test('gates extend countdown once without subtracting elapsed time', () {
    final race = RaceController()..start(cars.first, seed: 64);
    while (race.gatesPassed == 0 && !race.finished) {
      race.steering =
          (-race.playerX * 4 + race.curveAt(race.worldDistance) * .23).clamp(
            -1,
            1,
          );
      race.tick(1 / 60);
    }
    expect(race.gatesPassed, 1);
    expect(race.remaining, closeTo(90 - race.elapsed + 45, 1e-6));
    expect(race.distanceMiles, greaterThanOrEqualTo(155));
    final elapsed = race.elapsed;
    advance(race, .5);
    expect(race.gatesPassed, 1);
    expect(race.elapsed, greaterThan(elapsed));
  });

  test('a rear-end impact recovers into a clear protected central lane', () {
    final race = RaceController()..start(cars.first, seed: 9);
    advance(race, 6);
    race.traffic.add(
      TrafficCar(
        id: 999,
        position: race.worldDistance + 5,
        x: race.playerX,
        cruiseSpeed: 35,
        color: 0xffffffff,
        truck: false,
        changeAt: 9999,
      ),
    );
    race.tick(1 / 60);
    expect(race.recovering, isTrue);
    expect(race.crashes, 1);
    expect(race.crashPose, CrashPose.flip);
    advance(race, 2.2);
    expect(race.recovering, isFalse);
    expect(race.playerX.abs(), lessThan(.05));
    expect(race.protection, greaterThan(2));
    expect(
      race.traffic.every((t) => (t.position - race.worldDistance).abs() > 350),
      isTrue,
    );
  });

  test('failure freezes a partial route receipt and new run resets it', () {
    final race = RaceController()..start(cars.first, seed: 81);
    race.braking = true;
    advance(race, 92);
    expect(race.finished, isTrue);
    expect(race.completed, isFalse);
    expect(race.receipt!.route.single.edgeId, 'hudson');
    expect(race.receipt!.route.single.fraction, 0);
    final record = jsonEncode(race.receipt!.toJson());
    advance(race, 50);
    expect(jsonEncode(race.receipt!.toJson()), record);
    race.start(cars[1], seed: 81);
    expect(race.finished, isFalse);
    expect(race.receipt, isNull);
    expect(race.elapsed, 0);
    expect(race.car.id, 'coupe');
  });

  test('seeded closures always leave a reachable open alternative', () {
    final observed = <String>{};
    for (var seed = 0; seed < 40; seed++) {
      final race = RaceController()..start(cars.first, seed: seed);
      for (final node in routeGraph.nodes) {
        final outgoing = routeGraph.outgoing(node.id);
        if (outgoing.isEmpty) continue;
        final open = outgoing.where(
          (e) => e.id != race.closedBranches[node.id],
        );
        expect(open, isNotEmpty, reason: 'all routes closed at ${node.id}');
        expect(open.every((e) => routeGraph.remainingMiles(e.to) >= 0), isTrue);
      }
      // Advance using normal controls through complete seeded routes.
      if (seed < 3) {
        drive(race);
        expect(
          race.completed,
          isTrue,
          reason: 'seed $seed, ${race.distanceMiles} miles at ${race.elapsed}s',
        );
        for (final visit in race.routeProgress) {
          observed.add(visit.edgeId);
          final edge = routeGraph.edge(visit.edgeId);
          expect(race.closedBranches[edge.from], isNot(edge.id));
        }
      }
    }
    expect(observed.length, greaterThan(7));
  });

  test('complete starter trip, route accounting and gate receipts are coherent', () {
    final race = RaceController()..start(cars.first, seed: 731);
    drive(race, preferredEdges: {'prairie', 'nebraska', 'rockies'});
    expect(
      race.completed,
      isTrue,
      reason:
          '${race.distanceMiles} miles in ${race.elapsed}s, ${race.crashes} crashes',
    );
    expect(race.elapsed, inInclusiveRange(600, 900));
    expect(race.routeProgress.last.edgeId, 'pacific');
    expect(race.routeProgress.every((e) => e.fraction == 1), isTrue);
    final miles = race.routeProgress.fold<double>(
      0,
      (sum, visit) =>
          sum + routeGraph.edge(visit.edgeId).miles * visit.fraction,
    );
    expect(race.distanceMiles, closeTo(miles, 1e-6));
    expect(race.gatesPassed, (miles / 155).floor());
    expect(race.receipt!.gates.toSet().length, race.gatesPassed);
    expect(race.earnedUnlockIds.contains('corvette'), isFalse);
  });

  test('secret detours award their keys and Corvette is the final unlock', () {
    final race = RaceController()
      ..unlockedCarIds = {'wagon', 'coupe', 'rally', 'muscle', 'grandtourer'};
    race.start(cars.last, seed: 731);
    drive(
      race,
      preferredEdges: {
        'allegheny',
        'prairie',
        'plains-backroad',
        'monarch-pass',
        'route66',
      },
    );
    expect(race.completed, isTrue);
    expect(race.earnedUnlockIds.contains('corvette'), isTrue);
    expect(race.elapsed, inInclusiveRange(600, 900));
    final discovery = RaceController()..start(cars.first, seed: 731);
    drive(
      discovery,
      preferredEdges: {
        'allegheny',
        'prairie',
        'plains-backroad',
        'monarch-pass',
      },
    );
    final traversed = discovery.visitedEdges.toSet();
    final expected = routeGraph.edges
        .where((e) => e.secret && traversed.contains(e.id))
        .map((e) => e.secretUnlockId!)
        .toSet();
    expect(discovery.earnedUnlockIds, expected);
    expect(expected, isNotEmpty);
    expect(discovery.earnedUnlockIds.contains('corvette'), isFalse);
    // The immutable receipt may not be altered by later garage changes.
    expect(
      () => discovery.receipt!.earnedUnlockIds.add('corvette'),
      throwsUnsupportedError,
    );
  });

  test('comfort mode damps lean to a steady horizon', () {
    final race = RaceController()..start(cars.first, seed: 3);
    advance(race, 4);
    race.steering = .3;
    advance(race, 1);
    expect(race.cameraLean.abs(), greaterThan(.001));
    race.comfortMode = true;
    advance(race, 2);
    expect(race.cameraLean.abs(), lessThan(.00001));
    expect(math.max(0, race.speed), race.speed);
  });
}
