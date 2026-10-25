import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import 'race_controller.dart';
import 'render/proof_art.dart';
import 'render/road_mesh.dart';
import 'render/vehicle_pose.dart';
import 'render/proof_road_module.dart';
import 'route.dart';
import 'proof_course.dart';

class _RoadPoint {
  double x = 0, y = 0, halfWidth = 0, z = 0, clip = 0;
  bool visible = false;
}

enum _Kind {
  scenery,
  traffic,
  player,
  bridge,
  lamp,
  sign,
  cone,
  marker,
  canopy,
  portal,
}

class _Object {
  _Object(
    this.kind,
    this.z,
    this.lateral,
    this.width, {
    this.frame = 0,
    this.braking = false,
    this.incident = 0,
    this.reaction = 0,
  });
  final _Kind kind;
  final double z, lateral, width;
  final int frame;
  final bool braking;
  final double incident, reaction;
}

/// Original cartoon art proof with independent simulation and presentation.
/// Full-resolution generated textures are decoded once. The frame uses three
/// textured road meshes, cached parallax art, and depth-ordered atlas batches.
class RaceGame extends FlameGame {
  RaceGame({required this.controller, this.proofMode = false});
  final RaceController controller;
  final bool proofMode;
  final ProofArt _art = ProofArt();
  final SteeringPresentation _steeringArt = SteeringPresentation();
  final BillboardBatch _batch = BillboardBatch();
  static const _w = 1000.0, _roadHalfWidth = 1100.0;
  static const visualSpeedScale = 12.0;
  String _speedPreset = 'arcade';
  String get speedPreset => _speedPreset;
  void setSpeedPreset(String preset) {
    if (const ['classic', 'cruise', 'arcade'].contains(preset)) {
      final previous = _flowScale;
      _speedPreset = preset;
      _worldOffset += controller.worldDistance * (previous - _flowScale);
    }
  }

  bool get _nextProof => proofMode && controller.car.id == 's2000';
  double get _flowScale =>
      visualSpeedScale *
      (_nextProof
          ? (_speedPreset == 'classic'
                ? 1.0
                : _speedPreset == 'cruise'
                ? 1.3
                : 1.7)
          : 1.0);
  bool get _course => _nextProof && controller.testCourseEnabled;
  String _cameraPreset = 'flow';
  String get cameraPreset => _cameraPreset;
  void setCameraPreset(String value) {
    if (const ['baseline', 'wide', 'flow'].contains(value)) {
      _cameraPreset = value;
    }
  }

  double get visualSteering => _steeringArt.value;
  double get _projection => _course
      ? (_cameraPreset == 'baseline' ? .88 : .64)
      : _nextProof
      ? .76
      : .88;
  double _courseAt(double z) =>
      (z - _worldOffset) / _flowScale + controller.courseStartDistance;
  double _courseZ(double s) =>
      (s - controller.courseStartDistance) * _flowScale + _worldOffset;

  static const _segmentLength = 115.0, _segmentCount = 100;
  final List<_RoadPoint> _points = List.generate(
    _segmentCount + 1,
    (_) => _RoadPoint(),
  );
  final RoadMesh _ground = RoadMesh(_segmentCount);
  final RoadMesh _shoulder = RoadMesh(_segmentCount);
  final RoadMesh _asphalt = RoadMesh(_segmentCount);
  final RoadMesh _joiningLane = RoadMesh(_segmentCount);
  final RoadMesh _joiningMarkings = RoadMesh(_segmentCount * 2);
  final RoadMesh _markings = RoadMesh(_segmentCount * 5);
  final List<_Object> _objects = [];
  final Paint _paint = Paint()
    ..isAntiAlias = true
    ..filterQuality = FilterQuality.low;
  late Paint _roadPaint, _groundPaint;
  final Stopwatch _renderWatch = Stopwatch(), _updateWatch = Stopwatch();
  int renderCount = 0, updateCount = 0;
  int renderCpuMicros = 0, updateCpuMicros = 0;
  int lastRenderMicros = 0,
      maxRenderMicros = 0,
      lastUpdateMicros = 0,
      maxUpdateMicros = 0;
  int lastSpriteCount = 0, lastRoadQuads = 0;
  int get lastBillboardBatches => _batch.drawCalls;
  bool _loaded = false, _removed = false;
  double _lastElapsed = 0, _coursePitch = 0;
  double get coursePitch => _coursePitch;
  bool get assetsReady => _loaded && _art.ready;
  String? get artError => _art.error;
  double _h = 560, _cameraZ = 0, _cameraY = 0, _cameraX = 0, _tangent = 0;
  double _world = 0,
      _worldOffset = 0,
      _playerX = 0,
      _presentationTime = 0,
      _xVelocity = 0;
  double get visualFlowScale => _flowScale;
  double get presentationDistance => _world;
  int _lastSeed = -1;
  String get proofStage => _course
      ? ProofCourse.sectionAt(controller.courseDistance)
      : _biome == Biome.city
      ? 'CITY EDGE'
      : _biome == Biome.mountain
      ? 'HIGH COUNTRY'
      : 'GREEN COUNTRY';
  Biome get _biome => _nextProof
      ? controller.currentEdge.biome
      : proofMode
      ? (_presentationTime % 60 < 18
            ? Biome.city
            : _presentationTime % 60 < 39
            ? Biome.forest
            : Biome.mountain)
      : controller.currentEdge.biome;

  @override
  Color backgroundColor() => const Color(0xffa8d2df);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      await _art.load(s2000: _nextProof, course: _course);
      if (_removed) {
        _art.dispose();
        return;
      }
      final identity = Float64List.fromList([
        1,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        1,
      ]);
      _roadPaint = Paint()
        ..shader = ui.ImageShader(
          _art.asphalt,
          TileMode.repeated,
          TileMode.repeated,
          identity,
          filterQuality: FilterQuality.low,
        )
        ..isAntiAlias = false;
      _groundPaint = Paint()
        ..shader = ui.ImageShader(
          _art.meadow,
          TileMode.repeated,
          TileMode.repeated,
          identity,
          filterQuality: FilterQuality.low,
        )
        ..isAntiAlias = false;
      _loaded = true;
      _presentationTime = controller.elapsed;
    } catch (error) {
      _art.error = 'The art scene could not be prepared: $error';
      _art.dispose();
    }
  }

  @override
  void update(double dt) {
    if (!dt.isFinite || dt <= 0) return;
    _updateWatch
      ..reset()
      ..start();
    final oldElapsed = controller.elapsed, oldX = controller.playerX;
    super.update(dt);
    if (controller.seed != _lastSeed || controller.elapsed < _lastElapsed) {
      _lastSeed = controller.seed;
      _presentationTime = controller.elapsed;
      _worldOffset = 0;
      _xVelocity = 0;
      _steeringArt.reset();
      _coursePitch = _course
          ? ProofCourse.pitchAt(controller.courseDistance, _flowScale)
          : 0;
    }
    if (!controller.paused && !controller.finished && dt.isFinite) {
      _presentationTime += dt.clamp(0, .25);
    }
    controller.tick(dt);
    if (_course && !controller.paused && !controller.finished) {
      _steeringArt.update(controller.effectiveSteering, dt);
      final targetPitch = ProofCourse.pitchAt(
        controller.courseDistance,
        _flowScale,
      );
      _coursePitch +=
          (targetPitch - _coursePitch) * (1 - math.exp(-6 * dt.clamp(0, .25)));
    }
    _lastElapsed = controller.elapsed;
    final advanced = controller.elapsed - oldElapsed;
    if (advanced > 0) _xVelocity = (controller.playerX - oldX) / advanced;
    final remainder = (_presentationTime - controller.elapsed).clamp(
      0.0,
      RaceController.fixedStep,
    );
    final lag = controller.paused ? 0.0 : RaceController.fixedStep - remainder;
    _world =
        (controller.worldDistance -
                controller.speed * RouteGraph.speedScale * lag) *
            _flowScale +
        _worldOffset;
    _playerX = controller.playerX - _xVelocity * lag;
    updateCount++;
    _updateWatch.stop();
    lastUpdateMicros = _updateWatch.elapsedMicroseconds;
    updateCpuMicros += lastUpdateMicros;
    maxUpdateMicros = math.max(maxUpdateMicros, lastUpdateMicros);
  }

  double _center(double z) => _course
      ? ProofCourse.centerAt(_courseAt(z))
      : controller.centerAt((z - _worldOffset) / _flowScale) * 8;
  double _elevation(double z) {
    if (_course) return ProofCourse.elevationAt(_courseAt(z));
    if (proofMode) {
      return math.sin(z / 5900) * 620 + math.sin(z / 2750) * 115;
    }
    return controller.elevationAt((z - _worldOffset) / _flowScale) * 2.1;
  }

  void _project(double worldZ, _RoadPoint out) {
    final z = math.max(20.0, worldZ - _cameraZ), scale = _projection / z;
    out.z = z;
    out.x =
        _w * .5 +
        scale *
            (_center(worldZ) -
                _cameraX -
                _tangent * z -
                _playerX * _roadHalfWidth * .58) *
            _w *
            .5;
    out.y = _h * .30 + scale * (_cameraY - _elevation(worldZ)) * _h * .70;
    if (_course) out.y += _h * ProofCourse.pitchShift(_coursePitch, z);
    out.halfWidth = scale * _roadHalfWidth * _w * .5;
  }

  @override
  void render(Canvas canvas) {
    _renderWatch
      ..reset()
      ..start();
    super.render(canvas);
    _batch.drawCalls = 0;
    if (size.x > 0 && size.y > 0) {
      final scale = size.x / _w;
      _h = size.y / scale;
      canvas.save();
      canvas.scale(scale);
      canvas.clipRect(Rect.fromLTWH(0, 0, _w, _h));
      _sky(canvas);
      if (_loaded) {
        _cameraZ =
            _world -
            (_course
                ? 560
                : _nextProof
                ? 700
                : 850);
        _cameraY =
            _elevation(_world) +
            (_course
                ? 720
                : _nextProof
                ? 660
                : 730);
        _cameraX = _center(_cameraZ);
        _tangent = (_center(_cameraZ + 20) - _cameraX) / 20;
        canvas.save();
        canvas.translate(_w / 2, _h * .32);
        canvas.rotate(controller.cameraLean * .65);
        canvas.translate(-_w / 2, -_h * .32);
        _backdrop(canvas);
        if (_course && ProofCourse.tunnelAt(controller.courseDistance) > 0) {
          final shade = ProofCourse.tunnelAt(controller.courseDistance);
          canvas.drawRect(
            Rect.fromLTWH(0, 0, _w, _h),
            Paint()..color = Color.fromRGBO(20, 28, 34, shade * .96),
          );
        }
        _road(canvas);
        if (_course && ProofCourse.tunnelAt(controller.courseDistance) > 0) {
          final shade = ProofCourse.tunnelAt(controller.courseDistance);
          final wallPaint = Paint()
            ..shader = ui.Gradient.linear(
              Offset.zero,
              const Offset(_w, 0),
              [
                Color.fromRGBO(9, 14, 20, shade * .82),
                const Color(0x00101620),
                const Color(0x00101620),
                Color.fromRGBO(9, 14, 20, shade * .82),
              ],
              [.0, .24, .76, 1],
            );
          canvas.drawRect(Rect.fromLTWH(0, 0, _w, _h), wallPaint);
        }
        _composeObjects();
        _drawObjects(canvas);
        _dust(canvas);
        canvas.restore();
        _weather(canvas);
        if (_course) _courseAtmosphere(canvas);
      }
      canvas.restore();
    }
    renderCount++;
    _renderWatch.stop();
    lastRenderMicros = _renderWatch.elapsedMicroseconds;
    renderCpuMicros += lastRenderMicros;
    maxRenderMicros = math.max(maxRenderMicros, lastRenderMicros);
  }

  int _fogAt(double distance) => Color.fromRGBO(
    184,
    205,
    207,
    ((distance - 1800) / 11000).clamp(0.0, .48),
  ).toARGB32();

  void _courseAtmosphere(Canvas canvas) {
    final darkness = ProofCourse.tunnelAt(controller.courseDistance);
    if (darkness > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, _w, _h),
        Paint()..color = Color.fromRGBO(16, 23, 31, darkness * .56),
      );
      // A readable headlight pool uses one cached-style gradient, not a blur.
      final light = ui.Gradient.radial(Offset(_w * .5, _h * .69), _w * .4, [
        Color.fromRGBO(255, 230, 175, darkness * .14),
        const Color(0x00ffe6af),
      ]);
      canvas.drawRect(
        Rect.fromLTWH(0, _h * .38, _w, _h * .62),
        Paint()..shader = light,
      );
    }
  }

  void _sky(Canvas canvas) {
    final sky = Rect.fromLTWH(0, 0, _w, _h);
    _paint.shader = ui.Gradient.linear(
      Offset.zero,
      Offset(0, _h * .48),
      [
        const Color(0xff80bbd5),
        const Color(0xffd8e6d4),
        const Color(0xffffe6ba),
      ],
      [0, .72, 1],
    );
    canvas.drawRect(sky, _paint);
    _paint.shader = null;
    final sun = Offset(800, _h * (.17 + _coursePitch));
    _paint.color = const Color(0xffffefd0);
    canvas.drawCircle(sun, 27, _paint);
    if (!_loaded) return;
    final src = Rect.fromLTWH(
      0,
      0,
      _art.cloud.width.toDouble(),
      _art.cloud.height.toDouble(),
    );
    for (var i = 0; i < 6; i++) {
      final depth = i.isEven ? 1.0 : .66;
      final x =
          ((i * 237 +
                  _presentationTime * (7 + i % 3) -
                  _center(_world) * .003) %
              1440) -
          240;
      final y = _h * (.045 + (i % 3) * .065 + _coursePitch);
      _paint.color = Color.fromRGBO(255, 255, 255, i.isEven ? .88 : .50);
      canvas.drawImageRect(
        _art.cloud,
        src,
        Rect.fromLTWH(x, y, 230 * depth, 90 * depth),
        _paint,
      );
    }
    _paint.color = const Color(0xffffffff);
  }

  void _backdrop(Canvas canvas) {
    final backdrop = _art.backdrop;
    if (backdrop == null) return;
    final source = Rect.fromLTWH(
      0,
      0,
      backdrop.width.toDouble(),
      backdrop.height.toDouble(),
    );
    final offset = -(_center(_world) * .018) % 1200;
    final height = _h * .54;
    final y = _h * (.39 + _coursePitch) - height;
    _paint.color = const Color(0xffffffff);
    for (var i = -2; i < 2; i++) {
      canvas.drawImageRect(
        backdrop,
        source,
        Rect.fromLTWH(offset + i * 1200, y, 1202, height),
        _paint,
      );
    }
    // A thin haze unifies the painted distance with the live projected terrain.
    _paint.shader = ui.Gradient.linear(
      Offset(0, _h * (.32 + _coursePitch)),
      Offset(0, _h * (.46 + _coursePitch)),
      [const Color(0x00d6dfbe), const Color(0xffb5c49a)],
    );
    canvas.drawRect(
      Rect.fromLTWH(0, _h * (.32 + _coursePitch), _w, _h * .19),
      _paint,
    );
    _paint.shader = null;
  }

  void _road(Canvas canvas) {
    _ground.clear();
    _shoulder.clear();
    _asphalt.clear();
    _joiningLane.clear();
    _joiningMarkings.clear();
    _markings.clear();
    final base = (_cameraZ / _segmentLength).floor() * _segmentLength;
    var crestClip = _h + 200;
    for (var i = 0; i <= _segmentCount; i++) {
      _project(base + (i + 1) * _segmentLength, _points[i]);
      _points[i].clip = crestClip;
      if (_points[i].y < crestClip) crestClip = _points[i].y;
    }
    final biome = _biome;
    final green = biome == Biome.city
        ? const Color(0xff9cb77c)
        : biome == Biome.mountain
        ? const Color(0xff8da982)
        : const Color(0xff94b66d);
    for (var i = _segmentCount - 1; i >= 0; i--) {
      final a = _points[i], b = _points[i + 1];
      a.visible = a.y > b.y && b.y < a.clip && b.y < _h + 60 && a.z > 20;
      if (!a.visible) continue;
      final worldZ = base + (i + 1) * _segmentLength;
      final yNear = a.y, yFar = b.y;
      final fade = (a.z / 13000).clamp(0.0, .65);
      final color = Color.lerp(
        green,
        const Color(0xffd1d8bb),
        fade,
      )!.toARGB32();
      _ground.quad(
        a.x - a.halfWidth * 7,
        a.x + a.halfWidth * 7,
        yNear,
        b.x - b.halfWidth * 7,
        b.x + b.halfWidth * 7,
        yFar,
        0,
        2048,
        worldZ / 900 * 256,
        (worldZ + _segmentLength) / 900 * 256,
        color,
        color,
      );
      final shoulderColor = biome == Biome.city ? 0xffc9c5aa : 0xffd4c297;
      _shoulder.quad(
        a.x - a.halfWidth * 1.14,
        a.x + a.halfWidth * 1.14,
        yNear,
        b.x - b.halfWidth * 1.14,
        b.x + b.halfWidth * 1.14,
        yFar,
        0,
        512,
        worldZ / 480 * 512,
        (worldZ + _segmentLength) / 480 * 512,
        shoulderColor,
        shoulderColor,
      );
      final weatherTint = controller.weather == RaceWeather.rain
          ? const Color(0xffb4c6d0)
          : controller.weather == RaceWeather.snow
          ? const Color(0xffd5dfe0)
          : const Color(0xffffffff);
      final tint = Color.lerp(
        weatherTint,
        const Color(0xffd5dfdf),
        fade * .5,
      )!.toARGB32();
      if (_nextProof &&
          ProofJoiningLane.visible(worldZ) &&
          ProofJoiningLane.visible(worldZ + _segmentLength)) {
        final ac = ProofJoiningLane.center(worldZ);
        final bc = ProofJoiningLane.center(worldZ + _segmentLength);
        final aw = ProofJoiningLane.halfWidth(worldZ);
        final bw = ProofJoiningLane.halfWidth(worldZ + _segmentLength);
        _joiningLane.quad(
          a.x + a.halfWidth * (ac - aw),
          a.x + a.halfWidth * (ac + aw),
          yNear,
          b.x + b.halfWidth * (bc - bw),
          b.x + b.halfWidth * (bc + bw),
          yFar,
          0,
          512,
          worldZ / 480 * 512,
          (worldZ + _segmentLength) / 480 * 512,
          tint,
          tint,
        );
        // A continuous outer edge and a dashed inner edge make the merge legible.
        for (final side in [-1.0, 1.0]) {
          if (side < 0 && (worldZ / _segmentLength).floor() % 4 > 1) continue;
          _joiningMarkings.quad(
            a.x + a.halfWidth * (ac + side * aw - .006),
            a.x + a.halfWidth * (ac + side * aw + .006),
            yNear,
            b.x + b.halfWidth * (bc + side * bw - .006),
            b.x + b.halfWidth * (bc + side * bw + .006),
            yFar,
            0,
            1,
            0,
            1,
            0xfff5efd8,
            0xfff5efd8,
          );
        }
      }
      _asphalt.quad(
        a.x - a.halfWidth,
        a.x + a.halfWidth,
        yNear,
        b.x - b.halfWidth,
        b.x + b.halfWidth,
        yFar,
        0,
        512,
        worldZ / 480 * 512,
        (worldZ + _segmentLength) / 480 * 512,
        tint,
        tint,
      );
    }
    // Markings are projected geometry rather than affine tile samples: long
    // straight lane lines must not bend across a textured triangle diagonal.
    for (var i = _segmentCount - 1; i >= 0; i--) {
      final a = _points[i], b = _points[i + 1];
      if (!a.visible) continue;
      final worldZ = base + (i + 1) * _segmentLength;
      void line(double left, double right, int color) {
        _markings.quad(
          a.x + a.halfWidth * left,
          a.x + a.halfWidth * right,
          a.y,
          b.x + b.halfWidth * left,
          b.x + b.halfWidth * right,
          b.y,
          0,
          1,
          0,
          1,
          color,
          color,
        );
      }

      line(-.974, -.968, 0xffead394);
      line(-.956, -.950, 0xffead394);
      line(.960, .970, 0xfff5f1d9);
      if ((worldZ / _segmentLength).floor() % 5 < 3) {
        line(-.338, -.328, 0xfff4f2e4);
        line(.328, .338, 0xfff4f2e4);
      }
    }
    _ground.draw(canvas, _groundPaint);
    _shoulder.draw(
      canvas,
      Paint()
        ..color = const Color(0xffffffff)
        ..isAntiAlias = false,
    );
    _joiningLane.draw(canvas, _roadPaint);
    _joiningMarkings.draw(
      canvas,
      Paint()
        ..color = const Color(0xffffffff)
        ..isAntiAlias = false,
    );
    _asphalt.draw(canvas, _roadPaint);
    _markings.draw(
      canvas,
      Paint()
        ..color = const Color(0xffffffff)
        ..isAntiAlias = false,
    );
    lastRoadQuads = _asphalt.count;
  }

  void _composeObjects() {
    _objects.clear();
    final near = _cameraZ + 450,
        far = _cameraZ + _segmentLength * (_segmentCount - 2);
    final first = (near / 330).floor();
    for (var i = first; i * 330 < far; i++) {
      final z = i * 330.0;
      if (_course && !ProofCourse.vegetationAllowedAt(_courseAt(z))) continue;
      final side = i.isEven ? -1.0 : 1.0;
      final hash = ((i * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff;
      // Samples are selected spatially, so no popping when a UI stage changes.
      final cityEnd =
          controller.graph.edges.first.length * _flowScale + _worldOffset;
      final biome = _course
          ? (_courseAt(z) < 600 ? Biome.city : Biome.forest)
          : _nextProof
          ? (z < cityEnd ? Biome.city : Biome.forest)
          : proofMode
          ? (z < 14500
                ? Biome.city
                : z < 36500
                ? Biome.forest
                : Biome.mountain)
          : _biome;
      final tree = biome == Biome.mountain
          ? 1
          : biome == Biome.coast
          ? 2
          : 0;
      if (biome == Biome.city && i % 4 == 0) {
        _objects.add(
          _Object(_Kind.scenery, z, side * (2.5 + hash * .3), 1500, frame: 3),
        );
        _objects.add(
          _Object(
            _Kind.scenery,
            z + 130,
            -side * 2.5,
            1500,
            frame: i % 8 == 0 ? 4 : 3,
          ),
        );
      } else {
        _objects.add(
          _Object(
            _Kind.scenery,
            z,
            side * (1.48 + hash * .65),
            1000 + hash * 550,
            frame: tree,
          ),
        );
        if (i % 3 == 0) {
          _objects.add(
            _Object(
              _Kind.scenery,
              z + 170,
              -side * (1.75 + hash * .9),
              1100,
              frame: tree,
            ),
          );
        }
      }
      if (i % 2 == 0) {
        _objects.add(
          _Object(_Kind.scenery, z + 90, -side * 1.28, 430, frame: 5),
        );
      }
      if (_nextProof &&
          ProofJoiningLane.visible(z) &&
          ProofJoiningLane.progress(z) < .6) {
        _objects.add(
          _Object(
            _Kind.cone,
            z,
            ProofJoiningLane.center(z) - ProofJoiningLane.halfWidth(z) - .05,
            48,
          ),
        );
      }
      if (_nextProof && (!_course || _cameraPreset != 'baseline')) {
        // Small near-road references carry fast peripheral flow without hiding
        // upcoming traffic behind a wall of large trees.
        _objects.add(_Object(_Kind.marker, z + 140, side * 1.15, 34));
      }
      if (biome == Biome.city && i % 3 == 0) {
        _objects.add(_Object(_Kind.lamp, z - 80, side * 1.20, 550));
      }
    }
    for (final car in controller.traffic) {
      final z = car.position * _flowScale + _worldOffset;
      if (z > near && z < far) {
        _objects.add(
          _Object(
            _Kind.traffic,
            z,
            car.x,
            car.truck ? 370 : 300,
            frame: car.paintVariant,
            braking: car.braking,
            incident: car.incidentSeconds,
            reaction: car.reactionIntensity,
          ),
        );
      }
    }
    // Two scenic spans within the proof, using the same depth ordering as cars.
    final firstBridge = (_world / 25000).floor() * 25000.0 + 11500;
    final bridgeSpans = _course
        ? [_courseZ(5660)]
        : [firstBridge, firstBridge + 25000];
    for (final z in bridgeSpans) {
      if (z > _cameraZ + 280 && z < far) {
        _objects.add(_Object(_Kind.bridge, z, 0, 4100));
      }
    }
    if (controller.closedLane != null) {
      final start =
          (controller.worldDistance +
                  controller.closureStart -
                  controller.edgeDistance) *
              _flowScale +
          _worldOffset;
      final end =
          (controller.worldDistance +
                  controller.closureEnd -
                  controller.edgeDistance) *
              _flowScale +
          _worldOffset;
      for (final z in ProofCourse.fixedPositions(
        origin: start - 1800,
        spacing: 230,
        near: near,
        far: far,
        end: end,
      )) {
        final taper = ((z - start + 1800) / 1800).clamp(0, 1);
        _objects.add(
          _Object(
            _Kind.cone,
            z,
            controller.closedLane! * (1 - .56 * taper),
            52,
          ),
        );
      }
    }
    if (_course) {
      for (final s in [5110.0, 5310.0, 5500.0]) {
        final z = _courseZ(s);
        if (z > near && z < far) {
          _objects.add(_Object(_Kind.canopy, z, 0, 3200));
        }
      }
      for (final s in [6080.0, 6230.0, 6380.0, 6530.0, 6680.0, 6770.0]) {
        final z = _courseZ(s);
        if (z > near && z < far) {
          _objects.add(_Object(_Kind.portal, z, 0, 6400));
        }
      }
    }
    _objects.add(_Object(_Kind.player, _world, _playerX, _course ? 285 : 300));
    _objects.sort((a, b) => b.z.compareTo(a.z));
    lastSpriteCount = _objects.length;
  }

  final _RoadPoint _objectPoint = _RoadPoint();
  double _clipAt(double z) {
    final index = ((z - _cameraZ) / _segmentLength).floor().clamp(
      0,
      _segmentCount - 1,
    );
    return _points[index].clip;
  }

  void _drawObjects(Canvas canvas) {
    for (final object in _objects) {
      _project(object.z, _objectPoint);
      final p = _objectPoint;
      if (p.z < 200) continue;
      final x = p.x + p.halfWidth * object.lateral;
      final width = p.halfWidth * object.width / _roadHalfWidth;
      final clip = _clipAt(object.z);
      if (x + width < -30 || x - width > _w + 30) continue;
      switch (object.kind) {
        case _Kind.scenery:
          final atlas = _art.environmentAtlas;
          if (atlas == null) continue;
          final source = _art.environmentFrames[object.frame];
          // All environment cells share a ground baseline near their lower edge.
          final scale = width / 450;
          _sprite(
            canvas,
            atlas,
            source,
            x - source.width * scale * .5,
            p.y - ProofArt.sceneryGround[object.frame] * scale,
            scale,
            clip: clip,
            fog: _course ? _fogAt(p.z) : null,
          );
        case _Kind.traffic:
          _vehicle(canvas, object, x, p.y, width, clip, false);
        case _Kind.player:
          _vehicle(canvas, object, x, p.y, width, clip, true);
        case _Kind.bridge:
          final scale = width / 1024;
          _sprite(
            canvas,
            _art.bridge,
            const Rect.fromLTWH(0, 0, 1024, 480),
            x - width * .5,
            p.y - 480 * scale,
            scale,
            clip: clip,
          );
        case _Kind.lamp:
        case _Kind.cone:
        case _Kind.marker:
        case _Kind.canopy:
        case _Kind.portal:
          final roadIndex = switch (object.kind) {
            _Kind.cone => 0,
            _Kind.marker => 2,
            _Kind.canopy => 3,
            _Kind.portal => 4,
            _ => 5,
          };
          if (_art.coursePropsReady) {
            final source = _art.coursePropFrames[roadIndex];
            final scale = width / source.width;
            final overhead = object.kind == _Kind.canopy
                ? p.halfWidth * .34
                : 0.0;
            _sprite(
              canvas,
              _art.environmentAtlas!,
              source,
              x - width * .5,
              p.y - source.height * scale - overhead,
              scale,
              clip: clip,
              fog: _course ? _fogAt(p.z) : null,
            );
          } else {
            final source = object.kind == _Kind.cone
                ? ProofArt.coneFrame
                : object.kind == _Kind.marker
                ? ProofArt.markerFrame
                : ProofArt.lampFrame;
            final basis = object.kind == _Kind.cone
                ? 180.0
                : object.kind == _Kind.marker
                ? 120.0
                : 150.0;
            final scale = width / basis;
            _sprite(
              canvas,
              _art.environmentAtlas!,
              source,
              x - source.width * scale * .5,
              p.y - source.height * scale,
              scale,
              clip: clip,
            );
          }
        case _Kind.sign:
          break;
      }
    }
    _batch.flush(canvas);
  }

  void _sprite(
    Canvas canvas,
    ui.Image image,
    Rect source,
    double x,
    double y,
    double scale, {
    double clip = double.infinity,
    int tint = 0xffffffff,
    bool mirrored = false,
    int? fog,
  }) {
    if (scale <= 0 || y >= clip) return;
    final visibleHeight = math.min(source.height, (clip - y) / scale);
    if (visibleHeight <= 0) return;
    // Half-texel inset keeps bilinear samples inside their authored cell.
    if (visibleHeight <= 1 || source.width <= 1) return;
    final cropped = Rect.fromLTWH(
      source.left + .5,
      source.top + .5,
      source.width - 1,
      visibleHeight - 1,
    );
    if (mirrored) {
      _batch.flush(canvas);
      canvas.save();
      canvas.translate(x + source.width * scale, y);
      canvas.scale(-1, 1);
      _paint.color = Color(tint);
      canvas.drawImageRect(
        image,
        cropped,
        Rect.fromLTWH(
          .5 * scale,
          .5 * scale,
          cropped.width * scale,
          cropped.height * scale,
        ),
        _paint,
      );
      canvas.restore();
      return;
    }
    _batch.add(
      canvas,
      image,
      cropped,
      x + .5 * scale,
      y + .5 * scale,
      scale,
      color: fog ?? tint,
      // Atlas image is source and tint is destination; keep image alpha.
      blend: fog == null ? BlendMode.modulate : BlendMode.dstATop,
    );
  }

  VehiclePose _pose(bool player) {
    if (!player) return const VehiclePose(0);
    if (_course) {
      return _steeringArt.pose(
        speed: controller.speed,
        grade: (_elevation(_world + 160) - _elevation(_world - 160)) / 320,
        recovering: controller.recovering,
      );
    }
    return VehiclePose.select(
      steering: controller.steering,
      speed: controller.speed,
      grade: (_elevation(_world + 160) - _elevation(_world - 160)) / 320,
      recovering: controller.recovering,
    );
  }

  void _vehicle(
    Canvas canvas,
    _Object object,
    double x,
    double y,
    double width,
    double clip,
    bool player,
  ) {
    var pose = _pose(player);
    final useTurn = player && pose.turnSheet && _art.turnAtlas != null;
    if (pose.turnSheet && !useTurn) {
      pose = VehiclePose(pose.frame.isEven ? 1 : 2);
    }
    final atlas = useTurn
        ? _art.turnAtlas
        : player
        ? _art.carAtlas
        : (_art.trafficAtlas ?? _art.carAtlas);
    if (atlas == null) return;
    final frame = pose.frame;
    final paletteTraffic = !player && _art.trafficAtlas != null;
    final src = paletteTraffic
        ? Rect.fromLTWH((object.frame % 8) * 256.0, 0, 256, 256)
        : useTurn
        ? _art.turnFrames[frame]
        : _art.carFrames[frame];
    final anchorScale = paletteTraffic ? .5 : 1.0;
    final scale = width / (450 * anchorScale);
    final speed = controller.speed / controller.car.topSpeed;
    final bounce = player
        ? (math.sin(_world * .021) * 1.1 + math.sin(_world * .057) * .42) *
              speed
        : 0.0;
    final bodyY = y + bounce;
    final groundAnchor =
        (useTurn ? _art.turnGround[frame] : _art.groundAnchors[frame]) *
        anchorScale;
    final center = useTurn ? _art.turnCenter[frame] : _art.centerAnchors[frame];
    final centerAnchor = pose.mirrored
        ? src.width - center * anchorScale
        : center * anchorScale;
    final shadowWidth = width * 1.13;
    _sprite(
      canvas,
      _art.shadow,
      const Rect.fromLTWH(0, 0, 128, 48),
      x - shadowWidth * .5,
      y - 24 * (shadowWidth / 128),
      shadowWidth / 128,
      clip: clip,
      tint: 0xffffffff,
    );
    if ((player && controller.recovering) || (!player && object.incident > 0)) {
      _batch.flush(canvas);
      canvas.save();
      canvas.translate(x, bodyY);
      if (player) {
        canvas.translate(
          0,
          -math.sin(controller.recoveryProgress * math.pi) * 62,
        );
        canvas.rotate(
          controller.recoveryProgress *
              math.pi *
              (controller.crashPose == CrashPose.flip ? 2 : .6),
        );
      } else {
        canvas.rotate(math.sin((2.4 - object.incident) * 2.5) * .22);
      }
      _paint.color = const Color(0xffffffff);
      canvas.drawImageRect(
        atlas,
        src,
        Rect.fromLTWH(
          -centerAnchor * scale,
          -groundAnchor * scale,
          src.width * scale,
          src.height * scale,
        ),
        _paint,
      );
      canvas.restore();
    } else {
      final flicker =
          player &&
          controller.protection > 0 &&
          (controller.elapsed * 9).floor().isEven;
      if (!flicker) {
        _sprite(
          canvas,
          atlas,
          src,
          x - centerAnchor * scale,
          bodyY - groundAnchor * scale,
          scale,
          clip: clip,
          tint: 0xffffffff,
          mirrored: pose.mirrored,
        );
      }
    }
    if ((player ? controller.braking : object.braking) &&
        bodyY - width * .39 < clip) {
      _batch.flush(canvas);
      for (final side in [-1.0, 1.0]) {
        _paint
          ..color = const Color(0x99ff5539)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x + side * width * .29, bodyY - width * .39),
            width: width * .20,
            height: width * .055,
          ),
          _paint,
        );
      }
      _paint.maskFilter = null;
    }
    // Rapid alternating tire highlights are tied to distance, not frame count.
    if (player && speed > .1 && !controller.recovering) {
      _batch.flush(canvas);
      final phase = (_world * .027) % 1;
      _paint
        ..color = Color.fromRGBO(169, 183, 178, .22 + phase * .13)
        ..strokeWidth = 1.1;
      for (final side in [-1.0, 1.0]) {
        final tx = x + side * width * .43;
        canvas.drawLine(
          Offset(tx, bodyY - 10 - phase * 10),
          Offset(tx + side * 3, bodyY - 5 - phase * 10),
          _paint,
        );
      }
    }
  }

  void _dust(Canvas canvas) {
    if (controller.speed < 40 || controller.paused) return;
    _project(_world, _objectPoint);
    final x = _objectPoint.x + _objectPoint.halfWidth * _playerX,
        y = _objectPoint.y;
    final offroad = controller.playerX.abs() > 1;
    final sliding = controller.steering.abs() > .6;
    final intensity = (offroad || sliding) ? .45 : .12;
    for (var i = 0; i < 10; i++) {
      final phase = (_presentationTime * 2.0 + i * .137) % 1;
      final side = i.isEven ? -1 : 1;
      final px = x + side * (60 + phase * 80), py = y + phase * 32;
      _paint.color = Color.fromRGBO(237, 220, 169, intensity * (1 - phase));
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(px, py),
          width: 10 + phase * 32,
          height: 5 + phase * 13,
        ),
        _paint,
      );
    }
  }

  void _weather(Canvas canvas) {
    if (proofMode && !_nextProof) return;
    final snow = controller.weather == RaceWeather.snow;
    if (!snow && controller.weather != RaceWeather.rain) return;
    _paint
      ..color = const Color(0x65e8f3f4)
      ..strokeWidth = 1;
    for (var i = 0; i < 44; i++) {
      final x = (i * 137.0 + _presentationTime * (snow ? 15 : 65)) % _w;
      final y = (i * 79.0 + _presentationTime * (snow ? 55 : 380)) % _h;
      if (snow) {
        canvas.drawCircle(Offset(x, y), 1.2 + i % 2, _paint);
      } else {
        canvas.drawLine(Offset(x, y), Offset(x - 4, y + 11), _paint);
      }
    }
  }

  @override
  void onRemove() {
    _removed = true;
    _art.dispose();
    super.onRemove();
  }
}
