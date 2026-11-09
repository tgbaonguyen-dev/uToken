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
  final List<DailyDoc> dailyValues = [];
  Object? dailyError;
  final efficiency = StreamController<EfficiencyDoc?>.broadcast();
  final insights = StreamController<InsightsDoc?>.broadcast();
  final sync = StreamController<DateTime?>.broadcast();

  @override
  Stream<List<DailyDoc>> watchDaily(
          {required String uid,
          required DateTime start,
          required DateTime end}) =>
      dailyError == null
          ? Stream.value(dailyValues)
          : Stream.error(dailyError!);
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
