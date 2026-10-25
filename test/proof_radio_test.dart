import 'package:cannonball/platform/proof_radio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('interjections remain short across every authored condition family', () {
    final d = ProofRadioDirector();
    for (var i = 0; i < 20; i++) {
      for (final condition in [
        'closure',
        'worksite',
        'snow',
        'rain',
        'clear',
        'traffic',
      ]) {
        final r = d.choose(
          station: 'City',
          weather: condition,
          trafficCount: condition == 'traffic' ? 12 : 2,
          detourClosed: condition == 'closure',
          laneClosed: condition == 'worksite',
        );
        expect(r.text.split(' ').length, lessThanOrEqualTo(9));
      }
    }
  });
  test('weather and closures outrank banter and come from supplied state', () {
    final director = ProofRadioDirector();
    final rain = director.choose(
      station: 'City',
      weather: 'rain',
      trafficCount: 1,
    );
    expect(rain.family, 'rain');
    expect(rain.text.toLowerCase(), contains('rain'));
    final closure = director.choose(
      station: 'Forest',
      weather: 'snow',
      trafficCount: 1,
      detourClosed: true,
    );
    expect(closure.family, 'closure');
    expect(closure.text.toLowerCase(), contains('closed'));
    expect(closure.text.toLowerCase(), isNot(contains('flood')));
    final snow = director.choose(
      station: 'Mountain',
      weather: 'snow',
      trafficCount: 10,
    );
    expect(snow.family, 'snow');
  });

  test('low traffic variants do not immediately repeat and reset deterministically', () {
    final director = ProofRadioDirector();
    final first = director.choose(
      station: 'City',
      weather: 'clear',
      trafficCount: 2,
    );
    final second = director.choose(
      station: 'City',
      weather: 'clear',
      trafficCount: 2,
    );
    expect(first.family, 'clear');
    expect(second.text, isNot(first.text));
    director.reset();
    expect(
      director.choose(station: 'City', weather: 'clear', trafficCount: 2).text,
      first.text,
    );
    expect(
      director
          .choose(station: 'Forest', weather: 'clear', trafficCount: 10)
          .family,
      'traffic',
    );
  });
  test('authored lane closure gets its own truthful report', () {
    final report = ProofRadioDirector().choose(
      station: 'City',
      weather: 'clear',
      trafficCount: 0,
      laneClosed: true,
    );
    expect(report.family, 'worksite');
    expect(report.text.toLowerCase(), contains('lanes'));
  });
}
