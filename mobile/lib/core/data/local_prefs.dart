import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../format/token_format.dart';

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

/// Preferences that live only on this phone (they are not synced).
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
  bool isReviewed(String insightId) => _reviewed.contains(insightId);

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
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
  }

  Future<void> setTokenFormat(TokenFormat format) async {
    _tokenFormat = format;
    notifyListeners();
    await _store.write(
        'token_format', format == TokenFormat.full ? 'full' : 'compact');
  }

  Future<void> markReviewed(String insightId) async {
    if (!_reviewed.add(insightId)) return;
    notifyListeners();
    await _store.write('reviewed_insights', jsonEncode(_reviewed.toList()));
  }
}
