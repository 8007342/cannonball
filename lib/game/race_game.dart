import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import 'race_controller.dart';
import 'render/proof_art.dart';
import 'render/proof_camera.dart';
import 'render/proof_depth.dart';
import 'render/proof_foliage.dart';
import 'render/proof_lighting.dart';
import 'proof_level.dart';
import 'render/proof_suspension.dart';
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
  flyingCone,
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
    this.flightAge = 0,
  });
  final _Kind kind;
  final double z, lateral, width;
  final int frame;
  int lightId = -1;
  final bool braking;
  final double incident, reaction, flightAge;
  double fadeFar = double.infinity;
}

/// Original cartoon art proof with independent simulation and presentation.
/// Full-resolution generated textures are decoded once. The frame uses three
/// textured road meshes, cached parallax art, and depth-ordered atlas batches.
class RaceGame extends FlameGame {
  RaceGame({required this.controller, this.proofMode = false});
  final RaceController controller;
  final bool proofMode;
  final ProofArt _art = ProofArt();
  final lighting = ProofLighting();
  final lightHistory = LightHistory();
  final Map<int, double> _lightCache = {};
  final Map<(double, double), bool> _lightVisibilityCache = {};
  ProofLevel get level => controller.proofLevel;
  ProofTerrain get terrain => controller.proofTerrain;
  int get levelAssetCount => _art.levelAssetCount;
  int get levelAssetPixels => _art.levelAssetPixels;
  double get nightStrength => _course
      ? math.max(
          level.night,
          ProofCourse.tunnelAt(controller.courseDistance) * .9,
        )
      : 0;
  ui.Image? get _environment =>
      _course ? _art.environmentFor(level) : _art.environmentAtlas;

  final SteeringPresentation _steeringArt = SteeringPresentation();
  final BillboardBatch _batch = BillboardBatch();
  static const _w = 1000.0, _roadHalfWidth = 1100.0;
  static const visualSpeedScale = 12.0;
  String _speedPreset = 'velocity';
  String get speedPreset => _speedPreset;
  void setSpeedPreset(String preset) {
    if (const [
      'classic',
      'cruise',
      'arcade',
      'turbo',
      'afterburn',
      'hyperspeed',
      'velocity',
    ].contains(preset)) {
      final previous = _flowScale;
      _speedPreset = preset;
      final interpolatedDistance = (_world - _worldOffset) / previous;
      _worldOffset += interpolatedDistance * (previous - _flowScale);
      if (_course) {
        controller.proofPresentationScale = _flowScale;
        controller.proofTrafficPreview = ProofDepth.preview(_flowScale);
      }
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
                : _speedPreset == 'arcade'
                ? 1.7
                : _speedPreset == 'turbo'
                ? 3.0
                : _speedPreset == 'afterburn'
                ? 7.0
                : _speedPreset == 'hyperspeed'
                ? 11.0
                : 14.0)
          : 1.0);
  bool get _course => _nextProof && controller.testCourseEnabled;
  String _cameraPreset = 'wide';
  final chase = ProofChaseResponse();
  final suspension = ProofSuspension();
  final groundedSlope = GroundedSlopePresentation();
  bool legacySlopePoses = false;
  bool animatedFoliage = true;
  bool suspensionEnabled = true;
  int _lastConeHits = 0;
  bool stableChase = false, speedEffects = false;
  String get cameraPreset => _cameraPreset;
  void setCameraPreset(String value) {
    if (const ['baseline', 'wide', 'flow'].contains(value)) {
      _cameraPreset = value;
    }
  }

  double get roadHeading => _tangent;
  double get horizonFraction =>
      _course ? ProofCamera.horizon(_cameraPreset) : .30;
  double get cameraHeight => _course
      ? ProofCamera.height(_cameraPreset, _projection, ground: chase.ground)
      : 660;
  double get _viewPitch =>
      _course ? ProofCamera.pitch(_coursePitch, _cameraPreset) : 0;
  double _objectOpacity = 1;
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

  static const _segmentLength = 170.0, _segmentCount = ProofDepth.segments;
  double _depthAt(int index) =>
      _course ? ProofDepth.sample(index, _flowScale) : index * _segmentLength;
  double get _farDepth => _depthAt(_segmentCount - 2);
  double get trafficPreviewDistance => ProofDepth.preview(_flowScale);
  double get previewSeconds =>
      trafficPreviewDistance /
      math.max(1, controller.speed * RouteGraph.speedScale);
  final List<_RoadPoint> _points = List.generate(
    _segmentCount + 1,
    (_) => _RoadPoint(),
  );
  final RoadMesh _ground = RoadMesh(_segmentCount);
  final RoadMesh _shoulder = RoadMesh(_segmentCount);
  final RoadMesh _asphalt = RoadMesh(_segmentCount * 3);
  final RoadMesh _leaves = RoadMesh(_segmentCount * 2);
  final RoadMesh _joiningLane = RoadMesh(_segmentCount);
  final RoadMesh _joiningMarkings = RoadMesh(_segmentCount * 2);
  final RoadMesh _markings = RoadMesh(_segmentCount * 9);
  final _RoadPoint _dashNear = _RoadPoint(), _dashFar = _RoadPoint();
  final List<_Object> _objects = [];
  final Paint _paint = Paint()
    ..isAntiAlias = true
    ..filterQuality = FilterQuality.low;
  late Paint _roadPaint, _groundPaint, _leafPaint;
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
      _leafPaint = Paint()
        ..shader = ui.ImageShader(
          _art.leafPatch,
          TileMode.repeated,
          TileMode.repeated,
          identity,
          filterQuality: FilterQuality.low,
        );
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
    final previousSpeed = controller.speed, previousPitch = _coursePitch;
    super.update(dt);
    if (controller.seed != _lastSeed || controller.elapsed < _lastElapsed) {
      _lastSeed = controller.seed;
      _presentationTime = controller.elapsed;
      _worldOffset = 0;
      _xVelocity = 0;
      _steeringArt.reset();
      chase.reset();
      suspension.reset();
      groundedSlope.reset();
      lighting.reset();
      lightHistory.clear();
      _lastConeHits = 0;
      _coursePitch = _course
          ? terrain.pitchAt(controller.courseDistance, _flowScale)
          : 0;
    }
    if (!controller.paused && !controller.finished && dt.isFinite) {
      _presentationTime += dt.clamp(0, .25);
    }
    if (_course) {
      controller.proofPresentationScale = _flowScale;
      controller.proofTrafficPreview = ProofDepth.preview(_flowScale);
    }
    controller.tick(dt);
    if (_course && !controller.paused && !controller.finished) {
      _steeringArt.update(controller.effectiveSteering, dt);
      lighting.update(controller.effectiveSteering, dt);
      chase.update(
        speedRatio: controller.speed / controller.car.topSpeed,
        steering: controller.effectiveSteering,
        braking: controller.braking,
        recovering: controller.recovering,
        stable: stableChase || controller.comfortMode,
        dt: dt,
      );
      final targetPitch = terrain.pitchAt(
        controller.courseDistance,
        _flowScale,
      );
      _coursePitch +=
          (targetPitch - _coursePitch) * (1 - math.exp(-6 * dt.clamp(0, .25)));
    }
    if (_course && !controller.paused && !controller.finished) {
      suspension.update(
        speedRatio: controller.speed / controller.car.topSpeed,
        acceleration: (controller.speed - previousSpeed) / dt,
        steering: controller.effectiveSteering,
        gradeRate: (_coursePitch - previousPitch) / dt,
        quiet: controller.comfortMode || !suspensionEnabled,
        dt: dt,
        impact: controller.coneHitCount > _lastConeHits,
      );
      groundedSlope.update(
        grade: terrain.gradeAt(controller.courseDistance, _flowScale),
        cameraPitch: math.atan(_viewPitch / (_projection * .70)),
        dt: dt,
        quiet: controller.comfortMode || !suspensionEnabled,
      );
      _lastConeHits = controller.coneHitCount;
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
      ? terrain.centerAt(_courseAt(z))
      : controller.centerAt((z - _worldOffset) / _flowScale) * 8;
  double _elevation(double z) {
    if (_course) return terrain.elevationAt(_courseAt(z));
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
    out.y =
        _h * horizonFraction +
        scale * (_cameraY - _elevation(worldZ)) * _h * .70;
    if (_course) out.y += _h * ProofCourse.pitchShift(_viewPitch, z);
    out.halfWidth = scale * _roadHalfWidth * _w * .5;
  }

  @override
  void render(Canvas canvas) {
    _renderWatch
      ..reset()
      ..start();
    super.render(canvas);
    _batch.drawCalls = 0;
    _lightCache.clear();
    _lightVisibilityCache.clear();
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
                ? cameraHeight
                : _nextProof
                ? 660
                : 730);
        final roadFrame = ProofRoadFrame(
          roadCenter: _center(_cameraZ),
          roadAhead: _center(_cameraZ + 20),
          lookOffset: _course ? chase.lateralLook * _roadHalfWidth : 0,
        );
        _cameraX = roadFrame.origin;
        _tangent = roadFrame.heading;
        canvas.save();
        canvas.translate(_w / 2, _h * horizonFraction);
        canvas.rotate(controller.cameraLean * .65);
        canvas.translate(-_w / 2, -_h * horizonFraction);
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
        if (_course && speedEffects && !controller.comfortMode) {
          _speedCues(canvas);
        }
      }
      canvas.restore();
    }
    renderCount++;
    _renderWatch.stop();
    lastRenderMicros = _renderWatch.elapsedMicroseconds;
    renderCpuMicros += lastRenderMicros;
    maxRenderMicros = math.max(maxRenderMicros, lastRenderMicros);
  }

  void _speedCues(Canvas canvas) {
    final strength = ((controller.speed / controller.car.topSpeed - .35) / .65)
        .clamp(0.0, 1.0);
    if (strength <= 0) return;
    final center = Offset(_w * .5, _h * .60);
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        _w * .68,
        [
          const Color(0x00081018),
          const Color(0x00081018),
          Color.fromRGBO(8, 16, 24, strength * .40),
        ],
        [0, .48, 1],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, _w, _h), paint);
    paint.shader = null;
    paint.strokeWidth = 1.5;
    // Short peripheral streaks, no full-frame blur or obscured central hazards.
    for (var i = 0; i < 20; i++) {
      final phase = (_presentationTime * (1.1 + strength) + i * .127) % 1;
      final side = i.isEven ? -1.0 : 1.0;
      final x = center.dx + side * (_w * .36 + phase * _w * .16);
      final y = _h * (.12 + (i % 7) * .13);
      final outer = Offset(x, y);
      final fromHorizon = outer - Offset(_w * .5, _h * .48);
      final direction = fromHorizon / fromHorizon.distance;
      final inner = outer - direction * (35 + strength * 120);
      paint.strokeWidth = 2.2;
      paint.shader = ui.Gradient.linear(inner, outer, [
        const Color(0x00e0f3ff),
        Color.fromRGBO(224, 243, 255, strength * .62 * (1 - phase * .4)),
      ]);
      canvas.drawLine(inner, outer, paint);
      paint.shader = null;
    }
  }

  bool _lightVisible(double from, double to) {
    return _lightVisibilityCache.putIfAbsent((
      from,
      to,
    ), () => _evaluateLightVisibility(from, to));
  }

  bool _evaluateLightVisibility(double from, double to) {
    final a = _elevation(from) + 140, b = _elevation(to) + 30;
    for (final t in [.25, .5, .75]) {
      if (_elevation(from + (to - from) * t) > a + (b - a) * t) return false;
    }
    return true;
  }

  double _illumination(double z, double lateral) {
    if (!_course || nightStrength < .05) return 0;
    final key = z.round() * 8192 + (lateral * 256).round();
    return _lightCache.putIfAbsent(
      key,
      () => _evaluateIllumination(z, lateral),
    );
  }

  double _evaluateIllumination(double z, double lateral) {
    final distance = z - _world;
    final bend =
        (_center(z) - _center(_world) - _tangent * distance) / _roadHalfWidth;
    var light = distance > 0 && distance < 26000 && _lightVisible(_world, z)
        ? ProofLighting.beam(distance, lateral + bend - _playerX, lighting.aim)
        : 0.0;
    // Only the nearest three NPC emitters contribute to surfaces.
    var used = 0;
    for (final car in controller.traffic) {
      final origin = car.position * _flowScale + _worldOffset;
      if ((origin - _world).abs() > 18000) continue;
      final forward = z - origin;
      if (forward <= 0 || forward > 14000) continue;
      if (_lightVisible(origin, z)) {
        light += ProofLighting.beam(forward * 1.6, lateral - car.x, 0) * .42;
      }
      if (++used >= 3) break;
    }
    if (level.lampSpacing > 0) {
      final s = _courseAt(z);
      final ordinal = ((s - 25) / level.lampSpacing).round();
      final lampS = 25 + ordinal * level.lampSpacing;
      final side = ordinal.isEven ? -1.24 : 1.24;
      final along = (s - lampS) / 25;
      final across = (lateral - side) / 1.35;
      if (ProofCourse.tunnelAt(lampS) < .1) {
        light += .8 / (1 + along * along * 2 + across * across);
      }
    }
    return light.clamp(0.0, 1.0);
  }

  int _material(int color, double z, double lateral) => !_course
      ? color
      : ProofLighting.material(color, nightStrength, _illumination(z, lateral));

  void _glow(
    Canvas canvas,
    Offset position,
    double radius,
    Color color, {
    double strength = 1,
  }) {
    final paint = Paint()..blendMode = BlendMode.plus;
    paint.shader = ui.Gradient.radial(position, radius, [
      color.withValues(alpha: .36 * strength),
      color.withValues(alpha: 0),
    ]);
    canvas.drawCircle(position, radius, paint);
    paint
      ..shader = null
      ..color = color.withValues(alpha: .95 * strength);
    canvas.drawCircle(position, math.max(.7, radius * .10), paint);
  }

  void _carLights(
    Canvas canvas,
    _Object object,
    double x,
    double y,
    double width,
    double clip,
  ) {
    if (nightStrength < .05 || y - width * .30 >= clip) return;
    _batch.flush(canvas);
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(
        -200,
        -200,
        _w + 400,
        math.max(0, math.min(_h + 200, clip) + 200),
      ),
    );
    final braking = object.kind == _Kind.player
        ? controller.braking
        : object.braking;
    final radius = (width * (braking ? .16 : .105)).clamp(2.0, 32.0);
    for (var side = 0; side < 2; side++) {
      final position = Offset(
        x + (side == 0 ? -1 : 1) * width * .29,
        y - width * .34,
      );
      final id = object.lightId * 2 + side;
      final history = lightHistory.record(
        id,
        controller.elapsed,
        position,
        quiet: controller.comfortMode || controller.paused,
      );
      for (final sample in history) {
        final age = controller.elapsed - sample.time;
        if (age <= .002) continue;
        final fade = math.pow(1 - age / LightHistory.lifetime, 2).toDouble();
        final paint = Paint()
          ..blendMode = BlendMode.plus
          ..strokeCap = StrokeCap.round
          ..strokeWidth = math.max(1, width * .022)
          ..color = Color.fromRGBO(255, 34, 12, fade * .32);
        canvas.drawLine(sample.position, position, paint);
      }
      _glow(
        canvas,
        position,
        radius,
        braking ? const Color(0xffff431e) : const Color(0xffff2812),
      );
      if (level.wet > 0) {
        if (width > 30) {
          final reflection = Paint()..strokeWidth = math.max(.6, width * .008);
          for (var ripple = 0; ripple < 8; ripple++) {
            final t = ripple / 8;
            final shimmer = math.sin(_world / 200 + ripple * 2.4);
            final rx = position.dx + shimmer * width * .012;
            final ry = y + width * (.015 + t * .32);
            reflection.color = Color.fromRGBO(
              255,
              76,
              30,
              (1 - t) * .22 * level.wet,
            );
            canvas.drawLine(
              Offset(rx - width * .055 * (1 - t), ry),
              Offset(rx + width * .055 * (1 - t), ry),
              reflection,
            );
          }
        }
      }
    }
    canvas.restore();
  }

  void _lampLight(
    Canvas canvas,
    _Object object,
    _RoadPoint p,
    double x,
    double width,
    double clip,
  ) {
    if (nightStrength < .05 || object.kind != _Kind.lamp) return;
    final y = p.y - width * 1.57;
    if (y >= clip) return;
    _batch.flush(canvas);
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(
        -200,
        -200,
        _w + 400,
        math.max(0, math.min(_h + 200, clip) + 200),
      ),
    );
    final position = Offset(x - width * .1, y);
    for (final sample in lightHistory.record(
      object.lightId * 2,
      controller.elapsed,
      position,
      quiet: controller.comfortMode || controller.paused,
    )) {
      final age = controller.elapsed - sample.time;
      if (age <= .002) continue;
      final fade = math.pow(1 - age / LightHistory.lifetime, 2).toDouble();
      canvas.drawLine(
        sample.position,
        position,
        Paint()
          ..blendMode = BlendMode.plus
          ..strokeCap = StrokeCap.round
          ..strokeWidth = math.max(1, width * .035)
          ..color = Color.fromRGBO(255, 211, 139, fade * .25),
      );
    }
    _glow(
      canvas,
      position,
      (width * .26).clamp(2.0, 75.0),
      const Color(0xffffd38b),
    );
    if (level.wet > 0) {
      final paint = Paint()
        ..shader = ui.Gradient.radial(Offset(x, p.y), math.max(2, width * .8), [
          const Color(0x55ffcd75),
          const Color(0x00ffcd75),
        ]);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, p.y),
          width: width * .3,
          height: width * 1.2,
        ),
        paint,
      );
    }
    // Scenic signal sample, outside the travel lane; no stop-rule gameplay.
    if (level.urban && object.lightId.isEven) {
      final signal = Offset(x + width * .28, y + width * .4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: signal,
            width: width * .18,
            height: width * .46,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xff152326),
      );
      _glow(
        canvas,
        signal + Offset(0, -width * .12),
        (width * .11).clamp(1.0, 20.0),
        const Color(0xffff3b18),
      );
    }
    canvas.restore();
  }

  void _sky(Canvas canvas) {
    _paint
      ..color = const Color(0xffffffff)
      ..colorFilter = null
      ..maskFilter = null
      ..blendMode = BlendMode.srcOver;
    final sky = Rect.fromLTWH(0, 0, _w, _h);
    _paint.shader = ui.Gradient.linear(
      Offset.zero,
      Offset(0, _h * (horizonFraction + .18)),
      [
        _course
            ? Color.lerp(
                Color.lerp(
                  const Color(0xff80bbd5),
                  const Color(0xff705d86),
                  level.sunset,
                )!,
                const Color(0xff080f24),
                nightStrength,
              )!
            : const Color(0xff80bbd5),
        _course
            ? Color.lerp(
                Color.lerp(
                  const Color(0xffd8e6d4),
                  const Color(0xffe0a66f),
                  level.sunset,
                )!,
                const Color(0xff25354b),
                nightStrength,
              )!
            : const Color(0xffd8e6d4),
        _course
            ? Color.lerp(
                const Color(0xffffc178),
                const Color(0xff35424b),
                nightStrength,
              )!
            : const Color(0xffffe6ba),
      ],
      [0, .72, 1],
    );
    canvas.drawRect(sky, _paint);
    _paint.shader = null;
    final sun = Offset(800, _h * (horizonFraction - .13 + _viewPitch));
    _paint.color = nightStrength > .7
        ? const Color(0xffd6e3ed)
        : const Color(0xffffd49b);
    canvas.drawCircle(sun, nightStrength > .7 ? 15 : 27, _paint);
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
      final y = _h * (horizonFraction - .255 + (i % 3) * .065 + _viewPitch);
      _paint.color = Color.fromRGBO(
        255,
        255,
        255,
        (i.isEven ? .88 : .50) * (1 - nightStrength * .8),
      );
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
    final height =
        _h *
        (_course && level.id == 'iowa'
            ? .16
            : _course && level.id == 'chicago'
            ? .28
            : .54);
    final y = _h * (horizonFraction + .09 + _viewPitch) - height;
    _paint.color = const Color(0xffffffff);
    if (_course) {
      final n = nightStrength;
      _paint.colorFilter = ColorFilter.matrix([
        1 - .82 * n,
        0,
        0,
        0,
        level.sunset * 12,
        0,
        1 - .75 * n,
        0,
        0,
        0,
        0,
        0,
        1 - .55 * n,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ]);
    }
    for (var i = -2; i < 2; i++) {
      canvas.drawImageRect(
        backdrop,
        source,
        Rect.fromLTWH(offset + i * 1200, y, 1202, height),
        _paint,
      );
    }
    _paint.colorFilter = null;
    // A thin haze unifies the painted distance with the live projected terrain.
    _paint.shader = ui.Gradient.linear(
      Offset(0, _h * (horizonFraction + .02 + _viewPitch)),
      Offset(0, _h * (horizonFraction + .16 + _viewPitch)),
      [
        const Color(0x00d6dfbe),
        Color(_course ? _material(0xffb5c49a, _world + 25000, 0) : 0xffb5c49a),
      ],
    );
    canvas.drawRect(
      Rect.fromLTWH(0, _h * (horizonFraction + .02 + _viewPitch), _w, _h * .19),
      _paint,
    );
    _paint.shader = null;
  }

  void _road(Canvas canvas) {
    _ground.clear();
    _shoulder.clear();
    _asphalt.clear();
    _leaves.clear();
    _joiningLane.clear();
    _joiningMarkings.clear();
    _markings.clear();
    final base = (_cameraZ / _segmentLength).floor() * _segmentLength;
    var crestClip = _h + 200;
    for (var i = 0; i <= _segmentCount; i++) {
      _project(base + _depthAt(i + 1), _points[i]);
      _points[i].clip = crestClip;
      if (_points[i].y < crestClip) crestClip = _points[i].y;
    }
    final biome = _biome;
    final green = _course
        ? Color(level.ground)
        : biome == Biome.city
        ? const Color(0xff9cb77c)
        : biome == Biome.mountain
        ? const Color(0xff8da982)
        : const Color(0xff94b66d);
    for (var i = _segmentCount - 1; i >= 0; i--) {
      final a = _points[i], b = _points[i + 1];
      a.visible = a.y > b.y && b.y < a.clip && b.y < _h + 60 && a.z > 20;
      if (!a.visible) continue;
      final worldZ = base + _depthAt(i + 1);
      final nextWorldZ = base + _depthAt(i + 2);
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
        nextWorldZ / 900 * 256,
        _material(color, worldZ, 2),
        _material(color, nextWorldZ, 2),
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
        nextWorldZ / 480 * 512,
        _material(shoulderColor, worldZ, 1.15),
        _material(shoulderColor, nextWorldZ, 1.15),
      );
      final weatherTint = controller.weather == RaceWeather.rain
          ? const Color(0xffb4c6d0)
          : controller.weather == RaceWeather.snow
          ? const Color(0xffd5dfe0)
          : const Color(0xffffffff);
      var tint = Color.lerp(
        weatherTint,
        const Color(0xffd5dfdf),
        fade * .5,
      )!.toARGB32();
      if (_nextProof &&
          ProofJoiningLane.visible(worldZ) &&
          ProofJoiningLane.visible(nextWorldZ)) {
        final ac = ProofJoiningLane.center(worldZ);
        final bc = ProofJoiningLane.center(nextWorldZ);
        final aw = ProofJoiningLane.halfWidth(worldZ);
        final bw = ProofJoiningLane.halfWidth(nextWorldZ);
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
          nextWorldZ / 480 * 512,
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
      if (_course) {
        final cover = level.canopyAt(_courseAt(worldZ));
        final shade =
            level.wet * .15 +
            cover * (.05 + .09 * (1 + math.sin(worldZ / 380)));
        tint = Color.lerp(
          Color(tint),
          const Color(0xff493f37),
          shade,
        )!.toARGB32();
      }
      for (var lane = 0; lane < 3; lane++) {
        final left = -1 + lane * 2 / 3, right = left + 2 / 3;
        _asphalt.quad(
          a.x + a.halfWidth * left,
          a.x + a.halfWidth * right,
          yNear,
          b.x + b.halfWidth * left,
          b.x + b.halfWidth * right,
          yFar,
          (left + 1) * 256,
          (right + 1) * 256,
          worldZ / 480 * 512,
          nextWorldZ / 480 * 512,
          _material(tint, worldZ, left),
          _material(tint, nextWorldZ, left),
          nearRightColor: _material(tint, worldZ, right),
          farRightColor: _material(tint, nextWorldZ, right),
        );
      }
      if (_course && level.autumn) {
        for (final side in [-1.0, 1.0]) {
          final edge = side * .94;
          _leaves.quad(
            a.x + a.halfWidth * (edge - .11),
            a.x + a.halfWidth * (edge + .11),
            yNear,
            b.x + b.halfWidth * (edge - .11),
            b.x + b.halfWidth * (edge + .11),
            yFar,
            0,
            256,
            worldZ / 600 * 128,
            nextWorldZ / 600 * 128,
            _material(0xffc2a17b, worldZ, edge),
            _material(0xffc2a17b, nextWorldZ, edge),
          );
        }
      }
    }
    // Markings are projected geometry rather than affine tile samples: long
    // straight lane lines must not bend across a textured triangle diagonal.
    for (var i = _segmentCount - 1; i >= 0; i--) {
      final a = _points[i], b = _points[i + 1];
      if (!a.visible) continue;
      final worldZ = base + _depthAt(i + 1);
      void line(
        double left,
        double right,
        int color, [
        _RoadPoint? near,
        _RoadPoint? far,
      ]) {
        final n = near ?? a, f = far ?? b;
        _markings.quad(
          n.x + n.halfWidth * left,
          n.x + n.halfWidth * right,
          n.y,
          f.x + f.halfWidth * left,
          f.x + f.halfWidth * right,
          f.y,
          0,
          1,
          0,
          1,
          _material(color, worldZ, (left + right) * .5),
          _material(color, base + _depthAt(i + 2), (left + right) * .5),
        );
      }

      line(-.974, -.968, 0xffead394);
      line(-.956, -.950, 0xffead394);
      line(.960, .970, 0xfff5f1d9);
      for (final (start, end) in ProofDepth.dashes(
        worldZ,
        base + _depthAt(i + 2),
      )) {
        _project(start, _dashNear);
        _project(end, _dashFar);
        if (_dashNear.y <= _dashFar.y) continue;
        line(-.338, -.328, 0xfff4f2e4, _dashNear, _dashFar);
        line(.328, .338, 0xfff4f2e4, _dashNear, _dashFar);
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
    if (_course && level.autumn) {
      _leaves.draw(canvas, _leafPaint);
    }
    _markings.draw(
      canvas,
      Paint()
        ..color = const Color(0xffffffff)
        ..isAntiAlias = false,
    );
    lastRoadQuads = _asphalt.count;
    if (_course) {
      // The finite ribbon ends inside this narrow horizon-colored veil. World
      // objects independently fade over the last24% of their visible depth.
      final y = _h * (horizonFraction + _viewPitch);
      canvas.drawRect(
        Rect.fromLTWH(0, y - _h * .025, _w, _h * .075),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, y - _h * .025),
            Offset(0, y + _h * .05),
            [
              const Color(0x00b5c49a),
              Color(
                _course
                    ? _material(0xffb5c49a, _world + _farDepth, 0)
                    : 0xffb5c49a,
              ),
              const Color(0x00b5c49a),
            ],
            [0, .33, 1],
          ),
      );
    }
  }

  void _composeObjects() {
    _objects.clear();
    final near = _cameraZ + 450, far = _cameraZ + _farDepth;
    final first = (near / 330).floor();
    for (var i = first; i * 330 < far; i++) {
      final z = i * 330.0;
      if (_course && !ProofCourse.vegetationAllowedAt(_courseAt(z))) continue;
      if (_course && i % level.sceneryStride != 0) continue;
      final sampleOrdinal = _course ? i ~/ level.sceneryStride : i;
      final side = sampleOrdinal.isEven ? -1.0 : 1.0;
      final hash = ((i * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff;
      // Samples are selected spatially, so no popping when a UI stage changes.
      final cityEnd =
          controller.graph.edges.first.length * _flowScale + _worldOffset;
      final biome = _course
          ? (level.urban ? Biome.city : Biome.forest)
          : _nextProof
          ? (z < cityEnd ? Biome.city : Biome.forest)
          : proofMode
          ? (z < 14500
                ? Biome.city
                : z < 36500
                ? Biome.forest
                : Biome.mountain)
          : _biome;
      final tree = _course
          ? level.treeFrame
          : biome == Biome.mountain
          ? 1
          : biome == Biome.coast
          ? 2
          : 0;
      // At the extended far range, alternate vegetation samples provide the
      // same silhouette density at tiny pixel sizes with bounded atlas work.
      final farLod = z - _cameraZ > 15000 && i.isOdd;
      if (farLod) continue;
      final firstObject = _objects.length;
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
        if (sampleOrdinal % 3 == 0) {
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
      if (_nextProof) {
        // Small near-road references carry fast peripheral flow without hiding
        // upcoming traffic behind a wall of large trees.
        _objects.add(_Object(_Kind.marker, z + 140, side * 1.15, 44));
      }
      if (!_course && biome == Biome.city && i % 3 == 0) {
        _objects.add(_Object(_Kind.lamp, z - 80, side * 1.20, 550));
      }
      if (_course && i.isOdd) {
        for (var j = firstObject; j < _objects.length; j++) {
          _objects[j].fadeFar = 15000;
        }
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
          )..lightId = car.id,
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
    if (_course) {
      for (final cone in controller.proofCones) {
        if (controller.isConeHit(cone.id)) continue;
        final z = _courseZ(cone.courseDistance);
        if (z > near && z < far) {
          _objects.add(_Object(_Kind.cone, z, cone.lateral, cone.width));
        }
      }
      for (final flight in controller.coneFlights) {
        final z = _courseZ(
          flight.cone.courseDistance + flight.forwardVelocity * flight.age,
        );
        if (z > _cameraZ + 100 && z < far) {
          _objects.add(
            _Object(
              _Kind.flyingCone,
              z,
              flight.cone.lateral + flight.lateralVelocity * flight.age,
              flight.cone.width,
              flightAge: flight.age,
            ),
          );
        }
      }
      // Sparse, authored one-offs break the repeating scenery rhythm. Their
      // ground positions are stable through optical-flow preset changes.
      if (_art.environmentFrames.length >= 10) {
        const stops = [480.0, 1760.0, 3980.0, 4860.0, 5820.0, 7060.0];
        for (var i = 0; i < stops.length; i++) {
          final z = _courseZ(stops[i]);
          if (z > near && z < far) {
            _objects.add(
              _Object(
                _Kind.scenery,
                z,
                i.isEven ? -2.65 : 2.65,
                1450,
                frame: 6 + i % 4,
              ),
            );
          }
        }
      }
    } else if (controller.closedLane != null) {
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
      for (final courseZ in ProofCourse.fixedPositions(
        origin: 0,
        spacing: 42,
        near: _courseAt(near),
        far: _courseAt(far),
      )) {
        final cover = level.canopyAt(courseZ);
        if (cover <= .1) continue;
        final z = _courseZ(courseZ);
        // Roots stay outside pavement; wide crowns share the actual tree art.
        _objects.add(_Object(_Kind.scenery, z, -2.1, 2450 * cover, frame: 0));
        _objects.add(
          _Object(_Kind.scenery, z + 950, 2.15, 2250 * cover, frame: 0),
        );
      }
      if (level.lampSpacing > 0) {
        for (final courseZ in ProofCourse.fixedPositions(
          origin: 25,
          spacing: level.lampSpacing,
          near: _courseAt(near),
          far: _courseAt(far),
        )) {
          if (ProofCourse.tunnelAt(courseZ) > .1) continue;
          final ordinal = (courseZ / level.lampSpacing).floor();
          _objects.add(
            _Object(
              _Kind.lamp,
              _courseZ(courseZ),
              ordinal.isEven ? -1.24 : 1.24,
              550,
            )..lightId = 10000 + ordinal,
          );
        }
      }
      for (final s in [6080.0, 6230.0, 6380.0, 6530.0, 6680.0, 6770.0]) {
        final z = _courseZ(s);
        if (z > near && z < far) {
          _objects.add(_Object(_Kind.portal, z, 0, 6400));
        }
      }
    }
    _objects.add(
      _Object(_Kind.player, _world, _playerX, _course ? 285 : 300)
        ..lightId = -2,
    );
    if (_nextProof) {
      _objects.removeWhere(
        (object) =>
            (object.kind == _Kind.scenery ||
                object.kind == _Kind.lamp ||
                object.kind == _Kind.marker) &&
            ProofJoiningLane.overlapsScenery(
              object.z,
              object.lateral,
              object.width / _roadHalfWidth * .6 + .15,
            ),
      );
    }
    _objects.sort((a, b) => b.z.compareTo(a.z));
    lastSpriteCount = _objects.length;
  }

  final _RoadPoint _objectPoint = _RoadPoint();
  double _clipAt(double z) {
    final depth = z - _cameraZ;
    var low = 0, high = _segmentCount;
    while (low < high) {
      final middle = (low + high + 1) ~/ 2;
      if (_points[middle].z <= depth) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }
    return _points[low.clamp(0, _segmentCount - 1)].clip;
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
      _objectOpacity = object.kind == _Kind.player || !_course
          ? 1
          : ProofCamera.opacityByte(p.z, math.min(object.fadeFar, _farDepth)) /
                255;
      if (_objectOpacity <= 0) continue;
      switch (object.kind) {
        case _Kind.scenery:
          final atlas = _environment;
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
            fog: null,
            tint: _course
                ? _material(0xffffffff, object.z, object.lateral)
                : 0xffffffff,
            rotationGround: ProofArt.sceneryGround[object.frame],
            rotation: _course && object.frame < 3
                ? ProofFoliage.angle(
                    time: _presentationTime,
                    position: object.z,
                    depth: p.z,
                    quiet: controller.comfortMode || !animatedFoliage,
                  )
                : 0,
          );
        case _Kind.traffic:
          _vehicle(canvas, object, x, p.y, width, clip, false);
          if (_course) _carLights(canvas, object, x, p.y, width, clip);
        case _Kind.player:
          _vehicle(canvas, object, x, p.y, width, clip, true);
          if (_course) _carLights(canvas, object, x, p.y, width, clip);
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
            tint: _material(0xffffffff, object.z, object.lateral),
          );
        case _Kind.flyingCone:
          if (!_art.coursePropsReady) continue;
          _batch.flush(canvas);
          final source = _art.coursePropFrames[0];
          final scale = width / source.width;
          final t = object.flightAge;
          final lift = math.max(0.0, 1800 * t - 1500 * t * t);
          final screenLift = _projection / p.z * lift * _h * .70;
          canvas.save();
          canvas.translate(x, p.y - source.height * scale * .5 - screenLift);
          canvas.rotate(t * 10 * object.lateral.sign);
          _paint.color = Color.fromRGBO(255, 255, 255, _objectOpacity);
          canvas.drawImageRect(
            _environment!,
            source,
            Rect.fromLTWH(
              -width * .5,
              -source.height * scale * .5,
              width,
              source.height * scale,
            ),
            _paint,
          );
          canvas.restore();
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
              _environment!,
              source,
              x - width * .5,
              p.y - source.height * scale - overhead,
              scale,
              clip: clip,
              fog: null,
              tint: _course
                  ? _material(0xffffffff, object.z, object.lateral)
                  : 0xffffffff,
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
              _environment!,
              source,
              x - source.width * scale * .5,
              p.y - source.height * scale,
              scale,
              clip: clip,
            );
          }
          if (_course) _lampLight(canvas, object, p, x, width, clip);
        case _Kind.sign:
          break;
      }
    }
    _batch.flush(canvas);
    _objectOpacity = 1;
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
    double rotation = 0,
    double? rotationGround,
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
      opacity: (_objectOpacity * 255).round(),
      rotation: visibleHeight < source.height ? 0 : rotation,
      pivotX: source.width * scale * .5,
      pivotY: (rotationGround ?? source.height) * scale,
    );
  }

  VehiclePose _pose(bool player) {
    if (!player) return const VehiclePose(0);
    if (_course) {
      return _steeringArt.pose(
        speed: controller.speed,
        grade: (_elevation(_world + 160) - _elevation(_world - 160)) / 320,
        recovering: controller.recovering,
        grounded: !legacySlopePoses,
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
    final bounce = player && _course
        ? (controller.comfortMode || !suspensionEnabled
              ? 0.0
              : suspension.heave +
                    math.sin(_presentationTime * 32) * .28 * speed)
        : player
        ? math.sin(_world * .021) * speed
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
      _paint.color = Color(_material(0xffffffff, object.z, object.lateral));
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
        if (player && _course) {
          _batch.flush(canvas);
          canvas.save();
          canvas.translate(x, bodyY);
          canvas.rotate(suspension.roll);
          final bodyScale =
              1 -
              suspension.pitch -
              (legacySlopePoses ? 0 : groundedSlope.visualPitch);
          canvas.scale(1, bodyScale);
          _sprite(
            canvas,
            atlas,
            src,
            -centerAnchor * scale,
            -groundAnchor * scale,
            scale,
            clip: (clip - bodyY) / bodyScale,
            tint: _course
                ? _material(0xffffffff, object.z, object.lateral)
                : 0xffffffff,
            mirrored: pose.mirrored,
          );
          _batch.flush(canvas);
          canvas.restore();
        } else {
          _sprite(
            canvas,
            atlas,
            src,
            x - centerAnchor * scale,
            bodyY - groundAnchor * scale,
            scale,
            clip: clip,
            tint: _course
                ? _material(0xffffffff, object.z, object.lateral)
                : 0xffffffff,
            mirrored: pose.mirrored,
          );
        }
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
