import 'package:cannonball/ui/departure_timeline.dart';
import 'package:cannonball/ui/proof_garage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pickup has reach, grasp and withdrawal before the camera turns', () {
    expect(DepartureTimeline.shot(.03), 'reach');
    expect(DepartureTimeline.shot(.10), 'grasp');
    expect(DepartureTimeline.shot(.17), 'pickup');
    expect(DepartureTimeline.shot(.30), 'reveal');
    expect(DepartureTimeline.handFrame(.1), 0);
    expect(DepartureTimeline.handFrame(.45), 1);
    expect(DepartureTimeline.handFrame(.65), 2);
    expect(DepartureTimeline.handFrame(.9), 3);
  });

  test('matched rear reveals live game without a black final frame', () {
    expect(DepartureTimeline.shot(.87), 'rear');
    expect(DepartureTimeline.shot(.97), 'launch');
    expect(DepartureTimeline.overlayOpacity(.92), 1);
    var previous = 1.0;
    for (var i = 93; i <= 100; i++) {
      final opacity = DepartureTimeline.overlayOpacity(i / 100);
      expect(opacity, inInclusiveRange(0, previous));
      previous = opacity;
    }
    expect(DepartureTimeline.overlayOpacity(1), 0);
  });

  test('long forearm leaves the screen while fingers meet the key hook', () {
    for (final size in [
      const Size(1280, 577),
      const Size(844, 390),
      const Size(1920, 1080),
    ]) {
      final bounds = GarageHandPlacement.bounds(
        size,
        reach: 1,
        withdrawal: 0,
        reducedMotion: false,
      );
      final finger =
          bounds.topLeft +
          Offset(
            bounds.width * GarageHandPlacement.contact.dx,
            bounds.height * GarageHandPlacement.contact.dy,
          );
      expect(finger.dx, closeTo(GarageHandPlacement.hook(size).dx, .001));
      expect(finger.dy, closeTo(GarageHandPlacement.hook(size).dy, .001));
      expect(
        bounds.bottom,
        greaterThan(size.height),
        reason: 'source wrist edge must be offscreen',
      );
    }
  });

  testWidgets('departure emits ordered beats and completes only once', (
    tester,
  ) async {
    final shots = <String>[];
    var completed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ProofGarage(
          departing: true,
          ready: true,
          reducedMotion: false,
          muted: true,
          artwork: false,
          onTakeKeys: () {},
          onComplete: () => completed++,
          onShot: shots.add,
          onSound: () {},
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(shots, [
      'reach',
      'grasp',
      'pickup',
      'reveal',
      'walk',
      'door',
      'cabin',
      'rear',
      'launch',
    ]);
    expect(completed, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(completed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide cabin keeps image proportions at a landscape viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ProofGarage(
          departing: true,
          ready: true,
          reducedMotion: false,
          muted: true,
          onTakeKeys: () {},
          onComplete: () {},
          onShot: (_) {},
          onSound: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 5700));
    final pictures = tester
        .widgetList<Image>(find.byType(Image))
        .where(
          (image) =>
              image.image is AssetImage &&
              (image.image as AssetImage).assetName.endsWith('/cabin.png'),
        );
    expect(pictures, isNotEmpty);
    expect(pictures.every((image) => image.fit == BoxFit.cover), isTrue);
    expect(tester.takeException(), isNull);
  });
}
