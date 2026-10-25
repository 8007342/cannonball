import 'dart:async';
import 'dart:convert';

import 'package:cannonball/app/session.dart';
import 'package:cannonball/game/race.dart';
import 'package:cannonball/services/api_client.dart';
import 'package:cannonball/services/local_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class MemoryStore extends LocalStore {
  final Map<String, String> values = {};
  @override
  String? read(String key) => values[key];
  @override
  void write(String key, String value) => values[key] = value;
  void unlocks(String owner, List<String> ids) =>
      write('cannonball.$owner.v1', jsonEncode({'unlocks': ids}));
  Set<String> saved(String owner) => Set<String>.from(
    (jsonDecode(read('cannonball.$owner.v1')!) as Map)['unlocks'] as List,
  );
  List<dynamic> pending(String owner) =>
      jsonDecode(read('cannonball.pending.$owner.v1') ?? '[]') as List;
}

http.Response json(Object? body, [int code = 200]) => http.Response(
  jsonEncode(body),
  code,
  headers: {'content-type': 'application/json'},
);
Map<String, Object?> state(
  String? owner, [
  List<String> unlocks = const ['wagon'],
]) => {
  'account': owner == null ? null : {'id': owner},
  'progress': owner == null ? null : {'version': 1, 'unlocks': unlocks},
};
Future<void> flush() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

GameSession session(
  FutureOr<http.Response> Function(http.Request) handler,
  MemoryStore store,
) => GameSession(
  api: ApiClient(
    client: MockClient((r) async => handler(r)),
    base: Uri.parse('https://game.test'),
  ),
  store: store,
);
http.Response fallback(http.Request request, {String? owner}) {
  switch (request.url.path) {
    case '/api/config':
      return json({'googleClientId': 'public-client'});
    case '/api/session':
      return json(state(owner));
    case '/api/runs/start':
      return json({
        'runId': 'run-a',
        'seed': 123,
        'startedAt': DateTime.now().millisecondsSinceEpoch,
      });
    case '/api/auth/logout':
      return json({'ok': true});
    default:
      return json({'error': 'unavailable'}, 503);
  }
}

void expireRun(GameSession s) {
  s.race.braking = true;
  for (var i = 0; i < 400 && !s.race.finished; i++) {
    s.race.tick(.25);
  }
  expect(s.race.finished, isTrue);
}

void main() {
  test('guest/account snapshots stay separate and server unlocks merge into own cache', () async {
    final store = MemoryStore()
      ..unlocks('guest', ['wagon', 'rally'])
      ..unlocks('alice', ['wagon', 'coupe']);
    final s = session(
      (r) => r.url.path == '/api/session'
          ? json(state('alice', ['wagon', 'muscle']))
          : fallback(r),
      store,
    );
    expect(s.unlocked, contains('rally'));
    s.select(cars.firstWhere((car) => car.id == 'rally'));
    await flush();
    expect(s.unlocked, unorderedEquals(['wagon', 'coupe', 'muscle']));
    expect(s.selected.id, 'wagon');
    expect(store.saved('guest'), contains('rally'));
    await s.signOut();
    expect(s.unlocked, unorderedEquals(['wagon', 'rally']));
    expect(store.saved('alice'), unorderedEquals(['wagon', 'coupe', 'muscle']));
    s.dispose();
  });

  test(
    'offline API still starts local play and restores comfort/mute preferences',
    () async {
      final store = MemoryStore()
        ..write('cannonball.steady', 'true')
        ..write('cannonball.muted', 'true');
      final s = session((r) => throw const ApiException('offline'), store);
      await flush();
      await s.start();
      expect(s.screen, AppScreen.racing);
      expect(s.race.comfortMode, isTrue);
      expect(s.muted, isTrue);
      expect(s.cloudStatus, contains('local'));
      s.toggleHorizon();
      expect(s.race.comfortMode, isFalse);
      s.dispose();
    },
  );

  test('a late initial session response cannot undo sign-out', () async {
    final response = Completer<http.Response>();
    final s = session(
      (r) => r.url.path == '/api/session' ? response.future : fallback(r),
      MemoryStore(),
    );
    await flush();
    await s.signOut();
    response.complete(json(state('alice', ['wagon', 'corvette'])));
    await flush();
    expect(s.accountId, isNull);
    expect(s.unlocked, {'wagon'});
    s.dispose();
  });

  test('login and logout cookie mutations are serialized and stale login is ignored', () async {
    final login = Completer<http.Response>();
    final requests = <String>[];
    final s = session((r) {
      requests.add(r.url.path);
      return r.url.path == '/api/auth/google' ? login.future : fallback(r);
    }, MemoryStore());
    await flush();
    final signingIn = s.signIn('credential');
    await flush();
    final signingOut = s.signOut();
    await flush();
    expect(requests, isNot(contains('/api/auth/logout')));
    login.complete(json(state('alice', ['wagon', 'corvette'])));
    expect(await signingIn, isFalse);
    await signingOut;
    expect(
      requests.indexOf('/api/auth/google'),
      lessThan(requests.indexOf('/api/auth/logout')),
    );
    expect(s.accountId, isNull);
    expect(s.unlocked, {'wagon'});
    s.dispose();
  });

  test(
    'failed finish is persisted before upload and retried for the same account',
    () async {
      final store = MemoryStore();
      var uploads = 0;
      final s = session((r) {
        if (r.url.path == '/api/runs/finish') {
          expect(store.pending('alice'), hasLength(1));
          uploads++;
          return uploads == 1
              ? json({'error': 'offline'}, 503)
              : json({
                  'accepted': true,
                  'qualified': false,
                  'progress': {
                    'unlocks': ['wagon', 'coupe'],
                  },
                });
        }
        return fallback(r, owner: 'alice');
      }, store);
      await flush();
      await s.start();
      expireRun(s);
      await flush();
      expect(s.screen, AppScreen.recap);
      expect(store.pending('alice'), hasLength(1));
      expect(s.cloudStatus, contains('retry pending'));
      await s.refreshAccount();
      await flush();
      expect(uploads, 2);
      expect(store.pending('alice'), isEmpty);
      expect(s.unlocked, contains('coupe'));
      s.dispose();
    },
  );

  test('an account switch during finish cannot merge progress or qualify the new account', () async {
    final finish = Completer<http.Response>();
    final store = MemoryStore();
    final s = session((r) {
      if (r.url.path == '/api/runs/finish') return finish.future;
      if (r.url.path == '/api/auth/google') {
        return json(state('bob', ['wagon', 'rally']));
      }
      return fallback(r, owner: 'alice');
    }, store);
    await flush();
    await s.start();
    expireRun(s);
    await flush();
    expect(s.finishing, isTrue);
    await s.signOut();
    await s.signIn('bob-token');
    finish.complete(
      json({
        'accepted': true,
        'qualified': true,
        'progress': {
          'unlocks': ['wagon', 'corvette'],
        },
      }),
    );
    await flush();
    expect(s.accountId, 'bob');
    expect(s.unlocked, unorderedEquals(['wagon', 'rally']));
    expect(s.screen, AppScreen.recap);
    expect(store.saved('bob'), isNot(contains('corvette')));
    expect(store.pending('alice'), hasLength(1));
    s.dispose();
  });

  test(
    'a signed-in run finished after logout queues under its original owner',
    () async {
      final store = MemoryStore()..unlocks('guest', ['wagon', 'rally']);
      var uploads = 0;
      final s = session((r) {
        if (r.url.path == '/api/runs/finish') {
          uploads++;
          return json({'accepted': true});
        }
        return fallback(r, owner: 'alice');
      }, store);
      await flush();
      await s.start();
      await s.signOut();
      expireRun(s);
      await flush();
      expect(uploads, 0);
      expect(store.pending('alice'), hasLength(1));
      expect(store.pending('guest'), isEmpty);
      expect(store.saved('guest'), unorderedEquals(['wagon', 'rally']));
      s.dispose();
    },
  );

  test(
    'pending uploads are owner-scoped and expired tickets remain local',
    () async {
      final store = MemoryStore();
      store.write(
        'cannonball.pending.alice.v1',
        jsonEncode([
          {
            'owner': 'alice',
            'runId': 'old',
            'receipt': {'runId': 'old'},
          },
          {
            'owner': 'bob',
            'runId': 'wrong-account',
            'receipt': {'runId': 'wrong-account'},
          },
        ]),
      );
      var uploads = 0;
      final s = session((r) {
        if (r.url.path == '/api/runs/finish') {
          uploads++;
          expect((jsonDecode(r.body) as Map)['runId'], 'old');
          return json({'error': 'run_expired'}, 409);
        }
        return fallback(r, owner: 'alice');
      }, store);
      await flush();
      expect(s.cloudStatus, contains('24 hours'));
      expect((store.pending('alice').single as Map)['expired'], isTrue);
      await s.refreshAccount();
      await flush();
      expect(uploads, 1);
      s.dispose();
    },
  );

  test('late ticket from old account cannot seed a guest run', () async {
    final tickets = <Completer<http.Response>>[];
    final s = session((r) {
      if (r.url.path == '/api/runs/start') {
        final c = Completer<http.Response>();
        tickets.add(c);
        return c.future;
      }
      return fallback(r, owner: 'alice');
    }, MemoryStore());
    await flush();
    final starting = s.start();
    await flush();
    await s.signOut();
    for (final ticket in tickets) {
      ticket.complete(json({'runId': 'old-account', 'seed': 42}));
    }
    await starting;
    expect(s.accountId, isNull);
    expect(s.screen, AppScreen.racing);
    expect(s.cloudStatus, contains('local'));
    expireRun(s);
    await flush();
    expect(s.screen, AppScreen.recap);
    s.dispose();
  });

  test(
    'late hall response cannot overwrite navigation or busy state',
    () async {
      final hall = Completer<http.Response>();
      final s = session(
        (r) => r.url.path == '/api/hall-of-fame' ? hall.future : fallback(r),
        MemoryStore(),
      );
      await flush();
      final loading = s.showHall();
      s.garage();
      hall.complete(json({'entries': []}));
      await loading;
      expect(s.screen, AppScreen.garage);
      expect(s.busy, isFalse);
      s.dispose();
    },
  );

  test('qualified delayed sync survives reload and resumes initials with its own receipt', () async {
    final store = MemoryStore();
    store.write(
      'cannonball.pending.alice.v1',
      jsonEncode([
        {
          'owner': 'alice',
          'runId': 'previous-run',
          'receipt': {
            'runId': 'previous-run',
            'elapsedMs': 650000,
            'distanceMiles': 2800,
            'carId': 'wagon',
          },
        },
      ]),
    );
    var finishUploads = 0;
    http.Response handler(http.Request r) {
      if (r.url.path == '/api/runs/finish') {
        finishUploads++;
        return json({
          'accepted': true,
          'qualified': true,
          'progress': {
            'unlocks': ['wagon'],
          },
        });
      }
      if (r.url.path == '/api/hall-of-fame') {
        expect((jsonDecode(r.body) as Map)['runId'], 'previous-run');
        return json({
          'entry': {'initials': 'AAA'},
        });
      }
      return fallback(r, owner: 'alice');
    }

    final first = session(handler, store);
    await flush();
    expect(first.screen, AppScreen.initials);
    expect(first.rankingReceipt?['elapsedMs'], 650000);
    expect(first.race.started, isFalse);
    expect(store.pending('alice'), hasLength(1));
    first.dispose();
    final restored = session(handler, store);
    await flush();
    expect(restored.screen, AppScreen.initials);
    expect(finishUploads, 1);
    await restored.submitInitials();
    expect(restored.screen, AppScreen.garage);
    expect(restored.cloudStatus, 'Hall of Fame entry saved');
    expect(store.pending('alice'), isEmpty);
    restored.dispose();
  });

  test('a displaced pending qualifier reports its real outcome', () async {
    final store = MemoryStore();
    store.write(
      'cannonball.pending.alice.v1',
      jsonEncode([
        {
          'owner': 'alice',
          'runId': 'displaced',
          'accepted': true,
          'qualified': true,
          'receipt': {
            'runId': 'displaced',
            'elapsedMs': 900000,
            'carId': 'wagon',
          },
        },
      ]),
    );
    final s = session(
      (r) => r.url.path == '/api/hall-of-fame'
          ? json({'entry': null, 'entries': []})
          : fallback(r, owner: 'alice'),
      store,
    );
    await flush();
    await s.submitInitials();
    expect(s.cloudStatus, contains('another time took the last place'));
    expect(s.screen, AppScreen.garage);
    expect(store.pending('alice'), isEmpty);
    s.dispose();
  });

  test('immediate qualification keeps its receipt until initials and then shows recap', () async {
    final store = MemoryStore();
    final s = session((r) {
      if (r.url.path == '/api/runs/finish') {
        return json({
          'accepted': true,
          'qualified': true,
          'progress': {
            'unlocks': ['wagon'],
          },
        });
      }
      if (r.url.path == '/api/hall-of-fame') {
        return json({
          'entry': {'initials': 'AAA'},
        });
      }
      return fallback(r, owner: 'alice');
    }, store);
    await flush();
    await s.start();
    expireRun(s);
    await flush();
    expect(s.screen, AppScreen.initials);
    expect(s.rankingReceipt?['carId'], 'wagon');
    await s.submitInitials();
    expect(s.screen, AppScreen.recap);
    expect(store.pending('alice'), isEmpty);
    s.dispose();
  });
}
