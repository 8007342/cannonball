import 'dart:math' as math;

import 'package:cannonball/game/proof_course.dart';
import 'package:cannonball/game/proof_level.dart';
import 'package:cannonball/game/render/proof_camera.dart';
import 'package:cannonball/game/terrain/level_profiles.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors RaceGame._project for the velocity preset and the 'wide' camera:
/// the logical canvas is 1000 wide and 562.5 high at 16:9.
const _flow = 168.0, _h = 562.5, _projection = .64;

ProofTerrain _terrain(String id) =>
    ProofTerrain(ProofLevel.all.firstWhere((l) => l.id == id));

/// Screen pixels by which the road [ahead] course units in front of the car
/// sits above (positive) or below where a flat road would be, relative to
/// the pitched horizon. Pitch-independent: what the eye reads as a hill.
double _rise(ProofTerrain t, double s, double ahead) {
  final z = ahead * _flow + 560;
  return _projection /
      z *
      (t.visualElevationAt(s + ahead) - t.visualElevationAt(s)) *
      _h *
      .70;
}

/// Visibility of the 330-unit preview with the renderer's camera pitch:
/// (first hidden distance, farthest visible distance) in course units.
(double, double) _sight(ProofTerrain t, double s) {
  final pitch = ProofCamera.pitch(t.pitchAt(s, _flow), 'wide');
  final cameraY =
      t.visualElevationAt(s) + ProofCamera.height('wide', _projection);
  var top = double.infinity, firstHidden = 330.0, farthest = 0.0;
  for (var a = 5.0; a < 330; a += 5) {
    final z = a * _flow + 560;
    final y =
        _projection / z * (cameraY - t.visualElevationAt(s + a)) * _h * .70 +
        _h * ProofCourse.pitchShift(pitch, z);
    if (y >= top) {
      firstHidden = math.min(firstHidden, a);
    } else {
      farthest = a;
    }
    top = math.min(top, y);
  }
  return (firstHidden, farthest);
}

/// Screen pixels the visible road climbs after its lowest point ahead.
double _climb(ProofTerrain t, double s) {
  var lowest = -double.infinity, climb = 0.0;
  for (var a = 5.0; a < 330; a += 5) {
    final z = a * _flow + 560;
    // Screen y relative to the horizon, without the shared pitch shear.
    final y =
        _projection /
        z *
        -(t.visualElevationAt(s + a) - t.visualElevationAt(s)) *
        _h *
        .70;
    lowest = math.max(lowest, y);
    climb = math.max(climb, lowest - y);
  }
  return climb;
}

double _maxRise(ProofTerrain t, double s) {
  var best = 0.0;
  for (var a = 10.0; a < 330; a += 10) {
    best = math.max(best, _rise(t, s, a));
  }
  return best;
}

void main() {
  test('relief is presentation only: simulation elevation is unchanged', () {
    for (final p in LevelProfile.all) {
      for (var s = 0.0; s < 7600; s += 13) {
        expect(p.visualElevationAt(s, 0), closeTo(p.elevationAt(s), 1e-9));
      }
    }
    // Hudson's reviewed course and flat Chicago are not exaggerated.
    for (final id in ['hudson', 'chicago']) {
      final t = _terrain(id);
      for (var s = 0.0; s < 7600; s += 17) {
        expect(t.visualElevationAt(s), t.elevationAt(s));
        final legacy =
            ((t.elevationAt(s + 60) - t.elevationAt(s - 60)) /
                    (120 * _flow) *
                    1.8)
                .clamp(-.24, .24);
        expect(t.pitchAt(s, _flow), legacy);
      }
    }
  });

  test('Ohio blind crest rises as a wall, then hides the road beyond', () {
    final t = _terrain('ohio');
    // Approaching the BLIND CREST hill (1660-2040, peak at 1850).
    expect(_maxRise(t, 1640), greaterThan(90));
    // On top, the road drops out of sight just beyond the crest.
    expect(_sight(t, 1850).$1, lessThan(80));
  });

  test('Indiana valley shows the road climbing far ahead', () {
    final t = _terrain('indiana');
    // Dropping into the 500-900 dip: the whole preview is in view, with
    // the road climbing up the far side of the valley.
    expect(_sight(t, 550).$1, greaterThan(280));
    expect(_climb(t, 550), greaterThan(60));
    // The crest of that swell hides the descent behind it.
    expect(_sight(t, 1175).$1, lessThan(80));
  });

  test('hilly levels read far stronger than the calm and baseline levels', () {
    double p95(String id) {
      final t = _terrain(id);
      final rises = [for (var s = 0.0; s < 7600; s += 10) _maxRise(t, s)]
        ..sort();
      return rises[(rises.length * .95).floor()];
    }

    final hudson = p95('hudson'), iowa = p95('iowa');
    for (final id in ['ohio', 'indiana', 'arizona']) {
      expect(p95(id), greaterThan(hudson * 2.4), reason: id);
    }
    expect(iowa, lessThan(hudson), reason: 'Iowa stays calm');
  });

  test('comfort mode halves the exaggeration and stays deterministic', () {
    final full = _terrain('ohio'), comfort = _terrain('ohio')..reliefScale = .5;
    final again = _terrain('ohio');
    for (var s = 0.0; s < 7600; s += 11) {
      expect(again.visualElevationAt(s), full.visualElevationAt(s));
      expect(again.pitchAt(s, _flow), full.pitchAt(s, _flow));
    }
    expect(_maxRise(comfort, 1640), lessThan(_maxRise(full, 1640) * .7));
    expect(_maxRise(comfort, 1640), greaterThan(_maxRise(full, 1640) * .3));
  });

  test('the camera never hides the player behind its own slope', () {
    // A slope steeper than cameraHeight/trail would raise the ground between
    // the camera and the car above the car's contact line.
    final limit = ProofCamera.height('wide', _projection) / 560;
    for (final l in ProofLevel.all) {
      final t = ProofTerrain(l);
      for (var s = 0.0; s < 7600; s += 2) {
        expect(
          t.gradeAt(s, _flow).abs(),
          lessThan(limit),
          reason: '${l.id} at $s',
        );
      }
    }
  });
}
