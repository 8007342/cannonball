import 'dart:collection';
import 'dart:math' as math;

import 'package:cannonball/game/proof_car.dart';
import 'package:cannonball/game/proof_level.dart';
import 'package:cannonball/game/race.dart';
import 'package:flutter_test/flutter_test.dart';

class MousePilotResult {
  double maxX = 0, endDistance = 0, minSpeed = double.infinity;
  int crashes = 0, offRoadSteps = 0, brakingSteps = 0;
  @override
  String toString() =>
      'maxX ${maxX.toStringAsFixed(3)} crashes $crashes offRoad '
      '$offRoadSteps braking $brakingSteps end ${endDistance.round()} '
      'minSpeed ${minSpeed.round()}';
}

/// An average desktop player dragging the rim with a mouse. Unlike the
/// skilled pilot in terrain_profiles_test it does not know the hairpin
/// demand: it reacts to what it sees (lateral drift and the road bending
/// ahead) after a [reaction] delay, can only move the wheel at a bounded
/// [steerRate] (full lock in about a third of a second), and brakes only
/// moderately: once the hairpin warning or a tight bend is in view, down to
/// [brakeTo] of top speed. Traffic is cleared so only road geometry and
/// handling are under test.
MousePilotResult mousePilot(
  ProofLevel level, {
  double seconds = 140,
  double reaction = .25,
  double steerRate = 3,
  double brakeTo = .74,
  double anticipation = 7,
}) {
  final race = RaceController()
    ..start(
      proofCar,
      seed: level.seed,
      testCourse: true,
      level: level,
      launchSpeed: proofCar.topSpeed,
    );
  final result = MousePilotResult();
  const dt = 1 / 60;
  final delaySteps = (reaction / dt).round();
  // Perceived (lateral position, lateral speed, bend ahead) with delay.
  final seen = Queue<(double, double, double, bool)>();
  var wheel = 0.0, lastX = 0.0;
  for (var i = 0; i < seconds * 60 && !race.finished; i++) {
    race.traffic.clear();
    final s = race.courseDistance;
    final unitsPerSecond = race.speed * .52;
    // The player watches the road about .7 s ahead: how hard it bends there
    // and whether a hairpin sign or radio warning is up within ~2.5 s.
    final bend = race.proofTerrain.curvatureAt(s + 10 + unitsPerSecond * .7);
    var tightAhead = false;
    for (var a = 0.0; a <= 40 + unitsPerSecond * 2.5; a += 5) {
      if (race.proofTerrain.curvatureAt(s + a).abs() > .1) {
        tightAhead = true;
        break;
      }
    }
    seen.add((race.playerX, (race.playerX - lastX) / dt, bend, tightAhead));
    lastX = race.playerX;
    if (seen.length <= delaySteps) {
      race.tick(dt);
      continue;
    }
    final (x, vx, c, tight) = seen.removeFirst();
    // Feed-forward: a player turns into a visible bend roughly in proportion
    // to how sharp it looks, then corrects drift from the lane centre.
    final feedForward = (c * anticipation).clamp(-1.0, 1.0);
    final target = (feedForward - x * 1.6 - vx * .35).clamp(-1.0, 1.0);
    wheel += (target - wheel).clamp(-steerRate * dt, steerRate * dt);
    race.steering = wheel;
    final ratio = race.speed / proofCar.topSpeed;
    race.braking = (tight && ratio > brakeTo) || (x.abs() > .9 && ratio > .5);
    if (race.braking) result.brakingSteps++;
    final before = race.crashes;
    race.tick(dt);
    if (race.crashes > before) result.crashes++;
    result.maxX = math.max(result.maxX, race.playerX.abs());
    if (race.playerX.abs() > 1.02) result.offRoadSteps++;
    result.minSpeed = math.min(result.minSpeed, race.speed);
  }
  result.endDistance = race.courseDistance;
  race.dispose();
  return result;
}

void main() {
  test('a mouse-like pilot completes every level on the road', () {
    for (final level in ProofLevel.all) {
      // Average desktop player: .3 s reaction, full lock in .4 s, under-reads
      // bends and brakes only to 80% before a hairpin.
      final r = mousePilot(
        level,
        reaction: .3,
        steerRate: 2.5,
        brakeTo: .8,
        anticipation: 5,
      );
      expect(r.crashes, 0, reason: '${level.id}: $r');
      expect(r.maxX, lessThan(1.02), reason: '${level.id} stays on road: $r');
      expect(r.endDistance, greaterThan(7600), reason: '${level.id}: $r');
    }
  });

  test('a slower mouse player only brushes the shoulder and recovers', () {
    for (final level in ProofLevel.all) {
      final r = mousePilot(
        level,
        reaction: .35,
        steerRate: 2,
        brakeTo: .85,
        anticipation: 4,
      );
      expect(r.crashes, 0, reason: '${level.id}: $r');
      expect(r.maxX, lessThan(1.15), reason: '${level.id}: $r');
      // About a second on the shoulder at most in the whole level.
      expect(r.offRoadSteps, lessThan(60), reason: '${level.id}: $r');
    }
  });

  test('the mouse pilot is deterministic', () {
    final a = mousePilot(ProofLevel.fromId('arizona'), seconds: 40);
    final b = mousePilot(ProofLevel.fromId('arizona'), seconds: 40);
    expect(a.toString(), b.toString());
  });

  test('hairpin assist is bounded and the shoulder pushes back', () {
    expect(RaceController.hairpinAssist, inInclusiveRange(.1, .3));
    expect(RaceController.edgeReturn(.5), 0);
    expect(RaceController.edgeReturn(.98), 0);
    expect(RaceController.edgeReturn(1.25), greaterThan(0));
    expect(RaceController.edgeReturn(-1.25), lessThan(0));
    expect(
      RaceController.edgeReturn(1.6),
      closeTo(RaceController.edgeReturnMax, 1e-9),
    );
  });
}
