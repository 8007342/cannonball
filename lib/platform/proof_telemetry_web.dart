import 'dart:js_interop';

@JS('CannonballProof')
external set _controls(JSObject? value);

@JS('CannonballProofBootstrap')
external _Bootstrap? get _bootstrap;

extension type _Bootstrap(JSObject _) implements JSObject {
  external JSObject snapshot();
}

extension type _Controls._(JSObject _) implements JSObject {
  external factory _Controls({
    required JSFunction snapshot,
    required JSFunction start,
    required JSFunction reset,
    required JSFunction pause,
    required JSFunction drive,
  });
}

void installProofTelemetry({
  required Map<String, Object?> Function() snapshot,
  required void Function() start,
  required void Function() reset,
  required void Function(bool) pause,
  required void Function(double, bool) drive,
}) {
  _controls = _Controls(
    snapshot: (() => <String, Object?>{
      ...snapshot(),
      'browser': _bootstrap?.snapshot().dartify(),
    }.jsify()).toJS,
    start: start.toJS,
    reset: reset.toJS,
    pause: ((JSBoolean value) => pause(value.toDart)).toJS,
    drive: ((JSNumber steer, JSBoolean brake) => drive(
      steer.toDartDouble,
      brake.toDart,
    )).toJS,
  );
}

void disposeProofTelemetry() => _controls = null;
