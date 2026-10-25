import 'package:cannonball/game/race.dart';
import 'package:cannonball/ui/visual_proof.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> startProof(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('take-keys')));
  await tester.pump();
  await tester.tap(find.byTooltip('Skip departure'));
  await tester.pump();
}

Future<RaceController> mountProof(
  WidgetTester tester, {
  VoidCallback? onSceneBuild,
}) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final controller = RaceController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: VisualProofScreen(
        controller: controller,
        sceneBuilder: (_) => Builder(
          builder: (context) {
            onSceneBuild?.call();
            return const ColoredBox(color: Color(0xff25453f));
          },
        ),
      ),
    ),
  );
  return controller;
}

void main() {
  testWidgets('proof starts paused with the seeded S2000 keys in the garage', (
    tester,
  ) async {
    final race = await mountProof(tester);
    expect(race.car.id, 's2000');
    expect(race.seed, 731);
    expect(race.paused, isTrue);
    expect(find.byKey(const ValueKey('take-keys')), findsOneWidget);
    expect(find.byTooltip('Take the S2000 keys'), findsOneWidget);
    expect(find.text('THE KEY BOX'), findsNothing);
    expect(race.elapsed, 0);
    expect(race.speed, 110);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'departure holds race clock until the painted sequence finishes',
    (tester) async {
      final race = await mountProof(tester);
      await tester.tap(find.byKey(const ValueKey('take-keys')));
      await tester.pump();
      expect(find.byTooltip('Skip departure'), findsOneWidget);
      race.tick(.2);
      expect(race.elapsed, 0);
      expect(race.paused, isTrue);
      await tester.pump(const Duration(seconds: 8));
      expect(race.paused, isFalse);
      expect(find.byTooltip('Skip departure'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('HUD changes do not rebuild the cached scene', (tester) async {
    var builds = 0;
    final race = await mountProof(tester, onSceneBuild: () => builds++);
    expect(builds, 1);
    await startProof(tester);
    for (var i = 0; i < 20; i++) {
      race.tick(.05);
      await tester.pump();
    }
    expect(race.elapsed, greaterThan(.9));
    expect(race.speed, greaterThan(0));
    expect(builds, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keyboard steering and braking remain independent and pause clears them',
    (tester) async {
      final race = await mountProof(tester);
      await startProof(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
      expect(race.steering, 1);
      expect(race.braking, isTrue);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
      expect(race.steering, 1);
      expect(race.braking, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.pump();
      expect(race.paused, isTrue);
      expect(race.steering, 0);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      expect(find.text('BACK TO THE ROAD'), findsOneWidget);
    },
  );

  testWidgets(
    'focus loss alone keeps moving; hidden lifecycle needs explicit resume',
    (tester) async {
      final race = await mountProof(tester);
      await startProof(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      expect(race.paused, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      expect(race.paused, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(race.paused, isTrue);
      await tester.tap(find.text('BACK TO THE ROAD'));
      await tester.pump();
      expect(race.paused, isFalse);
    },
  );

  testWidgets(
    'the 120-second study stops and retry resets its clock and seed',
    (tester) async {
      final race = await mountProof(tester);
      await startProof(tester);
      race.braking = true;
      for (var i = 0; i < 485; i++) {
        race.tick(.25);
      }
      await tester.pump();
      expect(race.elapsed, closeTo(120, .26));
      expect(race.paused, isTrue);
      expect(find.text('DRIVE IT AGAIN'), findsOneWidget);
      await tester.tap(find.text('DRIVE IT AGAIN'));
      await tester.pump();
      expect(race.elapsed, 0);
      expect(race.paused, isFalse);
      expect(race.seed, 731);
      expect(race.car.id, 's2000');
    },
  );

  testWidgets('portrait viewport provides a rotate prompt before driving', (
    tester,
  ) async {
    final race = await mountProof(tester);
    tester.view.physicalSize = const Size(720, 1280);
    await tester.pump();
    expect(find.text('Rotate to landscape to drive.'), findsOneWidget);
    expect(find.byKey(const ValueKey('take-keys')), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(race.paused, isTrue);
    expect(tester.takeException(), isNull);
  });
}
