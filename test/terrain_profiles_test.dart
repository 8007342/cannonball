import 'dart:math' as math;

import 'package:cannonball/game/proof_car.dart';
import 'package:cannonball/game/proof_level.dart';
import 'package:cannonball/game/race.dart';
import 'package:cannonball/game/terrain/level_profiles.dart';
import 'package:flutter_test/flutter_test.dart';

class PilotResult {
  double maxX = 0, finalX = 0, finalSpeed = 0, endDistance = 0;
  int brakingSteps = 0;
}

/// A skilled-driver model: looks ahead, brakes to a speed the hairpin
/// permits, and steers with feed-forward plus lane-centre correction.
/// Traffic is cleared so only road geometry is under test.
PilotResult drive(
  ProofLevel level, {
  required bool brake,
  double seconds = 95,
}) {
  final race = RaceController()
    ..start(
      proofCar,
      seed: level.seed,
      testCourse: true,
      level: level,
      launchSpeed: proofCar.topSpeed,
    );
  final result = PilotResult();
  final h = proofCar.handling;
  final grip = race.weather == RaceWeather.rain ? .91 : 1.0;
  for (var i = 0; i < seconds * 60 && !race.finished; i++) {
    race.traffic.clear();
    final s = race.courseDistance;
    final r = race.speed / proofCar.topSpeed;
    final look = 30 + race.speed * .52 * 1.6;
    var demand = 0.0;
    for (var a = 0.0; a <= look; a += 4) {
      demand = math.max(demand, race.proofTerrain.cornerDemandAt(s + a).abs());
    }
    var target = 1.0;
    if (demand > 0) {
      // Largest ratio where demand * r^2 <= .8 * authority(r).
      final qb = -.8 * h * grip * 1.15, qc = -.8 * h * grip * .2;
      target = ((-qb + math.sqrt(qb * qb - 4 * demand * qc)) / (2 * demand))
          .clamp(.2, 1.0);
    }
    race.braking = brake && r > target + .01;
    if (race.braking) result.brakingSteps++;
    final authority = h * grip * (.2 + 1.15 * r);
    final pull =
        race.proofTerrain.cornerDemandAt(s) * r * r +
        race.curveAt(race.worldDistance) * r * r * .23;
    race.steering = (pull / authority - race.playerX * 2.5).clamp(-1.0, 1.0);
    race.tick(1 / 60);
    result.maxX = math.max(result.maxX, race.playerX.abs());
  }
  result
    ..finalX = race.playerX
    ..finalSpeed = race.speed
    ..endDistance = race.courseDistance;
  race.dispose();
  return result;
}

ProofLevel level(String id) => ProofLevel.fromId(id);

void main() {
  test('hairpin levels need braking; braking keeps them passable', () {
    for (final id in ['ohio', 'arizona']) {
      final braked = drive(level(id), brake: true);
      final reckless = drive(level(id), brake: false);
      expect(braked.maxX, lessThan(1.0), reason: '$id braked pilot holds road');
      expect(braked.brakingSteps, greaterThan(120), reason: id);
      expect(braked.endDistance, greaterThan(5000), reason: id);
      expect(
        reckless.maxX,
        greaterThan(1.02),
        reason: '$id at top speed without braking leaves the road',
      );
    }
  });

  test('every level is passable by the braking pilot', () {
    for (final l in ProofLevel.all) {
      expect(drive(l, brake: true).maxX, lessThan(1.0), reason: l.id);
    }
  });

  test('hairpin runs are deterministic across replays', () {
    final a = drive(level('ohio'), brake: true, seconds: 30);
    final b = drive(level('ohio'), brake: true, seconds: 30);
    expect(a.finalX, b.finalX);
    expect(a.finalSpeed, b.finalSpeed);
    expect(a.endDistance, b.endDistance);
  });

  int hairpins(LevelProfile p) {
    var count = 0;
    var inside = false;
    for (var s = 0.0; s < 7600; s += 2) {
      final now = p.cornerDemandAt(s).abs() > 1;
      if (now && !inside) count++;
      inside = now;
    }
    return count;
  }

  /// A crest followed by a descent steep enough to hide the road beyond.
  int blindCrests(LevelProfile p) {
    var count = 0;
    for (var s = 0.0; s < 7400; s += 10) {
      final up = p.elevationAt(s + 1) - p.elevationAt(s - 1);
      if (up / 2 < 12) continue;
      for (var a = 40.0; a < 260; a += 10) {
        final down = p.elevationAt(s + a + 1) - p.elevationAt(s + a - 1);
        if (down / 2 < -12) {
          count++;
          s += 400;
          break;
        }
      }
    }
    return count;
  }

  test('levels differ in character: hairpin/crest levels and a calm one', () {
    final dramatic = LevelProfile.all
        .where((p) => hairpins(p) >= 4 && blindCrests(p) >= 1)
        .map((p) => p.id)
        .toSet();
    expect(dramatic, containsAll(['ohio', 'arizona']));
    final iowa = LevelProfile.iowa;
    expect(hairpins(iowa), 0);
    var longest = 0.0, run = 0.0;
    for (var s = 0.0; s < 7600; s += 5) {
      run = iowa.curvatureAt(s).abs() < .002 ? run + 5 : 0;
      longest = math.max(longest, run);
    }
    expect(longest, greaterThan(1200), reason: 'Iowa keeps long straights');
    for (final p in LevelProfile.all) {
      if (p.legacy) continue;
      expect(hairpins(p), lessThan(10), reason: p.id);
    }
  });

  test('structural chapters stay gentle on every profile', () {
    for (final p in LevelProfile.all) {
      for (var s = 4100.0; s < 6820; s += 5) {
        expect(p.curvatureAt(s).abs(), lessThan(.06), reason: '${p.id} $s');
        expect(p.cornerDemandAt(s), 0);
      }
    }
  });

  test('steep grades keep pitch clamped, finite and smooth', () {
    for (final l in ProofLevel.all) {
      final t = ProofTerrain(l);
      for (final flow in [12.0, 168.0]) {
        for (var s = 0.0; s < 9000; s += 7) {
          final pitch = t.pitchAt(s, flow);
          expect(pitch.isFinite, isTrue);
          expect(pitch.abs(), lessThanOrEqualTo(.24));
          expect(t.gradeAt(s, flow).isFinite, isTrue);
        }
      }
      for (var s = 2.0; s < 7600; s += 3) {
        expect(
          (t.elevationAt(s + .5) - t.elevationAt(s - .5)).abs(),
          lessThan(23),
          reason: '${l.id} slope at $s',
        );
      }
    }
  });

  test('section labels name the level character before shared chapters', () {
    expect(ProofTerrain(level('ohio')).sectionAt(1200), 'HAIRPIN PAIR');
    expect(ProofTerrain(level('iowa')).sectionAt(800), 'LONG STRAIGHT');
    expect(ProofTerrain(level('ohio')).sectionAt(5300), 'TREE CANOPY');
    expect(ProofTerrain(level('hudson')).sectionAt(5300), 'TREE CANOPY');
  });
}
