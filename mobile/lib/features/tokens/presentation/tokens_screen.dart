import 'package:flutter/material.dart';

import '../../../core/data/usage_repository.dart';
import '../../../core/data/stream_status.dart';
import '../../../core/format/token_format.dart';
import '../../../core/models/daily_doc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/real_screen_scaffold.dart';

/// M04 live token dashboard.
class TokensScreen extends StatefulWidget {
  const TokensScreen({super.key, required this.uid, required this.repository});

  final String uid;
  final UsageRepository repository;

  @override
  State<TokensScreen> createState() => _TokensScreenState();
}

enum _TokenPeriod { day, week, month, total }

class _TokensScreenState extends State<TokensScreen> {
  _TokenPeriod _period = _TokenPeriod.month;
  late Stream<List<DailyDoc>> _dailyStream;

  @override
  void initState() {
    super.initState();
    _dailyStream = _watchDaily();
  }

  @override
  void didUpdateWidget(covariant TokensScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid ||
        oldWidget.repository != widget.repository) {
      _dailyStream = _watchDaily();
    }
  }

  Stream<List<DailyDoc>> _watchDaily() {
    final now = DateTime.now();
    return widget.repository.watchDaily(
      uid: widget.uid,
      end: now,
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return RealScreenScaffold(
      title: 'Tokens',
      onRefresh: () async {
        await widget.repository.refresh(uid: widget.uid);
        if (mounted) setState(() => _dailyStream = _watchDaily());
      },
      selectedIndex: 0,
      body: StreamBuilder<List<DailyDoc>>(
        stream: _dailyStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(friendlyStreamError(snapshot.error!)));
          }
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = _filter(snapshot.data ?? [], now);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              SegmentedButton<_TokenPeriod>(
                segments: const [
                  ButtonSegment(value: _TokenPeriod.day, label: Text('Day')),
                  ButtonSegment(value: _TokenPeriod.week, label: Text('Week')),
                  ButtonSegment(
                      value: _TokenPeriod.month, label: Text('Month')),
                  ButtonSegment(
                      value: _TokenPeriod.total, label: Text('Total')),
                ],
                selected: {_period},
                onSelectionChanged: (value) =>
                    setState(() => _period = value.first),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _cloudCoverage(snapshot.data ?? []),
                  key: const ValueKey('cloud-data-coverage'),
                ),
              ),
              if (docs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                      'No uploaded usage in this period. Run Sync now on desktop, then refresh here.'),
                ),
              const SizedBox(height: 12),
              _Summary(docs: docs),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                    '${formatTokens(docs.fold<int>(0, (sum, doc) => sum + doc.totals.total), TokenFormat.full)} tokens',
                    key: const ValueKey('exact-token-total')),
              ),
              const SizedBox(height: 12),
              _ProviderShares(docs: docs),
              const SizedBox(height: 12),
              _DailyBars(docs: docs),
              const SizedBox(height: 12),
              _TopModels(docs: docs),
            ],
          );
        },
      ),
    );
  }

  List<DailyDoc> _filter(List<DailyDoc> docs, DateTime now) {
    if (_period == _TokenPeriod.total) return docs;
    final days = switch (_period) {
      _TokenPeriod.day => 1,
      _TokenPeriod.week => 7,
      _TokenPeriod.month => 30,
      _TokenPeriod.total => 3650,
    };
    final cutoff = DateTime(now.year, now.month, now.day - days + 1);
    final cutoffText = cutoff.toIso8601String().substring(0, 10);
    return docs.where((doc) => doc.date.compareTo(cutoffText) >= 0).toList();
  }

  String _cloudCoverage(List<DailyDoc> docs) {
    if (docs.isEmpty) return 'No daily summaries received from Firebase.';
    final dates = docs.map((doc) => doc.date).toList()..sort();
    return 'Cloud data: ${dates.first} to ${dates.last} (${dates.toSet().length} days). Dates use this phone: ${DateTime.now().toIso8601String().substring(0, 10)}.';
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.docs});
  final List<DailyDoc> docs;

  @override
  Widget build(BuildContext context) {
    final total = docs.fold<int>(0, (sum, doc) => sum + doc.totals.total);
    final cached = docs.fold<int>(0, (sum, doc) => sum + doc.totals.cached);
    final costs = docs.map((doc) => doc.totals.costMicro).toList();
    final cost = costs.every((value) => value != null)
        ? costs.fold<int>(0, (sum, value) => sum + value!)
        : null;
    return Row(
      children: [
        Expanded(
          child: MetricCard(
            label: 'Tổng token',
            value: total == 0 ? '—' : formatTokens(total, TokenFormat.compact),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: MetricCard(
            label: 'Chi phí',
            value: cost == null ? '—' : '\$${(cost / 1e6).toStringAsFixed(2)}',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: MetricCard(
            label: 'Cached',
            value:
                cached == 0 ? '—' : formatTokens(cached, TokenFormat.compact),
          ),
        ),
      ],
    );
  }
}

class _ProviderShares extends StatelessWidget {
  const _ProviderShares({required this.docs});
  final List<DailyDoc> docs;

  @override
  Widget build(BuildContext context) {
    final totals = <String, int>{};
    for (final doc in docs) {
      for (final entry in doc.byKey.entries) {
        final provider = entry.key.split('|').first;
        totals[provider] = (totals[provider] ?? 0) + entry.value.total;
      }
    }
    final total = totals.values.fold<int>(0, (sum, value) => sum + value);
    final names = {
      'codex': 'Codex',
      'claude_code': 'Claude',
      'antigravity': 'Gemini'
    };
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Theo provider', style: AppTypography.cardTitle),
          const SizedBox(height: 10),
          for (final entry in totals.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(child: Text(names[entry.key] ?? entry.key)),
                  Text(total == 0
                      ? '—'
                      : '${(entry.value / total * 100).toStringAsFixed(1)}%'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DailyBars extends StatelessWidget {
  const _DailyBars({required this.docs});
  final List<DailyDoc> docs;

  @override
  Widget build(BuildContext context) {
    final max = docs.fold<int>(
        0, (value, doc) => value > doc.totals.total ? value : doc.totals.total);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Xu hướng theo ngày', style: AppTypography.cardTitle),
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: docs.take(31).map((doc) {
                final height = max == 0 ? 0.0 : doc.totals.total / max * 64;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Container(
                      height: height,
                      decoration: BoxDecoration(
                        color: AppColors.iconPrimaryBorder,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopModels extends StatelessWidget {
  const _TopModels({required this.docs});
  final List<DailyDoc> docs;

  @override
  Widget build(BuildContext context) {
    final models = <String, int>{};
    for (final doc in docs) {
      for (final entry in doc.byKey.entries) {
        final parts = entry.key.split('|');
        final model = parts.length > 1 ? parts[1] : entry.key;
        models[model] = (models[model] ?? 0) + entry.value.total;
      }
    }
    final rows = models.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top models', style: AppTypography.cardTitle),
          for (final row in rows.take(5))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(row.key),
              trailing: Text(formatTokens(row.value, TokenFormat.compact)),
            ),
        ],
      ),
    );
  }
}
