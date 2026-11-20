import 'dart:typed_data';
import 'dart:ui' as ui;

import '../scenic/road_surfaces.dart';
import '../scenic/scenic_bands.dart';
import '../scenic/scenic_library.dart';
import 'road_mesh.dart';

/// Textured surface layers (ground, shoulder, road). Each surface id gets one
/// base mesh and one overlay mesh per layer; all bases of a layer draw before
/// its overlays, so a blend is "base opaque, overlay at weight t" with one
/// draw call per visible surface rather than per strip.
class SurfaceMeshes {
  SurfaceMeshes(this.library, this.quadsPerLayer);
  final ScenicLibrary library;
  final int quadsPerLayer;
  final Map<(String, bool, String), RoadMesh> _meshes = {};
  final Map<String, ui.Paint> _paints = {};
  int drawCalls = 0;

  /// Forward world units per metre for texture tiling; calibrated to the
  /// velocity preset where forward and lateral scales match.
  static const worldUnitsPerMetre = 195.0;

  /// Detail surfaces blended over a plain base: (base id, detail share).
  static const underlays = <String, (String, double)>{
    'asphalt-worn': ('asphalt-fresh', .55),
  };

  /// Lateral texture origin (metres from the road centre). Lane lines sit at
  /// about ±1.8 m, so slab textures with a joint at u = 0 put their
  /// longitudinal joints on the lane lines rather than down a lane.
  static const laneOffsetM = 1.8;

  static final _identity = Float64List.fromList([
    1, 0, 0, 0, //
    0, 1, 0, 0, //
    0, 0, 1, 0, //
    0, 0, 0, 1, //
  ]);

  ui.Paint? _paint(String id) {
    final cached = _paints[id];
    if (cached != null) return cached;
    final surface = library.surface(id);
    if (surface == null) return null;
    return _paints[id] = ui.Paint()
      ..shader = ui.ImageShader(
        surface.image,
        ui.TileMode.repeated,
        ui.TileMode.repeated,
        _identity,
        // Mipmapped sampling: a 2-3 m crack or joint tile minifies to a few
        // pixels within ~60 m, and without mips it sparkles as the road
        // flows. The mip chain fades distant detail to the surface's mean
        // colour instead.
        filterQuality: ui.FilterQuality.medium,
      )
      ..isAntiAlias = false;
  }

  void clear() {
    for (final mesh in _meshes.values) {
      mesh.clear();
    }
  }

  /// Adds one strip between a near and a far road point. `left`/`right` are
  /// lateral road half-widths; texture u follows metres from the centre.
  void strip(
    String layer,
    SurfaceSample sample,
    double nearT,
    double farT, {
    required double left,
    required double right,
    required double nearX,
    required double nearY,
    required double nearHalf,
    required double farX,
    required double farY,
    required double farHalf,
    required double nearZ,
    required double farZ,
    required int Function(String id, double z, double lateral) color,
    double? nearLeft,
    double? nearRight,
  }) {
    void add(String id, bool overlay, double tn, double tf) {
      final surface = library.surface(id);
      if (surface == null) return;
      final mesh = _meshes.putIfAbsent((
        layer,
        overlay,
        id,
      ), () => RoadMesh(quadsPerLayer));
      final w = surface.image.width.toDouble();
      final h = surface.image.height.toDouble();
      final tileU = surface.tileM[0], tileV = surface.tileM[1];
      double u(double lateral) =>
          (lateral * ScenicScale.roadHalfWidthM + laneOffsetM) / tileU * w;
      double v(double z) => z / worldUnitsPerMetre / tileV * h;
      int alpha(int c, double t) =>
          (c & 0x00ffffff) | ((t.clamp(0.0, 1.0) * 255).round() << 24);
      final nl = nearLeft ?? left, nr = nearRight ?? right;
      final n = columns(nearHalf, farHalf);
      for (var c = 0; c < n; c++) {
        final f0 = c / n, f1 = (c + 1) / n;
        final l = left + (right - left) * f0, r = left + (right - left) * f1;
        final ln = nl + (nr - nl) * f0, rn = nl + (nr - nl) * f1;
        mesh.quad(
          nearX + nearHalf * ln,
          nearX + nearHalf * rn,
          nearY,
          farX + farHalf * l,
          farX + farHalf * r,
          farY,
          u(l),
          u(r),
          v(nearZ),
          v(farZ),
          alpha(color(id, nearZ, ln), tn),
          alpha(color(id, farZ, l), tf),
          nearRightColor: alpha(color(id, nearZ, rn), tn),
          farRightColor: alpha(color(id, farZ, r), tf),
        );
      }
    }

    // A detail texture with an underlay draws the underlay first and itself
    // on top at a fixed share, so its cracks and patches read as wear on a
    // sound road rather than a shattered one.
    void surface(String id, bool overlay, double tn, double tf) {
      final under = underlays[id];
      if (under == null) return add(id, overlay, tn, tf);
      add(under.$1, overlay, tn, tf);
      add(id, true, tn * under.$2, tf * under.$2);
    }

    surface(sample.base, false, 1, 1);
    final overlay = sample.overlay;
    if (overlay != null && overlay != sample.base) {
      surface(overlay, true, nearT, farT);
    }
  }

  /// Lateral subdivisions of one strip. A textured quad is two affine
  /// triangles, so on a strongly perspective trapezoid (near the camera)
  /// lines running along the road kink at the diagonal; plank decks showed
  /// it as a chevron pattern. Narrower columns shrink the kink in proportion.
  static int columns(double nearHalf, double farHalf) {
    if (farHalf <= 0) return 1;
    final ratio = nearHalf / farHalf;
    return ((ratio - 1) * 10).ceil().clamp(1, 4);
  }

  void draw(ui.Canvas canvas, String layer) {
    for (final overlay in const [false, true]) {
      _meshes.forEach((key, mesh) {
        if (key.$1 != layer || key.$2 != overlay || mesh.count == 0) return;
        final paint = _paint(key.$3);
        if (paint == null) return;
        mesh.draw(canvas, paint);
        drawCalls++;
      });
    }
  }
}
