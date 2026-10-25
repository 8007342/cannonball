import 'package:cannonball/game/render/proof_camera.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
