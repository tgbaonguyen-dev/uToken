import 'dart:async';
import '../../core/data/usage_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/usage_aggregates.dart';
import '../../core/format/token_format.dart';
import '../../core/models/daily_doc.dart';
import '../../core/ui/ut_kit.dart';
import 'notices.dart';
import 'live_common.dart';
import 'sync_banners.dart';
import '../../core/i18n/tr.dart';

/// M04 — Tokens overview, including the S01/S02/S04 states.
class LiveTokensScreen extends StatefulWidget {
  const LiveTokensScreen(
      {super.key,
      required this.args,
      this.initialPeriod = UsagePeriod.month,
      this.now = DateTime.now});
  final LiveArgs args;
  final UsagePeriod initialPeriod;
  final DateTime Function() now;

  @override
  State<LiveTokensScreen> createState() => _LiveTokensScreenState();
}

class _LiveTokensScreenState extends State<LiveTokensScreen>
    with WidgetsBindingObserver {
  late UsagePeriod _period = widget.initialPeriod;
  late Stream<DailySnapshot> _daily;
  late Stream<DateTime?> _lastSync =
      widget.args.repository.watchLastSync(uid: widget.args.uid);

  Timer? _midnightTimer;
  String? _queryDate;

  @override
  void initState() {
    super.initState();
    _daily = _watchDaily();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnight();
  }

  @override
  void didUpdateWidget(covariant LiveTokensScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.args.uid != widget.args.uid ||
        oldWidget.args.repository != widget.args.repository ||
        oldWidget.now != widget.now) {
      _daily = _watchDaily();
      _lastSync = widget.args.repository.watchLastSync(uid: widget.args.uid);
      _scheduleMidnight();
    }
  }

  Stream<DailySnapshot> _watchDaily() {
    final now = widget.now();
    _queryDate = now.toIso8601String().substring(0, 10);
    return widget.args.repository.watchDaily(
      uid: widget.args.uid,
      end: now,
    );
  }

  void _scheduleMidnight() {
    _midnightTimer?.cancel();
    final now = widget.now();
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(next.difference(now), _refreshDate);
  }

  void _refreshDate() {
    if (!mounted) return;
    if (_queryDate != widget.now().toIso8601String().substring(0, 10)) {
      setState(() => _daily = _watchDaily());
    }
    _scheduleMidnight();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshDate();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UtTabPage(
      trailing: NoticeBell(args: widget.args),
      title: tr('Tokens'),
      subtitle: tr('What your AI chats used.'),
      tabIndex: 0,
      onRefresh: () async {
        await widget.args.refresh();
        if (mounted) setState(() => _daily = _watchDaily());
      },
      body: ListenableBuilder(
        listenable: widget.args.sync,
        builder: (context, _) => StreamBuilder<DateTime?>(
          stream: _lastSync,
          builder: (context, sync) {
            _autoSync(sync.data);
            return UtStream<DailySnapshot>(
              stream: _daily,
              builder: (context, all) => Column(children: [
                if (all.invalidDocumentIds.isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                          tr('Ignored {n} invalid daily summaries. Totals and exports exclude these days. Fix field types in Firebase and refresh.',
                              {'n': all.invalidDocumentIds.length}),
                          key: const ValueKey('invalid-daily-warning'),
                          style: UtText.caption)),
                Expanded(child: _body(context, all.documents, sync.data)),
              ]),
            );
          },
        ),
      ),
    );
  }

  /// FR-SYNC-001 screen_open: ask for fresh data when it's old. Deferred
  /// to after the frame because it notifies listeners.
  void _autoSync(DateTime? lastSync) {
    if (lastSync == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.args.sync.maybeAutoSync(lastSync);
    });
  }

  Future<void> _choose(UsagePeriod p, DateTime now) async {
    final picked = await choosePeriod(context, p, now);
    if (picked != null && mounted) setState(() => _period = picked);
  }

  Widget _body(BuildContext context, List<DailyDoc> all, DateTime? lastSync) {
    final now = widget.now();
    final sync = widget.args.sync;
    final banner = switch (sync.phase) {
      SyncPhase.syncing => SyncingBanner(sync: sync),
      SyncPhase.failed => SyncFailedBanner(sync: sync),
      SyncPhase.idle =>
        lastSync != null && now.difference(lastSync).inHours >= 24
            ? _StaleBanner(lastSync: lastSync, sync: sync)
            : null,
    };
    if (all.isEmpty) {
      return UtList(children: [
        NoticeBanner(args: widget.args),
        if (banner != null && lastSync != null) banner,
        lastSync == null ? const _NotConnected() : const _WaitingForUsage(),
      ]);
    }
    final docs = filterPeriod(all, _period, now);
    final totals = sumTotals(docs);
    final providers = byProvider(docs);
    return UtList(children: [
      NoticeBanner(args: widget.args),
      if (banner != null) banner,
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
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('Total tokens'), style: UtText.label),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(formatTokens(totals.tokens, TokenFormat.full),
                  key: const ValueKey('exact-token-total'),
                  textAlign: TextAlign.center,
                  style: UtText.hero),
            ),
            InkWell(
              key: utActionKey('Estimated cost'),
              onTap: () => context.push(withPeriod('/cost-breakdown', _period)),
              child: Text(
                  tr('{amount} estimated', {'amount': usd(totals.costUsd)}),
                  textAlign: TextAlign.center,
                  style: UtText.title
                      .copyWith(fontSize: 16, color: UtColors.green)),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ShareBar(height: 7, parts: [
                for (final p in providers)
                  (
                    share(p.value.tokens, totals.tokens),
                    providerColorOf(p.key)
                  ),
              ]),
            ),
            const SizedBox(height: 8),
            _MiniStats(all: all, docs: docs, now: now),
          ],
        ),
      ),
      if (docs.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
              tr('No uploaded usage in this period. Run Sync now on desktop, then refresh here.'),
              style: UtText.body),
        ),
      const SizedBox(height: 28),
      UtSectionLabel(tr('Sources'),
          trailing: InkWell(
            key: utActionKey('Full report'),
            onTap: () => context.push(withPeriod('/usage-details', _period)),
            child: Text(tr('Full report  ›'),
                style: UtText.caption.copyWith(color: UtColors.text)),
          )),
      _ProviderCards(providers: providers, total: totals.tokens),
      const SizedBox(height: 28),
      UtCard(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UtSectionLabel(tr('Usage trend'),
                trailing: Text(_trendLabel(docs, now), style: UtText.caption)),
            _Trend(docs: docs, period: _period, now: now),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Text(_coverage(all, now),
          key: const ValueKey('cloud-data-coverage'), style: UtText.caption),
    ]);
  }

  /// Range the chart covers, e.g. "Today", "Last 7 days", "Since 02 Aug".
  String _trendLabel(List<DailyDoc> docs, DateTime now) => switch (_period) {
        UsagePeriod.day => tr('Today'),
        UsagePeriod.week => tr('Last 7 days'),
        UsagePeriod.month => monthYear(now),
        UsagePeriod.custom => customUsageRange?.label ?? monthYear(now),
        UsagePeriod.total => docs.isEmpty
            ? tr('All time')
            // The chart shows at most 90 days (see _Trend).
            : now.difference(DateTime.parse(docs.first.date)).inDays >= 90
                ? tr('Last 90 days')
                : tr('Since {d}', {'d': shortDate(docs.first.date)}),
      };

  String _coverage(List<DailyDoc> docs, DateTime now) {
    final dates = docs.map((d) => d.date).toList()..sort();
    return tr(
        'Cloud data: {from} to {to} ({n} days). Dates use this phone: {today}.',
        {
          'from': dates.first,
          'to': dates.last,
          'n': dates.toSet().length,
          'today': dayKey(now),
        });
  }
}

class _MiniStats extends StatelessWidget {
  const _MiniStats({required this.all, required this.docs, required this.now});
  final List<DailyDoc> all, docs;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final week = sumTotals(filterLastDays(all, 7, now)).tokens;
    final month = sumTotals(filterLastDays(all, 30, now)).tokens;
    final total = sumTotals(docs);
    final days = docs.map((d) => d.date).toSet().length;
    Widget tile(String value, String label) => Expanded(
          child: Container(
            height: 54,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
                color: UtColors.chip, borderRadius: BorderRadius.circular(11)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(value,
                      style: UtText.title.copyWith(fontSize: 16, height: 1.4)),
                ),
                Text(label, style: UtText.caption),
              ],
            ),
          ),
        );
    return Row(children: [
      tile(compact(week), tr('7 days')),
      tile(compact(month), tr('30 days')),
      tile(days == 0 ? '—' : compact(total.tokens ~/ days), tr('daily avg')),
      tile(compact(total.cached), tr('cached')),
    ]);
  }
}

class _ProviderCards extends StatelessWidget {
  const _ProviderCards({required this.providers, required this.total});
  final List<MapEntry<String, UsageTotals>> providers;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (providers.isEmpty) {
      return UtCard(child: Text(tr('No sources yet.'), style: UtText.body));
    }
    return Row(children: [
      for (var i = 0; i < providers.length && i < 3; i++) ...[
        if (i > 0) const SizedBox(width: 10),
        Expanded(
          child: UtCard(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  ProviderBadge(providers[i].key),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(providerName(providers[i].key),
                          overflow: TextOverflow.ellipsis,
                          style: UtText.caption.copyWith(
                              color: UtColors.text,
                              fontWeight: FontWeight.w500))),
                ]),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(pct(share(providers[i].value.tokens, total)),
                      style: UtText.title.copyWith(fontSize: 22)),
                ),
                const SizedBox(height: 4),
                Text(
                    tr(
                        providers[i].value.models.length == 1
                            ? '{n} model'
                            : '{n} models',
                        {'n': providers[i].value.models.length}),
                    style: UtText.caption),
              ],
            ),
          ),
        ),
      ],
    ]);
  }
}

class _Trend extends StatelessWidget {
  const _Trend({required this.docs, required this.period, required this.now});
  final List<DailyDoc> docs;
  final UsagePeriod period;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final byDate = {for (final d in docs) d.date: d};
    final range = period == UsagePeriod.custom ? customUsageRange : null;
    // A custom range ends on its last day; every other period ends today.
    final end = range?.to ?? now;
    final days = switch (period) {
      UsagePeriod.day => 1,
      UsagePeriod.week => 7,
      // From the 1st of the current month to today.
      UsagePeriod.month => now.day,
      UsagePeriod.total => docs.isEmpty
          ? 1
          : now.difference(DateTime.parse(docs.first.date)).inDays + 1,
      UsagePeriod.custom => range?.days ?? now.day,
    }
        .clamp(1, 90);
    final keys = [
      for (var i = days - 1; i >= 0; i--)
        dayKey(DateTime(end.year, end.month, end.day - i))
    ];
    final providers = byProvider(docs).map((e) => e.key).toList();
    final stacks = [
      for (final k in keys)
        [
          for (final p in providers)
            (byDate[k] == null
                    ? 0
                    : byProvider([byDate[k]!])
                        .where((e) => e.key == p)
                        .fold<int>(0, (a, e) => a + e.value.tokens))
                .toDouble()
        ]
    ];
    return Column(children: [
      StackedBarChart(
          stacks: stacks,
          colors: [for (final p in providers) providerColorOf(p)]),
      const SizedBox(height: 10),
      Row(children: [
        Text(keys.first.substring(5), style: UtText.caption),
        const Spacer(),
        Text(keys.last.substring(5), style: UtText.caption),
      ]),
    ]);
  }
}

/// Stale data: the last upload is over a day old. Data stays visible.
class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.lastSync, required this.sync});
  final DateTime lastSync;
  final SyncCenter sync;

  @override
  Widget build(BuildContext context) => SyncBannerCard(
        key: const ValueKey('stale-banner'),
        icon: Icons.schedule_rounded,
        color: UtColors.muted,
        title: tr('Data may be out of date'),
        message: tr(
            'Last sync {when}. Pull down or tap Sync now for fresh usage.',
            {'when': relativeTime(lastSync, DateTime.now())}),
        actions: [
          UtChipButtonSmall(label: tr('Sync now'), onPressed: sync.start),
        ],
      );
}

/// S01 — no desktop has uploaded for this account yet.
class _NotConnected extends StatelessWidget {
  const _NotConnected();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UtMessage(
            icon: Icons.desktop_windows_outlined,
            title: tr('Connect your desktop'),
            message: tr(
                'Install μToken on your computer and sign in with this Google account. Usage appears here after its first sync.'),
            action: UtButton(
                label: tr('Connect desktop'),
                onPressed: () => context.push('/install-guide')),
          ),
          UtCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UtSectionLabel(tr('Once connected')),
                UtRow(
                    title: tr('Token totals'),
                    subtitle: tr('Across Codex, Gemini and Claude')),
                UtRow(
                    title: tr('Provider breakdown'),
                    subtitle: tr('See which tools use the most')),
                UtRow(
                    title: tr('Cost estimates'),
                    subtitle: tr('Calculated from saved model pricing')),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(tr('Prompts stay on your devices.'),
              textAlign: TextAlign.center, style: UtText.caption),
        ],
      );
}

/// S02 — desktop has synced but no usage was recorded yet.
class _WaitingForUsage extends StatelessWidget {
  const _WaitingForUsage();

  @override
  Widget build(BuildContext context) => UtMessage(
        icon: Icons.hourglass_empty_rounded,
        title: tr('Waiting for first activity'),
        message: tr(
            'Your desktop is connected. Start a session in Codex, Gemini or Claude, then refresh.'),
      );
}

/// M04B — Usage details.
class LiveUsageDetailsScreen extends StatelessWidget {
  const LiveUsageDetailsScreen(
      {super.key, required this.args, this.period = UsagePeriod.month});
  final LiveArgs args;
  final UsagePeriod period;

  @override
  Widget build(BuildContext context) {
    return UtPage(
      title: tr('Usage details'),
      onBack: () => liveBack(context, '/tokens'),
      children: [
        UtStream<List<DailyDoc>>(
          stream: args.daily(),
          builder: (context, all) {
            final now = DateTime.now();
            final docs = filterPeriod(all, period, now);
            final models = byModel(docs);
            final total = sumTotals(docs).tokens;
            final recent = [...all]..sort((a, b) => b.date.compareTo(a.date));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UtSectionLabel(tr('Top models'),
                    trailing: Text(periodText(period), style: UtText.caption)),
                UtCard(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: models.isEmpty
                      ? Text(tr('No usage in this period.'), style: UtText.body)
                      : UtRowGroup(children: [
                          for (var i = 0; i < models.length && i < 6; i++)
                            UtRow(
                              leading: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                        width: 16,
                                        child: Text('${i + 1}',
                                            style: UtText.caption)),
                                    ProviderBadge(models[i].value.provider),
                                  ]),
                              title: models[i].key,
                              subtitle: tok(models[i].value.tokens),
                              trailing: Text(
                                  pct(share(models[i].value.tokens, total)),
                                  style: UtText.caption),
                            ),
                        ]),
                ),
                const SizedBox(height: 28),
                UtSectionLabel(tr('Activity'),
                    trailing: Text(tr('119 days'), style: UtText.caption)),
                UtCard(child: _Heatmap(docs: all, now: now)),
                const SizedBox(height: 28),
                UtSectionLabel(tr('Recent days')),
                UtCard(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: UtRowGroup(children: [
                    for (final d in recent.take(3))
                      UtRow(
                        title: shortDate(d.date),
                        subtitle: tr('{n} chats', {'n': d.totals.chats}),
                        trailing: UtValue(tok(d.totals.total)),
                      ),
                    UtRow(
                        title: tr('See all days'),
                        onTap: () => context.push('/daily-usage')),
                  ]),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.docs, required this.now});
  final List<DailyDoc> docs;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final values = {for (final d in docs) d.date: d.totals.total};
    final max = values.values.fold<int>(0, (m, v) => v > m ? v : m);
    const weeks = 17;
    final today = DateTime(now.year, now.month, now.day);
    final lastMonday = today.subtract(Duration(days: today.weekday - 1));
    final start = lastMonday.subtract(const Duration(days: 7 * (weeks - 1)));
    Color cell(DateTime day) {
      if (day.isAfter(today)) return Colors.transparent;
      final v = values[dayKey(day)] ?? 0;
      if (v == 0 || max == 0) return UtColors.chip;
      final level = (v / max * 4).ceil().clamp(1, 4);
      return UtColors.green.withValues(alpha: 0.2 + level * 0.2);
    }

    return Column(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 18,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('M'), style: UtText.caption),
            const SizedBox(height: 20),
            Text(tr('W'), style: UtText.caption),
            const SizedBox(height: 20),
            Text(tr('F'), style: UtText.caption),
          ]),
        ),
        for (var w = 0; w < weeks; w++)
          Expanded(
            child: Column(children: [
              for (var d = 0; d < 7; d++)
                Padding(
                  padding: const EdgeInsets.all(1.5),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            color: cell(start.add(Duration(days: w * 7 + d))),
                            borderRadius: BorderRadius.circular(3))),
                  ),
                ),
            ]),
          ),
      ]),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Text(tr('Less'), style: UtText.caption),
        for (final a in [0.0, 0.4, 0.6, 0.8, 1.0])
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
                color: a == 0
                    ? UtColors.chip
                    : UtColors.green.withValues(alpha: a),
                borderRadius: BorderRadius.circular(2)),
          ),
        const SizedBox(width: 6),
        Text(tr('More'), style: UtText.caption),
      ]),
    ]);
  }
}

/// M06 — Daily usage table (by day or by project).
class LiveDailyUsageScreen extends StatefulWidget {
  const LiveDailyUsageScreen({super.key, required this.args});
  final LiveArgs args;

  @override
  State<LiveDailyUsageScreen> createState() => _LiveDailyUsageScreenState();
}

enum _Group { daily, project }

enum _Sort { name, tokens, chats }

class _LiveDailyUsageScreenState extends State<LiveDailyUsageScreen> {
  _Group _group = _Group.daily;
  _Sort _sort = _Sort.name;
  bool _ascending = false;
  late final Stream<List<DailyDoc>> _daily = widget.args.daily();
  late final Stream<Map<String, String>> _names = widget.args.projectNames();

  void _sortBy(_Sort sort) => setState(() {
        _ascending = sort == _sort ? !_ascending : false;
        _sort = sort;
      });

  @override
  Widget build(BuildContext context) {
    return UtPage(
      title: tr('Daily usage'),
      subtitle: tr('Usage uploaded by your desktop.'),
      onBack: () => liveBack(context, '/usage-details'),
      children: [
        UtSegmented<_Group>(
          values: _Group.values,
          selected: _group,
          label: (g) => g == _Group.daily ? tr('Daily') : tr('Project'),
          onChanged: (g) => setState(() {
            _group = g;
            _sort = _Sort.name;
            _ascending = g == _Group.project;
          }),
        ),
        const SizedBox(height: 20),
        StreamBuilder<Map<String, String>>(
          stream: _names,
          initialData: const {},
          builder: (context, namesSnap) => UtStream<List<DailyDoc>>(
            stream: _daily,
            builder: (context, all) {
              final names = namesSnap.data ?? const <String, String>{};
              final rows = _group == _Group.daily
                  ? [
                      for (final d in all)
                        (
                          d.date,
                          shortDate(d.date),
                          d.totals.total,
                          d.totals.chats
                        )
                    ]
                  : [
                      for (final p in byProject(all))
                        (
                          projectLabel(p.key, names).toLowerCase(),
                          projectLabel(p.key, names),
                          p.value.tokens,
                          p.value.chats
                        )
                    ];
              int cmp((String, String, int, int) a,
                      (String, String, int, int) b) =>
                  switch (_sort) {
                    _Sort.name => a.$1.compareTo(b.$1),
                    _Sort.tokens => a.$3.compareTo(b.$3),
                    _Sort.chats => a.$4.compareTo(b.$4),
                  };
              rows.sort((a, b) => _ascending ? cmp(a, b) : cmp(b, a));
              return UtCard(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Column(children: [
                  Row(children: [
                    _Header(
                        label:
                            _group == _Group.daily ? tr('Date') : tr('Project'),
                        action: 'Sort date',
                        flex: 3,
                        active: _sort == _Sort.name,
                        onTap: () => _sortBy(_Sort.name)),
                    _Header(
                        label: tr('Total'),
                        action: 'Sort tokens',
                        flex: 2,
                        active: _sort == _Sort.tokens,
                        onTap: () => _sortBy(_Sort.tokens)),
                    _Header(
                        label: tr('Chats'),
                        action: 'Sort chats',
                        flex: 2,
                        active: _sort == _Sort.chats,
                        onTap: () => _sortBy(_Sort.chats)),
                  ]),
                  const UtDivider(),
                  if (rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(tr('No usage uploaded yet.'),
                          style: UtText.body),
                    ),
                  for (final r in rows)
                    SizedBox(
                      height: 50,
                      child: Row(children: [
                        Expanded(
                            flex: 3,
                            child: Text(r.$2,
                                overflow: TextOverflow.ellipsis,
                                style: UtText.bodyStrong)),
                        Expanded(
                            flex: 2,
                            child: Text(tok(r.$3),
                                textAlign: TextAlign.right,
                                style: UtText.bodyStrong)),
                        Expanded(
                            flex: 2,
                            child: Text('${r.$4}',
                                textAlign: TextAlign.right,
                                style: UtText.body)),
                      ]),
                    ),
                ]),
              );
            },
          ),
        ),
        if (_group == _Group.project)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
                tr('Names come from folder names on your desktop. Turn on "Share project names" in desktop Settings if you only see IDs.'),
                style: UtText.caption),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(
      {required this.label,
      required this.action,
      required this.flex,
      required this.active,
      required this.onTap});
  final String label, action;
  final int flex;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: InkWell(
          key: utActionKey(action),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(label,
                textAlign:
                    action == 'Sort date' ? TextAlign.left : TextAlign.right,
                style: UtText.label
                    .copyWith(color: active ? UtColors.text : UtColors.muted)),
          ),
        ),
      );
}
