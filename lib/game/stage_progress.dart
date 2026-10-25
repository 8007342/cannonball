/// A versioned city-to-city corridor. Each allowed path is an ordered list of
/// route-edge IDs; all alternatives share this stage's checkpoint endpoints.
class StageDefinition {
  StageDefinition({
    required this.id,
    required this.from,
    required this.to,
    required List<List<String>> paths,
  }) : paths = List.unmodifiable(
         paths.map((path) => List<String>.unmodifiable(path)),
       );

  final String id, from, to;
  final List<List<String>> paths;
}

/// An immutable completed-stage receipt. The selected car belongs to this
/// attempt, so a composed journey may legitimately use several owned cars.
class StageAttempt {
  StageAttempt({
    required this.id,
    required this.stageId,
    required this.from,
    required this.to,
    required this.carId,
    required this.elapsedMs,
    required this.distanceMiles,
    required List<String> path,
    required this.seed,
    required this.contentVersion,
    required this.rulesVersion,
    this.completed = true,
  }) : path = List.unmodifiable(path);

  final String id, stageId, from, to, carId, contentVersion, rulesVersion;
  final int elapsedMs, seed;
  final double distanceMiles;
  final List<String> path;
  final bool completed;

  Map<String, Object> toJson() => {
    'id': id,
    'stageId': stageId,
    'from': from,
    'to': to,
    'carId': carId,
    'elapsedMs': elapsedMs,
    'distanceMiles': distanceMiles,
    'path': path,
    'seed': seed,
    'contentVersion': contentVersion,
    'rulesVersion': rulesVersion,
    'completed': completed,
  };

  static StageAttempt? fromJson(Object? value) {
    if (value is! Map) return null;
    const strings = [
      'id',
      'stageId',
      'from',
      'to',
      'carId',
      'contentVersion',
      'rulesVersion',
    ];
    if (strings.any((key) => !_label(value[key]))) return null;
    final time = value['elapsedMs'],
        distance = value['distanceMiles'],
        seed = value['seed'];
    final path = value['path'];
    if (time is! int ||
        time <= 0 ||
        time > _maxSafeInteger ||
        distance is! num ||
        !distance.isFinite ||
        distance <= 0 ||
        seed is! int ||
        seed.abs() > _maxSafeInteger ||
        path is! List ||
        path.isEmpty ||
        path.length > 512 ||
        path.any((edge) => !_label(edge)) ||
        value['completed'] != true) {
      return null;
    }
    return StageAttempt(
      id: value['id'] as String,
      stageId: value['stageId'] as String,
      from: value['from'] as String,
      to: value['to'] as String,
      carId: value['carId'] as String,
      elapsedMs: time,
      distanceMiles: distance.toDouble(),
      path: path.cast<String>(),
      seed: seed,
      contentVersion: value['contentVersion'] as String,
      rulesVersion: value['rulesVersion'] as String,
    );
  }
}

const _maxSafeInteger = 9007199254740991;
bool _label(Object? value) =>
    value is String &&
    value.trim().isNotEmpty &&
    value.length <= 128 &&
    !value.contains(RegExp(r'[\x00-\x1f]'));
bool _samePath(List<String> a, List<String> b) =>
    a.length == b.length &&
    List.generate(a.length, (i) => i).every((i) => a[i] == b[i]);

/// Local campaign foundation only. Server verification and rankings remain
/// independent; a locally accepted receipt is not an authoritative public score.
class StageProgress {
  StageProgress({
    required List<StageDefinition> catalog,
    required this.contentVersion,
    required this.rulesVersion,
  }) : catalog = List.unmodifiable(catalog) {
    if (!_label(contentVersion) || !_label(rulesVersion)) {
      throw ArgumentError('Versions must be nonempty labels');
    }
    for (final definition in this.catalog) {
      if (!_label(definition.id) ||
          !_label(definition.from) ||
          !_label(definition.to) ||
          definition.from == definition.to ||
          definition.paths.isEmpty ||
          definition.paths.any(
            (path) =>
                path.isEmpty ||
                path.length > 512 ||
                path.any((edge) => !_label(edge)),
          ) ||
          _byId.containsKey(definition.id)) {
        throw ArgumentError(
          'Invalid or duplicate stage definition: ${definition.id}',
        );
      }
      _byId[definition.id] = definition;
      _checkpoints.addAll([definition.from, definition.to]);
    }
  }

  final List<StageDefinition> catalog;
  final String contentVersion, rulesVersion;
  final _byId = <String, StageDefinition>{};
  final _checkpoints = <String>{};
  final _attempts = <String, StageAttempt>{};
  List<StageAttempt> get attempts => List.unmodifiable(_attempts.values);
  Set<String> get completedCities =>
      Set.unmodifiable({for (final attempt in _attempts.values) attempt.to});

  /// Rejects malformed/incompatible/duplicate attempts without mutating progress.
  bool record(StageAttempt attempt) {
    final stage = _byId[attempt.stageId];
    if (stage == null ||
        _attempts.containsKey(attempt.id) ||
        _attempts.length >= 10000 ||
        attempt.from != stage.from ||
        attempt.to != stage.to ||
        attempt.contentVersion != contentVersion ||
        attempt.rulesVersion != rulesVersion ||
        StageAttempt.fromJson(attempt.toJson()) == null ||
        !stage.paths.any((path) => _samePath(path, attempt.path))) {
      return false;
    }
    _attempts[attempt.id] = attempt;
    return true;
  }

  /// Dijkstra over successful directed attempts. Positive durations make cycles
  /// safe. Equal-time ties use stable receipt-ID order, independent of restore.
  List<StageAttempt>? bestJourney(String from, String to) {
    if (!_checkpoints.contains(from) || !_checkpoints.contains(to)) return null;
    if (from == to) return const [];
    final distance = <String, int>{from: 0};
    final previous = <String, StageAttempt>{};
    final visited = <String>{};
    final edges = _attempts.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    while (true) {
      String? current;
      for (final node in distance.keys) {
        if (!visited.contains(node) &&
            (current == null ||
                distance[node]! < distance[current]! ||
                distance[node] == distance[current] &&
                    node.compareTo(current) < 0)) {
          current = node;
        }
      }
      if (current == null) return null;
      if (current == to) {
        final path = <StageAttempt>[];
        var node = to;
        while (node != from) {
          final edge = previous[node]!;
          path.add(edge);
          node = edge.from;
        }
        return List.unmodifiable(path.reversed);
      }
      visited.add(current);
      for (final edge in edges) {
        if (edge.from != current || visited.contains(edge.to)) continue;
        final candidate = distance[current]! + edge.elapsedMs;
        if (candidate <= _maxSafeInteger &&
            (distance[edge.to] == null || candidate < distance[edge.to]!)) {
          distance[edge.to] = candidate;
          previous[edge.to] = edge;
        }
      }
    }
  }

  Map<String, Object> toJson() => {
    'schemaVersion': 1,
    'contentVersion': contentVersion,
    'rulesVersion': rulesVersion,
    'attempts': [for (final attempt in _attempts.values) attempt.toJson()],
  };

  /// The caller supplies the trusted current catalog. Corrupt entries are
  /// dropped individually; unknown document versions restore empty progress.
  factory StageProgress.fromJson(
    Object? value, {
    required List<StageDefinition> catalog,
    required String contentVersion,
    required String rulesVersion,
  }) {
    final result = StageProgress(
      catalog: catalog,
      contentVersion: contentVersion,
      rulesVersion: rulesVersion,
    );
    if (value is! Map ||
        value['schemaVersion'] != 1 ||
        value['contentVersion'] != contentVersion ||
        value['rulesVersion'] != rulesVersion ||
        value['attempts'] is! List) {
      return result;
    }
    for (final raw in (value['attempts'] as List).take(10000)) {
      final attempt = StageAttempt.fromJson(raw);
      if (attempt != null) result.record(attempt);
    }
    return result;
  }
}
