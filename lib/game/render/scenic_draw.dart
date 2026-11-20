import 'dart:math' as math;
import 'dart:ui' as ui;

import '../scenic/scenic_bands.dart';
import '../scenic/scenic_library.dart';
import '../scenic/scenic_manifest.dart';
import '../scenic/scenic_scheduler.dart';
import 'proof_art.dart';

/// Presentation helpers for scenic sprites that do not need the road
/// projection: animation frame choice and the heading-driven vista strip.
class ScenicDraw {
  /// Grazing animals change pose slowly; swaying props a little faster.
  static double frameRate(ScenicSprite sprite) =>
      sprite.kind == 'animal' ? .45 : 1.2;

  static ScenicSprite frameAt(
    ScenicManifest manifest,
    ScenicPlacement placement,
    double time,
  ) {
    final frames = manifest.framesOf(placement.sprite);
    if (frames.length < 2) return placement.sprite;
    final tick =
        (time * frameRate(placement.sprite) + placement.phase * frames.length)
            .floor();
    return frames[tick % frames.length];
  }

  /// Assumed distance of vista layers. Their screen width follows the
  /// pinhole size of `worldWidthM` at this distance.
  static const vistaDistanceM = 3600.0;
  static const stripScreens = 2.6;

  /// Tallest vista panel as a fraction of screen height: mountain and
  /// skyline paintings stay a horizon band, not a wall.
  static const maxHeightFraction = .2;

  /// Height of the ground-haze ramp that dissolves panel bottoms (and their
  /// painted foregrounds) into the terrain, as a fraction of screen height.
  static const footFraction = .075;

  static double vistaWidth(
    ScenicSprite sprite,
    double projection,
    double halfScreen,
  ) => (sprite.worldWidthM / vistaDistanceM * projection * halfScreen).clamp(
    60.0,
    1600.0,
  );

  /// Pixel scale of a vista panel: metric width, capped in height.
  static double vistaScale(
    ScenicSprite sprite,
    double projection,
    double screenWidth,
    double screenHeight,
  ) => math.min(
    vistaWidth(sprite, projection, screenWidth * .5) / sprite.rect[2],
    screenHeight * maxHeightFraction / sprite.rect[3],
  );

  /// Ground haze over the vista feet: transparent [footFraction] above
  /// [baseY], opaque [color] from [baseY] down so it continues under the
  /// projected terrain. Hides the bottom edges and painted foregrounds of the
  /// panels and the gaps between them; far-band sprites draw on top later.
  static void foot({
    required ui.Canvas canvas,
    required ui.Paint paint,
    required double baseY,
    required double screenWidth,
    required double screenHeight,
    required int color,
  }) {
    final top = baseY - screenHeight * footFraction;
    final solid = ui.Color(color);
    paint.color = const ui.Color(0xffffffff);
    paint.shader = ui.Gradient.linear(
      ui.Offset(0, top),
      ui.Offset(0, baseY),
      [solid.withValues(alpha: 0), solid],
      const [0, 1],
    );
    canvas.drawRect(
      ui.Rect.fromLTWH(
        0,
        top,
        screenWidth,
        screenHeight * (footFraction + .14),
      ),
      paint,
    );
    paint.shader = null;
  }

  /// Draws one zone's vista slots on a wrapped horizon strip. [offset] comes
  /// from [ScenicParallax.vistaOffset]; [opacity] is quantized for batching.
  static int vista({
    required ui.Canvas canvas,
    required BillboardBatch batch,
    required ScenicLibrary library,
    required List<VistaSlot> slots,
    required double opacity,
    required double offset,
    required double baseY,
    required double screenWidth,
    required double screenHeight,
    required double projection,
    required int tint,
    ui.Image? proofAtlas,
  }) {
    if (slots.isEmpty || opacity <= .01) return 0;
    final alpha =
        ((opacity * ScenicScale.peakOpacity(ScenicBand.vista) * 8).round() *
                255 ~/
                8)
            .clamp(0, 255);
    if (alpha == 0) return 0;
    final strip = screenWidth * stripScreens;
    var drawn = 0;
    for (final slot in slots) {
      final sprite = slot.sprite;
      final image = library.atlas(sprite.atlas, proofAtlas: proofAtlas);
      if (image == null) continue;
      final scale = vistaScale(sprite, projection, screenWidth, screenHeight);
      final width = sprite.rect[2] * scale;
      final anchorX = sprite.anchor[0] * scale;
      final x = (slot.position * strip + offset) % strip;
      for (final wrap in [-strip, 0.0, strip]) {
        final left = x + wrap - anchorX;
        if (left > screenWidth || left + width < 0) continue;
        batch.add(
          canvas,
          image,
          ui.Rect.fromLTWH(
            sprite.rect[0] + .5,
            sprite.rect[1] + .5,
            sprite.rect[2] - 1,
            sprite.rect[3] - 1,
          ),
          left,
          baseY - sprite.anchor[1] * scale,
          scale,
          color: tint,
          opacity: alpha,
        );
        drawn++;
      }
    }
    return drawn;
  }
}
