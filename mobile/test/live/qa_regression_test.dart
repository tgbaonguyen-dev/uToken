import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utoken_mobile/core/data/local_prefs.dart';
import 'package:utoken_mobile/core/data/usage_repository.dart';
import 'package:utoken_mobile/core/models/daily_doc.dart';
import 'package:utoken_mobile/features/live/analytics_screens.dart';
import 'package:utoken_mobile/features/live/live_common.dart';
import 'package:utoken_mobile/features/live/insights_screens.dart';
import 'package:utoken_mobile/features/live/settings_screens.dart';

import 'console_edits_test.dart' show document;
import 'live_screens_test.dart' show FakeUsageRepository;

void main() {
  setUp(() => LocalPrefs.instance = LocalPrefs(MemoryPrefsStore()));

  test('daily counters reject negatives but retain optional legacy defaults',
      () {
    for (final field in [
      'input',
      'cached',
      'cache_write',
      'output',
      'thinking',
      'cost_micro',
      'side_tokens',
      'chats',
      'requests',
      'error_requests',
      'side_cost_micro',
      'context_growth_count',
      'duration_sum_ms',
      'duration_count',
    ]) {
      expect(() => TokenBreakdown.fromMap({field: -1}), throwsFormatException,
          reason: field);
    }
    expect(TokenBreakdown.fromMap({'input': 0, 'output': 0}).total, 0);
    expect(TokenBreakdown.fromMap({}).thinking, isNull);
    expect(TokenBreakdown.fromMap({'cost_micro': null}).costMicro, isNull);
    final snapshot = parseDailySnapshot({
      '2026-11-11': document('2026-11-11', -1),
      '2026-11-10': document('2026-11-10', 100),
    });
    expect(snapshot.documents.single.totals.total, 120);
    expect(snapshot.invalidDocumentIds, ['2026-11-11']);
  });

  test(
      'profile and sync request malformed values use recoverable format errors',
      () {
    expect(parseDesktopName(null), isNull);
    expect(parseDesktopName({'desktop_name': 'Test desktop'}), 'Test desktop');
    for (final value in [123, [], {}]) {
      expect(() => parseDesktopName({'desktop_name': value}),
          throwsFormatException);
      expect(() => SyncRequestStatus.fromMap({'state': value}),
          throwsFormatException);
      expect(
          () =>
              SyncRequestStatus.fromMap({'state': 'done', 'error_code': value}),
          throwsFormatException);
    }
    expect(() => SyncRequestStatus.fromMap({'state': 'surprise'}),
        throwsFormatException);
    expect(SyncRequestStatus.fromMap({}).state, 'pending');
    expect(SyncRequestStatus.fromMap({'state': 'done'}).finished, isTrue);
  });

  for (final screen in ['Analytics', 'Budget', 'Export']) {
    testWidgets('$screen shows invalid-day warning and removes it on recovery',
        (tester) async {
      final raw = StreamController<Map<String, JsonMap>>();
      final repo = FakeUsageRepository()
        ..parsedDailyStream = raw.stream.map(parseDailySnapshot);
      addTearDown(repo.close);
      addTearDown(raw.close);
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      final args = LiveArgs(
          uid: 'test', repository: repo, now: () => DateTime(2026, 11, 11));
      final widget = switch (screen) {
        'Analytics' => LiveAnalyticsScreen(args: args),
        'Budget' => LiveBudgetScreen(args: args),
        _ => LiveExportScreen(args: args),
      };
      await tester.pumpWidget(MaterialApp(home: widget));
      raw.add({
        '2026-11-11': document('2026-11-11', 'bad'),
        '2026-11-10': document('2026-11-10', 100)
      });
      await tester.pumpAndSettle();
      expect(
          find.byKey(const ValueKey('invalid-daily-warning')), findsOneWidget);
      expect(tester.takeException(), isNull);
      raw.add({'2026-11-11': document('2026-11-11', 100)});
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('invalid-daily-warning')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  test(
      'failed preferences survive restart without old cloud values replacing them',
      () async {
    final store = MemoryPrefsStore();
    final repo = FakeUsageRepository()..failPreferences = true;
    final first = LocalPrefs(store)..bindAccount('A', repo);
    await first.setMonthlyBudget(75);
    expect(first.saveError, isNotNull);
    first.unbindAccount();
    final restarted = LocalPrefs(store);
    await restarted.load();
    restarted.bindAccount('A', repo);
    repo.prefs.add({'budget_usd': 10});
    await Future<void>.delayed(Duration.zero);
    expect(restarted.monthlyBudgetUsd, 75);
    expect(restarted.saveError, isNotNull);
    repo.failPreferences = false;
    await restarted.retrySave();
    expect(repo.savedPrefs.last['budget_usd'], 75);
    expect(restarted.saveError, isNull);
    expect(store.values['pending_preferences_A'], '');
    restarted.unbindAccount();
    await repo.close();
  });

  test('pending preferences stay isolated and recover for both accounts',
      () async {
    final store = MemoryPrefsStore();
    final repo = FakeUsageRepository()..failPreferences = true;
    final prefs = LocalPrefs(store)..bindAccount('A', repo);
    await prefs.setMonthlyBudget(75);
    prefs.bindAccount('B', repo);
    repo.prefs.add({'budget_usd': 20});
    await Future<void>.delayed(Duration.zero);
    expect(prefs.monthlyBudgetUsd, 20);
    await prefs.setMonthlyBudget(25);
    prefs.bindAccount('A', repo);
    await Future<void>.delayed(Duration.zero);
    expect(prefs.monthlyBudgetUsd, 75);
    prefs.bindAccount('B', repo);
    await Future<void>.delayed(Duration.zero);
    expect(prefs.monthlyBudgetUsd, 25);
    expect(
        jsonDecode(store.values['pending_preferences_A']!)['budget_usd'], 75);
    prefs.unbindAccount();
    await repo.close();
  });
  test(
      'newest preference intent is durable while an older cloud write waits offline',
      () async {
    final store = MemoryPrefsStore();
    final wait = Completer<void>();
    final repo = FakeUsageRepository()
      ..savePreferencesHandler = () => wait.future;
    final prefs = LocalPrefs(store)..bindAccount('A', repo);
    final first = prefs.setMonthlyBudget(10);
    await Future<void>.delayed(Duration.zero);
    final second = prefs.setMonthlyBudget(90);
    await Future<void>.delayed(Duration.zero);
    expect(
        jsonDecode(store.values['pending_preferences_A']!)['budget_usd'], 90);
    wait.complete();
    await Future.wait([first, second]);
    expect(repo.savedPrefs.last['budget_usd'], 90);
    expect(store.values['pending_preferences_A'], '');
    prefs.unbindAccount();
    await repo.close();
  });
  for (final screen in ['Suggestions', 'Efficiency']) {
    testWidgets('$screen shows empty data after a live null snapshot',
        (tester) async {
      final repo = FakeUsageRepository();
      addTearDown(repo.close);
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      final args = LiveArgs(uid: 'A', repository: repo);
      await tester.pumpWidget(MaterialApp(
          home: screen == 'Suggestions'
              ? LiveInsightsScreen(args: args)
              : LiveEfficiencyScreen(args: args)));
      await tester.pump();
      repo.insights.add(null);
      repo.efficiency.add(null);
      await tester.pump();
      await tester.pump();
      expect(
          find.text(screen == 'Suggestions'
              ? 'No AI review yet'
              : 'No efficiency report yet'),
          findsOneWidget);
      expect(
          find.byWidgetPredicate((widget) =>
              widget is CircularProgressIndicator && widget.value == null),
          findsNothing);
    });
  }
  test(
      'signing out immediately does not discard the old account pending intent',
      () async {
    final store = MemoryPrefsStore();
    final repo = FakeUsageRepository();
    final prefs = LocalPrefs(store)..bindAccount('A', repo);
    final saving = prefs.setMonthlyBudget(55);
    prefs.bindAccount('B', repo);
    repo.prefs.add(null);
    await saving;
    await Future<void>.delayed(Duration.zero);
    expect(
        jsonDecode(store.values['pending_preferences_A']!)['budget_usd'], 55);
    expect(prefs.monthlyBudgetUsd, isNull);
    expect(repo.savedPrefs, isEmpty);
    prefs.bindAccount('A', repo);
    await Future<void>.delayed(Duration.zero);
    expect(prefs.monthlyBudgetUsd, 55);
    prefs.unbindAccount();
    await repo.close();
  });
}
