import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/usage_aggregates.dart';
import '../../core/models/daily_doc.dart';
import '../../core/models/usage_docs.dart';
import '../../core/ui/ut_kit.dart';
import 'live_common.dart';
import '../../core/i18n/tr.dart';

/// M05 — Analytics: token mix, models and cost.
class LiveAnalyticsScreen extends StatefulWidget {
  const LiveAnalyticsScreen(
      {super.key, required this.args, this.initialPeriod = UsagePeriod.month});
  final LiveArgs args;
  final UsagePeriod initialPeriod;

  @override
  State<LiveAnalyticsScreen> createState() => _LiveAnalyticsScreenState();
}

class _LiveAnalyticsScreenState extends State<LiveAnalyticsScreen> {
  late UsagePeriod _period = widget.initialPeriod;
  late Stream<List<DailyDoc>> _daily = widget.args.daily();

  @override
  Widget build(BuildContext context) {
    return UtTabPage(
      title: tr('Analytics'),
      subtitle: tr('Token mix, models, and cost.'),
      tabIndex: 1,
      onRefresh: () async {
        await widget.args.refresh();
        if (mounted) setState(() => _daily = widget.args.daily());
      },
      body: UtStream<List<DailyDoc>>(
        stream: _daily,
        builder: (context, all) {
          final now = DateTime.now();
          final docs = filterPeriod(all, _period, now);
          final t = sumTotals(docs);
          final models = byModel(docs);
          final outcomes = sumOutcomes(filterLastDays(all, 30, now));
          return UtList(children: [
            UtSegmented<UsagePeriod>(
              values: UsagePeriod.values,
              selected: _period,
              label: (p) => tr(p.label),
              onChanged: (p) => setState(() => _period = lastUsagePeriod = p),
            ),
            const SizedBox(height: 22),
            UtCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(tr('Total tokens'), style: UtText.label),
                  const SizedBox(height: 8),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(
                        child: Text(compact(t.tokens), style: UtText.code)),
                    Text(usd(t.costUsd),
                        style: UtText.title.copyWith(color: UtColors.green)),
                  ]),
                  const SizedBox(height: 18),
                  ShareBar(parts: [
                    (share(t.input, t.tokens), UtColors.blue),
                    (share(t.output, t.tokens), UtColors.orange),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Text(tr('Input {p}', {'p': pct(share(t.input, t.tokens))}),
                        style: UtText.caption),
                    const Spacer(),
                    Text(
                        tr('Output {p}', {'p': pct(share(t.output, t.tokens))}),
                        style: UtText.caption),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 16),
            UtCard(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(children: [
                Row(children: [
                  Expanded(
                      flex: 5, child: Text(tr('Model'), style: UtText.label)),
                  Expanded(
                      flex: 2,
                      child: Text(tr('Tokens'),
                          textAlign: TextAlign.right, style: UtText.label)),
                  Expanded(
                      flex: 2,
                      child: Text(tr('Share'),
                          textAlign: TextAlign.right, style: UtText.label)),
                ]),
                const SizedBox(height: 8),
                if (models.isEmpty)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(tr('No usage in this period.'),
                          style: UtText.body)),
                for (final m in models.take(6))
                  SizedBox(
                    height: 46,
                    child: Row(children: [
                      ProviderBadge(m.value.provider),
                      const SizedBox(width: 10),
                      Expanded(
                          flex: 5,
                          child: Text(m.key,
                              overflow: TextOverflow.ellipsis,
                              style: UtText.caption.copyWith(
                                  color: UtColors.text,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500))),
                      Expanded(
                          flex: 2,
                          child: Text(tok(m.value.tokens),
                              textAlign: TextAlign.right,
                              style: UtText.bodyStrong)),
                      Expanded(
                          flex: 2,
                          child: Text(pct(share(m.value.tokens, t.tokens)),
                              textAlign: TextAlign.right,
                              style: UtText.caption)),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(height: 16),
            _CostWeek(all: all, now: now),
            const SizedBox(height: 16),
            UtCard(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: UtRow(
                title: tr('Efficiency'),
                trailing: Text(
                    outcomes.successRate == null
                        ? tr('No outcomes yet')
                        : tr('{p} success',
                            {'p': pct(outcomes.successRate!, digits: 0)}),
                    style: UtText.caption),
                onTap: () => context.push('/efficiency'),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _CostWeek extends StatelessWidget {
  const _CostWeek({required this.all, required this.now});
  final List<DailyDoc> all;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final current = sumTotals(filterLastDays(all, 7, now));
    final previous = sumTotals(filterLastDays(all, 7, now, offsetDays: 7));
    final byDate = {for (final d in all) d.date: d.totals.costMicro ?? 0};
    final values = [
      for (var i = 6; i >= 0; i--)
        (byDate[dayKey(DateTime(now.year, now.month, now.day - i))] ?? 0)
            .toDouble()
    ];
    final delta = previous.cost == 0 || !previous.costKnown
        ? null
        : (current.cost - previous.cost) / previous.cost;
    return UtCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('Cost · last 7 days'), style: UtText.label),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: Text(usd(current.costUsd), style: UtText.title)),
            if (delta != null)
              UtPill('${delta >= 0 ? '+' : '−'}${pct(delta.abs())}',
                  tone: delta > 0 ? UtTone.review : UtTone.good),
          ]),
          const SizedBox(height: 16),
          BarChart(values: values, height: 64, highlightLast: true),
        ],
      ),
    );
  }
}

String metricTitle(String id) => switch (id) {
      'cache_hit_rate' => tr('Cache hit rate'),
      'context_growth' => tr('Context growth'),
      'thinking_share' => tr('Thinking share'),
      'error_rate' => tr('Error rate'),
      'retry_rate' => tr('Retry rate'),
      'tokens_per_turn_vs_median' => tr('Tokens per turn'),
      'cost_tail' => tr('Cost tail'),
      'hidden_cost_share' => tr('Hidden cost'),
      _ => id,
    };

String metricHint(String id) => switch (id) {
      'cache_hit_rate' => tr('Input served from cache'),
      'context_growth' => tr('Last vs first turn in a chat'),
      'thinking_share' => tr('Reasoning inside output'),
      'error_rate' => tr('Requests that failed'),
      'retry_rate' => tr('Requests resent within 2 min'),
      'tokens_per_turn_vs_median' => tr('Last 7 days vs your daily median'),
      'cost_tail' => tr('Costliest chats (p90) vs a typical chat'),
      'hidden_cost_share' => tr('Background requests you did not send'),
      _ => '',
    };

String metricValue(ProcessMetric m) {
  final v = m.value;
  if (v == null) return '—';
  return switch (m.metric) {
    'context_growth' || 'cost_tail' => '${v.toStringAsFixed(1)}×',
    'tokens_per_turn_vs_median' =>
      '${v >= 0 ? '+' : '−'}${pct(v.abs(), digits: 0)}',
    _ => pct(v, digits: 0),
  };
}

/// "Leading so far: X on small tasks" from early results, across task sizes.
String _earlyLeader(List<SetupMetric> setups) {
  for (final g in ['small', 'medium', 'large']) {
    final (ranked, _) = rankForDisplay(setups, g);
    if (ranked.isNotEmpty) {
      return tr('Leading so far on {g} tasks: {m} · early results',
          {'g': groupLabel(g), 'm': ranked.first.$1.name});
    }
  }
  return 'Not enough chats to compare models yet';
}

/// M05B — Efficiency: outcomes, reliability, process health and per-tool view.
class LiveEfficiencyScreen extends StatefulWidget {
  const LiveEfficiencyScreen({super.key, required this.args});
  final LiveArgs args;

  @override
  State<LiveEfficiencyScreen> createState() => _LiveEfficiencyScreenState();
}

class _LiveEfficiencyScreenState extends State<LiveEfficiencyScreen> {
  late final Stream<List<DailyDoc>> _daily = widget.args.daily();
  late final Stream<EfficiencyDoc?> _doc =
      widget.args.repository.watchEfficiency(uid: widget.args.uid);

  @override
  Widget build(BuildContext context) {
    return UtPage(
      title: tr('Efficiency'),
      subtitle: tr('Results per token · last 30 days'),
      onBack: () => liveBack(context, '/analytics'),
      children: [
        UtStream<List<DailyDoc>>(
          stream: _daily,
          builder: (context, all) {
            final now = DateTime.now();
            final month = filterLastDays(all, 30, now);
            final prior = filterLastDays(all, 30, now, offsetDays: 30);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Outcome(month: month, prior: prior),
                const SizedBox(height: 16),
                _OutcomeMix(docs: month),
                const SizedBox(height: 28),
                UtSectionLabel(tr('Weekly trend'),
                    trailing: Text(tr('Success rate'), style: UtText.caption)),
                _WeeklyTrend(all: all, now: now),
                const SizedBox(height: 28),
                UtSectionLabel(tr('Reliability')),
                _Reliability(docs: month),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        UtStream<EfficiencyDoc?>(
          stream: _doc,
          builder: (context, doc) {
            if (doc == null) {
              return UtMessage(
                  icon: Icons.speed_outlined,
                  title: tr('No efficiency report yet'),
                  message: tr(
                      'The desktop app writes this report after it has enough chats to compare.'));
            }
            final overall =
                doc.processMetrics.where((m) => m.provider == null).toList();
            final best = bestSetup(doc.setups, null);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UtSectionLabel(tr('Process health'),
                    trailing: Text(
                        '${overall.where((m) => m.label == 'review').length} to review',
                        style: UtText.caption)),
                if (overall.isEmpty)
                  UtCard(
                      child: Text(tr('No process metrics yet.'),
                          style: UtText.body)),
                for (var i = 0; i < overall.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _MetricCard(
                      metric: overall[i],
                      perTool: doc.processMetrics
                          .where((m) =>
                              m.provider != null &&
                              m.metric == overall[i].metric)
                          .toList()),
                ],
                const SizedBox(height: 28),
                UtSectionLabel(tr('By tool')),
                _ToolTable(setups: doc.setups),
                const SizedBox(height: 16),
                UtCard(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: UtRow(
                    title: tr('Compare models'),
                    subtitle: best != null
                        ? tr('{g} tasks: {m} gives most success per dollar',
                            {'g': groupLabel(best.taskGroup), 'm': best.name})
                        : _earlyLeader(doc.setups),
                    onTap: () => context.push('/model-comparison'),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                    '${tr('A chat counts as successful when it ends with a verified or likely successful result.')} '
                    '${tr('Report {from} – {to}', {
                          'from': doc.periodStart,
                          'to': doc.periodEnd
                        })}'
                    '${doc.undeterminedTasks == null ? '' : ' · ${tr('{n} chats could not be judged', {
                            'n': doc.undeterminedTasks
                          })}'}.',
                    style: UtText.caption),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: utActionKey('See suggestions'),
                    onPressed: () => context.go('/insights'),
                    child:
                        Text(tr('See AI insights ›'), style: UtText.bodyStrong),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Outcome extends StatelessWidget {
  const _Outcome({required this.month, required this.prior});
  final List<DailyDoc> month, prior;

  static double? _cps(List<DailyDoc> docs) {
    final t = sumTotals(docs);
    final o = sumOutcomes(docs);
    return o.success == 0 || !t.costKnown ? null : t.cost / 1e6 / o.success;
  }

  @override
  Widget build(BuildContext context) {
    final o = sumOutcomes(month);
    final t = sumTotals(month);
    final cps = _cps(month), before = _cps(prior);
    final change = cps == null || before == null || before == 0
        ? null
        : (cps - before) / before;
    final tokensPerSuccess = o.success == 0 ? null : t.tokens ~/ o.success;
    final all = o.decided + o.undetermined;
    return UtCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('Outcome'), style: UtText.label),
          const SizedBox(height: 10),
          Text(usd(cps), style: UtText.code),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
                child: Text(tr('Cost per successful task'),
                    style: UtText.caption)),
            if (change != null)
              Text(
                  '${change <= 0 ? '−' : '+'}${pct(change.abs(), digits: 0)} ${tr('vs last month')}',
                  style: UtText.caption.copyWith(
                      color: change <= 0 ? UtColors.green : UtColors.orange)),
          ]),
          const SizedBox(height: 20),
          const UtDivider(),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: MiniStat(
                    value: o.successRate == null
                        ? '—'
                        : pct(o.successRate!, digits: 0),
                    label: tr('Success rate'))),
            Expanded(
                child: MiniStat(
                    value: tokensPerSuccess == null
                        ? '—'
                        : compact(tokensPerSuccess),
                    label: tr('Tokens / success'))),
            Expanded(
                child: MiniStat(
                    value: all == 0 ? '—' : '$all', label: tr('Chats judged'))),
          ]),
        ],
      ),
    );
  }
}

/// How chats ended: verified/likely success, failure, undetermined.
class _OutcomeMix extends StatelessWidget {
  const _OutcomeMix({required this.docs});
  final List<DailyDoc> docs;

  @override
  Widget build(BuildContext context) {
    int sum(String k) => docs.fold(0, (a, d) => a + (d.tasksByState[k] ?? 0));
    const red = Color(0xFFE0525B);
    final parts = [
      ('Verified success', sum('verified_success'), UtColors.green),
      (
        'Likely success',
        sum('likely_success'),
        UtColors.green.withValues(alpha: 0.5)
      ),
      (
        'Failed',
        sum('verified_failure') + sum('likely_failure'),
        red,
      ),
      ('Undetermined', sum('undetermined'), UtColors.muted),
    ];
    final total = parts.fold<int>(0, (a, p) => a + p.$2);
    return UtCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('How chats ended'), style: UtText.label),
          const SizedBox(height: 14),
          if (total == 0)
            Text(tr('No finished chats in the last 30 days.'),
                style: UtText.body)
          else ...[
            ShareBar(height: 10, parts: [
              for (final p in parts) (share(p.$2, total), p.$3),
            ]),
            const SizedBox(height: 14),
            for (final p in parts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: p.$3, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 10),
                  Expanded(child: Text(p.$1, style: UtText.body)),
                  Text('${p.$2}', style: UtText.bodyStrong),
                  SizedBox(
                    width: 48,
                    child: Text(pct(share(p.$2, total), digits: 0),
                        textAlign: TextAlign.right, style: UtText.caption),
                  ),
                ]),
              ),
          ],
        ],
      ),
    );
  }
}

/// Success rate for each of the last four weeks, oldest first.
class _WeeklyTrend extends StatelessWidget {
  const _WeeklyTrend({required this.all, required this.now});
  final List<DailyDoc> all;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final weeks = [
      for (var w = 3; w >= 0; w--)
        (
          sumOutcomes(filterLastDays(all, 7, now, offsetDays: w * 7)),
          sumTotals(filterLastDays(all, 7, now, offsetDays: w * 7)),
          w,
        )
    ];
    final any = weeks.any((w) => w.$1.successRate != null);
    return UtCard(
      child: !any
          ? Text(tr('Not enough judged chats yet.'), style: UtText.body)
          : Column(children: [
              BarChart(
                  height: 80,
                  color: UtColors.green,
                  highlightLast: false,
                  values: [for (final w in weeks) w.$1.successRate ?? 0]),
              const SizedBox(height: 10),
              Row(children: [
                for (final w in weeks)
                  Expanded(
                    child: Column(children: [
                      Text(
                          w.$1.successRate == null
                              ? '—'
                              : pct(w.$1.successRate!, digits: 0),
                          style: UtText.bodyStrong),
                      Text(
                          w.$3 == 0
                              ? tr('This week')
                              : tr('{n}w ago', {'n': w.$3}),
                          style: UtText.caption),
                      Text(
                          w.$1.success == 0 || !w.$2.costKnown
                              ? '—'
                              : tr('{amount}/win', {
                                  'amount': usd(w.$2.cost / 1e6 / w.$1.success)
                                }),
                          style: UtText.caption),
                    ]),
                  ),
              ]),
            ]),
    );
  }
}

/// Request errors, retries and response time from daily totals.
class _Reliability extends StatelessWidget {
  const _Reliability({required this.docs});
  final List<DailyDoc> docs;

  @override
  Widget build(BuildContext context) {
    final t = sumTotals(docs);
    var durSum = 0, durCount = 0, side = 0;
    var growthSum = 0.0, growthCount = 0;
    for (final d in docs) {
      durSum += d.totals.durationSumMs ?? 0;
      durCount += d.totals.durationCount ?? 0;
      side += d.totals.sideTokens;
      growthSum += d.totals.contextGrowthSum ?? 0;
      growthCount += d.totals.contextGrowthCount ?? 0;
    }
    final errorRate = t.requests == 0 ? null : t.errorRequests / t.requests;
    final avgSec = durCount == 0 ? null : durSum / durCount / 1000;
    return UtCard(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: UtRowGroup(children: [
        UtRow(
            title: tr('Requests'),
            subtitle: tr('{n} chats in 30 days', {'n': t.chats}),
            trailing: UtValue(compact(t.requests))),
        UtRow(
            title: tr('Failed requests'),
            subtitle: tr(
                '{n} errors returned by the provider', {'n': t.errorRequests}),
            trailing: UtValue(errorRate == null ? '—' : pct(errorRate),
                color: errorRate != null && errorRate > 0.05
                    ? UtColors.orange
                    : UtColors.text)),
        UtRow(
            title: tr('Avg. response time'),
            subtitle: tr('Per request · Codex reports this'),
            trailing: UtValue(avgSec == null
                ? '—'
                : avgSec >= 60
                    ? '${(avgSec / 60).toStringAsFixed(1)} min'
                    : '${avgSec.toStringAsFixed(0)} s')),
        UtRow(
            title: tr('Context growth'),
            subtitle: tr('Last vs first turn in a chat'),
            trailing: UtValue(growthCount == 0
                ? '—'
                : '${(growthSum / growthCount).toStringAsFixed(1)}×')),
        UtRow(
            title: tr('Sub-agent tokens'),
            subtitle: tr('Side sessions, included in totals'),
            trailing: UtValue(t.tokens == 0
                ? '—'
                : '${compact(side)} · ${pct(share(side, t.tokens), digits: 0)}')),
      ]),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric, required this.perTool});
  final ProcessMetric metric;
  final List<ProcessMetric> perTool;

  @override
  Widget build(BuildContext context) {
    final (text, tone) = switch (metric.label) {
      'good' => ('Good', UtTone.good),
      'review' => ('Review', UtTone.review),
      _ => ('No data', UtTone.neutral),
    };
    return UtCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(metricTitle(metric.metric), style: UtText.bodyStrong),
                  Text(metricHint(metric.metric), style: UtText.caption),
                ],
              ),
            ),
            Text(metricValue(metric),
                style: UtText.title.copyWith(fontSize: 18)),
            const SizedBox(width: 10),
            UtPill(text, tone: tone),
          ]),
          if (perTool.isNotEmpty) ...[
            const SizedBox(height: 12),
            const UtDivider(),
            const SizedBox(height: 10),
            Wrap(spacing: 16, runSpacing: 8, children: [
              for (final m in perTool)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  ProviderBadge(m.provider!, size: 18),
                  const SizedBox(width: 6),
                  Text(metricValue(m),
                      style: UtText.bodyStrong.copyWith(
                          color: m.label == 'review'
                              ? UtColors.orange
                              : UtColors.text)),
                ]),
            ]),
          ],
        ],
      ),
    );
  }
}

/// Success and cost per success for each tool, from the setup comparisons.
class _ToolTable extends StatelessWidget {
  const _ToolTable({required this.setups});
  final List<SetupMetric> setups;

  @override
  Widget build(BuildContext context) {
    final byTool = <String, List<SetupMetric>>{};
    for (final s in setups) {
      (byTool[s.provider] ??= []).add(s);
    }
    if (byTool.isEmpty) {
      return UtCard(
          child: Text(tr('No tool comparison yet.'), style: UtText.body));
    }
    final rows = byTool.entries.map((e) {
      final tasks = e.value.fold<int>(0, (a, s) => a + s.tasks);
      final judged = e.value.where((s) => s.sr != null).toList();
      final judgedTasks = judged.fold<int>(0, (a, s) => a + s.tasks);
      final sr = judgedTasks == 0
          ? null
          : judged.fold<double>(0, (a, s) => a + s.sr! * s.tasks) / judgedTasks;
      final priced = e.value.where((s) => s.cpstMicro != null).toList();
      final pricedTasks = priced.fold<int>(0, (a, s) => a + s.tasks);
      final cps = pricedTasks == 0
          ? null
          : priced.fold<double>(0, (a, s) => a + s.cpstMicro! * s.tasks) /
              pricedTasks /
              1e6;
      return (e.key, tasks, sr, cps, e.value.map((s) => s.model).toSet());
    }).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    return UtCard(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: UtRowGroup(children: [
        for (final r in rows)
          UtRow(
            leading: ProviderBadge(r.$1),
            title: providerName(r.$1),
            subtitle:
                '${r.$2} chats · ${r.$5.length} model${r.$5.length == 1 ? '' : 's'} · ${r.$4 == null ? '—' : usd(r.$4)} / success',
            trailing: UtValue(r.$3 == null ? '—' : pct(r.$3!, digits: 0),
                color: r.$3 == null ? UtColors.muted : UtColors.green),
          ),
      ]),
    );
  }
}

String groupLabel(String g) => switch (g) {
      'small' => tr('Small'),
      'medium' => tr('Medium'),
      'large' => tr('Large'),
      _ => g,
    };

/// Highest success-per-dollar setup with a real verdict, optionally per group.
SetupMetric? bestSetup(List<SetupMetric> setups, String? group) {
  final ranked = rankSetups(setups, group);
  return ranked.isEmpty ? null : ranked.first.$1;
}

/// Ranked (setup, efficiency index) pairs; insufficient setups are excluded.
List<(SetupMetric, double)> rankSetups(
    List<SetupMetric> setups, String? group) {
  final usable = setups
      .where((s) =>
          (group == null || s.taskGroup == group) &&
          s.verdict != 'insufficient' &&
          s.sr != null &&
          s.cpstMicro != null &&
          s.cpstMicro! > 0)
      .toList();
  if (usable.isEmpty) return [];
  final avg =
      usable.fold<int>(0, (sum, s) => sum + s.cpstMicro!) / usable.length;
  final ranked = [
    for (final s in usable) (s, s.sr! / (s.cpstMicro! / avg)),
  ]..sort((a, b) => b.$2.compareTo(a.$2));
  return ranked;
}

/// Setups with enough data to rank. When none has a verdict yet, falls back
/// to early results (≥ 5 chats) so the screen is still useful.
(List<(SetupMetric, double)>, bool early) rankForDisplay(
    List<SetupMetric> setups, String group) {
  final ranked = rankSetups(setups, group);
  if (ranked.isNotEmpty) return (ranked, false);
  final usable = setups
      .where((s) =>
          s.taskGroup == group &&
          s.tasks >= 5 &&
          s.sr != null &&
          s.cpstMicro != null &&
          s.cpstMicro! > 0)
      .toList();
  if (usable.isEmpty) return (const [], true);
  final avg =
      usable.fold<int>(0, (sum, s) => sum + s.cpstMicro!) / usable.length;
  return (
    [for (final s in usable) (s, s.sr! / (s.cpstMicro! / avg))]
      ..sort((a, b) => b.$2.compareTo(a.$2)),
    true
  );
}

/// Why a setup has no verdict yet, in plain words.
String pendingReason(SetupMetric s) {
  if (s.tasks < 20) {
    final more = 20 - s.tasks;
    return '$more more chat${more == 1 ? '' : 's'} needed for a verdict';
  }
  if (s.mde != null && s.mde! > 0.2) {
    return tr(
        'Results still vary too much (±{p})', {'p': pct(s.mde!, digits: 0)});
  }
  return 'Needs another setup with 20+ chats to compare against';
}

/// M05C — Compare models by task size.
class LiveModelComparisonScreen extends StatefulWidget {
  const LiveModelComparisonScreen({super.key, required this.args});
  final LiveArgs args;

  @override
  State<LiveModelComparisonScreen> createState() =>
      _LiveModelComparisonScreenState();
}

class _LiveModelComparisonScreenState extends State<LiveModelComparisonScreen> {
  String? _group;
  late final Stream<EfficiencyDoc?> _doc =
      widget.args.repository.watchEfficiency(uid: widget.args.uid);

  static const _groups = ['small', 'medium', 'large'];
  static const _hints = {
    'small': '1 turn · 1 file',
    'medium': '2–15 turns · 2–5 files',
    'large': '15+ turns · 6+ files',
  };

  @override
  Widget build(BuildContext context) {
    return UtPage(
      title: tr('Compare models'),
      subtitle: tr('Which model gives the most success per dollar.'),
      onBack: () => liveBack(context, '/efficiency'),
      children: [
        UtStream<EfficiencyDoc?>(
          stream: _doc,
          builder: (context, doc) {
            final all = doc?.setups ?? const <SetupMetric>[];
            int count(String g) => all
                .where((s) => s.taskGroup == g)
                .fold(0, (a, s) => a + s.tasks);
            // Open on the task size with the most chats.
            final group = _group ??
                (all.isEmpty
                    ? 'medium'
                    : (_groups.toList()
                          ..sort((a, b) => count(b).compareTo(count(a))))
                        .first);
            final setups = all.where((s) => s.taskGroup == group).toList();
            final (ranked, early) = rankForDisplay(all, group);
            final shown = {for (final r in ranked) r.$1};
            final pending = setups.where((s) => !shown.contains(s)).toList()
              ..sort((a, b) => b.tasks.compareTo(a.tasks));
            final avg = ranked.isEmpty
                ? 0.0
                : ranked.fold<int>(0, (a, r) => a + r.$1.cpstMicro!) /
                    ranked.length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UtSegmented<String>(
                  values: _groups,
                  selected: group,
                  label: (g) => '${groupLabel(g)} · ${count(g)}',
                  onChanged: (g) => setState(() => _group = g),
                ),
                const SizedBox(height: 8),
                Text('${_hints[group]!} · ${tr('number = chats')}',
                    style: UtText.caption),
                const SizedBox(height: 20),
                if (setups.isEmpty)
                  UtMessage(
                      icon: Icons.compare_arrows_rounded,
                      title: tr('Nothing to compare yet'),
                      message: tr(
                          'No chats of this size were recorded in the latest efficiency report.'))
                else ...[
                  if (ranked.isNotEmpty)
                    _BestCard(
                        setup: ranked.first.$1,
                        group: group,
                        avg: avg,
                        early: early),
                  if (early && ranked.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const _EarlyNote(),
                  ],
                  if (ranked.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    UtSectionLabel(early ? tr('Early ranking') : 'Ranking',
                        trailing: Text(tr('Efficiency index'),
                            style: UtText.caption)),
                    UtCard(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: UtRowGroup(children: [
                        for (var i = 0; i < ranked.length; i++)
                          _SetupRow(
                              rank: i + 1,
                              setup: ranked[i].$1,
                              index: ranked[i].$2,
                              best: i == 0 && !early),
                      ]),
                    ),
                  ],
                  if (pending.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    UtSectionLabel(tr('Collecting data')),
                    UtCard(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: UtRowGroup(children: [
                        for (final s in pending) _PendingRow(setup: s),
                      ]),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                Text(
                    tr('Efficiency index = success rate ÷ (cost per success ÷ average). Above 1 is better than average. A verdict needs 20+ chats per setup and results precise to ±20%.'),
                    style: UtText.caption),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _EarlyNote extends StatelessWidget {
  const _EarlyNote();
  @override
  Widget build(BuildContext context) => UtCard(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded,
              size: 18, color: UtColors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
                tr('Early results: no setup has enough chats for a confident verdict yet, so treat this ranking as a hint.'),
                style: UtText.caption.copyWith(color: UtColors.text)),
          ),
        ]),
      );
}

/// Success-rate bar with its 95% range shaded behind it.
class _SuccessBar extends StatelessWidget {
  const _SuccessBar({required this.setup});
  final SetupMetric setup;
  @override
  Widget build(BuildContext context) {
    final sr = (setup.sr ?? 0).clamp(0.0, 1.0);
    final lo = (setup.srCiLow ?? sr).clamp(0.0, 1.0);
    final hi = (setup.srCiHigh ?? sr).clamp(0.0, 1.0);
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      return SizedBox(
        height: 6,
        child: Stack(children: [
          Container(
              decoration: BoxDecoration(
                  color: UtColors.chip,
                  borderRadius: BorderRadius.circular(3))),
          Positioned(
            left: lo * w,
            width: ((hi - lo) * w).clamp(0, w),
            top: 0,
            bottom: 0,
            child: Container(
                decoration: BoxDecoration(
                    color:
                        providerColorOf(setup.provider).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(3))),
          ),
          Container(
              width: sr * w,
              decoration: BoxDecoration(
                  color: providerColorOf(setup.provider),
                  borderRadius: BorderRadius.circular(3))),
        ]),
      );
    });
  }
}

String _srText(SetupMetric s) {
  if (s.sr == null) return '—';
  final range = s.srCiLow != null && s.srCiHigh != null
      ? ' (${pct(s.srCiLow!, digits: 0)}–${pct(s.srCiHigh!, digits: 0)})'
      : '';
  return '${tr('{p} success', {'p': pct(s.sr!, digits: 0)})}$range';
}

class _SetupRow extends StatelessWidget {
  const _SetupRow(
      {required this.rank,
      required this.setup,
      required this.index,
      required this.best});
  final int rank;
  final SetupMetric setup;
  final double index;
  final bool best;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              SizedBox(width: 18, child: Text('$rank', style: UtText.caption)),
              ProviderBadge(setup.provider, size: 20),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(setup.name,
                      overflow: TextOverflow.ellipsis,
                      style: UtText.bodyStrong)),
              if (best) ...[
                UtPill(tr('Best'), tone: UtTone.good),
                const SizedBox(width: 8),
              ],
              UtValue(index.toStringAsFixed(2),
                  color: index >= 1 ? UtColors.green : UtColors.text),
            ]),
            const SizedBox(height: 10),
            _SuccessBar(setup: setup),
            const SizedBox(height: 8),
            Text(
                '${_srText(setup)} · ${usd(setup.cpstMicro! / 1e6)} / success · ${setup.tasks} chats'
                '${setup.verdict == 'insufficient' ? '' : ' · ${verdictLabel(setup.verdict)}'}',
                style: UtText.caption),
          ],
        ),
      );
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({required this.setup});
  final SetupMetric setup;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              ProviderBadge(setup.provider, size: 20),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(setup.name,
                      overflow: TextOverflow.ellipsis,
                      style: UtText.bodyStrong)),
              Text(tr('{n} chats', {'n': setup.tasks}), style: UtText.caption),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                minHeight: 4,
                value: (setup.tasks / 20).clamp(0, 1),
                backgroundColor: UtColors.chip,
                color: UtColors.muted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
                [
                  pendingReason(setup),
                  if (setup.sr != null) _srText(setup),
                ].join(' · '),
                style: UtText.caption),
          ],
        ),
      );
}

class _BestCard extends StatelessWidget {
  const _BestCard(
      {required this.setup,
      required this.group,
      required this.avg,
      this.early = false});
  final SetupMetric setup;
  final String group;
  final double avg;
  final bool early;

  @override
  Widget build(BuildContext context) {
    final cheaper = avg == 0 ? null : 1 - setup.cpstMicro! / avg;
    return UtCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
              early
                  ? tr('LEADING SO FAR · {g} TASKS',
                      {'g': groupLabel(group).toUpperCase()})
                  : tr('BEST FOR {g} TASKS',
                      {'g': groupLabel(group).toUpperCase()}),
              style: UtText.label
                  .copyWith(color: early ? UtColors.orange : UtColors.green)),
          const SizedBox(height: 8),
          Row(children: [
            ProviderBadge(setup.provider),
            const SizedBox(width: 10),
            Expanded(child: Text(setup.name, style: UtText.title)),
          ]),
          const SizedBox(height: 4),
          Text(
              tr('{tool} · {n} chats · {v} verified', {
                'tool': providerName(setup.provider),
                'n': setup.tasks,
                'v': setup.verified
              }),
              style: UtText.caption),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
                child: MiniStat(
                    value: pct(setup.sr!, digits: 0),
                    label: tr('Success rate'))),
            Expanded(
                child: MiniStat(
                    value: usd(setup.cpstMicro! / 1e6),
                    label: tr('Cost per success'))),
            Expanded(
                child: MiniStat(
                    value: cheaper == null || cheaper <= 0
                        ? '—'
                        : pct(cheaper, digits: 0),
                    label: tr('Cheaper than avg'))),
          ]),
          if (setup.redoRate != null) ...[
            const SizedBox(height: 12),
            Text(
                tr('Redo rate {p} · chats retried within 2 min',
                    {'p': pct(setup.redoRate!, digits: 0)}),
                style: UtText.caption),
          ],
        ],
      ),
    );
  }
}

String verdictLabel(String verdict) => switch (verdict) {
      'better' => tr('Better'),
      'cheaper_not_worse' => tr('Cheaper, not worse'),
      'tradeoff' => tr('Trade-off'),
      'worse' => tr('Worse'),
      'no_clear_difference' => tr('No clear difference'),
      _ => tr('Not enough data'),
    };
