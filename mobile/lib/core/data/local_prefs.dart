import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../format/token_format.dart';
import 'usage_repository.dart';

/// Key/value backend so tests can run without platform channels.
abstract interface class PrefsStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class SecurePrefsStore implements PrefsStore {
  const SecurePrefsStore();
  static const _storage = FlutterSecureStorage();
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

class MemoryPrefsStore implements PrefsStore {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

/// Account preferences. They are cached on this phone and, while signed in,
/// mirrored to users/{uid}/preferences/mobile so every phone sees the same values.
class LocalPrefs extends ChangeNotifier {
  LocalPrefs(this._store);

  /// App-wide instance; main() swaps in secure storage.
  static LocalPrefs instance = LocalPrefs(MemoryPrefsStore());

  final PrefsStore _store;
  bool _loaded = false;
  String? saveError;
  bool isSaving = false;
  bool _pending = false;
  int _version = 0;
  Future<void>? _writes;
  Future<void>? _localWrites;
  Future<void> retrySave() => _save();

  double? _budgetUsd;
  TokenFormat _tokenFormat = TokenFormat.compact;
  final Set<String> _reviewed = {};

  double? get monthlyBudgetUsd => _budgetUsd;
  TokenFormat get tokenFormat => _tokenFormat;

  /// App language: 'en' or 'vi'. Stored on this phone only.
  String _language = 'en';
  String get language => _language;
  bool get vietnamese => _language == 'vi';

  Future<void> setLanguage(String code) async {
    _language = code == 'vi' ? 'vi' : 'en';
    notifyListeners();
    await _store.write('language', _language);
  }

  bool isReviewed(String insightId) => _reviewed.contains(insightId);

  /// Admin notices already seen on this phone (local only, not synced).
  final Set<String> _readNotices = {};
  bool isNoticeRead(String id) => _readNotices.contains(id);

  Future<void> markNoticesRead(Iterable<String> ids) async {
    var changed = false;
    for (final id in ids) {
      changed |= _readNotices.add(id);
    }
    if (!changed) return;
    notifyListeners();
    try {
      await _store.write('read_notices', jsonEncode(_readNotices.toList()));
    } catch (error) {
      debugPrint('Could not save read notices: $error');
    }
  }

  StreamSubscription<Map<String, dynamic>?>? _remote;
  String? _uid;

  /// Account the cached values belong to.
  String? _cachedFor;
  UsageRepository? _repository;

  /// Follows the account copy for [uid]; local changes are written back.
  void bindAccount(String uid, UsageRepository repository) {
    if (_uid == uid && _repository == repository) return;
    unbindAccount();
    _uid = uid;
    _repository = repository;
    final restored = _restorePending(uid, repository);
    _remote = repository.watchPreferences(uid: uid).listen(
      (values) async {
        await restored;
        if (_uid != uid || _repository != repository) return;
        if (_pending && _cachedFor == uid) return;
        if (values != null) {
          _apply(values);
        } else if (_cachedFor == uid) {
          // Nothing on the account yet: publish this phone's values.
          await _push();
        } else {
          // Cache belongs to another account; start clean.
          _apply(const {});
        }
        if (_uid != uid || _repository != repository) return;
        _cachedFor = uid;
        try {
          await _store.write('prefs_uid', uid);
        } catch (_) {
          saveError = 'Preferences could not be saved. Retry saving.';
          notifyListeners();
        }
      },
      onError: (Object error) =>
          debugPrint('Could not read account preferences: $error'),
    );
  }

  void unbindAccount() {
    _remote?.cancel();
    _remote = null;
    _version++;
    _writes = null;
    _pending = false;
    saveError = null;
    isSaving = false;
    _uid = null;
    _repository = null;
  }

  Map<String, dynamic> get _values => {
        'budget_usd': _budgetUsd,
        'token_format': _tokenFormat == TokenFormat.full ? 'full' : 'compact',
        'reviewed_insights': _reviewed.toList()..sort(),
      };

  void _apply(Map<String, dynamic> values) {
    final budget = values['budget_usd'];
    _budgetUsd = budget is num ? budget.toDouble() : null;
    _tokenFormat = values['token_format'] == 'full'
        ? TokenFormat.full
        : TokenFormat.compact;
    final reviewed = values['reviewed_insights'];
    _reviewed
      ..clear()
      ..addAll(reviewed is List ? reviewed.whereType<String>() : const []);
    notifyListeners();
    unawaited(_cache().catchError((Object _) {
      saveError = "Preferences could not be saved. Retry saving.";
      notifyListeners();
    }));
  }

  Future<void> _push() => _save();

  String _pendingKey(String uid) => 'pending_preferences_$uid';

  Future<void> _restorePending(String uid, UsageRepository repository) async {
    final version = _version;
    try {
      final raw = await _store.read(_pendingKey(uid));
      if (_uid != uid ||
          _repository != repository ||
          _version != version ||
          raw == null ||
          raw.isEmpty) {
        return;
      }
      final values = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      _pending = true;
      _cachedFor = uid;
      _apply(values);
      saveError =
          'Preferences are waiting to be saved to your account. Retry saving.';
      notifyListeners();
    } catch (_) {
      if (_uid == uid && _repository == repository && _version == version) {
        saveError =
            'Could not restore pending preferences. Check local storage.';
        notifyListeners();
      }
    }
  }

  Future<void> _save() {
    final uid = _uid, repository = _repository;
    final version = ++_version;
    final values = _values;
    _pending = true;
    _cachedFor = uid;
    isSaving = true;
    saveError = null;
    notifyListeners();
    // Persist every intent independently of an older network write waiting offline.
    var persisted = false;
    final local = (_localWrites ?? Future<void>.value()).then((_) async {
      if (uid == null && _uid != null) return;
      try {
        if (uid != null) {
          await _store.write(_pendingKey(uid), jsonEncode(values));
        }
        if (_uid != uid || _repository != repository) {
          persisted = true;
          return;
        }
        await _store.write(
            'budget_usd', (values['budget_usd'] as double?)?.toString() ?? '');
        await _store.write('token_format', values['token_format'] as String);
        await _store.write(
            'reviewed_insights', jsonEncode(values['reviewed_insights']));
        if (uid != null) await _store.write('prefs_uid', uid);
        persisted = true;
      } catch (_) {
        if (_version == version) {
          saveError = 'Preferences could not be saved locally. Retry saving.';
          notifyListeners();
        }
      }
    });
    _localWrites = local;
    final task = (_writes ?? Future<void>.value()).then((_) async {
      await local;
      if (!persisted || _uid != uid || _repository != repository) return;
      try {
        if (uid != null && repository != null) {
          await repository.savePreferences(uid: uid, values: values);
        }
        final clear = (_localWrites ?? Future<void>.value()).then((_) async {
          if (_version != version || _uid != uid || _repository != repository) {
            return;
          }
          if (uid != null) await _store.write(_pendingKey(uid), '');
          if (_version == version) _pending = false;
        });
        _localWrites = clear;
        await clear;
      } catch (_) {
        if (_version == version) {
          saveError =
              'Preferences could not be saved. Your changes are kept here; retry saving.';
        }
      }
    }).whenComplete(() {
      if (_version == version) {
        isSaving = false;
        notifyListeners();
      }
    });
    _writes = task;
    return task;
  }

  Future<void> _cache() async {
    await _store.write('budget_usd', _budgetUsd?.toString() ?? '');
    await _store.write(
        'token_format', _tokenFormat == TokenFormat.full ? 'full' : 'compact');
    await _store.write('reviewed_insights', jsonEncode(_reviewed.toList()));
  }

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      _cachedFor = await _store.read('prefs_uid');
      _language = (await _store.read('language')) == 'vi' ? 'vi' : 'en';
      _budgetUsd = double.tryParse(await _store.read('budget_usd') ?? '');
      _tokenFormat = (await _store.read('token_format')) == 'full'
          ? TokenFormat.full
          : TokenFormat.compact;
      final notices = await _store.read('read_notices');
      if (notices != null) {
        _readNotices.addAll((jsonDecode(notices) as List).cast<String>());
      }
      final reviewed = await _store.read('reviewed_insights');
      if (reviewed != null) {
        _reviewed.addAll((jsonDecode(reviewed) as List).cast<String>());
      }
    } catch (error) {
      debugPrint('Could not read local preferences: $error');
    }
    notifyListeners();
  }

  Future<void> setMonthlyBudget(double? usd) async {
    _budgetUsd = usd;
    notifyListeners();
    await _save();
  }

  Future<void> setTokenFormat(TokenFormat format) async {
    _tokenFormat = format;
    notifyListeners();
    await _save();
  }

  Future<void> markReviewed(String insightId) async {
    if (!_reviewed.add(insightId)) return;
    notifyListeners();
    await _save();
  }
}
