/// Sprite choice is independent of the sprite sheet and camera. A skid has a
/// direction: sharing one unmirrored frame for both signs hides right steering.
class VehiclePose {
  const VehiclePose(this.frame, {this.mirrored = false});
  final int frame;
  final bool mirrored;

  static VehiclePose select({
    required double steering,
    required double speed,
    required double grade,
    bool recovering = false,
  }) {
    if (recovering || (steering.abs() > .87 && speed > 100)) {
      return VehiclePose(5, mirrored: steering < 0);
    }
    if (steering < -.16) return const VehiclePose(1);
    if (steering > .16) return const VehiclePose(2);
    if (grade > .075) return const VehiclePose(3);
    if (grade < -.075) return const VehiclePose(4);
    return const VehiclePose(0);
  }
}
