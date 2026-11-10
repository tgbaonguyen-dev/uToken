import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/data/local_prefs.dart';
import '../../core/data/usage_repository.dart';
import '../../core/models/usage_docs.dart';
import 'judge.dart';

/// Steps shown while a phone review runs.
enum JudgeStep { idle, reading, asking, checking, done, failed }

/// Provider, model and API key for the on-phone AI review (SRS FR-AIKEY-001).
/// The key lives only in Android Keystore (flutter_secure_storage); it is
/// never written to Firestore, logs or exports.
class PhoneJudge extends ChangeNotifier {
  PhoneJudge(this._store, {http.Client? client})
      : _client = client ?? http.Client();

  static PhoneJudge instance = PhoneJudge(MemoryPrefsStore());

  final PrefsStore _store;
  final http.Client _client;

  String _provider = 'google';
  String _model = defaultJudgeModel('google');
  String? _key;
  bool _loaded = false;

  JudgeStep step = JudgeStep.idle;
  String? errorCode;

  String get provider => _provider;
  String get model => _model;
  bool get hasKey => _key != null && _key!.isNotEmpty;
  bool get running =>
      step == JudgeStep.reading ||
      step == JudgeStep.asking ||
      step == JudgeStep.checking;

  /// Last 4 characters, for "••••abcd" in settings.
  String? get keyHint =>
      hasKey && _key!.length > 4 ? _key!.substring(_key!.length - 4) : null;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      _provider = await _store.read('ai_provider') ?? _provider;
      if (!judgeProviders.contains(_provider)) _provider = 'google';
      _model = await _store.read('ai_model') ?? defaultJudgeModel(_provider);
      final key = await _store.read('ai_key_$_provider');
      _key = key == null || key.isEmpty ? null : key;
    } catch (e) {
      debugPrint('Could not read AI settings: $e');
    }
    notifyListeners();
  }

  /// Saves settings. A null [apiKey] keeps the stored key for that provider.
  Future<void> save(
      {required String provider, required String model, String? apiKey}) async {
    _provider = provider;
    _model = model.trim().isEmpty ? defaultJudgeModel(provider) : model.trim();
    await _store.write('ai_provider', _provider);
    await _store.write('ai_model', _model);
    if (apiKey != null) {
      await _store.write('ai_key_$provider', apiKey.trim());
      _key = apiKey.trim().isEmpty ? null : apiKey.trim();
    } else {
      final key = await _store.read('ai_key_$provider');
      _key = key == null || key.isEmpty ? null : key;
    }
    notifyListeners();
  }

  Future<void> removeKey() async {
    await _store.write('ai_key_$_provider', '');
    _key = null;
    notifyListeners();
  }

  /// Checks a key/model pair without touching the saved settings.
  Future<String?> test(
      {required String provider,
      required String model,
      required String apiKey}) async {
    try {
      await testProvider(
          client: _client, provider: provider, model: model, apiKey: apiKey);
      return null;
    } on JudgeException catch (e) {
      return e.code;
    }
  }

  /// Tests the stored key for [provider] with [model].
  Future<String?> testSaved(
      {required String provider, required String model}) async {
    final key = await _store.read('ai_key_$provider');
    if (key == null || key.isEmpty) return 'missing_key';
    return test(
        provider: provider,
        model:
            model.trim().isEmpty ? defaultJudgeModel(provider) : model.trim(),
        apiKey: key);
  }

  void _set(JudgeStep s, [String? code]) {
    step = s;
    errorCode = code;
    notifyListeners();
  }

  /// Runs a review and writes users/{uid}/insights/current.
  /// On failure the previous insights stay and get a failed status + code.
  Future<void> run(
      {required String uid,
      required UsageRepository repository,
      required String language}) async {
    if (running) return;
    if (!hasKey) return _set(JudgeStep.failed, 'missing_key');
    _set(JudgeStep.reading);
    try {
      final daily = await repository
          .watchDaily(uid: uid)
          .first
          .timeout(const Duration(seconds: 20));
      EfficiencyDoc? efficiency;
      try {
        efficiency = await repository
            .watchEfficiency(uid: uid)
            .first
            .timeout(const Duration(seconds: 10));
      } catch (_) {}
      _set(JudgeStep.asking);
      final doc = await runJudge(
          client: _client,
          daily: daily,
          efficiency: efficiency,
          provider: _provider,
          model: _model,
          apiKey: _key!,
          language: language);
      _set(JudgeStep.checking);
      await repository.saveInsights(uid: uid, values: doc);
      _set(JudgeStep.done);
    } on JudgeException catch (e) {
      await _markFailed(uid, repository, e.code);
    } catch (e) {
      debugPrint('Phone AI review failed: $e');
      await _markFailed(uid, repository, 'provider_error');
    }
  }

  Future<void> _markFailed(
      String uid, UsageRepository repository, String code) async {
    try {
      await repository.saveInsights(
          uid: uid,
          values: {'status': 'failed', 'error_code': code, 'source': 'phone'},
          merge: true);
    } catch (_) {}
    _set(JudgeStep.failed, code);
  }

  void reset() {
    if (!running) _set(JudgeStep.idle);
  }
}
