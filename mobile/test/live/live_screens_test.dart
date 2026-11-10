import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utoken_mobile/core/data/usage_repository.dart';
import 'package:utoken_mobile/core/models/daily_doc.dart';
import 'package:utoken_mobile/core/models/usage_docs.dart';
import 'package:utoken_mobile/core/data/local_prefs.dart';
import 'package:utoken_mobile/core/format/token_format.dart';
import 'package:utoken_mobile/features/live/analytics_screens.dart';
import 'package:utoken_mobile/features/live/insights_screens.dart';
import 'package:utoken_mobile/features/live/live_common.dart';
import 'package:utoken_mobile/features/live/settings_screens.dart';
import 'package:utoken_mobile/features/live/tokens_screens.dart';

class FakeUsageRepository implements UsageRepository {
  int refreshCalls = 0;
  Future<void> Function()? refreshHandler;
  @override
  Future<void> refresh({required String uid}) async {
    refreshCalls++;
    if (refreshHandler != null) await refreshHandler!();
  }

  final List<DailyDoc> dailyValues = [];
  Object? dailyError;
  Stream<List<DailyDoc>>? dailyStream;
  final efficiency = StreamController<EfficiencyDoc?>.broadcast();
  final insights = StreamController<InsightsDoc?>.broadcast();
  final sync = StreamController<DateTime?>.broadcast();

  @override
  Stream<List<DailyDoc>> watchDaily(
          {required String uid, DateTime? start, DateTime? end}) =>
      dailyStream ??
      (dailyError == null
          ? Stream.value(dailyValues)
          : Stream.error(dailyError!));
  @override
  Stream<EfficiencyDoc?> watchEfficiency({required String uid}) =>
      efficiency.stream;
  @override
  Stream<InsightsDoc?> watchInsights({required String uid}) => insights.stream;
  @override
  Stream<DateTime?> watchLastSync({required String uid}) => sync.stream;

  final desktopName = StreamController<String?>.broadcast();
  final requests = <String>[];
  final requestStates = <String, StreamController<SyncRequestStatus?>>{};
  final prefs = StreamController<Map<String, dynamic>?>.broadcast();
  final savedPrefs = <Map<String, dynamic>>[];

  @override
  Stream<String?> watchDesktopName({required String uid}) => desktopName.stream;
  final List<Map<String, dynamic>> savedInsights = [];
  @override
  Future<void> saveInsights(
      {required String uid,
      required Map<String, dynamic> values,
      bool merge = false}) async {
    savedInsights.add(values);
    if (!merge) insights.add(InsightsDoc.fromMap(values));
  }

  final List<String> triggers = [];
  @override
  Future<String> requestSync(
      {required String uid, String trigger = 'manual_refresh'}) async {
    final id = 'req-${requests.length + 1}';
    requests.add(id);
    triggers.add(trigger);
    requestStates[id] = StreamController<SyncRequestStatus?>.broadcast();
    return id;
  }

  @override
  Stream<SyncRequestStatus?> watchSyncRequest(
          {required String uid, required String id}) =>
      requestStates[id]!.stream;
  @override
  Stream<Map<String, dynamic>?> watchPreferences({required String uid}) =>
      prefs.stream;
  @override
  Future<void> savePreferences(
      {required String uid, required Map<String, dynamic> values}) async {
    savedPrefs.add(values);
  }

  Future<void> close() async {
    await efficiency.close();
    await insights.close();
    await sync.close();
    await desktopName.close();
    await prefs.close();
    for (final c in requestStates.values) {
      await c.close();
    }
  }
}

DailyDoc dailyDoc(DateTime date, int tokens, int cost) => DailyDoc(
      date: date.toIso8601String().substring(0, 10),
      totals: TokenBreakdown(
          input: tokens, cached: 0, cacheWrite: 0, output: 0, costMicro: cost),
      byKey: const {},
      tasksByState: const {},
    );

DailyDoc keyedDoc(DateTime date, Map<String, int> tokensByKey,
        {Map<String, int> states = const {}}) =>
    DailyDoc(
      date: date.toIso8601String().substring(0, 10),
      totals: TokenBreakdown(
          input: tokensByKey.values.fold(0, (a, b) => a + b),
          cached: 0,
          cacheWrite: 0,
          output: 0,
          chats: 3,
          costMicro: tokensByKey.values.fold<int>(0, (a, b) => a + b) * 10),
      byKey: {
        for (final e in tokensByKey.entries)
          e.key: TokenBreakdown(
              input: e.value,
              cached: 0,
              cacheWrite: 0,
              output: 0,
              chats: 1,
              costMicro: e.value * 10)
      },
      tasksByState: states,
    );

Widget app(Widget home) => MaterialApp(home: home);

String exactTotal(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('exact-token-total'))).data!;

void main() {
  setUp(() => LocalPrefs.instance = LocalPrefs(MemoryPrefsStore()));

  LiveArgs argsFor(FakeUsageRepository r) => LiveArgs(uid: 'u', repository: r);

  testWidgets('live snapshots update exact totals without manual refresh',
      (tester) async {
    final repository = FakeUsageRepository();
    final updates = StreamController<List<DailyDoc>>();
    repository.dailyStream = updates.stream;
    addTearDown(updates.close);
    addTearDown(repository.close);
    await tester.pumpWidget(app(LiveTokensScreen(args: argsFor(repository))));
    updates.add([dailyDoc(DateTime.now(), 145890001, 100)]);
    await tester.pumpAndSettle();
    expect(exactTotal(tester), '145,890,001');
    await tester.scrollUntilVisible(find.textContaining('Cloud data:'), 300);
    expect(find.textContaining('Cloud data:'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('exact-token-total')), -300);
    updates.add([dailyDoc(DateTime.now(), 145890002, 100)]);
    await tester.pumpAndSettle();
    expect(exactTotal(tester), '145,890,002');
    expect(repository.refreshCalls, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'calendar periods exclude extra dates and Total includes old history',
      (tester) async {
    final repository = FakeUsageRepository();
    addTearDown(repository.close);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    repository.dailyValues.addAll([
      dailyDoc(today, 1, 0),
      dailyDoc(today.subtract(const Duration(days: 1)), 2, 0),
      dailyDoc(today.subtract(const Duration(days: 6)), 4, 0),
      dailyDoc(today.subtract(const Duration(days: 7)), 8, 0),
      dailyDoc(today.subtract(const Duration(days: 29)), 16, 0),
      dailyDoc(today.subtract(const Duration(days: 30)), 32, 0),
      dailyDoc(today.subtract(const Duration(days: 400)), 64, 0),
    ]..sort((a, b) => a.date.compareTo(b.date)));
    await tester.pumpWidget(app(LiveTokensScreen(args: argsFor(repository))));
    await tester.pumpAndSettle();
    expect(exactTotal(tester), '31');
    for (final (period, total) in [
      ('Day', '1'),
      ('Week', '7'),
      ('Total', '127')
    ]) {
      await tester.tap(find.text(period));
      await tester.pumpAndSettle();
      expect(exactTotal(tester), total, reason: period);
    }
  });

  testWidgets('manual server refresh is single-flight and updates usage',
      (tester) async {
    final repository = FakeUsageRepository();
    addTearDown(repository.close);
    repository.dailyValues.add(dailyDoc(DateTime.now(), 1200, 2500000));
    final pending = Completer<void>();
    repository.refreshHandler = () => pending.future;
    await tester.pumpWidget(app(LiveTokensScreen(args: argsFor(repository))));
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('figma-hotspot-Refresh'));
    await tester.tap(button);
    await tester.pump();
    expect(repository.refreshCalls, 1);
    expect(tester.widget<InkWell>(button).onTap, isNull);
    repository.dailyValues
      ..clear()
      ..add(dailyDoc(DateTime.now(), 2400, 5000000));
    pending.complete();
    await tester.pumpAndSettle();
    expect(exactTotal(tester), '2,400');
    expect(find.text('\$5.00 estimated'), findsOneWidget);
    expect(find.textContaining('Up to date'), findsOneWidget);
    expect(repository.requests, ['req-1']);
  });

  testWidgets('failed manual refresh retains data and allows retry',
      (tester) async {
    final repository = FakeUsageRepository();
    addTearDown(repository.close);
    repository.dailyValues.add(dailyDoc(DateTime.now(), 1200, 2500000));
    repository.refreshHandler = () async => throw Exception('offline');
    await tester.pumpWidget(app(LiveTokensScreen(args: argsFor(repository))));
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('figma-hotspot-Refresh'));
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(exactTotal(tester), '1,200');
    expect(find.textContaining('Up to date'), findsNothing);
    expect(tester.widget<InkWell>(button).onTap, isNotNull);
    repository.refreshHandler = null;
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(repository.refreshCalls, 2);
  });

  testWidgets('empty account shows S01, then S02 once desktop has synced',
      (tester) async {
    final repository = FakeUsageRepository();
    addTearDown(repository.close);
    await tester.pumpWidget(app(LiveTokensScreen(args: argsFor(repository))));
    await tester.pumpAndSettle();
    expect(find.text('Connect your desktop'), findsOneWidget);
    repository.sync.add(DateTime.now());
    await tester.pumpAndSettle();
    expect(find.text('Waiting for first activity'), findsOneWidget);
  });

  testWidgets('providers, models and projects come from by_key',
      (tester) async {
    final repository = FakeUsageRepository();
    addTearDown(repository.close);
    final now = DateTime.now();
    repository.dailyValues.addAll([
      keyedDoc(now.subtract(const Duration(days: 1)),
          {'codex|gpt-5|alpha': 300, 'claude_code|sonnet|none': 100}),
      keyedDoc(now, {'codex|gpt-5|alpha': 600}),
    ]);
    await tester.pumpWidget(app(LiveTokensScreen(args: argsFor(repository))));
    await tester.pumpAndSettle();
    expect(find.text('Codex'), findsOneWidget);
    expect(find.text('90.0%'), findsOneWidget);
    expect(find.text('Claude'), findsOneWidget);

    await tester
        .pumpWidget(app(LiveDailyUsageScreen(args: argsFor(repository))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Project'));
    await tester.pumpAndSettle();
    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('Unassigned'), findsOneWidget);
    expect(find.text('900'), findsOneWidget);
  });

  testWidgets('compare models ranks setups and lists insufficient ones',
      (tester) async {
    final repository = FakeUsageRepository();
    addTearDown(repository.close);
    await tester
        .pumpWidget(app(LiveModelComparisonScreen(args: argsFor(repository))));
    repository.efficiency.add(const EfficiencyDoc(
      periodStart: '2026-10-01',
      periodEnd: '2026-10-30',
      generatedAt: '',
      processMetrics: [],
      setups: [
        SetupMetric(
            provider: 'codex',
            model: 'fast',
            taskGroup: 'medium',
            tasks: 40,
            verdict: 'better',
            crossTool: false,
            sr: 0.8,
            cpstMicro: 400000),
        SetupMetric(
            provider: 'claude_code',
            model: 'new',
            taskGroup: 'medium',
            tasks: 7,
            verdict: 'insufficient',
            crossTool: false),
      ],
    ));
    await tester.pumpAndSettle();
    expect(find.text('BEST FOR MEDIUM TASKS'), findsOneWidget);
    expect(find.text('13 more chats needed for a verdict'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('desktop status shows last sync time', (tester) async {
    final repository = FakeUsageRepository();
    addTearDown(repository.close);
    await tester.pumpWidget(app(LiveDesktopScreen(args: argsFor(repository))));
    repository.sync.add(null);
    await tester.pumpAndSettle();
    expect(find.text('Not synced yet'), findsOneWidget);
    repository.sync.add(DateTime.now().subtract(const Duration(minutes: 3)));
    await tester.pumpAndSettle();
    expect(find.text('Desktop · synced 3m ago'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('budget limit is saved locally and alerts use real cost',
      (tester) async {
    final repository = FakeUsageRepository();
    addTearDown(repository.close);
    final now = DateTime.now();
    repository.dailyValues.add(keyedDoc(now, {'codex|gpt-5|none': 4500000}));
    await tester.pumpWidget(app(LiveBudgetScreen(args: argsFor(repository))));
    await tester.pumpAndSettle();
    expect(find.text('\$45.00'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('budget-limit-field')), '50');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(LocalPrefs.instance.monthlyBudgetUsd, 50);
    expect(find.text('90.0% used'), findsOneWidget);
    expect(find.text('Reached'), findsNWidgets(2));
    expect(find.text('Budget alert'), findsOneWidget);
  });

  testWidgets('insight detail can be marked reviewed', (tester) async {
    final repository = FakeUsageRepository();
    addTearDown(repository.close);
    await tester.pumpWidget(app(
        LiveInsightDetailScreen(args: argsFor(repository), insightId: 'trim')));
    repository.insights.add(const InsightsDoc(
        status: 'ok',
        generatedAt: '',
        headline: '',
        insights: [
          Insight(
              id: 'trim',
              title: 'Trim repeated context',
              severity: 'high',
              category: 'context',
              evidence: [
                Evidence(
                    metric: 'x', label: 'Repeated context share', value: '42%')
              ],
              recommendation: 'Move stable instructions earlier.',
              confidence: 'high')
        ]));
    await tester.pumpAndSettle();
    expect(find.text('Repeated context share'), findsOneWidget);
    await tester.tap(find.text('Mark as reviewed'));
    await tester.pumpAndSettle();
    expect(LocalPrefs.instance.isReviewed('trim'), isTrue);
    expect(find.text('Reviewed'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  test('export CSV contains one row per daily record', () {
    final csv =
        LiveExportScreen.toCsv([dailyDoc(DateTime(2026, 11, 1), 10, 2500000)]);
    expect(csv.split('\n'), [
      'date,input,cached,cache_write,output,chats,requests,cost_usd',
      '2026-11-01,10,0,0,0,0,0,2.500000',
    ]);
  });

  testWidgets('Sync now asks the desktop and shows the request state',
      (tester) async {
    final repository = FakeUsageRepository();
    addTearDown(repository.close);
    await tester.pumpWidget(app(LiveDesktopScreen(args: argsFor(repository))));
    repository.desktopName.add('CAMELLYA-PC');
    repository.sync.add(DateTime.now().subtract(const Duration(minutes: 2)));
    await tester.pumpAndSettle();
    expect(find.text('CAMELLYA-PC · synced 2m ago'), findsOneWidget);
    await tester.tap(find.text('Sync now'));
    await tester.pump();
    await tester.pump();
    expect(repository.requests, ['req-1']);
    String status() => tester
        .widget<Text>(find.byKey(const ValueKey('sync-request-status')))
        .data!;
    expect(status(), 'Waiting for the desktop to pick this up…');
    repository.requestStates['req-1']!
        .add(const SyncRequestStatus(state: 'running'));
    await tester.pump();
    expect(status(), 'Desktop is syncing…');
    repository.requestStates['req-1']!
        .add(const SyncRequestStatus(state: 'failed', errorCode: 'network'));
    await tester.pump();
    expect(status(), 'Desktop couldn’t reach Firebase');
    await tester.pumpWidget(const SizedBox());
  });

  test('preferences follow the account and are written back', () async {
    final repository = FakeUsageRepository();
    final store = MemoryPrefsStore();
    final prefs = LocalPrefs(store);
    await prefs.load();
    prefs.bindAccount('u', repository);
    repository.prefs.add({
      'budget_usd': 80,
      'token_format': 'full',
      'reviewed_insights': ['a'],
    });
    await Future<void>.delayed(Duration.zero);
    expect(prefs.monthlyBudgetUsd, 80);
    expect(prefs.tokenFormat, TokenFormat.full);
    expect(prefs.isReviewed('a'), isTrue);
    expect(store.values['prefs_uid'], 'u');

    await prefs.setMonthlyBudget(60);
    expect(repository.savedPrefs.last['budget_usd'], 60);
    await prefs.markReviewed('b');
    expect(repository.savedPrefs.last['reviewed_insights'], ['a', 'b']);
    prefs.unbindAccount();
    await repository.close();
  });

  test('another account does not inherit cached preferences', () async {
    final store = MemoryPrefsStore()
      ..values.addAll({'prefs_uid': 'old', 'budget_usd': '99'});
    final prefs = LocalPrefs(store);
    await prefs.load();
    expect(prefs.monthlyBudgetUsd, 99);
    final repository = FakeUsageRepository();
    prefs.bindAccount('new', repository);
    repository.prefs.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(prefs.monthlyBudgetUsd, isNull);
    expect(repository.savedPrefs, isEmpty);
    expect(store.values['prefs_uid'], 'new');
    prefs.unbindAccount();
    await repository.close();
  });

  testWidgets('stream errors show friendly text', (tester) async {
    final repository = FakeUsageRepository();
    addTearDown(repository.close);
    repository.dailyError = Exception('x');
    await tester.pumpWidget(app(LiveTokensScreen(args: argsFor(repository))));
    await tester.pump();
    await tester.pump();
    expect(find.text('Couldn’t load data. Check your internet connection.'),
        findsOneWidget);
  });
}
