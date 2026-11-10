import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utoken_mobile/core/data/usage_repository.dart';
import 'package:utoken_mobile/core/models/daily_doc.dart';
import 'package:utoken_mobile/core/models/usage_docs.dart';
import 'package:utoken_mobile/features/tokens/presentation/tokens_screen.dart';
import 'package:utoken_mobile/features/efficiency/presentation/efficiency_screen.dart';
import 'package:utoken_mobile/features/settings/presentation/last_sync_screen.dart';

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
          {required String uid, DateTime? start, required DateTime end}) =>
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

  Future<void> close() async {
    await efficiency.close();
    await insights.close();
    await sync.close();
  }
}

DailyDoc dailyDoc(DateTime date, int tokens, int cost) => DailyDoc(
      date: date.toIso8601String().substring(0, 10),
      totals: TokenBreakdown(
          input: tokens, cached: 0, cacheWrite: 0, output: 0, costMicro: cost),
      byKey: const {},
      tasksByState: const {},
    );

void main() {
  testWidgets('live snapshots update exact totals without manual refresh',
      (tester) async {
    final repository = FakeUsageRepository();
    final updates = StreamController<List<DailyDoc>>();
    repository.dailyStream = updates.stream;
    addTearDown(updates.close);
    addTearDown(repository.close);
    await tester.pumpWidget(
        MaterialApp(home: TokensScreen(uid: 'u', repository: repository)));
    updates.add([dailyDoc(DateTime.now(), 145890001, 100)]);
    await tester.pumpAndSettle();
    expect(find.text('145,890,001 tokens'), findsOneWidget);
    expect(find.textContaining('Cloud data:'), findsOneWidget);
    updates.add([dailyDoc(DateTime.now(), 145890002, 100)]);
    await tester.pumpAndSettle();
    expect(find.text('145,890,002 tokens'), findsOneWidget);
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
    ]);
    await tester.pumpWidget(
        MaterialApp(home: TokensScreen(uid: 'u', repository: repository)));
    await tester.pumpAndSettle();
    expect(find.text('31 tokens'), findsOneWidget);
    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();
    expect(find.text('1 tokens'), findsOneWidget);
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(find.text('7 tokens'), findsOneWidget);
    await tester.tap(find.text('Total'));
    await tester.pumpAndSettle();
    expect(find.text('127 tokens'), findsOneWidget);
  });

  testWidgets('manual server refresh is single-flight and updates usage',
      (tester) async {
    final repository = FakeUsageRepository();
    addTearDown(repository.close);
    repository.dailyValues.add(dailyDoc(DateTime.now(), 1200, 2500000));
    final pending = Completer<void>();
    repository.refreshHandler = () => pending.future;
    await tester.pumpWidget(
        MaterialApp(home: TokensScreen(uid: 'u', repository: repository)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Refresh from Firebase'));
    await tester.pump();
    expect(repository.refreshCalls, 1);
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate((widget) =>
                widget is IconButton &&
                widget.tooltip == 'Refresh from Firebase'))
            .onPressed,
        isNull);
    repository.dailyValues
      ..clear()
      ..add(dailyDoc(DateTime.now(), 2400, 5000000));
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('2.4K'), findsOneWidget);
    expect(find.textContaining('Read latest data'), findsOneWidget);
  });

  testWidgets('failed manual refresh retains data and allows retry',
      (tester) async {
    final repository = FakeUsageRepository();
    addTearDown(repository.close);
    repository.dailyValues.add(dailyDoc(DateTime.now(), 1200, 2500000));
    repository.refreshHandler = () async => throw Exception('offline');
    await tester.pumpWidget(
        MaterialApp(home: TokensScreen(uid: 'u', repository: repository)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Refresh from Firebase'));
    await tester.pumpAndSettle();
    expect(find.text('1.2K'), findsOneWidget);
    expect(find.textContaining('Read latest data'), findsNothing);
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate((widget) =>
                widget is IconButton &&
                widget.tooltip == 'Refresh from Firebase'))
            .onPressed,
        isNotNull);
    repository.refreshHandler = null;
    await tester.tap(find.byTooltip('Refresh from Firebase'));
    await tester.pumpAndSettle();
    expect(repository.refreshCalls, 2);
  });

  testWidgets('Tokens shows totals, cost, and changes period', (tester) async {
    final repository = FakeUsageRepository();
    addTearDown(repository.close);
    await tester.pumpWidget(
        MaterialApp(home: TokensScreen(uid: 'u', repository: repository)));
    repository.dailyValues.add(dailyDoc(DateTime.now(), 1200, 2500000));
    await tester.pumpWidget(
        MaterialApp(home: TokensScreen(uid: 'u', repository: repository)));
    await tester.pump();
    expect(find.text('1.2K'), findsOneWidget);
    expect(find.text('\$2.50'), findsOneWidget);
    for (final period in ['Day', 'Week', 'Month', 'Total']) {
      await tester.tap(find.text(period));
      await tester.pump();
    }
  });

  testWidgets('Efficiency and sync show stream values and nulls',
      (tester) async {
    final repository = FakeUsageRepository();
    addTearDown(repository.close);
    await tester.pumpWidget(
        MaterialApp(home: EfficiencyScreen(uid: 'u', repository: repository)));
    repository.efficiency.add(const EfficiencyDoc(
      periodStart: '',
      periodEnd: '',
      generatedAt: '',
      processMetrics: [],
      setups: [
        SetupMetric(
            provider: 'codex',
            model: 'm',
            taskGroup: 'g',
            tasks: 7,
            verdict: 'insufficient',
            crossTool: false)
      ],
    ));
    await tester.pump();
    expect(find.text('Chưa đủ dữ liệu · 7/20'), findsOneWidget);
    await tester.pumpWidget(
        MaterialApp(home: LastSyncScreen(uid: 'u', repository: repository)));
    repository.sync.add(null);
    await tester.pump();
    expect(find.text('—'), findsOneWidget);
    repository.sync.add(DateTime.now().subtract(const Duration(minutes: 3)));
    await tester.pump();
    expect(find.text('Đồng bộ 3 phút trước'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('stream errors show friendly text', (tester) async {
    final repository = FakeUsageRepository();
    addTearDown(repository.close);
    repository.dailyError = Exception('x');
    await tester.pumpWidget(
        MaterialApp(home: TokensScreen(uid: 'u', repository: repository)));
    await tester.pump();
    await tester.pump();
    expect(find.text('Không đọc được dữ liệu. Kiểm tra kết nối mạng.'),
        findsOneWidget);
  });
}
