import 'dart:convert';

import 'package:cannonball/game/stage_progress.dart';
import 'package:flutter_test/flutter_test.dart';

StageDefinition stage(String id, String from, String to) => StageDefinition(
  id: id,
  from: from,
  to: to,
  paths: [
    [id],
  ],
);
final catalog = [
  stage('ny-a', 'ny', 'a'),
  stage('a-la', 'a', 'la'),
  stage('ny-b', 'ny', 'b'),
  stage('b-la', 'b', 'la'),
  stage('x-la', 'x', 'la'),
  stage('a-ny', 'a', 'ny'),
];
StageProgress progress() => StageProgress(
  catalog: catalog,
  contentVersion: 'roads-2',
  rulesVersion: 'handling-2',
);
StageAttempt attempt(
  String id,
  String stageId,
  int ms, {
  String car = 's2000',
  String version = 'handling-2',
}) {
  final definition = catalog.firstWhere((s) => s.id == stageId);
  return StageAttempt(
    id: id,
    stageId: stageId,
    from: definition.from,
    to: definition.to,
    carId: car,
    elapsedMs: ms,
    distanceMiles: 100,
    path: [stageId],
    seed: 731,
    contentVersion: 'roads-2',
    rulesVersion: version,
  );
}

void main() {
  test(
    'best connected journey combines compatible attempts using different cars',
    () {
      final p = progress();
      expect(p.record(attempt('ny-fast', 'ny-a', 100)), isTrue);
      expect(p.record(attempt('a-fast', 'a-la', 200, car: 'corvette')), isTrue);
      p.record(attempt('ny-other', 'ny-b', 200));
      p.record(attempt('b-other', 'b-la', 200));
      final best = p.bestJourney('ny', 'la')!;
      expect(best.map((r) => r.id), ['ny-fast', 'a-fast']);
      expect(best.map((r) => r.carId), ['s2000', 'corvette']);
      expect(best.fold(0, (sum, r) => sum + r.elapsedMs), 300);
    },
  );
  test('a disconnected fast receipt cannot replace a connected stage', () {
    final p = progress()
      ..record(attempt('ny', 'ny-a', 100))
      ..record(attempt('orphan', 'x-la', 1));
    expect(p.bestJourney('ny', 'la'), isNull);
    p.record(attempt('a', 'a-la', 200));
    expect(p.bestJourney('ny', 'la')!.map((r) => r.id), ['ny', 'a']);
    expect(p.bestJourney('missing', 'la'), isNull);
    expect(p.bestJourney('ny', 'ny'), isEmpty);
  });
  test('positive stage durations make cyclic catalogs safe', () {
    final p = progress()
      ..record(attempt('first', 'ny-a', 100))
      ..record(attempt('back', 'a-ny', 1))
      ..record(attempt('finish', 'a-la', 200));
    expect(p.bestJourney('ny', 'la')!.map((r) => r.id), ['first', 'finish']);
  });
  test(
    'invalid stage endpoints, paths and versions do not mutate progress',
    () {
      final p = progress();
      final valid = attempt('ok', 'ny-a', 100);
      expect(
        p.record(attempt('old', 'ny-a', 100, version: 'handling-1')),
        isFalse,
      );
      for (final replacement in [
        <String, Object>{'from': 'x'},
        <String, Object>{'to': 'x'},
        <String, Object>{'stageId': 'missing'},
        <String, Object>{
          'path': ['not-a-road'],
        },
        <String, Object>{'completed': false},
      ]) {
        final decoded = StageAttempt.fromJson({
          ...valid.toJson(),
          ...replacement,
        });
        if (decoded != null) expect(p.record(decoded), isFalse);
      }
      expect(p.attempts, isEmpty);
      expect(p.record(valid), isTrue);
    },
  );
  test('JSON restore preserves all car attempts and rejects duplicate IDs', () {
    final p = progress()
      ..record(attempt('one', 'ny-a', 300))
      ..record(attempt('two', 'ny-a', 100, car: 'corvette'))
      ..record(attempt('three', 'a-la', 200));
    final restored = StageProgress.fromJson(
      jsonDecode(jsonEncode(p.toJson())),
      catalog: catalog,
      contentVersion: 'roads-2',
      rulesVersion: 'handling-2',
    );
    expect(restored.attempts.length, 3);
    expect(restored.bestJourney('ny', 'la')!.map((r) => r.id), [
      'two',
      'three',
    ]);
    expect(restored.record(attempt('two', 'ny-a', 1)), isFalse);
    expect(restored.attempts.length, 3);
  });
  test('corrupt rows are dropped individually and incompatible stores restore empty', () {
    final valid = attempt('valid', 'ny-a', 100).toJson();
    final p = StageProgress.fromJson(
      {
        'schemaVersion': 1,
        'contentVersion': 'roads-2',
        'rulesVersion': 'handling-2',
        'attempts': [
          null,
          {},
          'oops',
          {...valid, 'elapsedMs': 0},
          {...valid, 'distanceMiles': double.infinity},
          {
            ...valid,
            'path': [3],
          },
          valid,
        ],
      },
      catalog: catalog,
      contentVersion: 'roads-2',
      rulesVersion: 'handling-2',
    );
    expect(p.attempts.map((r) => r.id), ['valid']);
    for (final value in [
      null,
      'oops',
      [],
      {'schemaVersion': 2},
      {...p.toJson(), 'contentVersion': 'roads-old'},
    ]) {
      expect(
        StageProgress.fromJson(
          value,
          catalog: catalog,
          contentVersion: 'roads-2',
          rulesVersion: 'handling-2',
        ).attempts,
        isEmpty,
      );
    }
  });
  test('receipt data and exposed collections are immutable copies', () {
    final path = ['ny-a'];
    final a = StageAttempt(
      id: 'copy',
      stageId: 'ny-a',
      from: 'ny',
      to: 'a',
      carId: 's2000',
      elapsedMs: 100,
      distanceMiles: 100,
      path: path,
      seed: 1,
      contentVersion: 'roads-2',
      rulesVersion: 'handling-2',
    );
    path[0] = 'changed';
    expect(a.path, ['ny-a']);
    final p = progress()..record(a);
    expect(() => a.path.add('mutate'), throwsUnsupportedError);
    expect(() => p.attempts.clear(), throwsUnsupportedError);
    expect(() => p.catalog.first.paths.first.clear(), throwsUnsupportedError);
    expect(() => p.completedCities.clear(), throwsUnsupportedError);
  });
  test('catalog construction rejects ambiguous definitions', () {
    expect(
      () => StageProgress(
        catalog: [catalog.first, catalog.first],
        contentVersion: 'v1',
        rulesVersion: 'v1',
      ),
      throwsArgumentError,
    );
    expect(
      () => StageProgress(
        catalog: [StageDefinition(id: 'bad', from: 'ny', to: 'la', paths: [])],
        contentVersion: 'v1',
        rulesVersion: 'v1',
      ),
      throwsArgumentError,
    );
  });
}
