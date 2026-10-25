/// Browser measurement hooks are optional and have no simulation responsibilities.
library;

export 'proof_telemetry_stub.dart'
    if (dart.library.js_interop) 'proof_telemetry_web.dart';
