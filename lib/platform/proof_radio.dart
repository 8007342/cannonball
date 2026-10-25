/// Original proof scripts. Regional performance/accents still require a voiced
/// content pack; the browser speech fallback cannot promise a local accent.
class ProofRadioReport {
  const ProofRadioReport(this.station, this.text, this.family);
  final String station, text, family;
}

class ProofRadioDirector {
  int _variant = 0;
  String? _previousText;

  void reset() {
    _variant = 0;
    _previousText = null;
  }

  ProofRadioReport choose({
    required String station,
    required String weather,
    required int trafficCount,
    bool detourClosed = false,
    bool laneClosed = false,
  }) {
    final String family;
    final List<String> lines;
    if (detourClosed) {
      family = 'closure';
      lines = const [
        'Shortcut closed. Scenic route it is!',
        'Shortcut closed. Follow the open road.',
      ];
    } else if (laneClosed) {
      family = 'worksite';
      lines = const [
        'Narrow lanes ahead. Mind the cones!',
        'Lane closed. Cones are working overtime!',
      ];
    } else if (weather == 'snow') {
      family = 'snow';
      lines = const [
        'Snow ahead. Easy steering, early brakes.',
        'Mountain snow! Keep the shiny side up.',
      ];
    } else if (weather == 'rain') {
      family = 'rain';
      lines = const [
        'Rain ahead. Give those brakes room!',
        'Wet pavement. Smooth moves, folks!',
      ];
    } else if (trafficCount < 7) {
      family = 'clear';
      lines = const [
        'Cannonball today! Keep the roads clear!',
        'Light traffic. Even the vans got the memo!',
        'Lovely roads. Terrible day for excuses!',
      ];
    } else {
      family = 'traffic';
      lines = const [
        'Traffic ahead. Never argue with a minivan!',
        'Busy lanes. Pick a gap, not a fight!',
        'Traffic moving. Some drivers are still deciding!',
      ];
    }
    var text = lines[_variant++ % lines.length];
    if (text == _previousText) text = lines[_variant++ % lines.length];
    _previousText = text;
    return ProofRadioReport(station, text, family);
  }
}
