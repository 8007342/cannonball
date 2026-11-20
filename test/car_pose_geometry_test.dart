import 'dart:convert';
import 'dart:io';

import 'package:cannonball/game/render/vehicle_pose.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final poses = jsonDecode(
    File('art/rigs/cars/poses.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('Dart pose geometry matches the Blender rig pose table', () {
    for (final (sheet, table) in [
      ('body', VehiclePoseGeometry.body),
      ('turn', VehiclePoseGeometry.turn),
    ]) {
      final rig = (poses['sheets'] as Map)[sheet] as List;
      expect(rig.length, table.length, reason: sheet);
      for (var i = 0; i < table.length; i++) {
        final p = rig[i] as Map;
        expect(p.keys.toSet(), {'name', 'yaw', 'steer', 'roll', 'pitch'});
        expect(p['name'], table[i].name);
        expect((p['yaw'] as num).toDouble(), table[i].yaw);
        expect((p['steer'] as num).toDouble(), table[i].steer);
        expect((p['roll'] as num).toDouble(), table[i].roll);
        expect((p['pitch'] as num).toDouble(), table[i].pitch);
      }
    }
  });

  test('only the front axle steers in the rig', () {
    final rig = File('art/rigs/cars/car_rig.py').readAsStringSync();
    expect(
      rig,
      contains("math.radians(p['steer']) if axle == 'front' else 0.0"),
    );
    final table = (poses['sheets'] as Map).values.expand((s) => s as List);
    for (final p in table) {
      expect((p as Map).keys, isNot(contains('rearSteer')));
    }
  });

  test('steering left shows a nose-left yaw with front wheels turned in', () {
    for (final target in [-1.0, 1.0]) {
      final art = SteeringPresentation();
      for (var i = 0; i < 60; i++) {
        art.update(target * .9, 1 / 60);
        final pose = art.pose(speed: 155, grade: 0);
        final g = VehiclePoseGeometry.of(pose);
        if (art.value.abs() < .08) continue;
        // Left input (negative) turns the nose left (positive yaw).
        expect(g.yaw.sign, -target, reason: g.name);
        expect(g.steer.sign, -target, reason: g.name);
        expect(g.roll.sign, -target, reason: 'body leans out of the turn');
      }
    }
    for (final steering in [-.5, .5]) {
      final g = VehiclePoseGeometry.of(
        VehiclePose.select(steering: steering, speed: 150, grade: 0),
      );
      expect(g.yaw.sign, -steering.sign);
      expect(g.steer.sign, -steering.sign);
    }
  });

  test('a skid keeps its direction and counter-steers the front wheels', () {
    for (final steering in [-1.0, 1.0]) {
      final g = VehiclePoseGeometry.of(
        VehiclePose.select(steering: steering, speed: 150, grade: 0),
      );
      expect(g.yaw.sign, -steering.sign, reason: 'nose follows the input');
      expect(g.steer.sign, steering.sign, reason: 'front wheels counter-steer');
    }
  });
}
