import 'dart:math' as math;

import 'package:cannonball/app/wheel_input.dart';
import 'package:cannonball/ui/wheel_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Offset> mountWheel(
  WidgetTester tester,
  List<double> steer,
  List<bool> brake, {
  bool visible = true,
  bool travelSteering = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox(
          width: 800,
          height: 400,
          child: WheelControl(
            visible: visible,
            travelSteering: travelSteering,
            onSteer: steer.add,
            onBrake: brake.add,
          ),
        ),
      ),
    ),
  );
  return tester.getTopLeft(find.byType(WheelControl));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    expect(await WheelControl.prepareRimArtwork(), isTrue);
  });
  testWidgets('loaded rim artwork survives repeated painting and remounting', (
    tester,
  ) async {
    final steer = <double>[], brake = <bool>[];
    final origin = await mountWheel(tester, steer, brake);
    final thumb = await tester.startGesture(origin + const Offset(100, 200));
    for (var i = 0; i < 8; i++) {
      await thumb.moveTo(origin + Offset(100, 200 - i * 8));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
    await thumb.up();
    await tester.pumpWidget(const SizedBox());
    await mountWheel(tester, steer, brake);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('rim stays visibly inset and spans landscape height with a generous thumb target', () {
    for (final size in [
      const Size(800, 400),
      const Size(844, 390),
      const Size(1280, 720),
    ]) {
      final g = WheelGeometry(size);
      expect(g.radius, greaterThan(size.height / 2));
      expect(g.center.dx - g.radius, inInclusiveRange(40, 75));
      expect(g.strokeWidth, greaterThanOrEqualTo(40));
      expect(g.onRim(Offset(g.center.dx - g.radius + 45, g.center.dy)), isTrue);
      expect(g.onRim(Offset(size.width - 8, size.height / 2)), isTrue);
      expect(g.inSteeringGuard(g.center), isFalse);
    }
  });
  testWidgets(
    'inner edge near misses do not brake and can slide onto steering',
    (tester) async {
      final steer = <double>[], brake = <bool>[];
      final origin = await mountWheel(tester, steer, brake);
      final thumb = await tester.startGesture(origin + const Offset(140, 200));
      expect(brake, isEmpty);
      await thumb.moveTo(origin + const Offset(100, 200));
      await thumb.moveTo(origin + const Offset(100, 120));
      expect(steer.last, greaterThan(0));
      expect(brake, isEmpty);
      await thumb.up();
      expect(steer.last, 0);
    },
  );
  testWidgets(
    'a protected side touch stays neutral even when dragged toward the brake area',
    (tester) async {
      final steer = <double>[], brake = <bool>[];
      final origin = await mountWheel(tester, steer, brake);
      final touch = await tester.startGesture(origin + const Offset(1, 1));
      await touch.moveTo(origin + const Offset(400, 200));
      await touch.up();
      await tester.pump(const Duration(milliseconds: 160));
      expect(brake, isEmpty);
      expect(steer, isEmpty);
    },
  );

  test('outward leather preserves its opening and encloses every corner', () {
    for (final size in [
      const Size(667, 375),
      const Size(844, 390),
      const Size(1280, 720),
      const Size(1920, 720),
      const Size(1024, 768),
    ]) {
      final g = WheelGeometry(size);
      for (var i = 0; i < 360; i++) {
        final a = i * math.pi / 180;
        final oldInner =
            g.radius -
            g.strokeWidth * .5 -
            math.pow(math.cos(a).abs(), 18) * g.strokeWidth * .04;
        expect(g.innerPaintRadius(a), closeTo(oldInner, 1e-9));
      }
      for (final corner in [
        Offset.zero,
        Offset(size.width, 0),
        Offset(0, size.height),
        Offset(size.width, size.height),
      ]) {
        expect(g.outerPaintRadius, greaterThan((corner - g.center).distance));
      }
      // Painting out to the edges must not turn the opening into a hit target.
      expect(g.onRim(g.center), isFalse);
      expect(g.inSteeringGuard(g.center), isFalse);
    }
  });

  test('travel comparison has the same tangential gain across wheel sizes', () {
    for (final size in [const Size(844, 390), const Size(1280, 720)]) {
      final g = WheelGeometry(size);
      final angleFor40Pixels = 40 / g.radius;
      expect(
        g.steeringDelta(0, angleFor40Pixels, travel: true),
        closeTo(.25, 1e-9),
      );
      expect(
        g.steeringDelta(0, angleFor40Pixels),
        closeTo(angleFor40Pixels / .85, 1e-9),
      );
      expect(
        g.steeringDelta(angleFor40Pixels, 0, travel: true),
        closeTo(-.25, 1e-9),
      );
    }
  });

  testWidgets(
    'travel comparison is opt-in and cancellation releases steering',
    (tester) async {
      final steer = <double>[], brake = <bool>[];
      final origin = await mountWheel(
        tester,
        steer,
        brake,
        travelSteering: true,
      );
      final g = WheelGeometry(const Size(800, 400));
      final touch = await tester.startGesture(origin + const Offset(750, 200));
      await touch.moveTo(origin + const Offset(750, 240));
      expect(
        steer.last,
        closeTo(g.steeringDelta(0, math.atan2(40, 350), travel: true), 1e-6),
      );
      expect(brake, isEmpty);
      await touch.cancel();
      expect(steer.last, 0);
    },
  );

  test('angular wrap takes the short path across the left rim', () {
    expect(
      WheelGeometry.angleDelta(math.pi - .1, -math.pi + .1),
      closeTo(.2, 1e-9),
    );
    expect(
      WheelGeometry.angleDelta(-math.pi + .1, math.pi - .1),
      closeTo(-.2, 1e-9),
    );
  });
  testWidgets('right edge down and left edge up both steer clockwise/right', (
    tester,
  ) async {
    final steer = <double>[], brake = <bool>[];
    final origin = await mountWheel(tester, steer, brake);
    final right = await tester.startGesture(
      origin + const Offset(790, 150),
      pointer: 1,
    );
    await right.moveTo(origin + const Offset(790, 250));
    expect(steer.last, greaterThan(0));
    await right.up();
    expect(steer.last, 0);
    final left = await tester.startGesture(
      origin + const Offset(10, 250),
      pointer: 2,
    );
    await left.moveTo(origin + const Offset(10, 150));
    expect(steer.last, greaterThan(0));
    await left.up();
    expect(brake, isEmpty);
  });
  testWidgets('right edge up steers left, with return to center on release', (
    tester,
  ) async {
    final steer = <double>[], brake = <bool>[];
    final origin = await mountWheel(tester, steer, brake);
    final gesture = await tester.startGesture(origin + const Offset(790, 250));
    await gesture.moveTo(origin + const Offset(790, 150));
    expect(steer.last, lessThan(0));
    await gesture.up();
    expect(steer.last, 0);
  });
  testWidgets(
    'releasing steering leaves an independent brake pointer pressed',
    (tester) async {
      final steer = <double>[], brake = <bool>[];
      final origin = await mountWheel(tester, steer, brake);
      final wheel = await tester.startGesture(
        origin + const Offset(790, 150),
        pointer: 1,
      );
      final pedal = await tester.startGesture(
        origin + const Offset(400, 200),
        pointer: 2,
      );
      await wheel.moveTo(origin + const Offset(790, 250));
      expect(steer.last, greaterThan(0));
      expect(brake.last, isTrue);
      await wheel.up();
      await tester.pump(const Duration(milliseconds: 200));
      expect(brake.last, isTrue);
      await pedal.up();
      await tester.pump(const Duration(milliseconds: 140));
      expect(brake.last, isFalse);
    },
  );
  testWidgets(
    'releasing brake preserves steering and a tap has a short brake pulse',
    (tester) async {
      final steer = <double>[], brake = <bool>[];
      final origin = await mountWheel(tester, steer, brake);
      final wheel = await tester.startGesture(
        origin + const Offset(790, 150),
        pointer: 1,
      );
      await wheel.moveTo(origin + const Offset(790, 250));
      final value = steer.last;
      final pedal = await tester.startGesture(
        origin + const Offset(400, 200),
        pointer: 2,
      );
      await pedal.up();
      expect(brake.last, isTrue);
      expect(steer.last, value);
      await tester.pump(const Duration(milliseconds: 140));
      expect(brake.last, isFalse);
      expect(steer.last, value);
      await wheel.up();
    },
  );
  testWidgets('lifting one of two steering fingers does not jump the wheel', (
    tester,
  ) async {
    final steer = <double>[], brake = <bool>[];
    final origin = await mountWheel(tester, steer, brake);
    final right = await tester.startGesture(
      origin + const Offset(790, 150),
      pointer: 1,
    );
    await right.moveTo(origin + const Offset(790, 250));
    final left = await tester.startGesture(
      origin + const Offset(10, 250),
      pointer: 2,
    );
    await left.moveTo(origin + const Offset(10, 180));
    final value = steer.last;
    await left.up();
    expect(steer.last, value);
    await right.moveTo(origin + const Offset(790, 251));
    expect(steer.last, closeTo(value, .01));
    await right.up();
  });
  testWidgets('hidden tilt wheel retains outside-touch braking', (
    tester,
  ) async {
    final steer = <double>[], brake = <bool>[];
    final origin = await mountWheel(tester, steer, brake, visible: false);
    final touch = await tester.startGesture(origin + const Offset(790, 150));
    await touch.moveTo(origin + const Offset(790, 250));
    expect(brake.last, isTrue);
    expect(steer, isEmpty);
    await touch.cancel();
    await tester.pump(const Duration(milliseconds: 140));
    expect(brake.last, isFalse);
  });
}
