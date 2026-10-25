import 'dart:math' as math;
import 'dart:ui' as ui;

/// Local2.5D light field. Numeric gains are authored, not calibrated lux/optics.
class ProofLighting {
  double aim = 0;
  void reset() => aim = 0;
  void update(double steering, double dt) {
    if (!dt.isFinite || dt <= 0) return;
    aim +=
        (steering.clamp(-1.0, 1.0) * .65 - aim) *
        (1 - math.exp(-7 * dt.clamp(0.0, .25)));
  }

  static double beam(double forward, double lateral, double aim) {
    if (forward <= 0 || forward >= 26000) return 0;
    final center = aim * forward / 14000;
    final half = .36 + forward / 17000;
    final angular = (1 - ((lateral - center).abs() / half)).clamp(0.0, 1.0);
    final range = math.pow(1 - forward / 26000, 1.4).toDouble();
    final spill = (1 - ((lateral - center).abs() / (1.3 + forward / 18000)))
        .clamp(0.0, 1.0);
    return (angular * angular * (3 - 2 * angular) + .16 * spill) * range;
  }

  static int material(int color, double night, double light) {
    final strength = light.clamp(0.0, 1.0);
    final r = (color >> 16) & 255, g = (color >> 8) & 255, b = color & 255;
    final red = (1 - .84 * night + strength * .88 * night).clamp(0.0, 1.2);
    final green = (1 - .78 * night + strength * .77 * night).clamp(0.0, 1.2);
    final blue = (1 - .62 * night + strength * .54 * night).clamp(0.0, 1.2);
    return (color & 0xff000000) |
        ((r * red).round().clamp(0, 255) << 16) |
        ((g * green).round().clamp(0, 255) << 8) |
        (b * blue).round().clamp(0, 255);
  }
}

class LightSample {
  const LightSample(this.time, this.position);
  final double time;
  final ui.Offset position;
}

/// Short source-only afterimages; no full-frame feedback or frame-count decay.
class LightHistory {
  final Map<int, List<LightSample>> sources = {};
  static const lifetime = .12;
  void clear() => sources.clear();
  Iterable<LightSample> record(
    int id,
    double time,
    ui.Offset position, {
    bool quiet = false,
  }) {
    if (quiet) {
      sources.remove(id);
      return const [];
    }
    sources.removeWhere(
      (_, samples) =>
          samples.isEmpty ||
          time - samples.last.time > lifetime ||
          samples.last.time > time,
    );
    if (!sources.containsKey(id) && sources.length >= 64) return const [];
    final samples = sources.putIfAbsent(id, () => []);
    samples.removeWhere((sample) => time - sample.time > lifetime);
    if (samples.isEmpty || time - samples.last.time >= 1 / 90) {
      samples.add(LightSample(time, position));
      if (samples.length > 12) samples.removeAt(0);
    }
    return samples;
  }
}
