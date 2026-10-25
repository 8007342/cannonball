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
  }) {
    final String family;
    final List<String> lines;
    if (detourClosed) {
      family = 'closure';
      lines = const [
        'That shortcut is closed today. Stay on the open road; the scenery is on us.',
        'Road crews have the shortcut. Keep to the open lanes and give the cones some room.',
      ];
    } else if (weather == 'snow') {
      family = 'snow';
      lines = const [
        'Snow ahead. Gentle steering, earlier braking. Save the dramatic slides for the parking lot.',
        'A little mountain snow today. Leave more room than you think, and keep the shiny side up.',
      ];
    } else if (weather == 'rain') {
      family = 'rain';
      lines = const [
        'Rain on the road. Give the brakes a little more room than your coffee cup.',
        'Wet pavement ahead. Smooth moves, folks. This is a road trip, not a car wash stunt show.',
      ];
    } else if (trafficCount < 7) {
      family = 'clear';
      lines = const [
        'Remember, Cannonball is rolling today. Keep the roads clear, and your coffee in the cup.',
        'Light traffic, open road. Even the delivery vans got the memo. Enjoy it while it lasts.',
        'Roads are looking lovely. If you are running late, you will need a better excuse today.',
      ];
    } else {
      family = 'traffic';
      lines = const [
        'A few little traffic bunches ahead. Leave a gap. Nobody wins an argument with a minivan.',
        'Busy lanes up ahead. Pick your opening, not a fight. We like our listeners in one piece.',
        'Traffic is moving. Some drivers have places to be; some are still deciding where those places are.',
      ];
    }
    var text = lines[_variant++ % lines.length];
    if (text == _previousText) text = lines[_variant++ % lines.length];
    _previousText = text;
    return ProofRadioReport(station, text, family);
  }
}
