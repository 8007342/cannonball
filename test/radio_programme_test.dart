import 'dart:convert';
import 'dart:io';

import 'package:cannonball/platform/proof_radio.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  final spec = _json('art/music/radio-songs.json');
  final songs = (spec['songs'] as List).cast<Map<String, dynamic>>();
  final stations = (spec['stations'] as List).cast<Map<String, dynamic>>();

  test('song spec covers every requested genre with wordless takes', () {
    expect(songs.length, greaterThanOrEqualTo(24));
    final perGenre = <String, int>{};
    for (final song in songs) {
      perGenre.update(song['genre'] as String, (n) => n + 1, ifAbsent: () => 1);
      final duration = song['duration'] as num;
      expect(duration, inInclusiveRange(60, 120), reason: song['id'] as String);
    }
    for (final genre in ['pop', 'rock', 'metal', 'jazz', 'latin', 'folk']) {
      expect(perGenre[genre], greaterThanOrEqualTo(3), reason: genre);
    }
    expect(spec['lyrics'], '[instrumental]');
    expect(spec['common_tags'], contains('no vocals'));
    expect(songs.map((s) => s['id']).toSet().length, songs.length);
    expect(songs.map((s) => s['seed']).toSet().length, songs.length);
  });

  test('prompts describe genre traits, never named artists or songs', () {
    for (final song in songs) {
      final tags = (song['tags'] as String).toLowerCase();
      for (final banned in [
        'in the style of',
        ' by ',
        'cover of',
        'sounds like',
      ]) {
        expect(tags, isNot(contains(banned)), reason: song['id'] as String);
      }
    }
  });

  test('every station has songs, an ident and a presenter voice', () {
    final lines = (_json('art/music/radio-interjections.json')['lines'] as List)
        .cast<Map<String, dynamic>>();
    for (final station in stations) {
      final id = station['id'];
      expect(songs.where((s) => s['station'] == id).length, greaterThan(1));
      expect(
        lines.any((l) => l['station'] == id && l['kind'] == 'ident'),
        isTrue,
        reason: '$id ident',
      );
    }
    for (final line in lines) {
      final words = (line['text'] as String).split(' ').length;
      expect(words, lessThanOrEqualTo(16), reason: line['id'] as String);
    }
  });

  test('catalog programme ships every referenced file within budget', () {
    final catalog = _json('assets/audio/catalog.json');
    final programme = catalog['programme'] as Map<String, dynamic>;
    final files = [
      ...(programme['songs'] as List),
      ...(programme['buzz'] as List),
      ...(programme['interjections'] as List),
    ].cast<Map<String, dynamic>>();
    expect((programme['songs'] as List).length, greaterThanOrEqualTo(24));
    for (final entry in files) {
      expect(
        File('assets/audio/${entry['src']}').existsSync(),
        isTrue,
        reason: entry['src'] as String,
      );
    }
    final total = Directory('assets/audio')
        .listSync(recursive: true)
        .whereType<File>()
        .fold<int>(0, (sum, f) => sum + f.lengthSync());
    expect(total, lessThan(120 * 1024 * 1024));
    final verification = _json('assets/audio/radio-verification.json');
    expect(verification['ok'], isTrue);
  });

  test('only safety-relevant reports interrupt a song', () {
    final director = ProofRadioDirector();
    expect(
      director.choose(station: 'City', weather: 'snow', trafficCount: 0).urgent,
      isTrue,
    );
    expect(
      director
          .choose(station: 'City', weather: 'clear', trafficCount: 1)
          .urgent,
      isFalse,
    );
    expect(
      director
          .choose(
            station: 'City',
            weather: 'clear',
            trafficCount: 1,
            laneClosed: true,
          )
          .urgent,
      isTrue,
    );
  });
}
