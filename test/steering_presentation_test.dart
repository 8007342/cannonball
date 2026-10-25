import 'package:cannonball/game/render/vehicle_pose.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'digital tap starts gently instead of jumping to a hard turn or skid',
    () {
      final art = SteeringPresentation()..update(1, 1 / 60);
      final pose = art.pose(speed: 155, grade: 0);
      expect(pose.turnSheet, isTrue);
      expect(pose.frame, 1);
      art.update(0, 1 / 60);
      expect(art.value, 0);
      expect(art.pose(speed: 155, grade: 0).turnSheet, isFalse);
    },
  );

  test('held gentle input remains gentle rather than escalating with time', () {
    final art = SteeringPresentation();
    for (var i = 0; i < 240; i++) {
      art.update(-.25, 1 / 120);
    }
    expect(art.value, closeTo(-.25, .00001));
    expect(art.pose(speed: 155, grade: 0).frame, 0);
    expect(art.pose(speed: 155, grade: 0).turnSheet, isTrue);
    expect(art.sustained, 0);
  });

  test(
    'hard input progresses through gentle and medium before hard and skid',
    () {
      final art = SteeringPresentation();
      art.update(1, .05);
      expect(art.pose(speed: 155, grade: 0).frame, 1);
      art.update(1, .05);
      expect(art.pose(speed: 155, grade: 0).frame, 3);
      art.update(1, .10);
      expect(art.pose(speed: 155, grade: 0).frame, 5);
      expect(art.pose(speed: 155, grade: 0).turnSheet, isTrue);
      art.update(1, .2);
      art.update(1, .2);
      expect(art.pose(speed: 155, grade: 0).turnSheet, isFalse);
      expect(art.pose(speed: 60, grade: 0).turnSheet, isTrue);
    },
  );

  test('reversal passes neutral and release cannot queue old steering', () {
    final art = SteeringPresentation()..update(1, .2);
    art.update(-1, .1);
    expect(art.value.abs(), lessThan(.51));
    art.update(-1, .1);
    expect(art.value.abs(), lessThan(.01));
    art.update(-1, .1);
    expect(art.value, lessThan(0));
    art.update(0, .1);
    expect(art.value, 0);
    expect(art.sustained, 0);
  });

  test(
    '30 and 120 Hz schedules agree at the same elapsed presentation time',
    () {
      final slow = SteeringPresentation(), fast = SteeringPresentation();
      for (var i = 0; i < 6; i++) {
        slow.update(1, 1 / 30);
      }
      for (var i = 0; i < 24; i++) {
        fast.update(1, 1 / 120);
      }
      expect(slow.value, closeTo(fast.value, .00001));
      expect(slow.sustained, closeTo(fast.sustained, .00001));
      expect(
        slow.pose(speed: 155, grade: 0).frame,
        fast.pose(speed: 155, grade: 0).frame,
      );
    },
  );
}
