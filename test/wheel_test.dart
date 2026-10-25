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
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox(
          width: 800,
          height: 400,
          child: WheelControl(
            visible: visible,
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
