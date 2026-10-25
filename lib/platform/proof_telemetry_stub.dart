void installProofTelemetry({
  required Map<String, Object?> Function() snapshot,
  required void Function() start,
  required void Function() reset,
  required void Function(bool) pause,
  required void Function(double, bool) drive,
}) {}

void disposeProofTelemetry() {}
