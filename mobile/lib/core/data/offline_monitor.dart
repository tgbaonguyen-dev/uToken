import 'dart:async';

import '../ui/ut_kit.dart' show utOffline;
import 'usage_repository.dart';

/// Feeds [utOffline] from the signed-in account's Firestore metadata.
///
/// Going offline is shown after a short grace period, so the cache-first
/// snapshot at startup or a brief network blip doesn't flash the strip.
/// Coming back online hides it at once.
class OfflineMonitor {
  OfflineMonitor._();

  static String? _uid;
  static StreamSubscription<bool>? _sub;
  static Timer? _grace;
  static const grace = Duration(seconds: 3);

  static void bind(String uid, UsageRepository repository) {
    if (_uid == uid) return;
    unbind();
    _uid = uid;
    _sub = repository.watchOffline(uid: uid).listen((fromCache) {
      _grace?.cancel();
      if (!fromCache) {
        utOffline.value = false;
      } else {
        _grace = Timer(grace, () => utOffline.value = true);
      }
    }, onError: (_) {});
  }

  static void unbind() {
    _sub?.cancel();
    _sub = null;
    _grace?.cancel();
    _uid = null;
    utOffline.value = false;
  }
}
