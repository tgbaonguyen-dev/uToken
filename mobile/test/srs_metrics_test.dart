import 'package:flutter_test/flutter_test.dart';
import 'package:utoken_mobile/core/data/usage_aggregates.dart';
import 'package:utoken_mobile/core/models/daily_doc.dart';
import 'package:utoken_mobile/core/models/usage_docs.dart';
import 'package:utoken_mobile/features/live/analytics_screens.dart';
import 'package:utoken_mobile/features/live/live_common.dart';

DailyDoc _day(String date,
        {int tokens = 1, Map<String, int> states = const {}}) =>
    DailyDoc(
      date: date,
      totals: TokenBreakdown(
          input: tokens, cached: 0, cacheWrite: 0, output: 0, costMicro: 0),
      byKey: const {},
      tasksByState: states,
    );

SetupMetric _setup(String model, String verdict,
        {String group = 'medium', String provider = 'codex', int? cpst}) =>
    SetupMetric(
        provider: provider,
        model: model,
        taskGroup: group,
        tasks: 30,
        verdict: verdict,
        crossTool: false,
        sr: 0.8,
        cpstMicro: cpst);

void main() {
  group('Month = current calendar month (FR-DASH-001)', () {
    final docs = [
      _day('2026-10-31', tokens: 1),
      _day('2026-11-01', tokens: 2),
      _day('2026-11-11', tokens: 4),
      _day('2026-11-12', tokens: 8), // after "today": never counted
    ];

    test('mid-month keeps only this month up to today', () {
      final month =
          filterPeriod(docs, UsagePeriod.month, DateTime(2026, 11, 11, 9));
      expect(month.map((d) => d.date), ['2026-11-01', '2026-11-11']);
    });

    test('first day of the month does not reach into last month', () {
      final month =
          filterPeriod(docs, UsagePeriod.month, DateTime(2026, 11, 1, 23));
      expect(month.map((d) => d.date), ['2026-11-01']);
    });

    test('week and day stay rolling', () {
      final now = DateTime(2026, 11, 1, 8);
      expect(filterPeriod(docs, UsagePeriod.week, now).length, 2);
      expect(
          filterPeriod(docs, UsagePeriod.day, now).single.date, '2026-11-01');
    });
  });

  group('custom date range', () {
    final docs = [
      _day('2026-10-30', tokens: 1),
      _day('2026-11-02', tokens: 2),
      _day('2026-11-05', tokens: 4),
      _day('2026-11-09', tokens: 8),
    ];
    tearDown(() => customUsageRange = null);

    test('keeps both ends of the range', () {
      final r = UsageRange(DateTime(2026, 11, 2), DateTime(2026, 11, 5, 23));
      expect(filterRange(docs, r, DateTime(2026, 11, 11)).map((d) => d.date),
          ['2026-11-02', '2026-11-05']);
      expect(r.days, 4);
    });

    test('Custom without a range falls back to this month', () {
      expect(
          filterPeriod(docs, UsagePeriod.custom, DateTime(2026, 11, 11))
              .length,
          3);
    });

    test('route parameters round-trip and reversed ranges are rejected', () {
      customUsageRange = UsageRange(DateTime(2026, 11, 2), DateTime(2026, 11, 5));
      final uri = Uri.parse(withPeriod('/usage-details', UsagePeriod.custom));
      final back = UsageRange.tryParse(
          uri.queryParameters['from'], uri.queryParameters['to']);
      expect(back?.from, DateTime(2026, 11, 2));
      expect(back?.to, DateTime(2026, 11, 5));
      expect(UsageRange.tryParse('2026-11-05', '2026-11-01'), isNull);
      expect(UsageRange.tryParse(null, '2026-11-01'), isNull);
    });
  });

  group('success rate (FR-ANLY-003 §C)', () {
    final o = sumOutcomes([
      _day('2026-11-01', states: {
        'verified_success': 6,
        'verified_failure': 2,
        'likely_success': 2,
        'likely_failure': 0,
        'undetermined': 5,
      }),
    ]);

    test('main rate uses verified chats only', () {
      expect(o.verified, 8);
      expect(o.successRate, 0.75); // 6 / (6 + 2)
    });

    test('secondary rate adds likely results and skips undetermined', () {
      expect(o.successRateInclLikely, 0.8); // (6 + 2) / 10
      expect(o.undetermined, 5);
    });

    test('no verified chat gives no main rate', () {
      final none = sumOutcomes([
        _day('2026-11-01', states: {'likely_success': 3})
      ]);
      expect(none.successRate, isNull);
      expect(none.successRateInclLikely, 1.0);
    });

    test('Efficiency row prefers the desktop range, else Not enough data', () {
      const overall = OutcomeSummary(
          tasks: 40, verified: 30, sr: 0.7, srCiLow: 0.52, srCiHigh: 0.83);
      expect(efficiencySummary(overall, o), '70% (52%–83%) success');
      expect(efficiencySummary(null, o), '75% success');
      expect(efficiencySummary(null, sumOutcomes(const [])), 'Not enough data');
    });
  });

  group('best pick (M05C)', () {
    test('only Better or Cheaper-not-worse can be picked', () {
      expect(
          bestPick([
            _setup('a', 'tradeoff', cpst: 1),
            _setup('b', 'no_clear_difference', cpst: 1),
            _setup('c', 'insufficient', cpst: 1),
          ]),
          isNull);
    });

    test('Better wins over Cheaper-not-worse, then lower cost', () {
      final pick = bestPick([
        _setup('cheap', 'cheaper_not_worse', cpst: 100),
        _setup('better-expensive', 'better', cpst: 900),
        _setup('better-cheap', 'better', cpst: 500),
      ]);
      expect(pick?.model, 'better-cheap');
    });

    test('picks from different tools are never compared (§D step 0)', () {
      final setups = [
        _setup('codex-a', 'better', cpst: 900000),
        _setup('claude-b', 'better', provider: 'claude_code', cpst: 100000),
      ];
      final picks = bestPicksPerTool(setups);
      expect(picks.map((s) => s.model), ['claude-b', 'codex-a']);
      expect(bestPicksPerTool([_setup('x', 'worse')]), isEmpty);
    });

    test('respects task group and source filters', () {
      final setups = [
        _setup('small', 'better', group: 'small'),
        _setup('claude', 'better', provider: 'claude_code'),
      ];
      expect(bestPick(setups, group: 'large'), isNull);
      expect(bestPick(setups, provider: 'claude_code')?.model, 'claude');
    });
  });

  test('efficiency report reads the desktop overall summary', () {
    final doc = EfficiencyDoc.fromMap({
      'period_start': '2026-10-13',
      'period_end': '2026-11-11',
      'generated_at': '',
      'process_metrics': [],
      'setups': [
        {
          'provider': 'codex',
          'model': 'm',
          'task_group': 'small',
          'n_tasks': 25,
          'verdict': 'better',
          'stability_flag': true,
          'sr_alt': 0.9,
          'cost_p50_micro': 1000,
          'compared_to': 'other',
        }
      ],
      'overall': {
        'n_tasks': 60,
        'n_verified': 50,
        'sr': 0.66,
        'sr_ci_low': 0.5,
        'sr_ci_high': 0.78,
        'cost_p90_micro': 9000,
        'stability_flag': false,
      },
    });
    expect(doc.overall?.verified, 50);
    expect(doc.overall?.costP90Micro, 9000);
    final s = doc.setups.single;
    expect(s.unstable, isTrue);
    expect(s.srAlt, 0.9);
    expect(s.comparedTo, 'other');
    expect(s.isBestPick, isTrue);
    expect(EfficiencyDoc.fromMap({'setups': [], 'process_metrics': []}).overall,
        isNull);
  });
}
