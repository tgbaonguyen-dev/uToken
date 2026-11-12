import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/usage_aggregates.dart';
import '../../core/models/daily_doc.dart';
import '../../core/models/usage_docs.dart';
import '../../core/ui/ut_kit.dart';
import 'notices.dart';
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

class _LiveAnalyticsScreenState extends State<LiveAnalyticsScreen>
    with DayRollover<LiveAnalyticsScreen> {
  @override
  DateTime get localNow => widget.args.now();
  @override
  void onDayChanged() => _daily = widget.args.daily();
  late UsagePeriod _period = widget.initialPeriod;
  late Stream<List<DailyDoc>> _daily = widget.args.daily();
  late final Stream<EfficiencyDoc?> _efficiency =
      widget.args.repository.watchEfficiency(uid: widget.args.uid);

  Future<void> _choose(UsagePeriod p, DateTime now) async {
    final picked = await choosePeriod(context, p, now);
    if (picked != null && mounted) setState(() => _period = picked);
  }

  @override
  Widget build(BuildContext context) {
    return UtTabPage(
      trailing: NoticeBell(args: widget.args),
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
          final now = localNow;
          final docs = filterPeriod(all, _period, now);
          final t = sumTotals(docs);
          final models = byModel(docs);
          final outcomes = sumOutcomes(filterLastDays(all, 30, now));
          return UtList(children: [
            UtSegmented<UsagePeriod>(
              values: UsagePeriod.values,
              selected: _period,
              label: (p) => p.label,
              onChanged: (p) => _choose(p, now),
            ),
            if (_period == UsagePeriod.custom)
              CustomRangeChip(onTap: () => _choose(UsagePeriod.custom, now)),
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
              child: StreamBuilder<EfficiencyDoc?>(
                stream: _efficiency,
                builder: (context, snap) => UtRow(
                  title: tr('Efficiency'),
                  trailing: Text(
                      efficiencySummary(snap.data?.overall, outcomes),
                      style: UtText.caption),
                  onTap: () => context.push('/efficiency'),
                ),
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

/// "67% (58–75%)": a success rate with its 95% range when known.
String srWithRange(double sr, double? low, double? high) =>
    low == null || high == null
    ? pct(sr, digits: 0)
    : '${pct(sr, digits: 0)} (${pct(low, digits: 0)}–${pct(high, digits: 0)})';

/// M05 Efficiency row: main success rate (± range from the desktop report)
/// or "Not enough data" when no chat has verified evidence yet.
String efficiencySummary(OutcomeSummary? overall, Outcomes daily) {
  if (overall != null) {
    // The desktop report is authoritative; do not mix in phone estimates.
    return overall.sr == null
        ? tr('Not enough data')
        : tr('{p} success', {
            'p': srWithRange(overall.sr!, overall.srCiLow, overall.srCiHigh),
          });
  }
  if (daily.successRate != null) {
    return tr('{p} success', {'p': pct(daily.successRate!, digits: 0)});
  }
  return tr('Not enough data');
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
  late final Stream<EfficiencyDoc?> _summary =
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
                StreamBuilder<EfficiencyDoc?>(
                  stream: _summary,
                  builder: (context, snap) => _Outcome(
                      month: month,
                      prior: prior,
                      overall: snap.data?.overall,
                      undetermined: snap.data?.undeterminedTasks),
                ),
                const SizedBox(height: 16),
                _OutcomeMix(docs: month),
                const SizedBox(height: 28),
                UtSectionLabel(tr('Weekly trend'),
                    trailing: Text(tr('Success rate · verified chats'),
                        style: UtText.caption)),
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
            final picks = [
              for (final g in const ['small', 'medium', 'large'])
                ...bestPicksPerTool(doc.setups, group: g)
            ];
            final best = picks.length == 1 ? picks.single : null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UtSectionLabel(tr('Process health'),
                    trailing: Text(
                        tr('{n} to review', {
                          'n': overall.where((m) => m.label == 'review').length
                        }),
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
                        ? tr('{g} tasks: {m} · {v}', {
                            'g': groupLabel(best.taskGroup),
                            'm': best.name,
                            'v': verdictLabel(best.verdict)
                          })
                        : picks.isEmpty
                            ? tr('No setup has a clear verdict yet')
                            : tr('{n} setups have a clear verdict',
                                {'n': picks.length}),
                    onTap: () => context.push('/model-comparison'),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                    '${tr('Success rate counts only chats with evidence: a passing test or build, or a failed or aborted turn. "Incl. likely" also counts likely results.')} '
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
  const _Outcome({
    required this.month,
    required this.prior,
    this.overall,
    this.undetermined,
  });
  final List<DailyDoc> month, prior;

  /// Desktop summary for the same 30 days; null for older desktop builds.
  final OutcomeSummary? overall;
  final int? undetermined;

  /// Cost per verified success from daily totals (same rule as the desktop).
  static double? _cpst(List<DailyDoc> docs) {
    final t = sumTotals(docs);
    final o = sumOutcomes(docs);
    return o.verifiedSuccess == 0 || !t.costKnown
        ? null
        : t.cost / 1e6 / o.verifiedSuccess;
  }

  static String _money(int? micro) =>
      micro == null ? '—' : usdSmart(micro / 1e6);

  @override
  Widget build(BuildContext context) {
    final o = sumOutcomes(month);
    final s = overall;
    // With a desktop summary every number below comes from it; daily totals
    // are only a fallback for older desktop builds. The trend is always
    // estimated from daily totals because the report has no prior period.
    final cpst = s != null
        ? (s.cpstMicro == null ? null : s.cpstMicro! / 1e6)
        : _cpst(month);
    final before = _cpst(prior), now = _cpst(month);
    final change = now == null || before == null || before == 0
        ? null
        : (now - before) / before;
    final sr = s != null ? s.sr : o.successRate;
    final srAlt = s != null ? s.srAlt : o.successRateInclLikely;
    final verified = s != null ? s.verified : o.verified;
    final undecided = undetermined ?? o.undetermined;
    return UtCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('Outcome'), style: UtText.label),
          const SizedBox(height: 10),
          Text(usd(cpst), style: UtText.code),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  tr('Cost per successful task'),
                  style: UtText.caption,
                ),
              ),
              if (change != null)
                Text(
                  '${change <= 0 ? '−' : '+'}${pct(change.abs(), digits: 0)} ${tr(s == null ? 'vs previous 30 days' : 'vs previous 30 days (daily totals)')}',
                  style: UtText.caption.copyWith(
                    color: change <= 0 ? UtColors.green : UtColors.orange,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const UtDivider(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: MiniStat(
                  value: sr == null ? '—' : pct(sr, digits: 0),
                  label: tr('Success rate'),
                ),
              ),
              Expanded(
                child: MiniStat(
                  value: srAlt == null ? '—' : pct(srAlt, digits: 0),
                  label: tr('Incl. likely'),
                ),
              ),
              Expanded(
                child: MiniStat(value: '$undecided', label: tr('Undetermined')),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: MiniStat(
                  value: _money(s?.costP50Micro),
                  label: tr('Cost / task P50'),
                ),
              ),
              Expanded(
                child: MiniStat(
                  value: _money(s?.costP90Micro),
                  label: tr('Cost / task P90'),
                ),
              ),
              Expanded(
                child: MiniStat(
                  value: s?.redoRate == null
                      ? '—'
                      : pct(s!.redoRate!, digits: 0),
                  label: tr('Redo rate'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            [
              if (sr == null)
                tr('Not enough data: no chat has verified evidence yet.')
              else if (s?.srCiLow != null && s?.srCiHigh != null)
                tr('95% range {lo}–{hi} · {n} verified chats', {
                  'lo': pct(s!.srCiLow!, digits: 0),
                  'hi': pct(s.srCiHigh!, digits: 0),
                  'n': verified,
                })
              else
                tr('{n} verified chats', {'n': verified}),
              if (s?.unstable ?? false)
                tr('Unstable: results swing a lot week to week.'),
            ].join(' · '),
            style: UtText.caption,
          ),
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
      (tr('Verified success'), sum('verified_success'), UtColors.green),
      (
        tr('Likely success'),
        sum('likely_success'),
        UtColors.green.withValues(alpha: 0.5)
      ),
      (
        tr('Failed'),
        sum('verified_failure') + sum('likely_failure'),
        red,
      ),
      (tr('Undetermined'), sum('undetermined'), UtColors.muted),
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

/// Main success rate for each of the last four weeks, oldest first. A week
/// needs at least [minVerified] verified chats, like the desktop report.
class _WeeklyTrend extends StatelessWidget {
  const _WeeklyTrend({required this.all, required this.now});
  static const minVerified = 5;
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
        ),
    ];
    double? rate(Outcomes o) =>
        o.verified < _WeeklyTrend.minVerified ? null : o.successRate;
    final any = weeks.any((w) => rate(w.$1) != null);
    return UtCard(
      child: !any
          ? Text(tr('Not enough judged chats yet.'), style: UtText.body)
          : Column(
              children: [
                BarChart(
                  height: 80,
                  color: UtColors.green,
                  highlightLast: false,
                  values: [for (final w in weeks) rate(w.$1) ?? 0],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final w in weeks)
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              rate(w.$1) == null
                                  ? '—'
                                  : pct(rate(w.$1)!, digits: 0),
                              style: UtText.bodyStrong,
                            ),
                            Text(
                              w.$3 == 0
                                  ? tr('This week')
                                  : tr('{n}w ago', {'n': w.$3}),
                              style: UtText.caption,
                            ),
                            Text(
                              w.$1.verifiedSuccess == 0 || !w.$2.costKnown
                                  ? '—'
                                  : tr('{amount}/win', {
                                      'amount': usd(
                                        w.$2.cost / 1e6 / w.$1.verifiedSuccess,
                                      ),
                                    }),
                              style: UtText.caption,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
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
      'good' => (tr('Good'), UtTone.good),
      'review' => (tr('Review'), UtTone.review),
      _ => (tr('No data'), UtTone.neutral),
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
      // SR is verified successes ÷ verified chats across the tool's setups,
      // so weight by verified chats (all chats when a report lacks
      // n_verified); CPST = total cost ÷ total successes.
      double w(SetupMetric s) => (s.verified > 0 ? s.verified : s.tasks) * 1.0;
      final judged = e.value.where((s) => s.sr != null).toList();
      final weight = judged.fold<double>(0, (a, s) => a + w(s));
      final sr = weight == 0
          ? null
          : judged.fold<double>(0, (a, s) => a + s.sr! * w(s)) / weight;
      final priced = judged.where((s) => s.cpstMicro != null).toList();
      final wins = priced.fold<double>(0, (a, s) => a + s.sr! * w(s));
      final cps = wins == 0
          ? null
          : priced.fold<double>(0, (a, s) => a + s.cpstMicro! * s.sr! * w(s)) /
              wins /
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
            subtitle: tr(
                r.$5.length == 1
                    ? '{n} chats · 1 model · {amount} / success'
                    : '{n} chats · {m} models · {amount} / success',
                {
              'n': r.$2,
              'm': r.$5.length,
              'amount': r.$4 == null ? '—' : usd(r.$4)
            }),
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

/// "Best pick" (FR-ANLY-003 M05C): only a setup whose verdict is "Better" or
/// "Cheaper, not worse". "Better" wins, then the lower cost per success.
SetupMetric? bestPick(
  Iterable<SetupMetric> setups, {
  String? group,
  String? provider,
}) {
  final picks =
      setups
          .where(
            (s) =>
                s.isBestPick &&
                (group == null || s.taskGroup == group) &&
                (provider == null || s.provider == provider),
          )
          .toList()
        ..sort((a, b) {
          final v = (a.verdict == 'better' ? 0 : 1).compareTo(
            b.verdict == 'better' ? 0 : 1,
          );
          if (v != 0) return v;
          return (a.cpstMicro ?? 1 << 52).compareTo(b.cpstMicro ?? 1 << 52);
        });
  return picks.isEmpty ? null : picks.first;
}

/// One best pick per tool: verdicts only compare setups of the same tool and
/// task size (FR-ANLY-003 §D step 0), so picks from different tools were never
/// compared with each other and are shown side by side.
List<SetupMetric> bestPicksPerTool(Iterable<SetupMetric> setups,
    {String? group}) {
  final tools = setups.map((s) => s.provider).toSet().toList()..sort();
  return [
    for (final t in tools)
      if (bestPick(setups, group: group, provider: t) case final pick?) pick
  ];
}

/// Display order for setups with a verdict. This groups setups by verdict; it
/// is not a ranking (the SRS removed the efficiency index).
const _verdictOrder = [
  'better',
  'cheaper_not_worse',
  'no_clear_difference',
  'tradeoff',
  'worse',
];

/// Why a setup has no verdict yet, in plain words.
String pendingReason(SetupMetric s) {
  if (s.tasks < 20) {
    return tr('Not enough data · {n}/20', {'n': s.tasks});
  }
  if (s.mde != null && s.mde! > 0.2) {
    return tr('Results still vary too much (±{p})', {
      'p': pct(s.mde!, digits: 0),
    });
  }
  return tr('Needs another setup with 20+ chats to compare against');
}

UtTone verdictTone(String verdict) => switch (verdict) {
  'better' || 'cheaper_not_worse' => UtTone.good,
  'worse' => UtTone.review,
  _ => UtTone.neutral,
};

String? confidenceLabel(String? c) => switch (c) {
  'high' => tr('High certainty'),
  'medium' => tr('Medium certainty'),
  _ => null,
};

/// M05C — Compare setups by source and task size, with verdicts instead of a ranking.
class LiveModelComparisonScreen extends StatefulWidget {
  const LiveModelComparisonScreen({super.key, required this.args});
  final LiveArgs args;

  @override
  State<LiveModelComparisonScreen> createState() =>
      _LiveModelComparisonScreenState();
}

class _LiveModelComparisonScreenState extends State<LiveModelComparisonScreen> {
  String? _group;

  /// Selected source (collector id); null = every source.
  String? _provider;
  late final Stream<EfficiencyDoc?> _doc = widget.args.repository
      .watchEfficiency(uid: widget.args.uid);

  static const _groups = ['small', 'medium', 'large'];
  static const _hints = {
    // Same split as the desktop TaskBuilder (model requests per task).
    'small': 'Up to 10 model requests',
    'medium': '11–40 model requests',
    'large': 'Over 40 model requests',
  };

  @override
  Widget build(BuildContext context) {
    return UtPage(
      title: tr('Compare models'),
      subtitle: tr(
        'Success and cost per success, with a verdict when the data is strong enough.',
      ),
      onBack: () => liveBack(context, '/efficiency'),
      children: [
        UtStream<EfficiencyDoc?>(
          stream: _doc,
          builder: (context, doc) {
            final everything = doc?.setups ?? const <SetupMetric>[];
            final sources = everything.map((s) => s.provider).toSet().toList()
              ..sort();
            final provider = sources.contains(_provider) ? _provider : null;
            final all = everything
                .where((s) => provider == null || s.provider == provider)
                .toList();
            int count(String g) => all
                .where((s) => s.taskGroup == g)
                .fold(0, (a, s) => a + s.tasks);
            // Open on the task size with the most chats.
            final group =
                _group ??
                (all.isEmpty
                    ? 'medium'
                    : (_groups.toList()
                            ..sort((a, b) => count(b).compareTo(count(a))))
                          .first);
            final setups = all.where((s) => s.taskGroup == group).toList();
            final decided =
                setups.where((s) => _verdictOrder.contains(s.verdict)).toList()
                  ..sort((a, b) {
                    final v = _verdictOrder
                        .indexOf(a.verdict)
                        .compareTo(_verdictOrder.indexOf(b.verdict));
                    return v != 0 ? v : b.tasks.compareTo(a.tasks);
                  });
            final pending =
                setups.where((s) => !_verdictOrder.contains(s.verdict)).toList()
                  ..sort((a, b) => b.tasks.compareTo(a.tasks));
            final picks = bestPicksPerTool(setups);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (sources.length > 1) ...[
                  UtSegmented<String>(
                    values: ['', ...sources],
                    selected: provider ?? '',
                    label: (p) => p.isEmpty ? tr('All tools') : providerName(p),
                    onChanged: (p) =>
                        setState(() => _provider = p.isEmpty ? null : p),
                  ),
                  const SizedBox(height: 12),
                ],
                UtSegmented<String>(
                  values: _groups,
                  selected: group,
                  label: (g) => '${groupLabel(g)} · ${count(g)}',
                  onChanged: (g) => setState(() => _group = g),
                ),
                const SizedBox(height: 8),
                Text(
                  '${tr(_hints[group]!)} · ${tr('number = chats')}',
                  style: UtText.caption,
                ),
                const SizedBox(height: 20),
                if (setups.isEmpty)
                  UtMessage(
                    icon: Icons.compare_arrows_rounded,
                    title: tr('Nothing to compare yet'),
                    message: tr(
                      'No chats of this size were recorded in the latest efficiency report.',
                    ),
                  )
                else ...[
                  for (var i = 0; i < picks.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _BestCard(
                        setup: picks[i],
                        group: group,
                        perTool: picks.length > 1),
                  ],
                  if (decided.isNotEmpty) ...[
                    if (picks.isNotEmpty) const SizedBox(height: 28),
                    UtSectionLabel(tr('Verdicts')),
                    UtCard(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: UtRowGroup(
                        children: [
                          for (final s in decided)
                            _SetupRow(setup: s, best: picks.contains(s)),
                        ],
                      ),
                    ),
                  ],
                  if (pending.isNotEmpty) ...[
                    if (picks.isNotEmpty || decided.isNotEmpty)
                      const SizedBox(height: 28),
                    UtSectionLabel(tr('Collecting data')),
                    UtCard(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: UtRowGroup(
                        children: [
                          for (final s in pending) _PendingRow(setup: s),
                        ],
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                Text(
                  tr(
                    'Each setup is compared with the busiest setup of the same tool and task size. A verdict needs 20+ chats per setup and results precise to ±20 points; until then the setup shows its progress and is not ranked.',
                  ),
                  style: UtText.caption,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
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
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        return SizedBox(
          height: 6,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: UtColors.chip,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Positioned(
                left: lo * w,
                width: ((hi - lo) * w).clamp(0, w),
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: providerColorOf(setup.provider)
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Container(
                width: sr * w,
                decoration: BoxDecoration(
                  color: providerColorOf(setup.provider),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _srText(SetupMetric s) => s.sr == null
    ? '—'
    : tr('{p} success', {'p': srWithRange(s.sr!, s.srCiLow, s.srCiHigh)});

/// "$0.18 / success" with its bootstrap range when the desktop computed one.
String _cpstText(SetupMetric s) {
  if (s.cpstMicro == null) return tr('{amount} / success', {'amount': '—'});
  final range = s.cpstCiLowMicro != null && s.cpstCiHighMicro != null
      ? ' (${usdSmart(s.cpstCiLowMicro! / 1e6)}–${usdSmart(s.cpstCiHighMicro! / 1e6)})'
      : '';
  return tr('{amount} / success', {
    'amount': '${usdSmart(s.cpstMicro! / 1e6)}$range',
  });
}

class _SetupRow extends StatelessWidget {
  const _SetupRow({required this.setup, required this.best});
  final SetupMetric setup;
  final bool best;

  @override
  Widget build(BuildContext context) {
    final certainty = confidenceLabel(setup.confidence);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ProviderBadge(setup.provider, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  setup.name,
                  overflow: TextOverflow.ellipsis,
                  style: UtText.bodyStrong,
                ),
              ),
              if (best) ...[
                UtPill(tr('Best pick'), tone: UtTone.good),
                const SizedBox(width: 6),
              ],
              UtPill(
                verdictLabel(setup.verdict),
                tone: verdictTone(setup.verdict),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SuccessBar(setup: setup),
          const SizedBox(height: 8),
          Text(
            [
              _srText(setup),
              _cpstText(setup),
              tr('{n} chats', {'n': setup.tasks}),
            ].join(' · '),
            style: UtText.caption,
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (setup.comparedTo != null)
                tr('vs {m}', {'m': setup.comparedTo}),
              if (certainty != null) certainty,
              if (setup.mde != null)
                tr('MDE ±{p}', {'p': pct(setup.mde!, digits: 0)}),
              if (setup.unstable) tr('Unstable'),
              if (setup.crossTool) tr('Tool + model comparison'),
            ].join(' · '),
            style: UtText.caption.copyWith(
              color: setup.unstable ? UtColors.orange : UtColors.muted,
            ),
          ),
        ],
      ),
    );
  }
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
        Row(
          children: [
            ProviderBadge(setup.provider, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                setup.name,
                overflow: TextOverflow.ellipsis,
                style: UtText.bodyStrong,
              ),
            ),
            Text(tr('{n} chats', {'n': setup.tasks}), style: UtText.caption),
          ],
        ),
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
        Text(pendingReason(setup), style: UtText.caption),
      ],
    ),
  );
}

class _BestCard extends StatelessWidget {
  const _BestCard(
      {required this.setup, required this.group, this.perTool = false});
  final SetupMetric setup;
  final String group;

  /// Several tools each have a pick; say the pick is within its own tool.
  final bool perTool;

  @override
  Widget build(BuildContext context) {
    final certainty = confidenceLabel(setup.confidence);
    return UtCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            perTool
                ? tr('BEST PICK IN {tool} · {g} TASKS', {
                    'tool': providerName(setup.provider).toUpperCase(),
                    'g': groupLabel(group).toUpperCase()
                  })
                : tr('BEST PICK · {g} TASKS',
                    {'g': groupLabel(group).toUpperCase()}),
            style: UtText.label.copyWith(color: UtColors.green),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ProviderBadge(setup.provider),
              const SizedBox(width: 10),
              Expanded(child: Text(setup.name, style: UtText.title)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            tr('{tool} · {n} chats · {v} verified', {
              'tool': providerName(setup.provider),
              'n': setup.tasks,
              'v': setup.verified,
            }),
            style: UtText.caption,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: MiniStat(
                  value: setup.sr == null ? '—' : pct(setup.sr!, digits: 0),
                  label: tr('Success rate'),
                ),
              ),
              Expanded(
                child: MiniStat(
                  value: setup.cpstMicro == null
                      ? '—'
                      : usdSmart(setup.cpstMicro! / 1e6),
                  label: tr('Cost per success'),
                ),
              ),
              Expanded(
                child: MiniStat(
                  value: verdictLabel(setup.verdict),
                  label: setup.comparedTo == null
                      ? tr('Verdict')
                      : tr('vs {m}', {'m': setup.comparedTo}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            [
              if (setup.srCiLow != null && setup.srCiHigh != null)
                tr('95% range {lo}–{hi}', {
                  'lo': pct(setup.srCiLow!, digits: 0),
                  'hi': pct(setup.srCiHigh!, digits: 0),
                }),
              if (certainty != null) certainty,
              if (setup.verdict == 'cheaper_not_worse' && setup.mde != null)
                tr('MDE ±{p}', {'p': pct(setup.mde!, digits: 0)}),
              if (setup.redoRate != null)
                tr('Redo rate {p}', {'p': pct(setup.redoRate!, digits: 0)}),
              if (setup.unstable) tr('Unstable'),
            ].join(' · '),
            style: UtText.caption,
          ),
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
