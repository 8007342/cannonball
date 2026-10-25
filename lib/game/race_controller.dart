import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'proof_course.dart';
import 'proof_contacts.dart';
import 'proof_dynamics.dart';
import 'route.dart';
import 'traffic.dart';

export 'traffic.dart' show TrafficCar, TrafficProfile;
export 'proof_contacts.dart' show ProofCone, ConeFlight;

/// Integer arithmetic stays below 2^53 on the web as well as Dart VM.
class _RandomStream {
  _RandomStream(int seed) : state = seed.abs() % 2147483646 + 1;
  int state;
  double next() {
    state = state * 48271 % 2147483647;
    return state / 2147483647;
  }

  int index(int length) => (next() * length).floor();
}

enum CrashPose { driving, spin, flip }

/// The simulation never reads canvas dimensions, browser APIs, network or audio.
/// A fixed 60 Hz step controls clocks, traffic, branches, and collisions.
class RaceController extends ChangeNotifier {
  static const fixedStep = 1 / 60;
  static const gateSpacingMiles = 155.0;
  static const gateBonusSeconds = 45.0;
  final RouteGraph graph = routeGraph;
  CarSpec _car = cars.first;
  CarSpec get car => _car;
  Set<String> unlockedCarIds = {'wagon'};
  Set<String> get earnedUnlockIds => Set.unmodifiable(_earnedUnlockIds);
  final Set<String> _earnedUnlockIds = {};
  final List<RouteVisit> _completedVisits = [];
  final List<String> _gates = [];
  final List<TrafficCar> traffic = [];
  final List<ProofCone> _proofCones = [];
  final List<ConeFlight> _coneFlights = [];
  final Set<int> _hitCones = {};
  final ProofCollisionGate _proofContacts = ProofCollisionGate();
  List<ProofCone> get proofCones => List.unmodifiable(_proofCones);
  List<ConeFlight> get coneFlights => List.unmodifiable(_coneFlights);
  bool isConeHit(int id) => _hitCones.contains(id);
  int get coneHitCount => _hitCones.length;

  /// Set by the proof renderer, so contact depth tracks sprite projection.
  double proofPresentationScale = 84;
  double _stepPlayerStart = 0, _stepPlayerXStart = 0;
  bool reactiveTrafficEnabled = false;
  ReactiveTraffic _reactiveTraffic = ReactiveTraffic();
  double _lastTrafficPlayerX = 0;
  int get trafficReactionCount => _reactiveTraffic.reactions;
  int get trafficIncidentCount => _reactiveTraffic.incidents;
  final Map<String, String> _closedBranches = {};
  late _RandomStream _trafficRandom;
  late _RandomStream _conditionRandom;
  RouteEdge _edge = routeGraph.edges.first;
  RouteEdge get currentEdge => _edge;
  RaceWeather weather = RaceWeather.clear;
  Biome? previousBiome;
  double regionBlend = 1;
  double steering = 0;
  bool braking = false, paused = false, motionControl = false;
  bool comfortMode = false;
  bool testCourseEnabled = false;
  bool denseProofTraffic = false;
  double proofTrafficPreview = 230;
  double courseStartDistance = 0;
  double get courseDistance => _worldDistance + courseStartDistance;
  double _effectiveSteering = 0;
  double get effectiveSteering =>
      testCourseEnabled ? _effectiveSteering : steering;
  bool get steadyHorizon => comfortMode;
  set steadyHorizon(bool value) => comfortMode = value;
  bool _started = false, _finished = false, _completed = false;
  bool get started => _started;
  bool get finished => _finished;
  bool get completed => _completed;
  int _seed = 0, _stepCount = 0, _trafficId = 0, _crashes = 0;
  int get seed => _seed;
  int get crashes => _crashes;
  double _accumulator = 0, _notifyAccumulator = 0;
  double _remaining = 90, _speed = 0, _worldDistance = 0;
  double _edgeDistance = 0, _completedMiles = 0;
  double _nextSpawn = 3, _radioUntil = 0, _lastCrashAt = -100;
  double _recovery = 0, _recoveryDuration = 0, protection = 0;
  double playerX = 0, cameraLean = 0;
  int _radioPriority = 0;
  String _radio = 'The country is waiting. Take your keys.';
  bool _forkAnnounced = false, _closureAnnounced = false;
  bool _timeWarning = false;
  int? _closedLane;
  CrashPose crashPose = CrashPose.driving;
  RunReceipt? _receipt;
  RunReceipt? get receipt => _receipt;
  double get elapsed => _stepCount * fixedStep;
  double get remaining => _remaining;
  double get speed => _speed;
  double get worldDistance => _worldDistance;
  double get edgeDistance => _edgeDistance;
  double get edgeFraction => (_edgeDistance / _edge.length).clamp(0, 1);
  double get distanceMiles =>
      _completedMiles + _edgeDistance / RouteGraph.unitsPerMile;
  double get estimatedTotalMiles =>
      _completedMiles + _edge.miles + graph.remainingMiles(_edge.to);
  double get progress =>
      completed ? 1 : (distanceMiles / estimatedTotalMiles).clamp(0, 1);
  String get stageName => graph.node(_edge.to).name;
  String get radio => _radio;
  bool get recovering => _recovery > 0;
  double get recoveryProgress =>
      _recoveryDuration == 0 ? 0 : 1 - _recovery / _recoveryDuration;
  double get nextGateMiles =>
      gateSpacingMiles * (_gates.length + 1) - distanceMiles;
  int get gatesPassed => _gates.length;
  List<String> get visitedEdges =>
      routeProgress.map((e) => e.edgeId).toList(growable: false);
  List<RouteVisit> get routeProgress => List.unmodifiable([
    ..._completedVisits,
    if (!_completed) RouteVisit(_edge.id, edgeFraction),
  ]);
  List<RouteEdge> get nextChoices => graph.outgoing(_edge.to);
  String? get closedBranchId => _closedBranches[_edge.to];
  Map<String, String> get closedBranches => Map.unmodifiable(_closedBranches);
  bool get approachingFork =>
      nextChoices.length > 1 && _edge.length - _edgeDistance < 1000;
  double get distanceToFork => _edge.length - _edgeDistance;
  int? get closedLane => _closedLane;
  double get closureStart => testCourseEnabled
      ? 4300 - courseStartDistance - (_worldDistance - _edgeDistance)
      : _edge.length * .48;
  double get closureEnd => testCourseEnabled
      ? 4920 - courseStartDistance - (_worldDistance - _edgeDistance)
      : _edge.length * .59;
  bool get inLaneClosure =>
      _closedLane != null &&
      _edgeDistance > closureStart &&
      _edgeDistance < closureEnd;
  String get directorPhase {
    if (elapsed - _lastCrashAt < 13 || remaining < 15) return 'recovery';
    final beat = elapsed % 72;
    return beat < 24
        ? 'build'
        : beat < 43
        ? 'peak'
        : 'relax';
  }

  void start(
    CarSpec car, {
    int? seed,
    bool reactiveTraffic = false,
    double launchSpeed = 0,
    bool testCourse = false,
    bool denseTraffic = false,
    double courseStartDistance = 0,
  }) {
    testCourseEnabled = testCourse;
    denseProofTraffic = testCourse && denseTraffic;
    this.courseStartDistance = testCourse && courseStartDistance.isFinite
        ? courseStartDistance.clamp(0, ProofCourse.length)
        : 0;
    _effectiveSteering = 0;
    reactiveTrafficEnabled = reactiveTraffic;
    _reactiveTraffic = ReactiveTraffic();
    _lastTrafficPlayerX = 0;
    _car = car;
    _seed = seed ?? DateTime.now().microsecondsSinceEpoch % 1000000000;
    _trafficRandom = _RandomStream(_seed ^ 0x63d2);
    _conditionRandom = _RandomStream(_seed ^ 0x48a1);
    _closedBranches.clear();
    for (final node in graph.nodes) {
      final options = graph.outgoing(node.id);
      if (options.length > 1 && _conditionRandom.next() < .24) {
        _closedBranches[node.id] =
            options[_conditionRandom.index(options.length)].id;
      }
    }
    _stepCount = 0;
    _remaining = testCourseEnabled ? 300 : 90;
    _speed = launchSpeed.isFinite ? launchSpeed.clamp(0, car.topSpeed) : 0;
    _worldDistance = 0;
    _edgeDistance = 0;
    _completedMiles = 0;
    _accumulator = 0;
    _notifyAccumulator = 0;
    _nextSpawn = 5;
    _trafficId = 0;
    _crashes = 0;
    _lastCrashAt = -100;
    _recovery = 0;
    _recoveryDuration = 0;
    protection = 0;
    playerX = 0;
    cameraLean = 0;
    steering = 0;
    braking = false;
    paused = false;
    _started = true;
    _finished = false;
    _completed = false;
    _receipt = null;
    _earnedUnlockIds.clear();
    _completedVisits.clear();
    _gates.clear();
    traffic.clear();
    _proofCones.clear();
    _coneFlights.clear();
    _hitCones.clear();
    _proofContacts.clear();
    _radioPriority = 0;
    _radioUntil = 0;
    _timeWarning = false;
    crashPose = CrashPose.driving;
    _edge = graph.edges.first;
    previousBiome = null;
    _enterEdge();
    if (testCourseEnabled) {
      for (var id = 0; 4120 + id * 9 < 4920; id++) {
        final distance = 4120 + id * 9.0;
        final taper = ((distance - 4120) / 180).clamp(0.0, 1.0);
        _proofCones.add(
          ProofCone(
            id: id,
            courseDistance: distance,
            lateral: (_closedLane ?? 1) * (1 - .56 * taper),
          ),
        );
      }
    }
    if (testCourseEnabled && reactiveTrafficEnabled) {
      _nextSpawn = .8;
      for (var i = 0; i < (denseProofTraffic ? 10 : 4); i++) {
        _spawnTraffic(
          proofOffset: denseProofTraffic ? 55 + i * 36.0 : 95 + i * 85.0,
        );
      }
      // A slower lead vehicle stays in view while the player builds speed.
      traffic.first.cruiseSpeed = 55;
      traffic.first.currentSpeed = 55;
    }
    _say('Red Ball Garage. Westbound. Next stop: the Pacific.', 3, 8);
    notifyListeners();
  }

  void tick(double dt) {
    if (!_started || _finished || paused || !dt.isFinite || dt <= 0) return;
    // A lost/background frame must not teleport the car into hazards.
    _accumulator += dt.clamp(0, .25);
    while (_accumulator + 1e-10 >= fixedStep && !_finished) {
      _accumulator -= fixedStep;
      _step();
    }
    _notifyAccumulator += dt.clamp(0, .25);
    if (_notifyAccumulator >= .05 || _finished) {
      _notifyAccumulator %= .05;
      notifyListeners();
    }
  }

  double curveAt(double position) {
    if (testCourseEnabled) {
      return ProofCourse.steeringLoadAt(position + courseStartDistance);
    }
    final phase = _seed % 251 / 40;
    final strength = _edge.biome == Biome.mountain ? 1.0 : .62;
    return (math.sin(position / 1700 + phase) * .36 +
            math.sin(position / 4100) * .17) *
        strength;
  }

  double centerAt(double position) {
    final phase = _seed % 251 / 40;
    final strength = _edge.biome == Biome.mountain ? 1.0 : .62;
    return (1000 * math.sin(position / 1700 + phase) +
            1800 * math.sin(position / 4100)) *
        strength;
  }

  double elevationAt(double position) {
    final amplitude = switch (_edge.biome) {
      Biome.mountain => 450.0,
      Biome.canyon => 270.0,
      Biome.forest => 150.0,
      _ => 65.0,
    };
    return math.sin(position / 2200) * amplitude +
        math.sin(position / 900) * amplitude * .14;
  }

  void _step() {
    _stepPlayerStart = _worldDistance;
    _stepPlayerXStart = playerX;
    for (final flight in _coneFlights) {
      flight.age += fixedStep;
    }
    _coneFlights.removeWhere((flight) => flight.age >= ConeFlight.lifetime);
    _stepCount++;
    _remaining -= fixedStep;
    regionBlend = math.min(1, regionBlend + fixedStep / 4);
    protection = math.max(0, protection - fixedStep);
    final ratio = _speed / _car.topSpeed;
    final targetSteering = steering.isFinite ? steering.clamp(-1.0, 1.0) : 0.0;
    // ~0.2 s to full input is a playtest hypothesis, not a sourced optimum.
    // Release is quicker and reversals pass through neutral without a queue.
    final previousSteering = _effectiveSteering;
    final rate = targetSteering == 0 ? 10.0 : 5.5;
    _effectiveSteering += (targetSteering - _effectiveSteering).clamp(
      -rate * fixedStep,
      rate * fixedStep,
    );
    final safeSteering = testCourseEnabled
        ? _effectiveSteering
        : targetSteering;
    final leanTarget = comfortMode
        ? 0.0
        : -safeSteering * (motionControl ? .026 : .014) * ratio;
    cameraLean += (leanTarget - cameraLean) * fixedStep * 5;
    if (recovering) {
      _recovery -= fixedStep;
      _speed = math.max(18, _speed - 40 * fixedStep);
      if (_recovery <= 0) _resetSafely();
    } else {
      final grip = weather == RaceWeather.snow
          ? .82
          : weather == RaceWeather.rain
          ? .91
          : 1.0;
      final acceleration = testCourseEnabled
          ? ProofDynamics.acceleration(
              speed: _speed,
              topSpeed: _car.topSpeed,
              engineAcceleration: _car.acceleration,
              steering: safeSteering,
              steeringRate: (_effectiveSteering - previousSteering) / fixedStep,
              grade:
                  (ProofCourse.elevationAt(courseDistance + 5) -
                      ProofCourse.elevationAt(courseDistance - 5)) /
                  840,
            )
          : _car.acceleration;
      _speed = (_speed + (braking ? -82 : acceleration) * fixedStep).clamp(
        0,
        _car.topSpeed,
      );
      playerX +=
          (safeSteering * _car.handling * grip * (0.2 + ratio * 1.15) -
              curveAt(_worldDistance) * ratio * ratio * .23) *
          fixedStep;
      playerX = playerX.clamp(-1.65, 1.65);
      if (playerX.abs() > 1.02) {
        _speed = math.max(24, _speed - 52 * fixedStep);
        if (playerX.abs() > 1.52 && protection <= 0) _crash(flip: ratio > .72);
      }
      if (!testCourseEnabled &&
          inLaneClosure &&
          (playerX - _closedLane! * .65).abs() < .22 &&
          protection <= 0) {
        _crash(flip: ratio > .88);
      }
    }
    final distance = _speed * RouteGraph.speedScale * fixedStep;
    _worldDistance += distance;
    _edgeDistance += distance;
    _advanceTraffic();
    if (testCourseEnabled && !recovering) _advanceProofCones();
    while (distanceMiles >= (_gates.length + 1) * gateSpacingMiles) {
      final mile = ((_gates.length + 1) * gateSpacingMiles).round();
      _gates.add('mile-$mile');
      _remaining += gateBonusSeconds;
      _timeWarning = false;
      _say('TIME EXTENDED +45 · Keep it rolling.', 4, 4);
    }
    _advanceRoute();
    if (_finished) return;
    _advisories();
    if (_remaining <= 0) {
      _remaining = 0;
      _finish(false);
    }
  }

  void _enterEdge() {
    _forkAnnounced = false;
    _closureAnnounced = false;
    _closedLane = _edge.length > 2500 && _conditionRandom.next() < .58
        ? (_conditionRandom.next() < .5 ? -1 : 1)
        : null;
    // One authored proof taper lets the short sample exercise actual lane
    // restriction, NPC merging and advance warnings. Legacy seeds are unchanged.
    if (testCourseEnabled ||
        (reactiveTrafficEnabled && _edge.id == graph.edges.first.id)) {
      _closedLane = 1;
    }
    weather = switch (_edge.biome) {
      Biome.mountain =>
        _conditionRandom.next() < .55 ? RaceWeather.snow : RaceWeather.clear,
      Biome.forest =>
        _conditionRandom.next() < .32 ? RaceWeather.rain : RaceWeather.clear,
      Biome.desert || Biome.coast => RaceWeather.sunset,
      _ => RaceWeather.clear,
    };
    regionBlend = 0;
    final forecast = weather == RaceWeather.snow
        ? 'Snow ahead. Ease into the curves.'
        : weather == RaceWeather.rain
        ? 'Rain on the road. Leave a little space.'
        : _edge.id == 'nebraska'
        ? 'Nebraska sunshine. Colorado is waiting beyond the plains.'
        : '${_edge.landmark}. Keep an eye on the horizon.';
    _say('${_edge.road}. $forecast', 2, 7);
  }

  void _advanceRoute() {
    if (_edgeDistance < _edge.length) return;
    _edgeDistance -= _edge.length;
    _completedMiles += _edge.miles;
    _completedVisits.add(RouteVisit(_edge.id, 1));
    final unlock = _edge.secretUnlockId;
    if (unlock != null && !unlockedCarIds.contains(unlock)) {
      _earnedUnlockIds.add(unlock);
      _say(
        'A new key! ${cars.firstWhere((c) => c.id == unlock).name} is waiting in the garage.',
        5,
        7,
      );
    }
    final choices = nextChoices;
    if (choices.isEmpty) {
      // Clamp the final sub-step to the actual endpoint for receipt accounting.
      _worldDistance -= _edgeDistance;
      _edgeDistance = 0;
      _finish(true);
      return;
    }
    final available = choices.where((e) => e.id != closedBranchId).toList();
    final intended = playerX > .18 ? choices.last : choices.first;
    final next = available.contains(intended) ? intended : available.first;
    if (next != intended) {
      _say('Construction diversion. Follow the open westbound road.', 4, 5);
    }
    previousBiome = _edge.biome;
    _edge = next;
    _enterEdge();
  }

  void _advisories() {
    if (approachingFork && !_forkAnnounced) {
      _forkAnnounced = true;
      final left = nextChoices.first;
      final right = nextChoices.last;
      String label(RouteEdge e) => e.id == closedBranchId
          ? '${e.road}: CLOSED'
          : e.secret
          ? '${e.landmark}: old-road key rumor'
          : '${e.road} to ${graph.node(e.to).name}';
      _say('Fork ahead. LEFT ${label(left)}. RIGHT ${label(right)}.', 4, 12);
    }
    if (_closedLane != null &&
        !_closureAnnounced &&
        _edgeDistance > closureStart - 950) {
      _closureAnnounced = true;
      _say(
        'Road work ahead. ${_closedLane == -1 ? 'Left' : 'Right'} lane closes. Center lane stays open.',
        4,
        7,
      );
    }
    if (_remaining < 15 && !_timeWarning) {
      _timeWarning = true;
      _say(
        'Fifteen seconds. The next time gate is ${nextGateMiles.ceil()} route miles ahead.',
        5,
        6,
      );
    }
    if (elapsed > _radioUntil && _radioPriority > 0) {
      _radioPriority = 0;
      _radio = '${_edge.road} · ${_edge.landmark}';
    }
  }

  void _advanceTraffic() {
    if (reactiveTrafficEnabled) {
      _advanceReactiveTraffic();
      return;
    }
    if (elapsed >= _nextSpawn) {
      final phase = directorPhase;
      final interval = phase == 'peak'
          ? 3.8
          : phase == 'recovery'
          ? 9.0
          : 6.2;
      _nextSpawn = elapsed + interval + _trafficRandom.next() * 2;
      if (!approachingFork && traffic.length < 13) _spawnTraffic();
    }
    for (final other in traffic) {
      final previousPosition = other.position, previousX = other.x;
      other.position += other.cruiseSpeed * RouteGraph.speedScale * fixedStep;
      final otherEdgeZ = _edgeDistance + other.position - _worldDistance;
      final nearClosure =
          _closedLane != null &&
          otherEdgeZ > closureStart - 400 &&
          otherEdgeZ < closureEnd + 100;
      if (nearClosure &&
          (other.x - _closedLane! * .65).abs() < .3 &&
          other.targetX == null) {
        other.targetX = 0;
        other.signalTime = 0;
      }
      if (elapsed > other.changeAt && other.targetX == null && !nearClosure) {
        final target = [-.65, 0.0, .65][_trafficRandom.index(3)];
        other.changeAt = elapsed + 8 + _trafficRandom.next() * 9;
        if ((target - other.x).abs() > .3) {
          other.targetX = target;
          other.signalTime = 0;
        }
      }
      final target = other.targetX;
      if (target != null) {
        other.signalTime += fixedStep;
        final gapClear = traffic.every(
          (t) =>
              identical(t, other) ||
              (t.position - other.position).abs() > 190 ||
              (t.x - target).abs() > .3,
        );
        final playerClear =
            (other.position - _worldDistance).abs() > 240 ||
            (playerX - target).abs() > .35;
        if (other.signalTime >= 2 && gapClear && playerClear) {
          final difference = target - other.x;
          other.x +=
              difference.sign * math.min(difference.abs(), fixedStep * .19);
          if ((other.x - target).abs() < .01) {
            other.x = target;
            other.targetX = null;
          }
        }
      }
      // A vehicle yields before a closed lane if its signaled merge cannot fit.
      if (nearClosure &&
          (other.x - _closedLane! * .65).abs() < .25 &&
          otherEdgeZ >= closureStart - 60) {
        other.position -= other.cruiseSpeed * RouteGraph.speedScale * fixedStep;
      }
      final hit = testCourseEnabled
          ? _proofContacts.update(
              id: other.id,
              dt: fixedStep,
              fromForward: previousPosition - _stepPlayerStart,
              toForward: other.position - _worldDistance,
              fromLateral: previousX - _stepPlayerXStart,
              toLateral: other.x - playerX,
              halfDepth:
                  (other.truck ? 350 : 280) /
                  proofPresentationScale.clamp(12, 240),
              halfWidth: other.truck ? .22 : .18,
            )
          : (other.position - _worldDistance).abs() < (other.truck ? 30 : 23) &&
                (other.x - playerX).abs() < (other.truck ? .25 : .20);
      if (!recovering && protection <= 0 && hit) {
        _crash(
          flip:
              _speed - other.cruiseSpeed > 69 ||
              (playerX - other.x).abs() > .15 && _speed > 140,
        );
      }
    }
    if (testCourseEnabled) {
      _proofContacts.retain(traffic.map((car) => car.id).toSet());
      if (recovering || protection > 0) _proofContacts.clear();
    }
    traffic.removeWhere(
      (t) =>
          t.position < _worldDistance - 160 ||
          t.position > _worldDistance + 11000,
    );
  }

  void _advanceReactiveTraffic() {
    final previousPositions = testCourseEnabled
        ? {for (final car in traffic) car.id: car.position}
        : <int, double>{};
    final previousLaterals = testCourseEnabled
        ? {for (final car in traffic) car.id: car.x}
        : <int, double>{};
    if (elapsed >= _nextSpawn) {
      final interval = denseProofTraffic
          ? .65
          : testCourseEnabled
          ? 1.2
          : directorPhase == 'peak'
          ? 2.6
          : directorPhase == 'recovery'
          ? 7.0
          : 4.0;
      _nextSpawn =
          elapsed +
          interval +
          _trafficRandom.next() * (denseProofTraffic ? .25 : 1.5);
      if (!approachingFork && traffic.length < (denseProofTraffic ? 24 : 16)) {
        _spawnTraffic();
      }
    }
    _reactiveTraffic.tick(
      cars: traffic,
      dt: fixedStep,
      time: elapsed,
      playerPosition: _worldDistance,
      playerX: playerX,
      playerLateralSpeed: (playerX - _lastTrafficPlayerX) / fixedStep,
      playerSpeed: _speed,
      distanceScale: RouteGraph.speedScale,
      curve: curveAt(_worldDistance),
      closedLane: _closedLane,
      closureStart: _worldDistance - _edgeDistance + closureStart,
      closureEnd: _worldDistance - _edgeDistance + closureEnd,
    );
    _lastTrafficPlayerX = playerX;
    for (final other in traffic) {
      final hit = testCourseEnabled
          ? _proofContacts.update(
              id: other.id,
              dt: fixedStep,
              fromForward:
                  (previousPositions[other.id] ?? other.position) -
                  _stepPlayerStart,
              toForward: other.position - _worldDistance,
              fromLateral:
                  (previousLaterals[other.id] ?? other.x) - _stepPlayerXStart,
              toLateral: other.x - playerX,
              halfDepth:
                  (other.truck ? 350 : 280) /
                  proofPresentationScale.clamp(12, 240),
              halfWidth: other.truck ? .22 : .18,
            )
          : (other.position - _worldDistance).abs() < (other.truck ? 30 : 23) &&
                (other.x - playerX).abs() < (other.truck ? .25 : .20);
      if (!recovering && protection <= 0 && hit) {
        _crash(flip: _speed - other.currentSpeed > 69);
      }
    }
    if (testCourseEnabled) {
      _proofContacts.retain(traffic.map((car) => car.id).toSet());
      if (recovering || protection > 0) _proofContacts.clear();
    }
    traffic.removeWhere(
      (t) =>
          t.position < _worldDistance - 180 ||
          t.position > _worldDistance + 11000,
    );
  }

  void _advanceProofCones() {
    final scale = proofPresentationScale.clamp(12.0, 240.0);
    for (final cone in _proofCones) {
      if (_hitCones.contains(cone.id)) continue;
      final z = cone.courseDistance - courseStartDistance;
      final contact = ProofCollisionGate.overlapInterval(
        fromForward: z - _stepPlayerStart,
        toForward: z - _worldDistance,
        fromLateral: cone.lateral - _stepPlayerXStart,
        toLateral: cone.lateral - playerX,
        halfDepth: 180 / scale,
        halfWidth: .13,
      );
      if (contact == null) continue;
      _hitCones.add(cone.id);
      if (_coneFlights.length >= 24) _coneFlights.removeAt(0);
      final side = (cone.lateral - playerX).abs() < .01
          ? (cone.id.isEven ? 1.0 : -1.0)
          : (cone.lateral - playerX).sign;
      _coneFlights.add(
        ConeFlight(
          cone: cone,
          lateralVelocity: side * (.8 + _speed / 180),
          // Keep the first airborne beat beside/ahead of the chase car.
          forwardVelocity: _speed * RouteGraph.speedScale * .98 + 4,
        ),
      );
      _speed = math.max(0, _speed - .4);
    }
  }

  void _spawnTraffic({double? proofOffset}) {
    final spawn =
        _worldDistance +
        (testCourseEnabled
            ? (proofOffset ??
                  (denseProofTraffic ? proofTrafficPreview + 25 : 300))
            : (reactiveTrafficEnabled ? 520 : 1500)) +
        _trafficRandom.next() *
            (denseProofTraffic
                ? 10
                : (testCourseEnabled
                      ? 25
                      : (reactiveTrafficEnabled ? 520 : 900)));
    var lane = [-.65, 0.0, .65][_trafficRandom.index(3)];
    final spawnOnEdge = _edgeDistance + spawn - _worldDistance;
    if (reactiveTrafficEnabled &&
        _closedLane != null &&
        spawnOnEdge > closureStart - 200 &&
        spawnOnEdge < closureEnd + 100 &&
        (lane - _closedLane! * .65).abs() < .3) {
      lane = 0;
    }
    // One car at a time, separated longitudinally; no solid random traffic walls.
    if (testCourseEnabled) {
      // Stagger lanes and preserve a longitudinal opening rather than walls.
      lane = [-.65, .65, 0.0][_trafficId % 3];
      if (_closedLane != null &&
          spawnOnEdge > closureStart - 200 &&
          spawnOnEdge < closureEnd + 100 &&
          (lane - _closedLane! * .65).abs() < .3) {
        lane = 0;
      }
    }
    if (denseProofTraffic) {
      // Two adjacent lanes may pair up; a third car cannot close the whole road.
      final neighbors = traffic
          .where((t) => (t.position - spawn).abs() < 64)
          .toList();
      if (neighbors.length >= 2 ||
          traffic.any(
            (t) => (t.x - lane).abs() < .32 && (t.position - spawn).abs() < 78,
          )) {
        return;
      }
    } else if (traffic.any(
      (t) => (t.position - spawn).abs() < (testCourseEnabled ? 65 : 320),
    )) {
      return;
    }
    final palette = [
      0xffe9d9ac,
      0xffc16554,
      0xff698a98,
      0xff7b965d,
      0xff8e7ea1,
    ];
    final profileRoll = (_trafficId * 7 + _seed) % 20;
    final profile = !reactiveTrafficEnabled
        ? TrafficProfile.ordinary
        : profileRoll < 13
        ? TrafficProfile.ordinary
        : profileRoll < 17
        ? TrafficProfile.cautious
        : profileRoll < 19
        ? TrafficProfile.brisk
        : TrafficProfile.pushy;
    traffic.add(
      TrafficCar(
        id: _trafficId++,
        position: spawn,
        x: lane,
        cruiseSpeed:
            (67 + _trafficRandom.next() * 27) *
            (reactiveTrafficEnabled
                ? switch (profile) {
                    TrafficProfile.cautious => .88,
                    TrafficProfile.brisk => 1.24,
                    TrafficProfile.pushy => 1.16,
                    TrafficProfile.ordinary => 1.06,
                  }
                : 1),
        color: palette[_trafficRandom.index(palette.length)],
        truck: _trafficRandom.next() < .18,
        changeAt: elapsed + 4 + _trafficRandom.next() * 8,
        profile: profile,
        paintVariant: _trafficId % 8,
        usesSignals: !reactiveTrafficEnabled || profile != TrafficProfile.pushy,
      ),
    );
  }

  void _crash({required bool flip}) {
    _proofContacts.clear();
    _crashes++;
    _lastCrashAt = elapsed;
    crashPose = flip ? CrashPose.flip : CrashPose.spin;
    _recoveryDuration = flip ? 2.1 : 1.25;
    _recovery = _recoveryDuration;
    _speed *= flip ? .27 : .42;
    _say(
      flip
          ? 'Easy! Hold on. Finding a clear place to reset.'
          : 'A scrape. Breathe. We are still heading west.',
      5,
      4,
    );
  }

  void _resetSafely() {
    playerX = 0;
    // Recovery removes nearby traffic before placing the car in the always-open
    // center corridor, then grants visible temporary collision protection.
    traffic.removeWhere((t) => (t.position - _worldDistance).abs() < 420);
    protection = 3;
    _recovery = 0;
    crashPose = CrashPose.driving;
    _speed = math.max(_speed, 43);
  }

  void _say(String message, int priority, double duration) {
    if (priority < _radioPriority && elapsed < _radioUntil) return;
    _radio = message;
    _radioPriority = priority;
    _radioUntil = elapsed + duration;
  }

  void _finish(bool success) {
    _finished = true;
    _completed = success;
    if (success &&
        cars
            .take(cars.length - 1)
            .every(
              (c) =>
                  unlockedCarIds.contains(c.id) ||
                  _earnedUnlockIds.contains(c.id),
            )) {
      _earnedUnlockIds.add('corvette');
    }
    _radio = success
        ? 'The Portofino. Pacific air. You made it.'
        : 'Out of time. The road will be here when you are ready.';
    _receipt = RunReceipt(
      seed: _seed,
      carId: _car.id,
      elapsedMs: (elapsed * 1000).round(),
      distanceMiles: distanceMiles,
      completed: success,
      route: routeProgress,
      gates: _gates,
      crashes: _crashes,
      earnedUnlockIds: _earnedUnlockIds,
    );
  }
}
