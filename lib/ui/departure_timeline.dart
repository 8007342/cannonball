/// Directed departure beats. One normalized clock controls the picture and
/// sound handoff; the driving clock remains the caller's responsibility.
class DepartureTimeline {
  static const durationMilliseconds = 7600;
  static const reducedDurationMilliseconds = 1800;

  static double progress(double value, double start, double end) =>
      ((value - start) / (end - start)).clamp(0.0, 1.0);

  static double smooth(double value) => value * value * (3 - 2 * value);

  static String shot(double value) => value < .20
      ? 'pickup'
      : value < .40
      ? 'reveal'
      : value < .60
      ? 'walk'
      : value < .70
      ? 'door'
      : value < .82
      ? 'cabin'
      : value < .93
      ? 'rear'
      : 'launch';

  static int handFrame(double pickup) => pickup < .38
      ? 0
      : pickup < .55
      ? 1
      : pickup < .72
      ? 2
      : 3;

  /// The final overlay reveals the already loaded chase view, rather than
  /// fading all the way to black and replacing it with a different composition.
  static double overlayOpacity(double value) =>
      1 - smooth(progress(value, .93, 1));
}
