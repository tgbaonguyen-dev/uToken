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
    _remote = repository.watchPreferences(uid: uid).listen(
      (values) async {
        if (values != null) {
          _apply(values);
        } else if (_cachedFor == uid) {
          // Nothing on the account yet: publish this phone's values.
          await _push();
        } else {
          // Cache belongs to another account; start clean.
          _apply(const {});
        }
        _cachedFor = uid;
        await _store.write('prefs_uid', uid);
      },
      onError: (Object error) =>
          debugPrint('Could not read account preferences: $error'),
    );
  }

  void unbindAccount() {
    _remote?.cancel();
    _remote = null;
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
    _cache();
  }

  Future<void> _push() async {
    final uid = _uid, repository = _repository;
    if (uid == null || repository == null) return;
    try {
      await repository.savePreferences(uid: uid, values: _values);
    } catch (error) {
      debugPrint('Could not save account preferences: $error');
    }
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
    await _store.write('budget_usd', usd?.toString() ?? '');
    await _push();
  }

  Future<void> setTokenFormat(TokenFormat format) async {
    _tokenFormat = format;
    notifyListeners();
    await _store.write(
        'token_format', format == TokenFormat.full ? 'full' : 'compact');
    await _push();
  }

  Future<void> markReviewed(String insightId) async {
    if (!_reviewed.add(insightId)) return;
    notifyListeners();
    await _store.write('reviewed_insights', jsonEncode(_reviewed.toList()));
    await _push();
  }
}
