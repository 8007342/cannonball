import 'dart:math' as math;

import 'package:cannonball/game/render/vehicle_pose.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'course rear pose stays grounded through mild grades and turn release',
    () {
      final art = SteeringPresentation();
      for (final grade in [-.2, -.06, 0.0, .06, .2]) {
        expect(art.pose(speed: 140, grade: grade).frame, 0);
        expect(art.pose(speed: 140, grade: grade).turnSheet, isFalse);
      }
      art.update(.3, .1);
      expect(art.pose(speed: 140, grade: .1).turnSheet, isTrue);
      art.update(0, .1);
      expect(art.pose(speed: 140, grade: .1).frame, 0);
      expect(art.pose(speed: 140, grade: .1, grounded: false).frame, 3);
    },
  );

  test('slope cue uses road angle relative to the camera and stays subtle', () {
    final followed = GroundedSlopePresentation();
    final fixedCamera = GroundedSlopePresentation();
    for (var i = 0; i < 120; i++) {
      followed.update(grade: .1, cameraPitch: math.atan(.1), dt: 1 / 60);
      fixedCamera.update(grade: .1, cameraPitch: 0, dt: 1 / 60);
    }
    expect(followed.visualPitch.abs(), lessThan(1e-10));
    expect(fixedCamera.visualPitch, greaterThan(0));
    expect(fixedCamera.visualPitch, lessThan(.009));
    fixedCamera.update(grade: 100, cameraPitch: -10, dt: .25);
    expect(fixedCamera.visualPitch.abs(), lessThan(.024));
  });

  test('closed-form slope spring agrees across frame schedules', () {
    GroundedSlopePresentation run(int hz) {
      final presentation = GroundedSlopePresentation();
      for (var i = 0; i < hz; i++) {
        presentation.update(grade: -.12, cameraPitch: -.03, dt: 1 / hz);
      }
      return presentation;
    }

    final a = run(30), b = run(120);
    expect(a.relativePitch, closeTo(b.relativePitch, 1e-10));
    expect(a.visualPitch, closeTo(b.visualPitch, 1e-10));
    expect(a.slopeBand, -1);
  });

  test(
    'slope-band hysteresis prevents threshold chatter and resets quietly',
    () {
      final presentation = GroundedSlopePresentation();
      void settle(double angle) {
        for (var i = 0; i < 120; i++) {
          presentation.update(
            grade: math.tan(angle),
            cameraPitch: 0,
            dt: 1 / 60,
          );
        }
      }

      settle(.04);
      expect(presentation.slopeBand, 1);
      for (final angle in [.034, .031, .036, .025]) {
        settle(angle);
        expect(presentation.slopeBand, 1);
      }
      settle(.015);
      expect(presentation.slopeBand, 0);
      settle(-.04);
      expect(presentation.slopeBand, -1);
      final before = presentation.relativePitch;
      presentation.update(grade: double.nan, cameraPitch: 0, dt: .1);
      expect(presentation.relativePitch, before);
      presentation.update(grade: 1, cameraPitch: 0, dt: .1, quiet: true);
      expect(presentation.relativePitch, 0);
      expect(presentation.visualPitch, 0);
      expect(presentation.slopeBand, 0);
    },
  );
}
