import 'dart:typed_data';

/// Paint variants operate only on an authored body region. Lights, glass, trim
/// and tires keep their source colors. This first sample uses a red-paint key;
/// production atlases should export the same mask from the art source instead.
class PaintPalette {
  static const colors = <int>[
    0xffd74a36,
    0xff468bb5,
    0xffe6c961,
    0xff7da090,
    0xfff2e9ce,
    0xff756a92,
    0xff404c58,
    0xffd59467,
  ];

  static bool isPaint(
    int red,
    int green,
    int blue,
    double x,
    double y, {
    required bool redBody,
  }) {
    if (y < .43 || y > .81 || x < .08 || x > .92) return false;
    // Rear lamps stay independent of the selected paint. These are normalized
    // authoring-mask exclusion boxes for the straight-rear sample cell.
    if (y > .47 && y < .64 && (x < .34 || x > .66)) return false;
    if (y > .48 && y < .54 && x > .39 && x < .61) return false;
    if (redBody) {
      return red > 65 && red > green * 1.3 && red > blue * 1.25;
    }
    final max = red > green
        ? (red > blue ? red : blue)
        : (green > blue ? green : blue);
    final min = red < green
        ? (red < blue ? red : blue)
        : (green < blue ? green : blue);
    return min > 85 && max - min < 40;
  }

  static void recolor(
    Uint8List rgba,
    int width,
    int height,
    int target, {
    required bool redBody,
  }) {
    final tr = (target >> 16) & 255,
        tg = (target >> 8) & 255,
        tb = target & 255;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final i = (y * width + x) * 4;
        final r = rgba[i], g = rgba[i + 1], b = rgba[i + 2];
        if (rgba[i + 3] < 12 ||
            !isPaint(r, g, b, x / width, y / height, redBody: redBody)) {
          continue;
        }
        final light = redBody ? r / 210 : (r + g + b) / (3 * 220);
        rgba[i] = (tr * light).round().clamp(0, rgba[i + 3]);
        rgba[i + 1] = (tg * light).round().clamp(0, rgba[i + 3]);
        rgba[i + 2] = (tb * light).round().clamp(0, rgba[i + 3]);
      }
    }
  }
}
