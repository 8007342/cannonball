import 'package:cannonball/game/render/vehicle_pose.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('high speed skid preserves steering direction', () {
    final left = VehiclePose.select(steering: -1, speed: 150, grade: 0);
    final right = VehiclePose.select(steering: 1, speed: 150, grade: 0);
    expect(left.frame, 5);
    expect(right.frame, 5);
    expect(left.mirrored, isTrue);
    expect(right.mirrored, isFalse);
  });
  test(
    'gentle steering remains signed and slope only applies when straight',
    () {
      expect(VehiclePose.select(steering: -.4, speed: 150, grade: .1).frame, 1);
      expect(VehiclePose.select(steering: .4, speed: 150, grade: -.1).frame, 2);
      expect(VehiclePose.select(steering: 0, speed: 150, grade: .1).frame, 3);
      expect(VehiclePose.select(steering: 0, speed: 150, grade: -.1).frame, 4);
    },
  );
}
