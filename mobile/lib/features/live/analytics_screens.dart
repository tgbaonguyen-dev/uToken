import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/usage_aggregates.dart';
import '../../core/models/daily_doc.dart';
import '../../core/models/usage_docs.dart';
import '../../core/ui/ut_kit.dart';
import 'live_common.dart';

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
      title: 'Analytics',
      subtitle: 'Token mix, models, and cost.',
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
              label: (p) => p.label,
              onChanged: (p) => setState(() => _period = p),
            ),
            const SizedBox(height: 22),
            UtCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Total tokens', style: UtText.label),
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
                    Text('Input ${pct(share(t.input, t.tokens))}',
                        style: UtText.caption),
                    const Spacer(),
                    Text('Output ${pct(share(t.output, t.tokens))}',
                        style: UtText.caption),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 16),
            UtCard(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(children: [
                const Row(children: [
                  Expanded(flex: 5, child: Text('Model', style: UtText.label)),
                  Expanded(
                      flex: 2,
                      child: Text('Tokens',
                          textAlign: TextAlign.right, style: UtText.label)),
                  Expanded(
                      flex: 2,
                      child: Text('Share',
                          textAlign: TextAlign.right, style: UtText.label)),
                ]),
                const SizedBox(height: 8),
                if (models.isEmpty)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child:
                          Text('No usage in this period.', style: UtText.body)),
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
                title: 'Efficiency',
                trailing: Text(
                    outcomes.successRate == null
                        ? 'No outcomes yet'
                        : '${pct(outcomes.successRate!, digits: 0)} success',
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
          const Text('Cost · last 7 days', style: UtText.label),
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
      'cache_hit_rate' => 'Cache hit rate',
      'context_growth' => 'Context growth',
      'thinking_share' => 'Thinking share',
      'error_rate' => 'Error rate',
      'retry_rate' => 'Retry rate',
      'tokens_per_turn_vs_median' => 'Tokens per turn',
      'cost_tail' => 'Cost tail',
      'hidden_cost_share' => 'Hidden cost',
      _ => id,
    };

String metricHint(String id) => switch (id) {
      'cache_hit_rate' => 'Input served from cache',
      'context_growth' => 'Last vs first turn in a chat',
      'thinking_share' => 'Reasoning inside output',
      'error_rate' => 'Requests that failed',
      'retry_rate' => 'Requests resent within 2 min',
      'tokens_per_turn_vs_median' => 'Compared with your median',
      'cost_tail' => 'Share of cost from the costliest chats',
      'hidden_cost_share' => 'Background requests you did not send',
      _ => '',
    };

String metricValue(ProcessMetric m) {
  final v = m.value;
  if (v == null) return '—';
  return switch (m.metric) {
    'context_growth' ||
    'tokens_per_turn_vs_median' =>
      '${v.toStringAsFixed(1)}×',
    _ => pct(v, digits: 0),
  };
}

/// M05B — Efficiency: outcomes and process health.
class LiveEfficiencyScreen extends StatelessWidget {
  const LiveEfficiencyScreen({super.key, required this.args});
  final LiveArgs args;

  @override
  Widget build(BuildContext context) {
    return UtPage(
      title: 'Efficiency',
      subtitle: 'Results per token · last 30 days',
      onBack: () => liveBack(context, '/analytics'),
      children: [
        UtStream<List<DailyDoc>>(
          stream: args.daily(),
          builder: (context, all) {
            final now = DateTime.now();
            final month = filterLastDays(all, 30, now);
            final prior = filterLastDays(all, 30, now, offsetDays: 30);
            return _Outcome(month: month, prior: prior);
          },
        ),
        const SizedBox(height: 28),
        UtStream<EfficiencyDoc?>(
          stream: args.repository.watchEfficiency(uid: args.uid),
          builder: (context, doc) {
            if (doc == null) {
              return const UtMessage(
                  icon: Icons.speed_outlined,
                  title: 'No efficiency report yet',
                  message:
                      'The desktop app writes this report after it has enough chats to compare.');
            }
            final metrics =
                doc.processMetrics.where((m) => m.provider == null).toList();
            final best = bestSetup(doc.setups, null);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const UtSectionLabel('Process'),
                UtCard(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: UtRowGroup(children: [
                    if (metrics.isEmpty)
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('No process metrics yet.',
                              style: UtText.body)),
                    for (final m in metrics)
                      UtRow(
                        title: metricTitle(m.metric),
                        subtitle: metricHint(m.metric),
                        trailing:
                            Row(mainAxisSize: MainAxisSize.min, children: [
                          UtValue(metricValue(m)),
                          const SizedBox(width: 8),
                          UtPill(
                              switch (m.label) {
                                'good' => 'Good',
                                'review' => 'Review',
                                _ => 'No data',
                              },
                              tone: switch (m.label) {
                                'good' => UtTone.good,
                                'review' => UtTone.review,
                                _ => UtTone.neutral,
                              }),
                        ]),
                      ),
                  ]),
                ),
                const SizedBox(height: 16),
                UtCard(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: UtRow(
                    title: 'Compare models',
                    subtitle: best == null
                        ? 'Not enough chats to rank models yet'
                        : '${groupLabel(best.taskGroup)} tasks: ${best.model} gives most success per dollar',
                    onTap: () => context.push('/model-comparison'),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                    'A chat counts as successful when it ends with a verified or likely successful result. '
                    'Report ${doc.periodStart} – ${doc.periodEnd}.',
                    style: UtText.caption),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: utActionKey('See suggestions'),
                    onPressed: () => context.go('/insights'),
                    child: const Text('See suggestions ›',
                        style: UtText.bodyStrong),
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
    final cps = _cps(month), before = _cps(prior);
    final change = cps == null || before == null || before == 0
        ? null
        : (cps - before) / before;
    final all = o.decided + o.undetermined;
    return UtCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Outcome', style: UtText.label),
          const SizedBox(height: 10),
          Text(usd(cps), style: UtText.code),
          const SizedBox(height: 6),
          Row(children: [
            const Expanded(
                child: Text('Cost per successful task', style: UtText.caption)),
            if (change != null)
              Text(
                  '${change <= 0 ? '−' : '+'}${pct(change.abs(), digits: 0)} vs last month',
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
                    label: 'Success rate')),
            Expanded(
                child: MiniStat(
                    value: o.success == 0
                        ? '—'
                        : pct(o.verifiedSuccess / o.success, digits: 0),
                    label: 'Verified')),
            Expanded(
                child: MiniStat(
                    value:
                        all == 0 ? '—' : pct(o.undetermined / all, digits: 0),
                    label: 'Undetermined')),
          ]),
        ],
      ),
    );
  }
}

String groupLabel(String g) => switch (g) {
      'small' => 'Small',
      'medium' => 'Medium',
      'large' => 'Large',
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

/// M05C — Compare models by task size.
class LiveModelComparisonScreen extends StatefulWidget {
  const LiveModelComparisonScreen({super.key, required this.args});
  final LiveArgs args;

  @override
  State<LiveModelComparisonScreen> createState() =>
      _LiveModelComparisonScreenState();
}

class _LiveModelComparisonScreenState extends State<LiveModelComparisonScreen> {
  String _group = 'medium';
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
      title: 'Compare models',
      subtitle: 'Which model gives the most success per dollar.',
      onBack: () => liveBack(context, '/efficiency'),
      children: [
        UtSegmented<String>(
          values: _groups,
          selected: _group,
          label: groupLabel,
          onChanged: (g) => setState(() => _group = g),
        ),
        const SizedBox(height: 8),
        Text(_hints[_group]!, style: UtText.caption),
        const SizedBox(height: 20),
        UtStream<EfficiencyDoc?>(
          stream: _doc,
          builder: (context, doc) {
            final setups = (doc?.setups ?? const <SetupMetric>[])
                .where((s) => s.taskGroup == _group)
                .toList();
            if (setups.isEmpty) {
              return const UtMessage(
                  icon: Icons.compare_arrows_rounded,
                  title: 'Nothing to compare yet',
                  message:
                      'No chats of this size were recorded in the latest efficiency report.');
            }
            final ranked = rankSetups(setups, _group);
            final pending =
                setups.where((s) => !ranked.any((r) => r.$1 == s)).toList();
            final avg = setups
                    .where((s) => s.cpstMicro != null)
                    .fold<int>(0, (a, s) => a + s.cpstMicro!) /
                setups.where((s) => s.cpstMicro != null).length.clamp(1, 999);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (ranked.isNotEmpty)
                  _BestCard(setup: ranked.first.$1, group: _group, avg: avg),
                const SizedBox(height: 28),
                const UtSectionLabel('Ranking',
                    trailing: Text('Efficiency index', style: UtText.caption)),
                UtCard(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: UtRowGroup(children: [
                    for (var i = 0; i < ranked.length; i++)
                      UtRow(
                        leading: SizedBox(
                            width: 18,
                            child: Text('${i + 1}', style: UtText.caption)),
                        title: ranked[i].$1.model,
                        subtitle:
                            '${pct(ranked[i].$1.sr!, digits: 0)} success · ${usd(ranked[i].$1.cpstMicro! / 1e6)} / success · ${verdictLabel(ranked[i].$1.verdict)}',
                        trailing:
                            Row(mainAxisSize: MainAxisSize.min, children: [
                          if (i == 0) ...[
                            const UtPill('Best', tone: UtTone.good),
                            const SizedBox(width: 8),
                          ],
                          UtValue(ranked[i].$2.toStringAsFixed(2)),
                        ]),
                      ),
                    for (final s in pending)
                      UtRow(
                        leading: const SizedBox(
                            width: 18, child: Text('–', style: UtText.caption)),
                        title: s.model,
                        subtitle: '${s.tasks} of 20 chats needed to rank',
                        trailing: const UtValue('—', color: UtColors.muted),
                      ),
                  ]),
                ),
                const SizedBox(height: 16),
                const Text(
                    'Efficiency index = success rate ÷ (cost per success ÷ average). Above 1 is better than average.',
                    style: UtText.caption),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _BestCard extends StatelessWidget {
  const _BestCard(
      {required this.setup, required this.group, required this.avg});
  final SetupMetric setup;
  final String group;
  final double avg;

  @override
  Widget build(BuildContext context) {
    final cheaper = avg == 0 ? null : 1 - setup.cpstMicro! / avg;
    return UtCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('BEST FOR ${groupLabel(group).toUpperCase()} TASKS',
              style: UtText.label.copyWith(color: UtColors.green)),
          const SizedBox(height: 8),
          Text(setup.model, style: UtText.title),
          Text(providerName(setup.provider), style: UtText.caption),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
                child: MiniStat(
                    value: pct(setup.sr!, digits: 0), label: 'Success rate')),
            Expanded(
                child: MiniStat(
                    value: usd(setup.cpstMicro! / 1e6),
                    label: 'Cost per success')),
            Expanded(
                child: MiniStat(
                    value: cheaper == null || cheaper <= 0
                        ? '—'
                        : pct(cheaper, digits: 0),
                    label: 'Cheaper than avg')),
          ]),
        ],
      ),
    );
  }
}

String verdictLabel(String verdict) => switch (verdict) {
      'better' => 'Better',
      'cheaper_not_worse' => 'Cheaper, not worse',
      'tradeoff' => 'Trade-off',
      'worse' => 'Worse',
      'no_clear_difference' => 'No clear difference',
      _ => 'Not enough data',
    };
