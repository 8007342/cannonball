import 'dart:convert';
import 'dart:typed_data';

import 'racer_observation.dart';
import 'sha256.dart';

/// Immutable dense classifier loaded from assets/traffic/racer-policy.json.
///
/// Mirrors Atrapa's defensive bundle contract (format, schema, action order,
/// shape, size, checksum and finiteness checks; never throws to the game),
/// adapted to Cannonball's racer observation and a single JSON file. Inference
/// accumulates in double precision in a fixed order, so the same observation
/// always yields the same logits on every platform.
class RacerPolicy {
  RacerPolicy._(this.modelId, this.sha256, this._layers, int widest)
    : _a = Float64List(widest),
      _b = Float64List(widest);

  static const format = 'cannonball-dense-v1';
  static const maxParams = 50000;

  final String modelId, sha256;
  final List<_Layer> _layers;
  final Float64List _a, _b;
  int get inputSize => _layers.first.inputs;
  int get paramCount =>
      _layers.fold(0, (sum, l) => sum + l.inputs * l.outputs + l.outputs);

  /// Throws [FormatException] for anything incompatible; see [tryParse].
  factory RacerPolicy.fromBundle(Map<String, dynamic> bundle) {
    Never reject(String why) => throw FormatException('racer policy: $why');
    if (bundle['format'] != format ||
        bundle['numericFormat'] != 'float32-le-base64' ||
        bundle['output'] != 'masked-logits-argmax-first') {
      reject('unsupported format');
    }
    if (bundle['observationSchema'] != racerObservationSchema) {
      reject('observation schema mismatch');
    }
    final actions = bundle['actions'];
    if (actions is! List ||
        actions.length != racerActions.length ||
        [for (var i = 0; i < actions.length; i++) actions[i] == racerActions[i]]
            .contains(false)) {
      reject('action schema mismatch');
    }
    final id = bundle['modelId'];
    if (id is! String || id.isEmpty) reject('missing model identity');
    final defs = bundle['layers'];
    if (defs is! List || defs.isEmpty || defs.length > 8) {
      reject('invalid layer list');
    }
    var total = 0, widest = 0;
    final shapes = <(int, int, String)>[];
    for (final def in defs) {
      if (def is! Map) reject('invalid layer');
      final inputs = def['inputs'], outputs = def['outputs'];
      final activation = def['activation'];
      if (inputs is! int ||
          outputs is! int ||
          inputs <= 0 ||
          outputs <= 0 ||
          inputs > 4096 ||
          outputs > 4096 ||
          !const ['relu', 'linear'].contains(activation)) {
        reject('invalid layer dimensions or activation');
      }
      if (shapes.isNotEmpty && shapes.last.$2 != inputs) {
        reject('disconnected layer shapes');
      }
      total += inputs * outputs + outputs;
      if (total > maxParams) reject('too many parameters');
      widest = [widest, inputs, outputs].reduce((a, b) => a > b ? a : b);
      shapes.add((inputs, outputs, activation as String));
    }
    if (shapes.first.$1 != racerObservationSize ||
        shapes.last.$2 != racerActions.length ||
        shapes.last.$3 != 'linear') {
      reject('input/output shape mismatch');
    }
    final encoded = bundle['weights'];
    if (encoded is! String) reject('missing weights');
    final Uint8List bytes;
    try {
      bytes = base64Decode(encoded);
    } on FormatException {
      reject('weights are not base64');
    }
    if (bytes.length != total * 4) reject('weight count mismatch');
    final digest = sha256Hex(bytes);
    if (digest != bundle['weightsSha256']) reject('weights checksum mismatch');
    final data = ByteData.sublistView(bytes);
    var offset = 0;
    final layers = <_Layer>[];
    for (final (inputs, outputs, activation) in shapes) {
      final w = Float64List(inputs * outputs), b = Float64List(outputs);
      for (var i = 0; i < w.length; i++, offset += 4) {
        w[i] = data.getFloat32(offset, Endian.little);
        if (!w[i].isFinite) reject('nonfinite weight');
      }
      for (var i = 0; i < b.length; i++, offset += 4) {
        b[i] = data.getFloat32(offset, Endian.little);
        if (!b[i].isFinite) reject('nonfinite bias');
      }
      layers.add(_Layer(inputs, outputs, activation == 'relu', w, b));
    }
    final policy = RacerPolicy._(id, digest, List.unmodifiable(layers), widest);
    // Fixtures guard against encoder/evaluator drift between Rust and Dart.
    final fixtures = bundle['fixtures'];
    if (fixtures is List) {
      for (final fixture in fixtures) {
        final scene = RacerScene.fromJson(
          (fixture as Map).cast<String, dynamic>()['scene']
              as Map<String, dynamic>,
        );
        final observation = encodeRacerObservation(scene);
        final expected = fixture['observation'] as List;
        for (var i = 0; i < observation.length; i++) {
          if ((observation[i] - (expected[i] as num)).abs() > 1e-12) {
            reject('fixture observation parity');
          }
        }
        final mask = racerSafetyMask(scene);
        final logits = policy.logits(observation);
        final expectedLogits = fixture['logits'] as List;
        for (var i = 0; i < logits.length; i++) {
          if ((logits[i] - (expectedLogits[i] as num)).abs() > 1e-9) {
            reject('fixture logit parity');
          }
        }
        if (policy.decide(observation, mask) != fixture['action']) {
          reject('fixture action parity');
        }
      }
    }
    return policy;
  }

  static RacerPolicyResult tryParse(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('racer policy: not an object');
      }
      return RacerPolicyResult.ready(RacerPolicy.fromBundle(decoded));
    } catch (error) {
      return RacerPolicyResult.fallback('$error');
    }
  }

  /// Raw logits (fresh list) for diagnostics and parity tests.
  List<double> logits(List<double> observation) {
    _forward(observation);
    final last = _layers.length.isOdd ? _a : _b;
    return List<double>.generate(_layers.last.outputs, (i) => last[i]);
  }

  /// Masked argmax: the highest logit among allowed actions, first index on
  /// ties; keep when nothing else is allowed. Allocation-free.
  int decide(List<double> observation, List<bool> mask) {
    _forward(observation);
    final last = _layers.length.isOdd ? _a : _b;
    var best = -1;
    for (var i = 0; i < _layers.last.outputs; i++) {
      if (mask[i] && (best < 0 || last[i] > last[best])) best = i;
    }
    return best < 0 ? racerKeep : best;
  }

  void _forward(List<double> x) {
    if (x.length != inputSize) throw ArgumentError('observation size');
    List<double> input = x;
    var output = _a;
    for (var l = 0; l < _layers.length; l++) {
      final layer = _layers[l];
      final hidden = l + 1 < _layers.length;
      for (var r = 0; r < layer.outputs; r++) {
        var sum = layer.biases[r];
        final row = r * layer.inputs;
        for (var c = 0; c < layer.inputs; c++) {
          sum += layer.weights[row + c] * input[c];
        }
        if (!sum.isFinite) throw StateError('nonfinite policy intermediate');
        output[r] = hidden && layer.relu && !(sum > 0) ? 0.0 : sum;
      }
      input = output;
      output = identical(output, _a) ? _b : _a;
    }
  }
}

class RacerPolicyResult {
  const RacerPolicyResult.ready(RacerPolicy this.policy) : error = null;
  const RacerPolicyResult.fallback(String this.error) : policy = null;
  final RacerPolicy? policy;
  final String? error;
  bool get isReady => policy != null;
}

class _Layer {
  const _Layer(this.inputs, this.outputs, this.relu, this.weights, this.biases);
  final int inputs, outputs;
  final bool relu;
  final Float64List weights, biases;
}
