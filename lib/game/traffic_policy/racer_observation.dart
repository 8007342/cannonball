import 'dart:math' as math;
import 'dart:typed_data';

/// Shared racer decision contract. It must stay bit-identical to
/// tool/traffic_trainer/src/sim.rs (`encode`, `mask`, `rule_action`): the
/// bundle's parity fixtures are re-checked whenever a bundle loads.
const racerObservationSchema = 'cannonball-racer-obs-v1';
const racerObservationSize = 24;
const racerActions = ['keep', 'left', 'right', 'brake', 'accelerate'];
const racerKeep = 0,
    racerLeft = 1,
    racerRight = 2,
    racerBrake = 3,
    racerAccelerate = 4;
const racerLanes = [-.65, 0.0, .65];

/// Seconds between racer decisions (fixed-step clock, 6 steps at 30 Hz).
const racerDecisionInterval = .2;
const racerLateralRate = 1.1;

class RacerOther {
  const RacerOther(this.z, this.x, this.speed, [this.target]);
  final double z, x, speed;
  final double? target;
}

/// Everything a racer may observe at one decision tick.
class RacerScene {
  const RacerScene({
    required this.z,
    required this.x,
    required this.laneCenter,
    required this.speed,
    required this.cruise,
    required this.changing,
    required this.others,
    required this.playerZ,
    required this.playerX,
    required this.playerSpeed,
    this.closedLane,
    this.closureStart = 0,
    this.closureEnd = 0,
    this.curve = 0,
  });

  final double z, x, laneCenter, speed, cruise;
  final bool changing;
  final List<RacerOther> others;
  final double playerZ, playerX, playerSpeed;

  /// Lane index 0..2 (not the controller's -1..1 offset).
  final int? closedLane;
  final double closureStart, closureEnd, curve;

  factory RacerScene.fromJson(Map<String, dynamic> json) {
    double d(String key) => (json[key] as num).toDouble();
    return RacerScene(
      z: d('z'),
      x: d('x'),
      laneCenter: d('lane_center'),
      speed: d('speed'),
      cruise: d('cruise'),
      changing: json['changing'] as bool,
      others: [
        for (final o in json['others'] as List)
          RacerOther(
            (o['z'] as num).toDouble(),
            (o['x'] as num).toDouble(),
            (o['speed'] as num).toDouble(),
            (o['target'] as num?)?.toDouble(),
          ),
      ],
      playerZ: d('player_z'),
      playerX: d('player_x'),
      playerSpeed: d('player_speed'),
      closedLane: json['closed_lane'] as int?,
      closureStart: d('closure_start'),
      closureEnd: d('closure_end'),
      curve: d('curve'),
    );
  }
}

double _max0(double v) => v > 0 ? v : 0.0;
double _clamp1(double v) => v.clamp(-1.0, 1.0);

int racerNearestLane(double center) {
  var best = 0;
  for (var i = 1; i < 3; i++) {
    if ((racerLanes[i] - center).abs() < (racerLanes[best] - center).abs()) {
      best = i;
    }
  }
  return best;
}

bool _nearClosure(RacerScene s) =>
    s.closedLane != null &&
    s.z > s.closureStart - 400 &&
    s.z < s.closureEnd + 100;

bool _laneClosed(RacerScene s, int lane) =>
    _nearClosure(s) && s.closedLane == lane;

class _LaneView {
  double? aheadGap, behindGap;
  double aheadSpeed = 0, behindSpeed = 0;
  void visit(double z, double speed, double selfZ) {
    final gap = z - selfZ;
    if (gap >= 0) {
      if (aheadGap == null || gap < aheadGap!) {
        aheadGap = gap;
        aheadSpeed = speed;
      }
    } else if (behindGap == null || -gap < behindGap!) {
      behindGap = -gap;
      behindSpeed = speed;
    }
  }
}

_LaneView _neighbors(RacerScene s, int lane) {
  final lx = racerLanes[lane];
  final view = _LaneView();
  for (final o in s.others) {
    if ((o.x - lx).abs() < .33) view.visit(o.z, o.speed, s.z);
  }
  if ((s.playerX - lx).abs() < .36) view.visit(s.playerZ, s.playerSpeed, s.z);
  return view;
}

Float64List encodeRacerObservation(RacerScene s) {
  final o = Float64List(racerObservationSize);
  o[racerNearestLane(s.laneCenter)] = 1;
  o[3] = s.speed / 160;
  o[4] = _clamp1((s.cruise - s.speed) / 60);
  for (var i = 0; i < 3; i++) {
    final n = _neighbors(s, i);
    final b = 5 + i * 5;
    o[b] = n.aheadGap == null ? 1 : math.min(n.aheadGap! / 300, 1.0);
    o[b + 1] = n.aheadGap == null ? 0 : _clamp1((n.aheadSpeed - s.speed) / 60);
    o[b + 2] = n.behindGap == null ? 1 : math.min(n.behindGap! / 300, 1.0);
    o[b + 3] = n.behindGap == null
        ? 0
        : _clamp1((n.behindSpeed - s.speed) / 60);
    o[b + 4] = _laneClosed(s, i) ? 1 : 0;
  }
  o[20] = _clamp1((s.playerZ - s.z) / 300);
  o[21] = _clamp1((s.playerX - s.x) / 1.3);
  o[22] = _clamp1((s.playerSpeed - s.speed) / 60);
  o[23] = _clamp1(s.curve);
  return o;
}

/// Racer merge margins: tighter than ordinary drivers, never zero. Vehicles
/// already signalling into the lane count as occupants; the player gets a
/// wider berth so weaving stays fun rather than unfair.
bool racerGapClear(RacerScene s, int lane) {
  final lx = racerLanes[lane];
  for (final o in s.others) {
    final merging = o.target != null && (o.target! - lx).abs() < .05;
    if ((o.x - lx).abs() >= .33 && !merging) continue;
    final gap = o.z - s.z;
    final required = gap >= 0
        ? 30 + _max0(s.speed - o.speed) * .9
        : 22 + _max0(o.speed - s.speed) * .9;
    if (gap.abs() < required) return false;
  }
  if ((s.playerX - lx).abs() < .40) {
    final gap = s.playerZ - s.z;
    final required = gap >= 0
        ? 55 + _max0(s.speed - s.playerSpeed) * 1.2
        : 45 + _max0(s.playerSpeed - s.speed) * 1.2;
    if (gap.abs() < required) return false;
  }
  return true;
}

/// Actions the racer may take now; keep and brake are always allowed.
List<bool> racerSafetyMask(RacerScene s) {
  final lane = racerNearestLane(s.laneCenter);
  final m = [true, false, false, true, false];
  if (!s.changing) {
    m[racerLeft] =
        lane > 0 && !_laneClosed(s, lane - 1) && racerGapClear(s, lane - 1);
    m[racerRight] =
        lane < 2 && !_laneClosed(s, lane + 1) && racerGapClear(s, lane + 1);
  }
  final n = _neighbors(s, lane);
  final room =
      n.aheadGap == null ||
      n.aheadGap! > 45 + _max0(s.speed - n.aheadSpeed) * 1.2;
  m[racerAccelerate] =
      room && !(_laneClosed(s, lane) && s.z > s.closureStart - 150);
  return m;
}

/// Deterministic rule fallback used when no compatible bundle is loaded.
int ruleRacerAction(RacerScene s, List<bool> m) {
  final lane = racerNearestLane(s.laneCenter);
  final n = _neighbors(s, lane);
  final ag = n.aheadGap;
  final inClosed = _laneClosed(s, lane);
  final closing = ag == null ? 0.0 : _max0(s.speed - n.aheadSpeed);
  final blocked =
      ag != null && ag < 70 + closing * 1.5 && n.aheadSpeed < s.speed - 3;
  if (inClosed || blocked) {
    int? best;
    var bestRoom = inClosed ? -1.0 : (ag ?? 1e9) + 40;
    for (final (action, ok) in [
      (racerLeft, lane > 0),
      (racerRight, lane < 2),
    ]) {
      if (!ok || !m[action]) continue;
      final target = action == racerLeft ? lane - 1 : lane + 1;
      final room = _neighbors(s, target).aheadGap ?? 600.0;
      if (room > bestRoom) {
        best = action;
        bestRoom = room;
      }
    }
    if (best != null) return best;
    if ((ag != null && ag < 40 + closing * 1.2) ||
        (inClosed && s.z > s.closureStart - 250)) {
      return racerBrake;
    }
    return racerKeep;
  }
  if (m[racerAccelerate] && s.speed < s.cruise - 2) return racerAccelerate;
  return racerKeep;
}
