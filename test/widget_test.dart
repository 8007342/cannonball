import 'package:flutter/widgets.dart';

import 'package:cannonball/app/session.dart';
import 'package:cannonball/main.dart';
import 'package:cannonball/services/api_client.dart';
import 'package:cannonball/services/local_store.dart';
import 'package:cannonball/ui/wheel_control.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

GameSession session() => GameSession(
  api: ApiClient(
    client: MockClient((_) async => http.Response('{"error":"offline"}', 503)),
    base: Uri.parse('https://test.invalid'),
  ),
  store: LocalStore()..write('cannonball.guest.v1', '{"unlocks":["wagon"]}'),
);

void main() {
  testWidgets('garage fits landscape phone and portrait requests rotation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = session();
    await tester.pumpWidget(CannonballApp(session: state));
    await tester.pump();
    expect(find.text('CANNONBALL'), findsOneWidget);
    expect(find.text('THE KEY BOX'), findsOneWidget);
    expect(find.text('UNDISCOVERED'), findsNWidgets(5));
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pump();
    expect(find.text('Cannonball plays in landscape.'), findsOneWidget);
    expect(find.text('CANNONBALL'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
  testWidgets('guest can start and pause without an API', (tester) async {
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = session();
    await tester.pumpWidget(CannonballApp(session: state));
    await tester.pump();
    await tester.tap(find.textContaining('TAKE THE KEYS'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(state.screen, AppScreen.racing);
    expect(find.byType(WheelControl), findsOneWidget);
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(state.race.paused, isTrue);
    expect(find.text('TAKE A BREATHER'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
  testWidgets('timeout reaches recorded map recap without cloud services', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = session();
    await tester.pumpWidget(CannonballApp(session: state));
    await tester.pump();
    await state.start();
    state.race.braking = true;
    for (var i = 0; i < 3000 && !state.race.finished; i++) {
      state.race.tick(1 / 30);
    }
    await tester.pump();
    expect(state.race.completed, isFalse);
    expect(state.screen, AppScreen.recap);
    expect(find.text('EVERY ROAD TEACHES YOU SOMETHING.'), findsOneWidget);
    expect(find.text('THE KEY BOX'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
  test('time display preserves hundredths and minutes', () {
    expect(formatTime(654321), '10:54.32');
  });
}
