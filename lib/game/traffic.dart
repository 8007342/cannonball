import 'dart:math' as math;

/// Driver habits are independent of the vehicle's body, paint and route.
enum TrafficProfile { ordinary, cautious, brisk, pushy }

class TrafficCar {
  TrafficCar({
    required this.id,
    required this.position,
    required this.x,
    required this.cruiseSpeed,
    required this.color,
    required this.truck,
    required this.changeAt,
    this.profile = TrafficProfile.ordinary,
    this.paintVariant = 0,
    this.usesSignals = true,
  }) : currentSpeed = cruiseSpeed,
       laneCenter = x;

  final int id, color, paintVariant;
  final bool truck, usesSignals;
  final TrafficProfile profile;
  double position, x, cruiseSpeed, changeAt;
  double currentSpeed, laneCenter;
  double? targetX;
  double signalTime = 0;
  bool braking = false;
  double reactionIntensity = 0, incidentSeconds = 0;
  double _flinch = 0, _reactionUntil = 0, _reactionCooldown = 0;
  double _incidentCooldown = 0, _panicUntil = 0;
  double get reactionOffset => _flinch;
  bool get signaling => usesSignals && targetX != null && signalTime < 2;
}

/// Small, deterministic local policy inspired by Atrapa's bounded observation.
/// Coordinates are arcade road units, not a calibrated traffic simulator.
class ReactiveTraffic {
  int reactions = 0, incidents = 0;

  static const lanes = [-.65, 0.0, .65];

  void tick({
    required List<TrafficCar> cars,
    required double dt,
    required double time,
    required double playerPosition,
    required double playerX,
    required double playerLateralSpeed,
    required double playerSpeed,
    required double distanceScale,
    double curve = 0,
    int? closedLane,
    double closureStart = double.infinity,
    double closureEnd = double.infinity,
  }) {
    // Decisions use one pre-step observation: actor iteration order cannot create
    // an instantaneous braking wave through every car in a single step.
    final observed = [for (final car in cars) _Observation(car)];
    for (var index = 0; index < cars.length; index++) {
      final car = cars[index];
      car.incidentSeconds = math.max(0, car.incidentSeconds - dt);
      final self = observed[index];
      final longitudinal = car.position - playerPosition;
      final lateral = car.x - playerX;
      final lateralApproach = playerLateralSpeed * lateral.sign > .3;
      final closePass =
          longitudinal.abs() < 100 &&
          lateral.abs() < .64 &&
          lateral.abs() > .15 &&
          (playerSpeed - car.currentSpeed > 8 || lateralApproach);
      final intrusion =
          longitudinal.abs() < 40 &&
          lateral.abs() < .34 &&
          (playerLateralSpeed.abs() > .4 ||
              playerSpeed - car.currentSpeed > 15);
      if ((closePass || intrusion) && time >= car._reactionCooldown) {
        reactions++;
        car.reactionIntensity = intrusion ? 1 : .6;
        car._reactionUntil = time + (intrusion ? 1.8 : 1.1);
        car._reactionCooldown = time + 4.5;
        car._flinch = lateral.sign * (intrusion ? .11 : .07);
        if (intrusion || car.profile == TrafficProfile.cautious) {
          car._panicUntil = time + (intrusion ? .9 : .35);
        }
      }
      if (time >= car._reactionUntil) {
        car.reactionIntensity = math.max(0, car.reactionIntensity - dt * 1.4);
      }
      // A flinch never crosses a lane boundary; it settles back smoothly.
      car._flinch *= math.exp(-dt * (time < car._reactionUntil ? 1.2 : 5));
      car._flinch = car._flinch.clamp(-.12, .12);

      var desiredSpeed = car.cruiseSpeed;
      if (car.profile == TrafficProfile.brisk) {
        // A straight-line hero is less confident in bends.
        desiredSpeed *= 1 - curve.abs().clamp(0, 1) * .26;
      }
      var acceleration = ((desiredSpeed - self.speed) * .9).clamp(-20.0, 9.0);
      var leaderGap = double.infinity;
      var leaderSpeed = desiredSpeed;
      for (final candidate in observed) {
        if (candidate.id == self.id || (candidate.x - self.x).abs() > .31)
          continue;
        final gap = candidate.position - self.position;
        if (gap > 0 && gap < leaderGap) {
          leaderGap = gap;
          leaderSpeed = candidate.speed;
        }
      }
      if (playerPosition > self.position && (playerX - self.x).abs() < .32) {
        final gap = playerPosition - self.position;
        if (gap < leaderGap) {
          leaderGap = gap;
          leaderSpeed = playerSpeed;
        }
      }
      final headway = switch (car.profile) {
        TrafficProfile.cautious => 2.1,
        TrafficProfile.pushy => .9,
        _ => 1.4,
      };
      final desiredGap = 25 + self.speed * distanceScale * headway;
      if (leaderGap < desiredGap * 1.6) {
        final closing = self.speed - leaderSpeed;
        acceleration = math.min(
          acceleration,
          (leaderGap - desiredGap) * .17 - closing * 1.1,
        );
      }
      final nearClosure =
          closedLane != null &&
          self.position > closureStart - 400 &&
          self.position < closureEnd + 100;
      final blocked =
          nearClosure && (car.laneCenter - closedLane * .65).abs() < .28;
      if (time >= car.changeAt && car.targetX == null) {
        final needsPass =
            leaderGap < desiredGap * 1.4 && leaderSpeed < desiredSpeed - 5;
        if (blocked || needsPass) {
          double? best;
          var bestRoom = leaderGap;
          for (final lane in lanes) {
            if ((lane - car.laneCenter).abs() > .7 ||
                (lane - car.laneCenter).abs() < .3)
              continue;
            if (nearClosure && (lane - closedLane! * .65).abs() < .25) continue;
            if (!_laneClear(
              self,
              lane,
              observed,
              playerPosition,
              playerX,
              playerSpeed,
            ))
              continue;
            var room = 700.0;
            for (final candidate in observed) {
              if (candidate.id != self.id &&
                  (candidate.x - lane).abs() < .3 &&
                  candidate.position > self.position) {
                room = math.min(room, candidate.position - self.position);
              }
            }
            if (blocked || room > bestRoom + 60) {
              best = lane;
              bestRoom = room;
            }
          }
          if (best != null) {
            car.targetX = best;
            car.signalTime = 0;
          }
        }
        // Persistent cooldown stops frantic lane hopping.
        car.changeAt = time + 3 + (car.id % 7) * .35;
      }
      if (car.targetX case final target?) {
        car.signalTime += dt;
        final delay = car.usesSignals ? 1.25 : .65;
        if (car.signalTime >= delay &&
            _laneClear(
              self,
              target,
              observed,
              playerPosition,
              playerX,
              playerSpeed,
            )) {
          final difference = target - car.laneCenter;
          car.laneCenter +=
              difference.sign * math.min(difference.abs(), dt * .26);
          if ((car.laneCenter - target).abs() < .005) {
            car.laneCenter = target;
            car.targetX = null;
            car.changeAt = time + 5;
          }
        }
      }
      if (blocked && self.position >= closureStart - desiredGap) {
        acceleration = math.min(acceleration, -25);
      }
      if (time < car._panicUntil) acceleration = math.min(acceleration, -48);
      if (car.incidentSeconds > 0) acceleration = math.min(acceleration, -38);
      acceleration = acceleration.clamp(-58, 10);
      car.braking = acceleration < -3;
      car.currentSpeed = (self.speed + acceleration * dt).clamp(
        0,
        desiredSpeed + 5,
      );
      car.position += car.currentSpeed * distanceScale * dt;
      if (blocked && car.position >= closureStart - 20) {
        car.position = math.max(self.position, closureStart - 20);
        car.currentSpeed = 0;
        car.braking = true;
      }
      car.x = (car.laneCenter + car._flinch).clamp(-.81, .81);
    }
    // Rare secondary contacts emerge from actual closing gaps after panic
    // braking. No random accident is spawned in a clear lane.
    for (var i = 0; i < cars.length; i++) {
      for (var j = i + 1; j < cars.length; j++) {
        final a = cars[i], b = cars[j];
        if ((a.x - b.x).abs() > .20 || (a.position - b.position).abs() > 10)
          continue;
        final behind = a.position < b.position ? a : b;
        final ahead = identical(behind, a) ? b : a;
        if (behind.currentSpeed - ahead.currentSpeed < 8 ||
            time < behind._incidentCooldown ||
            time < ahead._incidentCooldown)
          continue;
        incidents++;
        for (final participant in [behind, ahead]) {
          participant.incidentSeconds = 2.2;
          participant._incidentCooldown = time + 10;
          participant._panicUntil = time + 1.1;
          participant.currentSpeed *= .55;
          participant.braking = true;
        }
      }
    }
  }

  bool _laneClear(
    _Observation self,
    double lane,
    List<_Observation> cars,
    double playerPosition,
    double playerX,
    double playerSpeed,
  ) {
    for (final car in cars) {
      if (car.id == self.id || (car.x - lane).abs() > .33) continue;
      final gap = car.position - self.position;
      final required = gap < 0
          ? 45 + math.max(0, car.speed - self.speed) * 2
          : 70 + math.max(0, self.speed - car.speed) * 2;
      if (gap.abs() < required) return false;
    }
    if ((playerX - lane).abs() < .36 &&
        (playerPosition - self.position).abs() <
            170 + math.max(0, playerSpeed - self.speed))
      return false;
    return true;
  }
}

class _Observation {
  _Observation(TrafficCar car)
    : id = car.id,
      position = car.position,
      x = car.x,
      speed = car.currentSpeed;
  final int id;
  final double position, x, speed;
}
