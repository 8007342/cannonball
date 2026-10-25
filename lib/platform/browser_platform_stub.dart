/// No-op services for Dart VM tests; the product itself targets browsers.
class BrowserPlatform {
  BrowserPlatform._();
  static final BrowserPlatform instance = BrowserPlatform._();

  bool muted = false;
  bool get reducedMotion => false;

  void initialize({
    required void Function(double) onTilt,
    required void Function(bool) onVisibility,
    void Function(bool)? onOrientation,
    void Function(bool)? onTiltStatus,
  }) {}

  Future<bool> enableTilt() async => false;
  void disableTilt() {}
  Future<bool> beginAudio() async => false;
  void setAudioState({
    required double speed,
    required double intensity,
    required String region,
  }) {}
  void say(String text) {}
  void setProofAudio(bool enabled) {}
  void garageCue(String cue) {}
  void radioBreak({required String text, required String station}) {}
  void pause(bool paused) {}
  Future<bool> requestLandscape() async => false;
  void dispose() {}

  void renderGoogleButton(
    Object element,
    String clientId,
    String nonce,
    void Function(String) credential,
    void Function(String) error,
  ) => error('Google sign-in is available in a browser.');
}
