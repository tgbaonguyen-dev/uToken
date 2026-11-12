import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/data/usage_repository.dart';

enum SyncPhase {
  /// Nothing in flight.
  idle,

  /// S03: request written, waiting for the desktop to pick it up or finish.
  syncing,

  /// S04: the desktop didn't answer in time or reported a failure.
  failed,
}

/// One sync flow per account (FR-SYNC-001), shared by the refresh button,
/// pull-to-refresh, Sync now and the automatic `screen_open` request.
///
/// - Single-flight: while a request is pending no new one is written.
/// - S03 while waiting; S04 when the desktop doesn't pick the request up
///   within [pickupTimeout] (COMPANION_OFFLINE) or reports `failed`.
/// - Old data stays on screen in every phase; this only drives banners.
class SyncCenter extends ChangeNotifier {
  SyncCenter._(this.repository, this.uid);

  static final _centers = <String, SyncCenter>{};

  /// The shared center for this repository and account.
  static SyncCenter of(UsageRepository repository, String uid) {
    final key = '${identityHashCode(repository)}/$uid';
    return _centers.putIfAbsent(key, () => SyncCenter._(repository, uid));
  }

  /// Drops every center (sign-out, tests).
  static void resetAll() {
    for (final c in _centers.values) {
      c._stop();
    }
    _centers.clear();
  }

  final UsageRepository repository;
  final String uid;

  /// SRS: desktop must react within 30 s, otherwise show S04.
  static Duration pickupTimeout = const Duration(seconds: 30);

  /// Once running, a scan should not take longer than this.
  static Duration runTimeout = const Duration(minutes: 3);

  /// Don't auto-request on screen open more often than this.
  static const autoInterval = Duration(minutes: 15);

  SyncPhase phase = SyncPhase.idle;

  /// Request state reported by the desktop: pending, running, done, failed.
  String? requestState;

  /// Error code for S04: `companion_offline`, `timeout`, `firebase`, or
  /// the desktop's own `error_code`.
  String? errorCode;

  /// When the last request finished successfully.
  DateTime? lastDone;

  DateTime? _lastAuto;
  StreamSubscription<SyncRequestStatus?>? _sub;
  Timer? _timer;

  bool get busy => phase == SyncPhase.syncing;

  /// Starts a sync unless one is already running. Returns false when skipped.
  Future<bool> start({String trigger = 'manual_refresh'}) async {
    if (busy) return false;
    _stop();
    phase = SyncPhase.syncing;
    requestState = 'pending';
    errorCode = null;
    notifyListeners();
    final String id;
    try {
      id = await repository.requestSync(uid: uid, trigger: trigger);
    } catch (error) {
      debugPrint('Could not ask the desktop to sync: $error');
      _fail('firebase');
      return true;
    }
    _timer = Timer(pickupTimeout, () => _fail('companion_offline'));
    _sub = repository.watchSyncRequest(uid: uid, id: id).listen((status) {
      if (status == null || status.state == requestState) return;
      requestState = status.state;
      switch (status.state) {
        case 'running':
          _timer?.cancel();
          _timer = Timer(runTimeout, () => _fail('timeout'));
          notifyListeners();
        case 'done':
          _stop();
          phase = SyncPhase.idle;
          lastDone = DateTime.now();
          notifyListeners();
        case 'failed':
          _fail(status.errorCode ?? 'unknown');
        default:
          notifyListeners();
      }
    }, onError: (Object e) => _fail('firebase'));
    return true;
  }

  /// FR-SYNC-001: on opening Tokens, ask for a sync when the data is older
  /// than [autoInterval]. Quiet: at most once per interval.
  void maybeAutoSync(DateTime? lastSync) {
    final now = DateTime.now();
    if (lastSync == null || busy) return;
    if (now.difference(lastSync) < autoInterval) return;
    if (_lastAuto != null && now.difference(_lastAuto!) < autoInterval) {
      return;
    }
    _lastAuto = now;
    start(trigger: 'screen_open');
  }

  /// Hides S04 without retrying.
  void dismiss() {
    if (phase != SyncPhase.failed) return;
    phase = SyncPhase.idle;
    notifyListeners();
  }

  void _fail(String code) {
    _stop();
    phase = SyncPhase.failed;
    errorCode = code;
    notifyListeners();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _sub?.cancel();
    _sub = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }
}
