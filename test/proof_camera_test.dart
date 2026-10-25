import 'package:cannonball/game/render/proof_camera.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('steering look translates the camera without changing straight or curved road heading', () {
    for (final slope in [0.0, .2, -.3]) {
      final centered = ProofRoadFrame(
        roadCenter: 500,
        roadAhead: 500 + 20 * slope,
        lookOffset: 0,
      );
      final shifted = ProofRoadFrame(
        roadCenter: 500,
        roadAhead: 500 + 20 * slope,
        lookOffset: 20,
      );
      expect(shifted.heading, centered.heading);
      double screenShift(double depth) =>
          .64 /
          depth *
          (shifted.lateralOffset(500 + slope * depth, depth) -
              centered.lateralOffset(500 + slope * depth, depth)) *
          500;
      expect(screenShift(560).abs(), lessThan(12));
      expect(screenShift(20000).abs(), lessThan(1));
      expect(screenShift(20000).abs(), lessThan(screenShift(560).abs() / 30));
    }
  });

  test(
    'lower horizon preserves the player ground contact at every camera preset',
    () {
      for (final preset in ['baseline', 'wide', 'flow']) {
        final projection = preset == 'baseline' ? .88 : .64;
        final height = ProofCamera.height(preset, projection);
        final ground =
            ProofCamera.horizon(preset) + projection / 560 * height * .70;
        expect(ground, closeTo(ProofCamera.playerGround, .000001));
        expect(height, greaterThan(0));
      }
      expect(ProofCamera.horizon('flow'), closeTo(2 / 3, .000001));
    },
  );

  test('distant sprites enter invisibly, fade continuously and become solid before approaching', () {
    const far = 20000.0;
    expect(ProofCamera.distanceOpacity(far, far), 0);
    expect(ProofCamera.distanceOpacity(far + 1, far), 0);
    expect(ProofCamera.distanceOpacity(15000, far), 1);
    expect(
      ProofCamera.distanceOpacity(18000, far),
      lessThan(ProofCamera.distanceOpacity(17000, far)),
    );
    expect(ProofCamera.opacityByte(2000, far), 255);
  });

  test('low camera pitch keeps preview room while preserving grade sign', () {
    final uphill = ProofCamera.pitch(.24, 'flow');
    final downhill = ProofCamera.pitch(-.24, 'flow');
    expect(uphill, greaterThan(0));
    expect(downhill, -uphill);
    expect(ProofCamera.horizon('flow') + uphill, lessThan(.80));
  });
}
