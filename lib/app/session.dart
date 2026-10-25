import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../game/race.dart';
import '../platform/browser_platform.dart';
import '../services/api_client.dart';
import '../services/local_store.dart';

enum AppScreen { garage, racing, initials, recap, hall }

class GameSession extends ChangeNotifier {
  GameSession({ApiClient? api, LocalStore? store})
    : api = api ?? ApiClient(),
      store = store ?? LocalStore() {
    _restoreOwner(null);
    muted = this.store.read('cannonball.muted') == 'true';
    final storedHorizon = this.store.read('cannonball.steady');
    steadyHorizon = storedHorizon == null
        ? platform.reducedMotion
        : storedHorizon == 'true';
    race.comfortMode = steadyHorizon;
    platform.muted = muted;
    race.addListener(_raceChanged);
    unawaited(refreshAccount());
  }

  final ApiClient api;
  final LocalStore store;
  final RaceController race = RaceController();
  final BrowserPlatform platform = BrowserPlatform.instance;
  AppScreen screen = AppScreen.garage;
  CarSpec selected = cars.first;
  Set<String> unlocked = {'wagon'};
  String? accountId;
  String? clientId;
  String cloudStatus = 'Checking cloud saves…';
  bool cloudAvailable = false;
  bool busy = false;
  bool tilt = false;
  bool steadyHorizon = false;
  bool muted = false;
  bool _disposed = false;
  bool _handledFinish = false;
  bool _finishing = false;
  bool get finishing => _finishing;
  int _identityEpoch = 0;
  int _ticketEpoch = 0;
  int _activityEpoch = 0;
  int _authPending = 0;
  Future<void> _authQueue = Future<void>.value();
  int runSerial = 0;
  Map<String, dynamic>? _ticket;
  String? _ticketAccount;
  String? _ticketCar;
  Map<String, dynamic>? _activeTicket;
  String? _activeAccount;
  int? _activeIdentityEpoch;
  String? _runOwner;
  final Set<String> _uploads = {};
  Map<String, dynamic>? _rankingEntry;
  String? _rankingOwner;
  AppScreen _rankingReturnScreen = AppScreen.recap;
  Map<String, dynamic>? get rankingReceipt => _rankingEntry?['receipt'] is Map
      ? Map<String, dynamic>.from(_rankingEntry!['receipt'] as Map)
      : null;
  List<Map<String, dynamic>> hall = [];
  String lastRadio = '';
  final List<String> initials = ['A', 'A', 'A'];

  Set<String> _localUnlocks(String? owner) {
    final result = <String>{'wagon'};
    try {
      final raw = store.read('cannonball.${owner ?? 'guest'}.v1');
      if (raw != null) {
        final value = jsonDecode(raw);
        if (value is Map) result.addAll(_validUnlocks(value['unlocks']));
      }
    } catch (_) {
      /* An invalid local save must not prevent driving. */
    }
    return result;
  }

  Iterable<String> _validUnlocks(dynamic value) => value is List
      ? value.whereType<String>().where((id) => cars.any((car) => car.id == id))
      : const [];

  void _restoreOwner(String? owner) {
    unlocked = _localUnlocks(owner);
    if (!unlocked.contains(selected.id)) selected = cars.first;
  }

  void _saveUnlocks(String? owner, Set<String> values) {
    store.write(
      'cannonball.${owner ?? 'guest'}.v1',
      jsonEncode({'unlocks': values.toList()}),
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool _currentIdentity(int epoch) => !_disposed && epoch == _identityEpoch;

  void _clearTicket() {
    _ticketEpoch++;
    _ticket = null;
    _ticketAccount = null;
    _ticketCar = null;
  }

  void _applyAccount(Map<String, dynamic> state) {
    final account = state['account'];
    final nextOwner = account is Map ? account['id'] as String? : null;
    if (_rankingOwner != null && _rankingOwner != nextOwner) {
      if (screen == AppScreen.initials) screen = _rankingReturnScreen;
      _rankingEntry = null;
      _rankingOwner = null;
    }
    _clearTicket();
    accountId = nextOwner;
    _restoreOwner(nextOwner);
    _mergeProgress(state['progress']);
    _saveUnlocks(accountId, unlocked);
    cloudAvailable = true;
    cloudStatus = accountId == null
        ? 'Guest · progress saved on this browser'
        : 'Signed in · progress synced';
    if (accountId != null) {
      unawaited(_prepareTicket());
      unawaited(_retryPending());
    }
  }

  Future<void> refreshAccount() async {
    if (_disposed || _authPending > 0) return;
    final epoch = ++_identityEpoch;
    _clearTicket();
    try {
      final config = await api.request('GET', '/api/config');
      if (!_currentIdentity(epoch)) return;
      clientId = config['googleClientId'] as String?;
      final state = await api.request('GET', '/api/session');
      if (!_currentIdentity(epoch)) return;
      _applyAccount(state);
    } catch (e) {
      if (!_currentIdentity(epoch)) return;
      cloudAvailable = false;
      cloudStatus = e.toString();
    }
    _notify();
  }

  void _mergeProgress(dynamic progress) {
    if (progress is Map) unlocked.addAll(_validUnlocks(progress['unlocks']));
  }

  List<Map<String, dynamic>> _pending(String owner) {
    try {
      final raw = store.read('cannonball.pending.$owner.v1');
      final value = raw == null ? null : jsonDecode(raw);
      if (value is List) {
        return value
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .where(
              (entry) =>
                  entry['owner'] == owner &&
                  entry['runId'] is String &&
                  entry['receipt'] is Map,
            )
            .toList();
      }
    } catch (_) {
      /* Ignore malformed local retry data. */
    }
    return [];
  }

  void _writePending(String owner, List<Map<String, dynamic>> entries) {
    store.write('cannonball.pending.$owner.v1', jsonEncode(entries));
  }

  void _queueReceipt(
    String owner,
    Map<String, dynamic> ticket,
    Map<String, Object> receipt,
  ) {
    final entries = _pending(owner);
    if (entries.any((entry) => entry['runId'] == ticket['runId'])) return;
    entries.add({
      'owner': owner,
      'runId': ticket['runId'],
      'startedAt': ticket['startedAt'],
      'receipt': {...receipt, 'runId': ticket['runId']},
    });
    _writePending(owner, entries);
  }

  Future<Map<String, dynamic>?> _uploadPending(
    String owner,
    Map<String, dynamic> entry,
    int epoch,
  ) async {
    final key = '$owner/${entry['runId']}';
    if (!_currentIdentity(epoch) ||
        accountId != owner ||
        entry['expired'] == true ||
        !_uploads.add(key)) {
      return null;
    }
    try {
      final result = await api.request(
        'POST',
        '/api/runs/finish',
        Map<String, dynamic>.from(entry['receipt'] as Map),
      );
      if (!_currentIdentity(epoch) || owner != accountId) return null;
      if (result['accepted'] == true) {
        final entries = _pending(owner);
        if (result['qualified'] == true) {
          for (final pending in entries) {
            if (pending['runId'] == entry['runId']) {
              pending['accepted'] = true;
              pending['qualified'] = true;
            }
          }
        } else {
          entries.removeWhere((pending) => pending['runId'] == entry['runId']);
        }
        _writePending(owner, entries);
        _mergeProgress(result['progress']);
        _saveUnlocks(owner, unlocked);
        cloudStatus = 'Run saved to cloud';
      }
      return result;
    } catch (error) {
      if (_currentIdentity(epoch) && owner == accountId) {
        if (error.toString().contains('run expired')) {
          final entries = _pending(owner);
          for (final pending in entries) {
            if (pending['runId'] == entry['runId']) pending['expired'] = true;
          }
          _writePending(owner, entries);
          cloudStatus =
              'Cloud ticket expired after 24 hours · local result retained';
        } else {
          cloudStatus = 'Local result saved · cloud retry pending · $error';
        }
      }
      return null;
    } finally {
      _uploads.remove(key);
    }
  }

  Future<void> _retryPending() async {
    final owner = accountId;
    final epoch = _identityEpoch;
    if (owner == null) return;
    for (final entry in _pending(owner)) {
      if (!_currentIdentity(epoch) || accountId != owner) return;
      if (entry['accepted'] != true) await _uploadPending(owner, entry, epoch);
    }
    if (_currentIdentity(epoch) &&
        accountId == owner &&
        screen == AppScreen.garage &&
        !busy) {
      final candidates = _pending(owner).where(
        (entry) => entry['accepted'] == true && entry['qualified'] == true,
      );
      if (candidates.isNotEmpty) {
        _presentQualification(owner, candidates.first, AppScreen.garage);
      }
    }
    _notify();
  }

  void _presentQualification(
    String owner,
    Map<String, dynamic> entry,
    AppScreen returnScreen,
  ) {
    _rankingEntry = entry;
    _rankingOwner = owner;
    _rankingReturnScreen = returnScreen;
    initials.fillRange(0, initials.length, 'A');
    screen = AppScreen.initials;
  }

  void _forgetQualification() {
    final owner = _rankingOwner;
    final entry = _rankingEntry;
    if (owner != null && entry != null) {
      _writePending(
        owner,
        _pending(owner)
          ..removeWhere((pending) => pending['runId'] == entry['runId']),
      );
    }
    _rankingEntry = null;
    _rankingOwner = null;
  }

  void select(CarSpec value) {
    if (busy || screen == AppScreen.racing || !unlocked.contains(value.id)) {
      return;
    }
    selected = value;
    _clearTicket();
    _notify();
    unawaited(_prepareTicket());
  }

  Future<void> _prepareTicket() async {
    final owner = accountId;
    final carId = selected.id;
    final epoch = _identityEpoch;
    if (owner == null || _disposed || screen == AppScreen.racing) return;
    final request = ++_ticketEpoch;
    try {
      final ticket = await api.request('POST', '/api/runs/start', {
        'carId': carId,
      });
      if (!_currentIdentity(epoch) ||
          request != _ticketEpoch ||
          owner != accountId ||
          carId != selected.id ||
          screen == AppScreen.racing) {
        return;
      }
      if (ticket['runId'] is! String || ticket['seed'] is! num) return;
      _ticket = ticket;
      _ticketAccount = owner;
      _ticketCar = carId;
    } catch (_) {
      /* A cloud ticket is optional for local driving. */
    }
  }

  Future<void> start() async {
    if (busy || _disposed) return;
    final activity = ++_activityEpoch;
    busy = true;
    _notify();
    unawaited(platform.beginAudio());
    unawaited(platform.requestLandscape());
    if (accountId != null && _ticket == null) {
      try {
        await _prepareTicket().timeout(const Duration(seconds: 3));
      } catch (_) {
        /* Continue locally. */
      }
    }
    if (_disposed || activity != _activityEpoch) return;
    _activeTicket = _ticketAccount == accountId && _ticketCar == selected.id
        ? _ticket
        : null;
    _activeAccount = _activeTicket != null ? accountId : null;
    _activeIdentityEpoch = _activeTicket != null ? _identityEpoch : null;
    _runOwner = accountId;
    _clearTicket(); // Also invalidate ticket requests which exceeded the deadline.
    _handledFinish = false;
    _rankingEntry = null;
    _rankingOwner = null;
    _finishing = false;
    lastRadio = '';
    initials.fillRange(0, initials.length, 'A');
    race.unlockedCarIds = Set.of(unlocked);
    race.comfortMode = steadyHorizon;
    race.motionControl = tilt;
    race.start(selected, seed: (_activeTicket?['seed'] as num?)?.toInt());
    race.paused = false;
    platform.pause(false);
    runSerial++;
    screen = AppScreen.racing;
    busy = false;
    if (_activeTicket == null) {
      cloudStatus = 'This run is local · no global record';
    }
    _notify();
  }

  void _raceChanged() {
    if (_disposed || screen != AppScreen.racing) return;
    platform.setAudioState(
      speed: (race.speed / race.car.topSpeed).clamp(0, 1),
      intensity: (1 - race.remaining / 100).clamp(0, 1),
      region: race.stageName,
    );
    if (race.radio.isNotEmpty && race.radio != lastRadio) {
      lastRadio = race.radio;
      platform.say(lastRadio);
    }
    if (race.finished && !_handledFinish) {
      _handledFinish = true;
      unawaited(_finish());
    }
    _notify();
  }

  Future<void> _finish() async {
    _finishing = true;
    platform.pause(true);
    final run = runSerial;
    final activity = _activityEpoch;
    final epoch = _identityEpoch;
    final local = _localUnlocks(_runOwner)..addAll(race.earnedUnlockIds);
    _saveUnlocks(_runOwner, local);
    if (_runOwner == accountId) unlocked.addAll(local);
    final ticket = _activeTicket;
    final owner = _activeAccount;
    var qualified = false;
    final receipt = race.receipt;
    if (ticket != null && owner != null && receipt != null) {
      _queueReceipt(owner, ticket, receipt.toJson());
      if (owner == accountId && _activeIdentityEpoch == epoch) {
        final entry = _pending(owner)
            .firstWhere((entry) => entry['runId'] == ticket['runId']);
        final result = await _uploadPending(owner, entry, epoch);
        if (_currentIdentity(epoch) && owner == accountId) {
          qualified = result?['qualified'] == true;
        }
      }
    }
    if (_disposed || activity != _activityEpoch || run != runSerial) return;
    _finishing = false;
    if (qualified && owner != null && ticket != null) {
      final entry = _pending(owner)
          .where((entry) => entry['runId'] == ticket['runId'])
          .firstOrNull;
      if (entry != null) {
        _presentQualification(owner, entry, AppScreen.recap);
      } else {
        screen = AppScreen.recap;
      }
    } else {
      screen = AppScreen.recap;
    }
    _notify();
  }

  Future<void> submitInitials() async {
    if (busy || _disposed || screen != AppScreen.initials) return;
    final entry = _rankingEntry;
    final epoch = _identityEpoch;
    if (entry == null || _rankingOwner != accountId) {
      screen = _rankingReturnScreen;
      _notify();
      return;
    }
    final activity = ++_activityEpoch;
    busy = true;
    _notify();
    try {
      final result = await api.request('POST', '/api/hall-of-fame', {
        'runId': entry['runId'],
        'initials': initials.join(),
      });
      if (!_currentIdentity(epoch) || activity != _activityEpoch) return;
      _forgetQualification();
      cloudStatus = result['entry'] == null
          ? 'Run saved · another time took the last place'
          : 'Hall of Fame entry saved';
      screen = _rankingReturnScreen;
    } catch (e) {
      if (!_currentIdentity(epoch) || activity != _activityEpoch) return;
      cloudStatus = e.toString();
    } finally {
      if (!_disposed && activity == _activityEpoch) {
        busy = false;
        _notify();
      }
    }
  }

  void skipInitials() {
    _activityEpoch++;
    busy = false;
    _forgetQualification();
    screen = _rankingReturnScreen;
    _notify();
  }

  void garage() {
    _activityEpoch++;
    _finishing = false;
    busy = false;
    race.paused = true;
    race.steering = 0;
    race.braking = false;
    platform.pause(true);
    screen = AppScreen.garage;
    _activeTicket = null;
    _activeAccount = null;
    unawaited(_prepareTicket());
    unawaited(_retryPending());
    _notify();
  }

  Future<void> showHall() async {
    final activity = ++_activityEpoch;
    race.paused = true;
    platform.pause(true);
    screen = AppScreen.hall;
    busy = true;
    _notify();
    try {
      final response = await api.request('GET', '/api/hall-of-fame');
      if (_disposed || activity != _activityEpoch) return;
      hall = (response['entries'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      cloudStatus = hall.isEmpty
          ? 'The road is open. Set the first time.'
          : 'Global Hall of Fame';
    } catch (e) {
      if (_disposed || activity != _activityEpoch) return;
      cloudStatus = e.toString();
    }
    busy = false;
    _notify();
  }

  void pause(bool value) {
    race.paused = value;
    race.braking = false;
    race.steering = 0;
    platform.pause(value);
    _notify();
  }

  Future<void> toggleTilt() async {
    if (tilt) {
      platform.disableTilt();
      tilt = false;
    } else {
      final enabled = await platform.enableTilt();
      if (_disposed) return;
      tilt = enabled;
    }
    race.motionControl = tilt;
    _notify();
  }

  void setTiltEnabled(bool enabled) {
    if (_disposed) return;
    tilt = enabled;
    race.motionControl = enabled;
    if (!enabled) race.steering = 0;
    _notify();
  }

  void toggleMute() {
    muted = !muted;
    platform.muted = muted;
    store.write('cannonball.muted', '$muted');
    _notify();
  }

  void toggleHorizon() {
    steadyHorizon = !steadyHorizon;
    race.comfortMode = steadyHorizon;
    store.write('cannonball.steady', '$steadyHorizon');
    _notify();
  }

  Future<String?> challenge() async {
    final epoch = _identityEpoch;
    try {
      final value = await api.request('GET', '/api/auth/challenge');
      return _currentIdentity(epoch) ? value['nonce'] as String? : null;
    } catch (e) {
      if (_currentIdentity(epoch)) {
        cloudStatus = e.toString();
        _notify();
      }
      return null;
    }
  }

  // Serialize cookie mutations as well as guarding Dart responses. An epoch
  // alone cannot prevent an older HTTP response overwriting the browser cookie.
  Future<T> _queueAuth<T>(Future<T> Function() action) {
    final result = Completer<T>();
    _authPending++;
    _authQueue = _authQueue.then((_) async {
      try {
        result.complete(await action());
      } catch (error, stack) {
        result.completeError(error, stack);
      } finally {
        _authPending--;
      }
    });
    return result.future;
  }

  Future<bool> signIn(String credential) {
    final epoch = ++_identityEpoch;
    _clearTicket();
    return _queueAuth(() async {
      if (!_currentIdentity(epoch)) return false;
      try {
        final state = await api.request('POST', '/api/auth/google', {
          'credential': credential,
        });
        if (!_currentIdentity(epoch)) return false;
        _applyAccount(state);
        _notify();
        return accountId != null;
      } catch (e) {
        if (_currentIdentity(epoch)) {
          await _recoverIdentity(epoch);
          if (!_currentIdentity(epoch)) return false;
          cloudStatus = e.toString();
          _notify();
        }
        return false;
      }
    });
  }

  Future<void> signOut() {
    final epoch = ++_identityEpoch;
    _clearTicket();
    return _queueAuth(() async {
      if (_disposed) return;
      try {
        await api.request('POST', '/api/auth/logout', {});
      } catch (e) {
        if (_currentIdentity(epoch)) {
          await _recoverIdentity(epoch);
          if (!_currentIdentity(epoch)) return;
          cloudStatus = e.toString();
          _notify();
        }
        return;
      }
      if (!_currentIdentity(epoch)) return;
      accountId = null;
      _restoreOwner(null);
      selected = cars.first;
      if (screen == AppScreen.initials) screen = _rankingReturnScreen;
      _rankingEntry = null;
      _rankingOwner = null;
      cloudStatus = 'Signed out · guest progress restored';
      _notify();
    });
  }

  Future<void> _recoverIdentity(int epoch) async {
    try {
      final state = await api.request('GET', '/api/session');
      if (_currentIdentity(epoch)) _applyAccount(state);
    } catch (_) {
      /* Keep the known local profile when the network is unavailable. */
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _identityEpoch++;
    race.removeListener(_raceChanged);
    race.dispose();
    api.close();
    platform.dispose();
    super.dispose();
  }
}
