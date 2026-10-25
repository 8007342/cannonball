import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/race.dart';
import '../game/proof_car.dart';
import '../game/proof_course.dart';
import '../platform/browser_platform.dart';
import '../platform/proof_telemetry.dart';
import '../platform/proof_radio.dart';
import 'proof_garage.dart';
import 'wheel_control.dart';

enum _ProofPhase { ready, departing, driving, paused, complete }

/// An isolated art/control study: no accounts, unlocks, records or persistence.
class VisualProofScreen extends StatefulWidget {
  const VisualProofScreen({super.key, this.controller, this.sceneBuilder});

  @visibleForTesting
  final RaceController? controller;
  @visibleForTesting
  final Widget Function(RaceController)? sceneBuilder;

  @override
  State<VisualProofScreen> createState() => _VisualProofScreenState();
}

class _VisualProofScreenState extends State<VisualProofScreen>
    with WidgetsBindingObserver {
  static const seed = 731;
  static const duration = 120.0;
  static const _chapterStarts = [
    0.0,
    650.0,
    2250.0,
    3250.0,
    4300.0,
    5100.0,
    5700.0,
    6150.0,
  ];
  late double _courseStart =
      _chapterStarts[((int.tryParse(
                    Uri.base.queryParameters['chapter'] ?? '',
                  ) ??
                  1) -
              1)
          .clamp(0, 7)];
  static const cream = Color(0xffffedcc);
  static const accent = Color(0xffffc56c);
  static const dark = Color(0xff14242b);
  late final RaceController _race;
  RaceGame? _game;
  late final Widget _scene;
  final _phase = ValueNotifier(_ProofPhase.ready);
  final _hud = ValueNotifier(0);
  final _ready = ValueNotifier(false);
  final _keyboard = FocusNode(debugLabel: 'Proof drive controls');
  final _keys = <LogicalKeyboardKey>{};
  final _platform = BrowserPlatform.instance;
  Timer? _loadingPoll;
  bool _tilt = false, _muted = false, _touchBrake = false;
  bool _captions = false;
  double _lastHudTime = -1;
  String _lastRadio = '';
  String _departureShot = 'keys';
  String _station = '';
  final _radioDirector = ProofRadioDirector();
  String? _artError;
  int _renderBaseline = 0, _updateBaseline = 0;
  int _renderUsBaseline = 0, _updateUsBaseline = 0;

  @override
  void initState() {
    super.initState();
    _race = widget.controller ?? RaceController();
    _race.start(
      proofCar,
      seed: seed,
      reactiveTraffic: true,
      launchSpeed: _courseStart > 0 ? 95 : 0,
      testCourse: true,
      denseTraffic: Uri.base.queryParameters['traffic'] != 'light',
      courseStartDistance: _courseStart,
    );
    _race.paused = true;
    _race.comfortMode = _platform.reducedMotion;
    _race.addListener(_onRace);
    WidgetsBinding.instance.addObserver(this);
    if (widget.sceneBuilder != null) {
      _scene = widget.sceneBuilder!(_race);
      _ready.value = true;
    } else {
      _game = RaceGame(controller: _race, proofMode: true)
        ..setSpeedPreset(Uri.base.queryParameters['motion'] ?? 'hyperspeed')
        ..setCameraPreset(Uri.base.queryParameters['camera'] ?? 'wide')
        ..stableChase = Uri.base.queryParameters['chase'] == 'stable'
        ..speedEffects = Uri.base.queryParameters['effects'] == 'on'
        ..suspensionEnabled = Uri.base.queryParameters['body'] != 'stable';
      _scene = RepaintBoundary(
        child: GameWidget(
          game: _game!,
          autofocus: false,
          loadingBuilder: (_) => const ColoredBox(color: dark),
          errorBuilder: (_, error) => const ColoredBox(color: dark),
        ),
      );
      _loadingPoll = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_game!.assetsReady || _game!.artError != null) {
          setState(() => _artError = _game!.artError?.toString());
          _ready.value = _game!.assetsReady;
          _hud.value++;
          timer.cancel();
        }
      });
    }
    _platform.initialize(
      onTilt: (value) {
        if (_tilt && _phase.value == _ProofPhase.driving) {
          _race.steering = value;
        }
      },
      onVisibility: (hidden) {
        if (hidden) _pause(true);
      },
      onOrientation: (landscape) {
        if (!landscape) _pause(true);
      },
      onTiltStatus: (enabled) {
        if (!mounted) return;
        _tilt = enabled;
        _race.motionControl = enabled;
        _race.steering = 0;
        _hud.value++;
      },
    );
    _platform.muted = _muted;
    _platform.setProofAudio(true);
    _platform.pause(true);
    installProofTelemetry(
      snapshot: _snapshot,
      start: _start,
      reset: _reset,
      pause: _pause,
      drive: (steer, brake) {
        if (_phase.value != _ProofPhase.driving) return;
        _race.steering = steer.isFinite ? steer.clamp(-1, 1) : 0;
        _race.braking = brake;
      },
    );
  }

  Map<String, Object?> _snapshot() => {
    'compiledToWasm': const bool.fromEnvironment('dart.tool.dart2wasm'),
    'seed': seed,
    'sceneCar': _race.car.id,
    'simClock': _race.elapsed,
    'durationSeconds': duration,
    'paused': _race.paused,
    'state': _phase.value.name,
    'departureShot': _departureShot,
    'radioStation': _station,
    'radioCaption': _lastRadio,
    'captionsEnabled': _captions,
    'speechMode':
        'prepared neural reports with device fallback; accents pending',
    'assetsReady': _ready.value,
    'artError': _artError,
    'speedMph': _race.speed,
    'worldDistance': _race.worldDistance,
    'steering': _race.steering,
    'effectiveSteering': _race.effectiveSteering,
    'visualSteering': _game?.visualSteering,
    'cameraPreset': _game?.cameraPreset,
    'horizonFraction': _game?.horizonFraction,
    'cameraHeight': _game?.cameraHeight,
    'chaseGround': _game?.chase.ground,
    'chaseLook': _game?.chase.lateralLook,
    'bodyRoll': _game?.suspension.roll,
    'bodyPitch': _game?.suspension.pitch,
    'bodyHeave': _game?.suspension.heave,
    'speedEffects': _game?.speedEffects,
    'denseTraffic': _race.denseProofTraffic,
    'coursePitch': _game?.coursePitch,
    'courseDistance': _race.courseDistance,
    'courseStartDistance': _race.courseStartDistance,
    'courseSection': ProofCourse.sectionAt(_race.courseDistance),
    'courseLength': ProofCourse.length,
    'braking': _race.braking,
    'playerX': _race.playerX,
    'speedPreset': _game?.speedPreset,
    'presentationDistance': _game?.presentationDistance,
    'roadCurve': _race.curveAt(_race.worldDistance),
    'closedLane': _race.closedLane,
    'traffic': [
      for (final car in _race.traffic)
        {
          'id': car.id,
          'distance': car.position - _race.worldDistance,
          'x': car.x,
          'speed': car.currentSpeed,
          'braking': car.braking,
          'reaction': car.reactionIntensity,
          'incident': car.incidentSeconds,
          'paint': car.paintVariant,
          'profile': car.profile.name,
        },
    ],
    'crashes': _race.crashes,
    'coneHitCount': _race.coneHitCount,
    'coneFlights': _race.coneFlights.length,
    'presentationScale': _race.proofPresentationScale,
    'trafficReactions': _race.trafficReactionCount,
    'trafficIncidents': _race.trafficIncidentCount,
    'sceneLogicalSize': _game?.hasLayout == true
        ? {'width': _game!.size.x, 'height': _game!.size.y}
        : null,
    'renderCount': (_game?.renderCount ?? 0) - _renderBaseline,
    'updateCount': (_game?.updateCount ?? 0) - _updateBaseline,
    'renderCommandCpuMicros': (_game?.renderCpuMicros ?? 0) - _renderUsBaseline,
    'updateCpuMicros': (_game?.updateCpuMicros ?? 0) - _updateUsBaseline,
    'lastRenderMicros': _game?.lastRenderMicros ?? 0,
    'maxRenderMicros': _game?.maxRenderMicros ?? 0,
    'stage': _game?.proofStage,
    'lastSpriteCount': _game?.lastSpriteCount ?? 0,
    'lastRoadQuads': _game?.lastRoadQuads ?? 0,
    'timingScope':
        'CPU command recording and loop calls, not presented-frame FPS',
  };

  void _resetInput() {
    _keys.clear();
    _touchBrake = false;
    _race.steering = 0;
    _race.braking = false;
  }

  void _reset() {
    if (!mounted) return;
    _resetInput();
    _race.start(
      proofCar,
      seed: seed,
      reactiveTraffic: true,
      launchSpeed: _courseStart > 0 ? 95 : 0,
      testCourse: true,
      denseTraffic: Uri.base.queryParameters['traffic'] != 'light',
      courseStartDistance: _courseStart,
    );
    _race.paused = true;
    _race.motionControl = _tilt;
    _platform.pause(true);
    _lastHudTime = -1;
    _lastRadio = '';
    _station = '';
    _departureShot = 'keys';
    _radioDirector.reset();
    _renderBaseline = _game?.renderCount ?? 0;
    _updateBaseline = _game?.updateCount ?? 0;
    _renderUsBaseline = _game?.renderCpuMicros ?? 0;
    _updateUsBaseline = _game?.updateCpuMicros ?? 0;
    _phase.value = _ProofPhase.ready;
    _hud.value++;
  }

  void _beginDeparture() {
    if (!mounted || !_ready.value || _phase.value != _ProofPhase.ready) return;
    final viewport = MediaQuery.sizeOf(context);
    if (viewport.height > viewport.width) return;
    unawaited(_platform.beginAudio());
    _race.paused = true;
    _phase.value = _ProofPhase.departing;
    _departureShot = 'reach';
  }

  void _toggleSound() {
    _muted = !_muted;
    _platform.muted = _muted;
    if (!_muted) {
      _station = '';
      unawaited(_platform.beginAudio());
    }
    _hud.value++;
  }

  void _start() {
    if (!mounted || !_ready.value) return;
    final viewport = MediaQuery.sizeOf(context);
    if (viewport.height > viewport.width) return;
    if (_phase.value == _ProofPhase.complete) _reset();
    _resetInput();
    unawaited(_platform.beginAudio());
    _race.paused = false;
    _platform.pause(false);
    _phase.value = _ProofPhase.driving;
    _keyboard.requestFocus();
  }

  void _pause(bool value) {
    if (!mounted) return;
    if (!value) {
      _start();
      return;
    }
    if (_phase.value != _ProofPhase.driving &&
        _phase.value != _ProofPhase.departing) {
      return;
    }
    _resetInput();
    _race.paused = true;
    _platform.pause(true);
    _phase.value = _ProofPhase.paused;
  }

  String get _radioStation => switch (_race.currentEdge.biome) {
    Biome.city => 'City',
    Biome.mountain || Biome.canyon => 'Mountain',
    _ => 'Forest',
  };

  void _onRace() {
    if (!mounted || _phase.value != _ProofPhase.driving) return;
    if (_race.elapsed >= duration || _race.finished) {
      _resetInput();
      _race.paused = true;
      _platform.pause(true);
      _phase.value = _ProofPhase.complete;
      _hud.value++;
      return;
    }
    final station = _radioStation;
    _platform.setAudioState(
      speed: (_race.speed / _race.car.topSpeed).clamp(0, 1),
      intensity: (_race.speed / _race.car.topSpeed).clamp(0, 1),
      region: station,
    );
    if (station != _station) {
      _station = station;
      final report = _radioDirector.choose(
        station: station,
        weather: _race.weather.name,
        trafficCount: _race.traffic.length,
        detourClosed: _race.approachingFork && _race.closedBranchId != null,
        laneClosed:
            _race.closedLane != null && _race.edgeDistance < _race.closureEnd,
      );
      _lastRadio = report.text;
      _platform.radioBreak(text: report.text, station: report.station);
      _hud.value++;
    }
    if (_race.elapsed - _lastHudTime >= .1) {
      _lastHudTime = _race.elapsed;
      _hud.value++;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A visible preview losing keyboard focus is not a hidden browser tab.
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _pause(true);
    }
  }

  void _toggleSpeedEffects() {
    final game = _game;
    if (game == null) return;
    game.speedEffects = !game.speedEffects;
    _hud.value++;
  }

  void _cycleCamera() {
    const variants = ['baseline', 'wide', 'flow'];
    final index = variants.indexOf(_game?.cameraPreset ?? 'wide');
    _game?.setCameraPreset(variants[(index + 1) % variants.length]);
    _hud.value++;
  }

  void _restartCourse([int? chapter]) {
    if (chapter != null) _courseStart = _chapterStarts[chapter.clamp(0, 7)];
    _reset();
    _start();
  }

  void _key(KeyEvent event) {
    if (event is KeyDownEvent && _phase.value != _ProofPhase.departing) {
      if (event.logicalKey == LogicalKeyboardKey.keyV) {
        _toggleSpeedEffects();
        return;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyC) {
        _cycleCamera();
        return;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyR) {
        _restartCourse();
        return;
      }
      const digits = [
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.digit4,
        LogicalKeyboardKey.digit5,
        LogicalKeyboardKey.digit6,
        LogicalKeyboardKey.digit7,
        LogicalKeyboardKey.digit8,
      ];
      final chapter = digits.indexOf(event.logicalKey);
      if (chapter >= 0) {
        _restartCourse(chapter);
        return;
      }
    }

    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.keyP ||
            event.logicalKey == LogicalKeyboardKey.escape)) {
      if (_phase.value == _ProofPhase.driving) {
        _pause(true);
      } else if (_phase.value == _ProofPhase.ready) {
        _beginDeparture();
      } else {
        _start();
      }
      return;
    }
    if (_phase.value != _ProofPhase.driving) return;
    if (event is KeyUpEvent) {
      _keys.remove(event.logicalKey);
    } else {
      _keys.add(event.logicalKey);
    }
    if (!_tilt) {
      _race.steering =
          (_keys.contains(LogicalKeyboardKey.arrowRight) ? 1.0 : 0) -
          (_keys.contains(LogicalKeyboardKey.arrowLeft) ? 1.0 : 0);
    }
    _race.braking =
        _touchBrake ||
        _keys.contains(LogicalKeyboardKey.arrowDown) ||
        _keys.contains(LogicalKeyboardKey.space);
  }

  Future<void> _toggleTilt() async {
    if (_tilt) {
      _platform.disableTilt();
    } else {
      final enabled = await _platform.enableTilt();
      if (!mounted) return;
      _tilt = enabled;
      _race.motionControl = enabled;
      _hud.value++;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loadingPoll?.cancel();
    _race.removeListener(_onRace);
    if (widget.controller == null) _race.dispose();
    _platform.dispose();
    disposeProofTelemetry();
    _keyboard.dispose();
    _phase.dispose();
    _hud.dispose();
    _ready.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: dark,
    body: KeyboardListener(
      focusNode: _keyboard,
      autofocus: true,
      onKeyEvent: _key,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final portrait = constraints.maxHeight > constraints.maxWidth;
          return Stack(
            fit: StackFit.expand,
            children: [
              _scene,
              ValueListenableBuilder(
                valueListenable: _phase,
                builder: (context, phase, _) =>
                    phase == _ProofPhase.driving && !portrait
                    ? ValueListenableBuilder(
                        valueListenable: _hud,
                        builder: (context, _, _) => WheelControl(
                          visible: !_tilt,
                          onSteer: (value) {
                            if (!_tilt) _race.steering = value;
                          },
                          onBrake: (value) {
                            _touchBrake = value;
                            _race.braking =
                                value ||
                                _keys.contains(LogicalKeyboardKey.arrowDown) ||
                                _keys.contains(LogicalKeyboardKey.space);
                          },
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 16,
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const IgnorePointer(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CANNONBALL',
                                  style: TextStyle(
                                    color: cream,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 24,
                                    letterSpacing: 4,
                                    shadows: [
                                      Shadow(blurRadius: 12, color: dark),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'THE ROAD IN MOTION',
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 9,
                                    letterSpacing: 2.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          ValueListenableBuilder(
                            valueListenable: _hud,
                            builder: (context, _, _) => Row(
                              children: [
                                _utility(
                                  _muted
                                      ? Icons.volume_off_outlined
                                      : Icons.volume_up_outlined,
                                  _muted ? 'Enable sound' : 'Mute sound',
                                  _toggleSound,
                                ),
                                _utility(
                                  Icons.camera_alt_outlined,
                                  'Change camera',
                                  _cycleCamera,
                                ),
                                _utility(
                                  Icons.blur_on,
                                  'Toggle speed effects',
                                  _toggleSpeedEffects,
                                  active: _game?.speedEffects ?? false,
                                ),
                                _utility(
                                  Icons.screen_rotation,
                                  _tilt ? 'Disable tilt' : 'Enable tilt',
                                  _toggleTilt,
                                  active: _tilt,
                                ),
                                _utility(
                                  Icons.closed_caption_outlined,
                                  _captions
                                      ? 'Hide radio captions'
                                      : 'Show radio captions',
                                  () {
                                    _captions = !_captions;
                                    _hud.value++;
                                  },
                                  active: _captions,
                                ),
                                _utility(
                                  Icons.pause,
                                  'Pause test drive',
                                  () => _pause(true),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      ValueListenableBuilder(
                        valueListenable: _hud,
                        builder: (context, _, _) =>
                            _captions && _lastRadio.isNotEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(bottom: 18),
                                child: Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 600,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  color: dark.withValues(alpha: .8),
                                  child: Text(
                                    _lastRadio,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: cream,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      ValueListenableBuilder(
                        valueListenable: _hud,
                        builder: (context, _, _) => IgnorePointer(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _stat(
                                _race.speed.round().toString().padLeft(3, '0'),
                                'MPH',
                              ),
                              const SizedBox(width: 24),
                              _stat(
                                '${(duration - _race.elapsed).clamp(0, duration).ceil()}',
                                'SECONDS LEFT',
                              ),
                              const Spacer(),
                              const Text(
                                'LEFT/RIGHT  STEER     DOWN  BRAKE\nOR DRAG THE RIM',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 9,
                                  height: 1.8,
                                  color: cream,
                                  shadows: [Shadow(blurRadius: 8, color: dark)],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ValueListenableBuilder(
                valueListenable: _phase,
                builder: (context, phase, _) => ValueListenableBuilder(
                  valueListenable: _ready,
                  builder: (context, ready, _) =>
                      (phase == _ProofPhase.ready ||
                              phase == _ProofPhase.departing) &&
                          !portrait
                      ? ValueListenableBuilder(
                          valueListenable: _hud,
                          builder: (context, _, _) => ProofGarage(
                            departing: phase == _ProofPhase.departing,
                            ready: ready,
                            reducedMotion: _platform.reducedMotion,
                            artwork: widget.sceneBuilder == null,
                            muted: _muted,
                            onTakeKeys: _beginDeparture,
                            onComplete: _start,
                            onShot: (shot) {
                              _departureShot = shot;
                              if (shot == 'grasp') _platform.garageCue('keys');
                              if (const [
                                'door',
                                'cabin',
                                'rear',
                                'launch',
                              ].contains(shot)) {
                                _platform.garageCue(shot);
                              }
                            },
                            onSound: _toggleSound,
                          ),
                        )
                      : phase == _ProofPhase.driving && !portrait
                      ? const SizedBox.shrink()
                      : _curtain(context, phase, ready, portrait),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  Widget _utility(
    IconData icon,
    String label,
    VoidCallback action, {
    bool active = false,
  }) => Padding(
    padding: const EdgeInsets.only(left: 6),
    child: Material(
      color: dark.withValues(alpha: .72),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: label,
        onPressed: action,
        icon: Icon(icon, size: 20, color: active ? accent : cream),
      ),
    ),
  );

  Widget _stat(String value, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        value,
        style: const TextStyle(
          fontSize: 29,
          fontWeight: FontWeight.w900,
          color: cream,
          shadows: [Shadow(blurRadius: 10, color: dark)],
        ),
      ),
      Text(
        label,
        style: const TextStyle(fontSize: 8, color: accent, letterSpacing: 1.8),
      ),
    ],
  );

  Widget _curtain(
    BuildContext context,
    _ProofPhase phase,
    bool ready,
    bool portrait,
  ) {
    final complete = phase == _ProofPhase.complete;
    final paused = phase == _ProofPhase.paused;
    return ColoredBox(
      color: dark.withValues(alpha: .48),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 60),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  portrait
                      ? 'TURN THE HORIZON SIDEWAYS'
                      : complete
                      ? 'THE NEXT CITY IS WAITING.'
                      : paused
                      ? 'THE ROAD CAN WAIT.'
                      : 'YOUR KEYS.\nYOUR ROAD.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: cream,
                    fontSize: 34,
                    height: 1.05,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(blurRadius: 20, color: dark)],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  portrait
                      ? 'Rotate to landscape to drive.'
                      : complete
                      ? 'Test drive complete. Take another look at the road.'
                      : paused
                      ? 'Your test drive is paused.'
                      : 'A 90-second drive in your S2000.\nCity light, forest roads, mountain air.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: cream,
                    height: 1.6,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 24),
                if (!portrait)
                  FilledButton(
                    onPressed: ready ? _start : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: dark,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    child: Text(
                      !ready
                          ? 'PREPARING THE ROAD…'
                          : complete
                          ? 'DRIVE IT AGAIN'
                          : paused
                          ? 'BACK TO THE ROAD'
                          : 'START TEST DRIVE',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                const SizedBox(height: 13),
                Text(
                  _artError == null
                      ? 'VISUAL STUDY  ·  NO SCORES OR SAVES'
                      : 'Artwork could not load. Reload to try again.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: cream,
                    fontSize: 8,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
