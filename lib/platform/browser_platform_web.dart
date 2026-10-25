import 'dart:js_interop';

@JS('CannonballPlatform')
external _PlatformBridge? get _bridge;

extension type _PlatformBridge(JSObject _) implements JSObject {
  external bool get reducedMotion;
  external void initialize(
    JSFunction tilt,
    JSFunction visibility,
    JSFunction orientation,
    JSFunction tiltStatus,
  );
  external JSPromise<JSBoolean> enableTilt();
  external void disableTilt();
  external JSPromise<JSBoolean> beginAudio();
  external void setAudioState(double speed, double intensity, String region);
  external void say(String text);
  external void setProofAudio(bool enabled);
  external void radioBreak(String text, String station);
  external void setMuted(bool muted);
  external void pause(bool paused);
  external JSPromise<JSBoolean> requestLandscape();
  external void dispose();
  external void renderGoogleButton(
    JSObject element,
    String clientId,
    String nonce,
    JSFunction credential,
    JSFunction error,
  );
}

/// Optional browser capabilities. Permission methods must start in a gesture.
class BrowserPlatform {
  BrowserPlatform._();
  static final BrowserPlatform instance = BrowserPlatform._();
  bool _muted = false;
  bool get muted => _muted;
  set muted(bool value) {
    _muted = value;
    _bridge?.setMuted(value);
  }

  bool get reducedMotion => _bridge?.reducedMotion ?? false;

  void initialize({
    required void Function(double) onTilt,
    required void Function(bool) onVisibility,
    void Function(bool)? onOrientation,
    void Function(bool)? onTiltStatus,
  }) {
    _bridge?.initialize(
      ((JSNumber value) => onTilt(value.toDartDouble)).toJS,
      ((JSBoolean value) => onVisibility(value.toDart)).toJS,
      ((JSBoolean value) => onOrientation?.call(value.toDart)).toJS,
      ((JSBoolean value) => onTiltStatus?.call(value.toDart)).toJS,
    );
    _bridge?.setMuted(_muted);
  }

  Future<bool> enableTilt() async {
    try {
      return (await _bridge?.enableTilt().toDart)?.toDart ?? false;
    } catch (_) {
      return false;
    }
  }

  void disableTilt() => _bridge?.disableTilt();

  Future<bool> beginAudio() async {
    try {
      return (await _bridge?.beginAudio().toDart)?.toDart ?? false;
    } catch (_) {
      return false;
    }
  }

  /// [speed] is normalized 0..1; [intensity] is normalized 0..1.
  void setAudioState({
    required double speed,
    required double intensity,
    required String region,
  }) => _bridge?.setAudioState(speed, intensity, region);

  void say(String text) => _bridge?.say(text);
  void setProofAudio(bool enabled) => _bridge?.setProofAudio(enabled);
  void radioBreak({required String text, required String station}) =>
      _bridge?.radioBreak(text, station);
  void pause(bool paused) => _bridge?.pause(paused);

  Future<bool> requestLandscape() async {
    try {
      return (await _bridge?.requestLandscape().toDart)?.toDart ?? false;
    } catch (_) {
      return false;
    }
  }

  void renderGoogleButton(
    Object element,
    String clientId,
    String nonce,
    void Function(String) credential,
    void Function(String) error,
  ) {
    final bridge = _bridge;
    if (bridge == null) {
      error('The browser sign-in bridge did not load.');
      return;
    }
    try {
      bridge.renderGoogleButton(
        element as JSObject,
        clientId,
        nonce,
        ((JSString value) => credential(value.toDart)).toJS,
        ((JSString value) => error(value.toDart)).toJS,
      );
    } catch (_) {
      error('Google sign-in could not start. Please try again.');
    }
  }

  void dispose() => _bridge?.dispose();
}
