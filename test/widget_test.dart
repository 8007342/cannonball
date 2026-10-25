import 'dart:ui';

import 'package:cannonball/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'foundation appears in landscape and requests rotation in portrait',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const CannonballApp());
      await tester.pump();
      expect(find.text('CANNONBALL'), findsOneWidget);
      tester.view.physicalSize = const Size(720, 1280);
      await tester.pump();
      expect(find.text('Rotate your device to landscape'), findsOneWidget);
      expect(find.text('CANNONBALL'), findsNothing);
    },
  );
}
