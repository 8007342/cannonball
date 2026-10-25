import 'dart:typed_data';
import 'dart:ui' as ui;

/// Reused CPU buffers; one triangle submission per surface instead of paths for
/// every stripe. Texture coordinates are world-anchored and continuous.
class RoadMesh {
  RoadMesh(this.maxQuads)
    : positions = Float32List(maxQuads * 12),
      coordinates = Float32List(maxQuads * 12),
      colors = Int32List(maxQuads * 6);
  final int maxQuads;
  final Float32List positions, coordinates;
  final Int32List colors;
  int count = 0;
  void clear() => count = 0;

  void quad(
    double x1,
    double x2,
    double y1,
    double x3,
    double x4,
    double y2,
    double u1,
    double u2,
    double v1,
    double v2,
    int nearColor,
    int farColor,
  ) {
    if (count >= maxQuads) return;
    final p = count * 12, c = count * 6;
    positions[p] = x1;
    positions[p + 1] = y1;
    positions[p + 2] = x2;
    positions[p + 3] = y1;
    positions[p + 4] = x3;
    positions[p + 5] = y2;
    positions[p + 6] = x2;
    positions[p + 7] = y1;
    positions[p + 8] = x4;
    positions[p + 9] = y2;
    positions[p + 10] = x3;
    positions[p + 11] = y2;
    coordinates[p] = u1;
    coordinates[p + 1] = v1;
    coordinates[p + 2] = u2;
    coordinates[p + 3] = v1;
    coordinates[p + 4] = u1;
    coordinates[p + 5] = v2;
    coordinates[p + 6] = u2;
    coordinates[p + 7] = v1;
    coordinates[p + 8] = u2;
    coordinates[p + 9] = v2;
    coordinates[p + 10] = u1;
    coordinates[p + 11] = v2;
    colors[c] = nearColor;
    colors[c + 1] = nearColor;
    colors[c + 2] = farColor;
    colors[c + 3] = nearColor;
    colors[c + 4] = farColor;
    colors[c + 5] = farColor;
    count++;
  }

  void draw(ui.Canvas canvas, ui.Paint paint) {
    if (count == 0) return;
    final vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      Float32List.sublistView(positions, 0, count * 12),
      textureCoordinates: Float32List.sublistView(coordinates, 0, count * 12),
      colors: Int32List.sublistView(colors, 0, count * 6),
    );
    canvas.drawVertices(vertices, ui.BlendMode.modulate, paint);
    vertices.dispose();
  }
}
