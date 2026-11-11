import 'package:utoken_mobile/features/live/live_common.dart';
import 'package:utoken_mobile/core/data/local_prefs.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utoken_mobile/core/data/usage_repository.dart';
import 'package:utoken_mobile/core/models/daily_doc.dart';
import 'package:utoken_mobile/core/models/usage_docs.dart';
import 'package:utoken_mobile/features/live/tokens_screens.dart';
import 'package:utoken_mobile/features/live/insights_screens.dart';
import 'live_screens_test.dart' show FakeUsageRepository, dailyDoc;

JsonMap document(String date, Object input) => {
      'schema_version': 2,
      'date': date,
      'totals': {
        'input': input,
        'output': 20,
        'cached': 40,
        'cost_micro': 1000000
      },
      'by_key': {
        'codex|test-model|none': {'input': input, 'output': 20}
      },
    };

void main() {
  setUp(() => LocalPrefs.instance = LocalPrefs(MemoryPrefsStore()));
  testWidgets('console-style edits update UI, isolate invalid docs and recover',
      (tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    final raw = StreamController<Map<String, JsonMap>>();
    final repository = FakeUsageRepository()
      ..parsedDailyStream = raw.stream.map(parseDailySnapshot);
    addTearDown(repository.close);
    addTearDown(raw.close);
    final date = DateTime.now().toIso8601String().substring(0, 10);
    await tester.pumpWidget(MaterialApp(
        home: LiveTokensScreen(
            args: LiveArgs(uid: 'u', repository: repository))));
    raw.add({date: document(date, 100)});
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('exact-token-total')))
            .data,
        '120');
    raw.add({date: document(date, 200)});
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('exact-token-total')))
            .data,
        '220');
    final yesterday = DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);
    raw.add({
      date: document(date, 'wrong string'),
      yesterday: document(yesterday, 10)
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('invalid-daily-warning')), findsOneWidget);
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('exact-token-total')))
            .data,
        '30');
    expect(tester.takeException(), isNull);
    raw.add({date: document(date, 300), yesterday: document(yesterday, 10)});
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('exact-token-total')))
            .data,
        '350');
    expect(find.byKey(const ValueKey('invalid-daily-warning')), findsNothing);
    raw.add({});
    await tester.pumpAndSettle();
    expect(find.text('Connect your desktop'), findsOneWidget);
    expect(repository.refreshCalls, 0);
  });

  test('malformed console values produce FormatException, never TypeError', () {
    for (final value in [
      {...document('2026-11-10', 10), 'date': 123},
      {...document('2026-11-10', 10), 'date': '2026-13-45'},
      {
        ...document('2026-11-10', 10),
        'by_key': {'bad': 123}
      },
      document('2026-11-10', double.nan),
      document('2026-11-10', 1.5),
      {...document('2026-11-10', 10), 'totals': 'bad'},
    ]) {
      expect(() => DailyDoc.fromMap(value), throwsFormatException);
    }
    expect(
        () => InsightsDoc.fromMap({'insights': 'bad'}), throwsFormatException);
    expect(
        () => EfficiencyDoc.fromMap({
              'process_metrics': [123]
            }),
        throwsFormatException);
  });

  testWidgets('day query rolls over at midnight and after resuming',
      (tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    final repository = FakeUsageRepository();
    addTearDown(repository.close);
    var now = DateTime(2026, 11, 10, 23, 59);
    repository.dailyValues.add(dailyDoc(now, 100, 0));
    await tester.pumpWidget(MaterialApp(
        home: LiveTokensScreen(
            args: LiveArgs(uid: 'u', repository: repository), now: () => now)));
    await tester.pumpAndSettle();
    now = DateTime(2026, 11, 11);
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(repository.requestedEnds.last.day, 11);
    now = DateTime(2026, 11, 12, 8);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(repository.requestedEnds.last.day, 12);
  });

  testWidgets('insight null, removed ID and errors have recovery states',
      (tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    final repository = FakeUsageRepository();
    addTearDown(repository.close);
    await tester.pumpWidget(MaterialApp(
        home: LiveInsightDetailScreen(
            args: LiveArgs(uid: 'u', repository: repository),
            insightId: 'one')));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    repository.insights.add(null);
    await tester.pumpAndSettle();
    expect(find.text('No AI review available yet.'), findsOneWidget);
    repository.insights.add(const InsightsDoc(
        status: 'ok', generatedAt: '', headline: '', insights: []));
    await tester.pumpAndSettle();
    expect(find.textContaining('no longer exists'), findsOneWidget);
    repository.insights.addError(const FormatException('bad field'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Invalid Firebase data'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    repository.insights.add(InsightsDoc.fromMap({
      'status': 'ok',
      'insights': [
        {'id': 'one', 'title': 'Recovered review'}
      ]
    }));
    await tester.pumpAndSettle();
    expect(find.text('Recovered review'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
