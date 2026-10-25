import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/session.dart';
import 'game/race.dart';
import 'ui/google_button.dart';
import 'ui/painters.dart';
import 'ui/wheel_control.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CannonballApp());
}

class CannonballApp extends StatelessWidget {
  const CannonballApp({super.key, this.session});
  final GameSession? session;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Cannonball',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: gold,
        brightness: Brightness.dark,
        surface: ink,
      ),
      scaffoldBackgroundColor: ink,
      fontFamily: 'Cannonball',
      useMaterial3: true,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: ink,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        ),
      ),
    ),
    home: GameShell(session: session),
  );
}

class GameShell extends StatefulWidget {
  const GameShell({super.key, this.session});
  final GameSession? session;
  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> with WidgetsBindingObserver {
  late final GameSession s;
  final FocusNode _keyboard = FocusNode();
  final Set<LogicalKeyboardKey> _keys = {};
  RaceGame? _game;
  int _gameSerial = -1;
  bool _touchBrake = false;
  @override
  void initState() {
    super.initState();
    s = widget.session ?? GameSession();
    WidgetsBinding.instance.addObserver(this);
    s.platform.initialize(
      onTilt: (value) {
        if (s.tilt && !s.race.paused) {
          s.race.steering = value;
        }
      },
      onVisibility: (hidden) {
        if (hidden && s.screen == AppScreen.racing) {
          _resetInput();
          s.pause(true);
        }
      },
      onOrientation: (landscape) {
        if (!landscape && s.screen == AppScreen.racing) {
          _resetInput();
          s.pause(true);
        }
      },
      onTiltStatus: s.setTiltEnabled,
    );
    s.platform.muted = s.muted;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keyboard.dispose();
    if (widget.session == null) {
      s.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && s.screen == AppScreen.racing) {
      _resetInput();
      s.pause(true);
    }
  }

  void _resetInput() {
    _keys.clear();
    _touchBrake = false;
    s.race.steering = 0;
    s.race.braking = false;
  }

  void _key(KeyEvent e) {
    if (s.screen != AppScreen.racing || s.finishing) {
      return;
    }
    if (e is KeyUpEvent) {
      _keys.remove(e.logicalKey);
    } else {
      _keys.add(e.logicalKey);
    }
    if (e is KeyDownEvent &&
        (e.logicalKey == LogicalKeyboardKey.escape ||
            e.logicalKey == LogicalKeyboardKey.keyP)) {
      _resetInput();
      s.pause(!s.race.paused);
      return;
    }
    if (s.race.paused) {
      return;
    }
    final left =
        _keys.contains(LogicalKeyboardKey.arrowLeft) ||
        _keys.contains(LogicalKeyboardKey.keyA);
    final right =
        _keys.contains(LogicalKeyboardKey.arrowRight) ||
        _keys.contains(LogicalKeyboardKey.keyD);
    if (!s.tilt) {
      s.race.steering = (right ? 1.0 : 0) - (left ? 1.0 : 0);
    }
    s.race.braking =
        _touchBrake ||
        _keys.contains(LogicalKeyboardKey.arrowDown) ||
        _keys.contains(LogicalKeyboardKey.space);
  }

  Future<void> _start() async {
    _resetInput();
    await s.start();
    if (mounted) {
      _keyboard.requestFocus();
    }
  }

  Future<void> _profile() async {
    if (s.screen == AppScreen.racing) {
      _resetInput();
      s.pause(true);
    }
    await showDialog<void>(
      context: context,
      builder: (context) => _ProfileDialog(session: s),
    );
  }

  @override
  Widget build(BuildContext context) => KeyboardListener(
    focusNode: _keyboard,
    autofocus: true,
    onKeyEvent: _key,
    child: AnimatedBuilder(
      animation: s,
      builder: (context, _) {
        return Scaffold(
          body: LayoutBuilder(
            builder: (context, c) {
              if (c.maxHeight > c.maxWidth) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.screen_rotation, size: 42, color: gold),
                      SizedBox(height: 20),
                      Text('TURN THE HORIZON SIDEWAYS'),
                      SizedBox(height: 8),
                      Text(
                        'Cannonball plays in landscape.',
                        style: TextStyle(color: mutedInk),
                      ),
                    ],
                  ),
                );
              }
              return switch (s.screen) {
                AppScreen.garage => _garage(c),
                AppScreen.racing => _race(),
                AppScreen.initials => _initials(),
                AppScreen.recap => _recap(),
                AppScreen.hall => _hall(),
              };
            },
          ),
        );
      },
    ),
  );
  Widget _garage(BoxConstraints c) {
    final compact = c.maxHeight < 440;
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: GarageWood())),
        SafeArea(
          child: Padding(
            padding: EdgeInsets.all(compact ? 16 : 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'A COAST-TO-COAST ARCADE ROAD TRIP',
                            style: TextStyle(
                              color: gold,
                              fontSize: 10,
                              letterSpacing: 2,
                            ),
                          ),
                          Text(
                            'CANNONBALL',
                            style: TextStyle(
                              fontSize: compact ? 30 : 46,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 5,
                              color: const Color(0xFFF6E5C8),
                            ),
                          ),
                          const Text(
                            'RED BALL GARAGE, NY  >  REDONDO BEACH, CA',
                            style: TextStyle(fontSize: 10, color: mutedInk),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Hall of Fame',
                      onPressed: s.showHall,
                      icon: const Icon(Icons.leaderboard_outlined, color: gold),
                    ),
                    IconButton(
                      tooltip: 'Profile and cloud saves',
                      onPressed: _profile,
                      icon: Icon(
                        s.accountId == null
                            ? Icons.person_outline
                            : Icons.cloud_done_outlined,
                        color: gold,
                      ),
                    ),
                    IconButton(
                      tooltip: s.muted ? 'Unmute' : 'Mute',
                      onPressed: s.toggleMute,
                      icon: Icon(
                        s.muted ? Icons.volume_off : Icons.volume_up_outlined,
                        color: mutedInk,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 10 : 22),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .24),
                            border: Border.all(
                              color: gold.withValues(alpha: .22),
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          padding: EdgeInsets.all(compact ? 10 : 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'THE KEY BOX',
                                style: TextStyle(
                                  color: gold,
                                  fontSize: 11,
                                  letterSpacing: 3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${s.unlocked.length.toString().padLeft(2, '0')} / ${cars.length} RIDES DISCOVERED',
                                style: const TextStyle(
                                  color: mutedInk,
                                  fontSize: 9,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, box) => GridView.count(
                                    crossAxisCount: 3,
                                    childAspectRatio: box.maxHeight < 155
                                        ? 1.45
                                        : 1.15,
                                    mainAxisSpacing: 6,
                                    crossAxisSpacing: 6,
                                    children: cars.map(_keyTile).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: compact ? 18 : 32),
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.selected.name.toUpperCase(),
                              style: TextStyle(
                                fontSize: compact ? 19 : 25,
                                fontWeight: FontWeight.bold,
                                color: gold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s.selected.description,
                              style: const TextStyle(
                                fontSize: 11,
                                color: mutedInk,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Expanded(
                              child: CustomPaint(
                                painter: CarPreview(s.selected),
                                child: const SizedBox.expand(),
                              ),
                            ),
                            Row(
                              children: [
                                _smallStat(
                                  'TOP SPEED',
                                  '${s.selected.topSpeed.round()} MPH',
                                ),
                                const SizedBox(width: 24),
                                _smallStat('JOURNEY', '10–15 MIN'),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton(
                                    onPressed: s.busy ? null : _start,
                                    child: Text(
                                      s.busy
                                          ? 'GETTING THE KEYS…'
                                          : 'TAKE THE KEYS  >',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: 'Controls',
                                  onPressed: _instructions,
                                  icon: const Icon(
                                    Icons.help_outline,
                                    color: mutedInk,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  s.cloudStatus,
                  style: const TextStyle(color: mutedInk, fontSize: 9),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _keyTile(CarSpec car) {
    final owned = s.unlocked.contains(car.id),
        selected = s.selected.id == car.id;
    return Semantics(
      button: true,
      label: owned ? 'Select ${car.name}' : 'Locked ${car.name}',
      child: InkWell(
        onTap: owned ? () => s.select(car) : () => _locked(car),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          decoration: BoxDecoration(
            color: selected ? gold.withValues(alpha: .09) : Colors.black12,
            border: Border.all(
              color: selected ? gold.withValues(alpha: .65) : Colors.white10,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: [
              Expanded(
                child: CustomPaint(
                  painter: KeyArt(
                    color: Color(car.color),
                    locked: !owned,
                    selected: selected,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
                child: Text(
                  owned ? car.name.toUpperCase() : 'UNDISCOVERED',
                  style: TextStyle(
                    color: owned ? gold : Colors.white24,
                    fontSize: 8,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _smallStat(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: mutedInk, fontSize: 9, letterSpacing: 1),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        style: const TextStyle(
          color: gold,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );
  Future<void> _locked(CarSpec car) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(car.name),
      content: Text(car.unlockHint),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('BACK TO THE BOX'),
        ),
      ],
    ),
  );
  Future<void> _instructions() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('KEEP THE HORIZON MOVING'),
      content: const SingleChildScrollView(
        child: Text(
          'Acceleration is automatic.\n\nDrag the translucent rim like a steering wheel. Right edge down or left edge up turns right. Tap outside the rim to brake; hold to brake longer.\n\nDesktop: Left/Right steer, Down or Space brakes, P pauses.\n\nTilt is optional. Gates add time. Road signs, cones and the radio warn of changing conditions. Follow a different road: you might find a different key.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('GOT IT'),
        ),
      ],
    ),
  );
  Widget _race() {
    if (_gameSerial != s.runSerial) {
      _game = RaceGame(controller: s.race);
      _gameSerial = s.runSerial;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        GameWidget(game: _game!),
        if (!s.race.paused && !s.finishing)
          WheelControl(
            key: ValueKey(s.runSerial),
            visible: !s.tilt,
            onSteer: (value) {
              if (!s.tilt) {
                s.race.steering = value;
              }
            },
            onBrake: (value) {
              _touchBrake = value;
              s.race.braking =
                  value ||
                  _keys.contains(LogicalKeyboardKey.arrowDown) ||
                  _keys.contains(LogicalKeyboardKey.space);
            },
          ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: ink.withValues(alpha: .74),
                          border: const Border(
                            left: BorderSide(color: gold, width: 3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _smallStat(
                              'TIME LEFT',
                              s.race.remaining.toStringAsFixed(1),
                            ),
                            const SizedBox(width: 22),
                            _smallStat('MPH', '${s.race.speed.round()}'),
                            const SizedBox(width: 22),
                            _smallStat(
                              'TOTAL',
                              formatTime((s.race.elapsed * 1000).round()),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    _utility(
                      Icons.screen_rotation,
                      s.tilt ? 'Disable tilt' : 'Enable tilt',
                      s.toggleTilt,
                      active: s.tilt,
                    ),
                    _utility(
                      s.muted ? Icons.volume_off : Icons.volume_up,
                      'Mute',
                      s.toggleMute,
                    ),
                    _utility(
                      s.steadyHorizon ? Icons.horizontal_rule : Icons.waves,
                      'Steady horizon',
                      () {
                        s.toggleHorizon();
                      },
                      active: s.steadyHorizon,
                    ),
                    _utility(Icons.person_outline, 'Profile', _profile),
                    _utility(Icons.pause, 'Pause', () {
                      _resetInput();
                      s.pause(true);
                    }),
                  ],
                ),
                const Spacer(),
                IgnorePointer(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 760),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: ink.withValues(alpha: .75),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            s.race.stageName.toUpperCase(),
                            style: const TextStyle(
                              color: gold,
                              fontSize: 10,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s.race.radio,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          LinearProgressIndicator(
                            value: s.race.progress,
                            color: gold,
                            backgroundColor: Colors.white12,
                            minHeight: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (s.race.paused && !s.finishing && !s.race.finished)
          Container(
            color: ink.withValues(alpha: .82),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'TAKE A BREATHER',
                    style: TextStyle(
                      fontSize: 28,
                      color: gold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your run is paused.',
                    style: TextStyle(color: mutedInk),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      _resetInput();
                      unawaited(s.platform.beginAudio());
                      s.pause(false);
                      _keyboard.requestFocus();
                    },
                    child: const Text('BACK TO THE ROAD'),
                  ),
                  TextButton(
                    onPressed: s.garage,
                    child: const Text('RETURN TO GARAGE'),
                  ),
                ],
              ),
            ),
          ),
        if (s.finishing)
          Container(
            color: ink.withValues(alpha: .8),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'END OF THE ROAD',
                    style: TextStyle(fontSize: 26, color: gold),
                  ),
                  SizedBox(height: 18),
                  CircularProgressIndicator(color: gold),
                  SizedBox(height: 14),
                  Text('Recording this journey…'),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _utility(
    IconData icon,
    String label,
    VoidCallback action, {
    bool active = false,
  }) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Material(
      color: ink.withValues(alpha: .55),
      borderRadius: BorderRadius.circular(25),
      child: IconButton(
        tooltip: label,
        onPressed: action,
        icon: Icon(icon, color: active ? gold : Colors.white70, size: 20),
      ),
    ),
  );
  String _rankingSummary() {
    final receipt = s.rankingReceipt ?? s.race.receipt?.toJson();
    if (receipt == null) {
      return 'Your coast-to-coast result';
    }
    final carId = receipt['carId'];
    final car = cars.where((car) => car.id == carId).firstOrNull;
    return '${formatTime((receipt['elapsedMs'] as num).toInt())} | '
        '${(receipt['distanceMiles'] as num).round()} MI | '
        '${car?.name ?? carId}';
  }

  Widget _initials() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'YOU MADE THE TOP 100',
            style: TextStyle(color: gold, fontSize: 12, letterSpacing: 3),
          ),
          const SizedBox(height: 8),
          const Text(
            'LEAVE YOUR MARK',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 30),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (i) => SizedBox(
                width: 76,
                height: 120,
                child: ListWheelScrollView.useDelegate(
                  itemExtent: 42,
                  perspective: .002,
                  diameterRatio: 1.8,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (index) =>
                      s.initials[i] = String.fromCharCode(65 + index % 26),
                  childDelegate: ListWheelChildLoopingListDelegate(
                    children: List.generate(
                      26,
                      (j) => Center(
                        child: Text(
                          String.fromCharCode(65 + j),
                          style: const TextStyle(
                            fontSize: 32,
                            color: gold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(_rankingSummary(), style: const TextStyle(color: mutedInk)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: s.busy ? null : s.submitInitials,
            child: Text(s.busy ? 'SAVING…' : 'PUT IT ON THE BOARD'),
          ),
          const SizedBox(height: 8),
          Text(
            s.cloudStatus,
            style: const TextStyle(fontSize: 10, color: mutedInk),
          ),
          TextButton(
            onPressed: s.skipInitials,
            child: const Text('CONTINUE WITHOUT ENTRY'),
          ),
        ],
      ),
    ),
  );
  Widget _recap() => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.race.completed
                          ? 'PACIFIC, AT LAST.'
                          : 'EVERY ROAD TEACHES YOU SOMETHING.',
                      style: const TextStyle(
                        fontSize: 21,
                        color: gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${formatTime((s.race.elapsed * 1000).round())}  ·  ${s.race.distanceMiles.round()} MILES  ·  ${s.race.car.name.toUpperCase()}',
                      style: const TextStyle(fontSize: 10, color: mutedInk),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: s.showHall, child: const Text('TOP 100')),
            ],
          ),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(seconds: 4),
              builder: (context, value, _) => CustomPaint(
                painter: RouteMapPainter(
                  route: ((s.race.receipt?.toJson()['route'] as List?) ?? [])
                      .map((e) => Map<String, dynamic>.from(e as Map))
                      .toList(),
                  fill: value,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          if (s.race.earnedUnlockIds.isNotEmpty)
            Text(
              'NEW KEYS: ${s.race.earnedUnlockIds.map((id) => cars.firstWhere((c) => c.id == id).name).join(' · ')}',
              style: const TextStyle(color: gold, fontSize: 11),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  s.cloudStatus,
                  style: const TextStyle(fontSize: 10, color: mutedInk),
                  maxLines: 2,
                ),
              ),
              TextButton(onPressed: s.garage, child: const Text('THE KEY BOX')),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _start,
                child: const Text('ONE MORE RUN  >'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  Widget _hall() => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'HALL OF FAME',
                  style: TextStyle(
                    fontSize: 27,
                    color: gold,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
              ),
              TextButton(
                onPressed: s.garage,
                child: const Text('BACK TO GARAGE'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'DIFFERENT ROADS. DIFFERENT RIDES. ONE CLOCK.',
            style: TextStyle(fontSize: 10, color: mutedInk, letterSpacing: 1),
          ),
          const Divider(color: Colors.white12, height: 26),
          Expanded(
            child: s.busy
                ? const Center(child: CircularProgressIndicator(color: gold))
                : s.hall.isEmpty
                ? Center(
                    child: Text(
                      s.cloudStatus,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: mutedInk),
                    ),
                  )
                : ListView.builder(
                    itemCount: s.hall.length,
                    itemBuilder: (context, i) {
                      final row = s.hall[i];
                      final car = cars
                          .where((c) => c.id == row['carId'])
                          .firstOrNull;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 14,
                        ),
                        color: i.isEven
                            ? Colors.white.withValues(alpha: .035)
                            : Colors.transparent,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 46,
                              child: Text(
                                '${i + 1}'.padLeft(2, '0'),
                                style: const TextStyle(color: mutedInk),
                              ),
                            ),
                            SizedBox(
                              width: 80,
                              child: Text(
                                '${row['initials']}',
                                style: const TextStyle(
                                  color: gold,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 4,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                car?.name ?? '${row['carId']}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            Text(
                              formatTime((row['elapsedMs'] as num).toInt()),
                              style: const TextStyle(
                                color: gold,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Text(
            s.cloudStatus,
            style: const TextStyle(color: mutedInk, fontSize: 9),
          ),
        ],
      ),
    ),
  );
}

String formatTime(int ms) {
  final seconds = ms ~/ 1000;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}.${((ms % 1000) ~/ 10).toString().padLeft(2, '0')}';
}

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({required this.session});
  final GameSession session;
  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  String? nonce, error;
  bool waiting = false;
  @override
  void initState() {
    super.initState();
    widget.session.addListener(_refresh);
    unawaited(_prepare());
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _prepare() async {
    final value = await widget.session.challenge();
    if (mounted) {
      setState(() => nonce = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return AlertDialog(
      title: Text(
        s.accountId == null ? 'TAKE YOUR KEYS WITH YOU' : 'YOUR GARAGE',
      ),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.accountId == null
                  ? 'Play now as a guest, or sign in to save verified discoveries across devices and record global times.'
                  : 'Google account connected. Your public Hall of Fame identity is only three initials.',
              style: const TextStyle(color: mutedInk, fontSize: 12),
            ),
            const SizedBox(height: 18),
            if (s.accountId == null && s.clientId != null && nonce != null)
              GoogleButton(
                key: ValueKey(nonce),
                clientId: s.clientId!,
                nonce: nonce!,
                onCredential: (value) async {
                  setState(() => waiting = true);
                  final success = await s.signIn(value);
                  if (!mounted || !context.mounted) {
                    return;
                  }
                  if (success) {
                    Navigator.pop(context);
                  } else {
                    setState(() {
                      waiting = false;
                      error = s.cloudStatus;
                      nonce = null;
                    });
                    unawaited(_prepare());
                  }
                },
                onError: (value) {
                  if (mounted) {
                    setState(() => error = value);
                  }
                },
              )
            else if (s.accountId == null)
              Text(
                s.cloudAvailable
                    ? 'Preparing sign-in…'
                    : 'Cloud sign-in is unavailable here. Guest play is ready.',
                style: const TextStyle(color: gold, fontSize: 12),
              ),
            if (waiting) const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              error ?? s.cloudStatus,
              style: const TextStyle(color: mutedInk, fontSize: 10),
            ),
            const SizedBox(height: 10),
            const Text(
              'Google names and emails never appear on the public board.',
              style: TextStyle(color: mutedInk, fontSize: 10),
            ),
          ],
        ),
      ),
      actions: [
        if (s.accountId != null)
          TextButton(
            onPressed: () async {
              await s.signOut();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('SIGN OUT'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('BACK'),
        ),
      ],
    );
  }
}
