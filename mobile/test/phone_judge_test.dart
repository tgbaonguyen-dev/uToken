import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:utoken_mobile/core/data/local_prefs.dart';
import 'package:utoken_mobile/core/data/usage_aggregates.dart';
import 'package:utoken_mobile/core/data/usage_repository.dart';
import 'package:utoken_mobile/core/models/usage_docs.dart';
import 'package:utoken_mobile/features/ai_review/phone_judge.dart';
import 'package:utoken_mobile/features/ai_review/review_window.dart';

import 'live/live_screens_test.dart' show FakeUsageRepository, keyedDoc;

class _PhoneRepository extends FakeUsageRepository {
  @override
  Stream<EfficiencyDoc?> watchEfficiency({required String uid}) =>
      Stream.value(null);
}

void main() {
  Future<_ReviewHarness> open() async {
    final harness = _ReviewHarness();
    addTearDown(harness.dispose);
    await harness.judge
        .save(provider: 'google', model: 'test-model', apiKey: 'fake-key');
    return harness;
  }

  test('new usage needs an account baseline and never borrows another UID',
      () async {
    final h = await open();
    await h.run(ReviewScope.sinceLastReview);
    expect(h.judge.errorCode, 'review_checkpoint_missing');
    expect(h.calls, 0);
    await h.run(ReviewScope.last30Days);
    h.addTokens(120);
    await h.run(ReviewScope.sinceLastReview, uid: 'B');
    expect(h.judge.errorCode, 'review_checkpoint_missing');
    expect(h.calls, 1);
    await h.run(ReviewScope.sinceLastReview);
    expect(h.input, '120');
    expect(h.judge.step, JudgeStep.done);
  });

  test(
      'same-day new usage survives restart and does not replay historical metrics',
      () async {
    final h = await open();
    await h.run(ReviewScope.last30Days);
    final from = h.now;
    h.addTokens(120);
    h.now = h.now.add(const Duration(minutes: 5));
    final reopened = PhoneJudge(h.store, client: h.client, now: () => h.now);
    addTearDown(reopened.dispose);
    await reopened.load();
    await reopened.run(
        uid: 'A',
        repository: h.repo,
        language: 'English',
        scope: ReviewScope.sinceLastReview);
    expect(h.input, '120');
    expect(h.brief['catalog'], isNot(contains('outcome.success_rate')));
    expect(h.repo.savedInsights.last['review_from'],
        from.toUtc().toIso8601String());
    expect(h.repo.savedInsights.last['review_through'],
        h.now.toUtc().toIso8601String());
  });

  test('30-day review includes history and becomes the shared latest baseline',
      () async {
    final h = await open();
    await h.run(ReviewScope.last30Days);
    expect(h.input, '3000');
    h.addTokens(100);
    await h.run(ReviewScope.sinceLastReview);
    expect(h.input, '100');
    h.addTokens(200);
    await h.run(ReviewScope.last30Days);
    expect(h.input, '3300');
    h.addTokens(50);
    await h.run(ReviewScope.sinceLastReview);
    expect(h.input, '50');
  });

  test('no new usage makes no paid call and does not move the baseline',
      () async {
    final h = await open();
    await h.run(ReviewScope.last30Days);
    final baseline = h.store.values['ai_review_checkpoint_v1_A'];
    h.now = h.now.add(const Duration(hours: 2));
    await h.run(ReviewScope.sinceLastReview);
    expect(h.judge.step, JudgeStep.noNewUsage);
    expect(h.calls, 1);
    expect(h.store.values['ai_review_checkpoint_v1_A'], baseline);
  });

  for (final failure in ['provider', 'upload', 'offline']) {
    test('$failure failure does not consume new usage', () async {
      final h = await open();
      await h.run(ReviewScope.last30Days);
      final baseline = h.store.values['ai_review_checkpoint_v1_A'];
      h.addTokens(123);
      h.failModel = failure == 'provider';
      h.repo.failInsights = failure == 'upload';
      if (failure == 'offline') {
        h.repo.refreshHandler = () async => throw Exception('offline');
      }
      await h.run(ReviewScope.sinceLastReview);
      expect(h.judge.step, JudgeStep.failed);
      expect(h.store.values['ai_review_checkpoint_v1_A'], baseline);
      h.failModel = false;
      h.repo.failInsights = false;
      h.repo.refreshHandler = null;
      await h.run(ReviewScope.sinceLastReview);
      expect(h.judge.step, JudgeStep.done);
      expect(h.input, '123');
    });
  }

  test('usage arriving during the model call is reserved for the next review',
      () async {
    final h = await open();
    h.onModel = () {
      h.onModel = null;
      h.addTokens(321);
    };
    await h.run(ReviewScope.last30Days);
    expect(h.input, '3000');
    await h.run(ReviewScope.sinceLastReview);
    expect(h.input, '321');
  });

  test('a long gap does not truncate the new-usage window to 30 days',
      () async {
    final h = await open();
    await h.run(ReviewScope.last30Days);
    final boundary = h.now;
    h.now = h.now.add(const Duration(days: 45));
    h.repo.dailyValues.add(keyedDoc(h.now, {'codex|test-model|none': 75}));
    await h.run(ReviewScope.sinceLastReview);
    expect(h.input, '75');
    expect(h.repo.savedInsights.last['review_from'],
        boundary.toUtc().toIso8601String());
  });

  test(
      'history rollback requires an overview instead of negative or replayed usage',
      () async {
    final h = await open();
    await h.run(ReviewScope.last30Days);
    h.repo.dailyValues[0] = keyedDoc(h.now, {'codex|test-model|none': 500});
    await h.run(ReviewScope.sinceLastReview);
    expect(h.judge.errorCode, 'review_data_changed');
    expect(h.calls, 1);
    await h.run(ReviewScope.last30Days);
    h.addTokens(25);
    await h.run(ReviewScope.sinceLastReview);
    expect(h.input, '25');
  });

  test('insufficient overview data does not establish a successful baseline',
      () async {
    final h = await open();
    h.repo.dailyValues.removeRange(1, 3);
    await h.run(ReviewScope.last30Days);
    expect(h.repo.savedInsights.last['status'], 'insufficient_data');
    expect(h.calls, 0);
    expect(h.store.values['ai_review_checkpoint_v1_A'], isNull);
  });

  test('invalid summaries cannot establish or consume a review baseline',
      () async {
    final h = await open();
    h.repo.parsedDailyStream = Stream.value(
        DailySnapshot(h.repo.dailyValues, invalidDocumentIds: ['2026-11-08']));
    await h.run(ReviewScope.last30Days);
    expect(h.judge.errorCode, 'invalid_review_data');
    expect(h.calls, 0);
    expect(h.store.values['ai_review_checkpoint_v1_A'], isNull);
  });

  test('a corrupted baseline can be recovered with a 30-day review', () async {
    final h = await open();
    h.store.values['ai_review_checkpoint_v1_A'] = '{broken';
    await h.run(ReviewScope.sinceLastReview);
    expect(h.judge.errorCode, 'review_data_changed');
    expect(h.calls, 0);
    await h.run(ReviewScope.last30Days);
    expect(h.judge.step, JudgeStep.done);
    expect(
        ReviewCheckpoint.decode(h.store.values['ai_review_checkpoint_v1_A']!)
            .documents,
        hasLength(3));
  });

  test('checkpoint storage failure is visible and does not silently skip usage',
      () async {
    final h = await open();
    await h.run(ReviewScope.last30Days);
    final baseline = h.store.values['ai_review_checkpoint_v1_A'];
    h.store.failCheckpoint = true;
    h.addTokens(40);
    await h.run(ReviewScope.sinceLastReview);
    expect(h.repo.savedInsights.last['status'], 'ok');
    expect(h.judge.errorCode, 'review_checkpoint_save_error');
    expect(h.store.values['ai_review_checkpoint_v1_A'], baseline);
  });

  test('phone reviews keep the full 30-day window on repeated runs', () async {
    final now = DateTime.now();
    final repo = _PhoneRepository();
    addTearDown(repo.close);
    repo.dailyValues.addAll([
      for (final daysAgo in [1, 2, 29, 31])
        keyedDoc(now.subtract(Duration(days: daysAgo)),
            {'codex|test-model|none': 1000}),
    ]);
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': jsonEncode({
                        'score': 72,
                        'grade': 'B',
                        'headline': 'Synthetic review',
                        'dimensions': [],
                        'insights': [],
                      })
                    }
                  ]
                }
              }
            ]
          }),
          200);
    });
    addTearDown(client.close);
    final judge = PhoneJudge(MemoryPrefsStore(), client: client);
    addTearDown(judge.dispose);
    await judge.save(
        provider: 'google', model: 'test-model', apiKey: 'fake-key');
    for (var i = 0; i < 2; i++) {
      await judge.run(uid: 'test-user', repository: repo, language: 'English');
      expect(judge.step, JudgeStep.done);
      expect(repo.savedInsights.last['status'], 'ok');
      expect(repo.savedInsights.last['period_start'],
          dayKey(now.subtract(const Duration(days: 29))));
      expect(repo.savedInsights.last['period_end'], dayKey(now));
    }
    expect(calls, 2);
    expect(repo.savedInsights, hasLength(2));
  });
}

class _CheckpointStore extends MemoryPrefsStore {
  bool failCheckpoint = false;
  @override
  Future<void> write(String key, String value) async {
    if (failCheckpoint && key.startsWith('ai_review_checkpoint_')) {
      throw Exception('storage unavailable');
    }
    await super.write(key, value);
  }
}

class _ReviewHarness {
  final store = _CheckpointStore();
  final repo = _PhoneRepository();
  DateTime now = DateTime(2026, 11, 11, 10);
  int calls = 0;
  bool failModel = false;
  void Function()? onModel;
  Map<String, dynamic> brief = {};
  late final MockClient client;
  late final PhoneJudge judge;
  String get input => brief['catalog']['usage.input_tokens']['value'] as String;

  _ReviewHarness() {
    for (var i = 0; i < 3; i++) {
      repo.dailyValues.add(keyedDoc(
          now.subtract(Duration(days: i)), {'codex|test-model|none': 1000}));
    }
    client = MockClient((request) async {
      calls++;
      final payload = jsonDecode(request.body);
      brief = jsonDecode(payload['contents'][0]['parts'][0]['text'])
          as Map<String, dynamic>;
      onModel?.call();
      if (failModel) return http.Response('{}', 401);
      return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': jsonEncode({
                        'score': 72,
                        'grade': 'B',
                        'headline': 'Synthetic review',
                        'dimensions': [],
                        'insights': []
                      })
                    }
                  ]
                }
              }
            ]
          }),
          200);
    });
    judge = PhoneJudge(store, client: client, now: () => now);
  }

  void addTokens(int extra) {
    repo.dailyValues[0] = keyedDoc(DateTime(2026, 11, 11),
        {'codex|test-model|none': repo.dailyValues[0].totals.input + extra});
  }

  Future<void> run(ReviewScope scope, {String uid = 'A'}) =>
      judge.run(uid: uid, repository: repo, language: 'English', scope: scope);
  Future<void> dispose() async {
    judge.dispose();
    client.close();
    await repo.close();
  }
}
