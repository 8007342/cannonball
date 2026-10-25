import 'package:cannonball/game/render/proof_road_module.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('joining lane converges continuously into the outside road edge', () {
    const start = ProofJoiningLane.start;
    const end = start + ProofJoiningLane.length;
    expect(ProofJoiningLane.visible(start - 1), isFalse);
    expect(ProofJoiningLane.visible(start), isTrue);
    expect(ProofJoiningLane.visible(end + 1), isFalse);
    expect(ProofJoiningLane.center(start), greaterThan(2));
    expect(ProofJoiningLane.center(end), closeTo(.75, .00001));
    expect(ProofJoiningLane.halfWidth(end), 0);
    var previous = double.infinity;
    for (var z = start; z <= end; z += 50) {
      final center = ProofJoiningLane.center(z);
      expect(center.isFinite, isTrue);
      expect(center, lessThanOrEqualTo(previous));
      expect(ProofJoiningLane.halfWidth(z), inInclusiveRange(0, .34));
      previous = center;
    }
  });
}
