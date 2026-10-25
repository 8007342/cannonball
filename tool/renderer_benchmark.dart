// Isolated renderer A/B harness. No auth, audio, root HUD or network work.
// Build both compiler targets with the same seed and unchanged game source.
import 'dart:js_interop';

import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:cannonball/game/race.dart';

@JS('cannonballReadBenchmarkStats')
external set _readStats(JSFunction value);
@JS('cannonballResetBenchmark')
external set _resetBenchmark(JSFunction value);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = RaceController();
  final game = _MeasuredGame(controller: controller);
  _readStats = (() => game.stats.jsify() as JSObject).toJS;
  _resetBenchmark = (() => game.reset()).toJS;
  game.reset();
  runApp(
    Directionality(
      textDirection: TextDirection.ltr,
      child: GameWidget(game: game),
    ),
  );
}

class _MeasuredGame extends RaceGame {
  _MeasuredGame({required super.controller});
  static const seed = 731;
  final _updateClock = Stopwatch(), _renderClock = Stopwatch();
  int _updates = 0, _renders = 0, _updateUs = 0, _renderUs = 0;

  Map<String, Object> get stats => {
    'compiledToWasm': const bool.fromEnvironment('dart.tool.dart2wasm'),
    'seed': seed,
    'updates': _updates,
    'renders': _renders,
    'updateCpuUs': _updateUs,
    // Canvas command-recording time, not GPU raster/presentation time.
    'renderCommandCpuUs': _renderUs,
    'simulationSeconds': controller.elapsed,
    'worldDistance': controller.worldDistance,
    'car': controller.car.id,
    'edge': controller.currentEdge.id,
    'finished': controller.finished,
    'paused': controller.paused,
  };

  void reset() {
    controller.start(cars.first, seed: seed);
    controller.paused = false;
    controller.comfortMode = true;
    _updates = _renders = _updateUs = _renderUs = 0;
  }

  @override
  void update(double dt) {
    _updateClock.reset();
    _updateClock.start();
    super.update(dt);
    _updateClock.stop();
    if (dt > 0) {
      _updates++;
      _updateUs += _updateClock.elapsedMicroseconds;
    }
  }

  @override
  void render(Canvas canvas) {
    _renderClock.reset();
    _renderClock.start();
    super.render(canvas);
    _renderClock.stop();
    _renders++;
    _renderUs += _renderClock.elapsedMicroseconds;
  }
}
