import 'dart:math' as math;

import 'package:cannonball/app/wheel_input.dart';
import 'package:cannonball/game/race.dart';
import 'package:cannonball/ui/visual_proof.dart';
import 'package:cannonball/ui/wheel_control.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('braking with the Down key keeps the mouse rim steering', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final race = RaceController();
    addTearDown(race.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: VisualProofScreen(
          controller: race,
          sceneBuilder: (_) => const ColoredBox(color: Color(0xff25453f)),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('take-keys')));
    await tester.pump();
    await tester.tap(find.byTooltip('Skip departure'));
    await tester.pump();

    final wheel = find.byType(WheelControl);
    final origin = tester.getTopLeft(wheel);
    final g = WheelGeometry(tester.getSize(wheel));
    Offset rim(double angle) =>
        origin + g.center + Offset(math.cos(angle), math.sin(angle)) * g.radius;
    final mouse = await tester.startGesture(
      rim(math.pi),
      kind: PointerDeviceKind.mouse,
    );
    await mouse.moveTo(rim(math.pi + .2));
    final held = race.steering;
    expect(held, closeTo(.2 / WheelGeometry.mouseFullLock, 1e-3));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    expect(race.braking, isTrue);
    expect(race.steering, held, reason: 'brake key leaves the rim alone');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
    expect(race.braking, isFalse);
    expect(race.steering, held);

    // Arrow keys still take over steering.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    expect(race.steering, -1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    expect(race.steering, 0);
    await mouse.up();
  });
}
