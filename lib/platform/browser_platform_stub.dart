import 'package:flutter/foundation.dart';

/// No-op services for Dart VM tests; the product itself targets browsers.
class BrowserPlatform {
  BrowserPlatform._();
  static final BrowserPlatform instance = BrowserPlatform._();

  bool muted = false;

  /// Audio calls made by the UI, for tests that check soundtrack continuity.
  @visibleForTesting
  final audioCalls = <String>[];
  bool get reducedMotion => false;

  void initialize({
    required void Function(double) onTilt,
    required void Function(bool) onVisibility,
    void Function(bool)? onOrientation,
    void Function(bool)? onTiltStatus,
  }) {}

  Future<bool> enableTilt() async => false;
  void disableTilt() {}
  Future<bool> beginAudio() async {
    audioCalls.add('beginAudio');
    return false;
  }

  void setAudioState({
    required double speed,
    required double intensity,
    required String region,
  }) {}
  void say(String text) {}
  void setProofAudio(bool enabled) => audioCalls.add('setProofAudio:$enabled');
  void garageCue(String cue) {}
  void radioBreak({
    required String text,
    required String station,
    bool urgent = true,
  }) => audioCalls.add('radioBreak:${urgent ? 'urgent' : 'queued'}');
  bool radioSkip() {
    audioCalls.add('radioSkip');
    return false;
  }

  String radioCaption() => '';
  void pause(bool paused) => audioCalls.add('pause:$paused');
  void holdRadio(bool held) => audioCalls.add('holdRadio:$held');
  Future<bool> requestLandscape() async => false;
  void dispose() => audioCalls.add('dispose');

  void renderGoogleButton(
    Object element,
    String clientId,
    String nonce,
    void Function(String) credential,
    void Function(String) error,
  ) => error('Google sign-in is available in a browser.');
}
