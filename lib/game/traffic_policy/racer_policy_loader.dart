import 'package:flutter/services.dart';

import 'racer_policy.dart';

/// Loads the bundled racer classifier once. Any failure (asset missing or not
/// registered, schema/checksum/parity mismatch) leaves [shared] null and the
/// traffic keeps its deterministic rule-based racer driving.
class RacerPolicyStore {
  static const assetPath = 'assets/traffic/racer-policy.json';
  static RacerPolicy? shared;
  static String status = 'not loaded';
  static Future<RacerPolicyResult>? _pending;

  static Future<RacerPolicyResult> load({AssetBundle? bundle}) =>
      _pending ??= _load(bundle ?? rootBundle);

  static Future<RacerPolicyResult> _load(AssetBundle bundle) async {
    RacerPolicyResult result;
    try {
      result = RacerPolicy.tryParse(await bundle.loadString(assetPath));
    } catch (error) {
      result = RacerPolicyResult.fallback('racer policy unavailable: $error');
    }
    shared = result.policy;
    status = result.isReady
        ? 'ready ${result.policy!.modelId}'
        : 'fallback rules (${result.error})';
    return result;
  }

  /// Test hook: forget any loaded policy.
  static void reset() {
    shared = null;
    status = 'not loaded';
    _pending = null;
  }
}
