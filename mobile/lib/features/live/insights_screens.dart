import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/local_prefs.dart';
import '../../core/data/stream_status.dart';
import '../../core/data/usage_aggregates.dart';
import '../../core/i18n/tr.dart';
import '../../core/models/daily_doc.dart';
import '../../core/models/usage_docs.dart';
import '../../core/ui/ut_kit.dart';
import '../ai_review/phone_judge.dart';
import '../ai_review/review_window.dart';
import 'analytics_screens.dart' show metricHint;
import 'notices.dart';
import 'live_common.dart';

String aiProviderName(String? id) => switch (id) {
      'google' => 'Google Gemini',
      'anthropic' => 'Anthropic Claude',
      'openai' => 'OpenAI',
      null => tr('Not set'),
      _ => id,
    };

String categoryName(String c) => switch (c) {
      'cache' => tr('Cache'),
      'context' => tr('Context'),
      'reasoning' => tr('Reasoning'),
      'reliability' => tr('Reliability'),
      'outcomes' => tr('Outcomes'),
      'hidden_cost' => tr('Hidden cost'),
      _ => c,
    };

IconData _categoryIcon(String c) => switch (c) {
      'cache' => Icons.bolt_rounded,
      'context' => Icons.layers_outlined,
      'reasoning' => Icons.psychology_outlined,
      'reliability' => Icons.verified_outlined,
      'outcomes' => Icons.flag_outlined,
      'hidden_cost' => Icons.visibility_off_outlined,
      _ => Icons.insights_outlined,
    };

const _danger = Color(0xFFE0525B);

/// Colour for a 0–100 score: green ≥ 75, orange ≥ 50, red below.
Color scoreColor(num? score) => score == null
    ? UtColors.muted
    : score >= 75
        ? UtColors.green
        : score >= 50
            ? UtColors.orange
            : _danger;

Color _severityColor(String s) => switch (s) {
      'high' => _danger,
      'medium' => UtColors.orange,
      _ => UtColors.blue,
    };

String _severityLabel(String s) => switch (s) {
      'high' => tr('High priority'),
      'medium' => tr('Medium priority'),
      _ => tr('Low priority'),
    };

String _confidenceLabel(String c) => switch (c) {
      'high' => tr('High confidence'),
      'medium' => tr('Medium confidence'),
      _ => tr('Low confidence'),
    };

int _severityRank(String s) => switch (s) {
      'high' => 0,
      'medium' => 1,
      _ => 2,
    };

/// "process.cache_hit_rate.codex" → explanation of the underlying metric.
String _evidenceHint(String metric) {
  final parts = metric.split('.');
  return metricHint(parts.length > 1 ? parts[1] : metric);
}

DateTime? _parseTime(String value) => DateTime.tryParse(value)?.toLocal();

String _reviewTime(String value) {
  final at = _parseTime(value);
  if (at == null) return '—';
  return '${shortDate(dayKey(at))}, ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
}

bool _isStale(InsightsDoc doc) {
  final at = _parseTime(doc.generatedAt);
  return at == null || DateTime.now().difference(at).inHours >= 24;
}

// ---------------------------------------------------------------------------
// M07 — Insights.

/// M07 — AI review: score, what to fix first, and the score breakdown.
/// The review runs on this phone with the user's own API key (FR-RECO-001);
/// asking the desktop is an optional fallback.
class LiveInsightsScreen extends StatefulWidget {
  const LiveInsightsScreen({super.key, required this.args});
  final LiveArgs args;
  @override
  State<LiveInsightsScreen> createState() => _LiveInsightsScreenState();
}

class _LiveInsightsScreenState extends State<LiveInsightsScreen> {
  late final Stream<InsightsDoc?> _doc =
      widget.args.repository.watchInsights(uid: widget.args.uid);
  @override
  Widget build(BuildContext context) {
    return UtTabPage(
      trailing: NoticeBell(args: widget.args),
      title: tr('Insights'),
      subtitle: tr('AI review of how you use tokens.'),
      tabIndex: 2,
      onRefresh: widget.args.refresh,
      body: ListenableBuilder(
        listenable:
            Listenable.merge([LocalPrefs.instance, PhoneJudge.instance]),
        builder: (context, _) => UtStream<InsightsDoc?>(
          stream: _doc,
          builder: (context, doc) {
            return _InsightsBody(args: widget.args, doc: doc);
          },
        ),
      ),
    );
  }
}

/// Starts a review on the phone, or offers setup / the desktop when the
/// phone has no API key.
Future<void> runReview(BuildContext context, LiveArgs args) async {
  final judge = PhoneJudge.instance;
  if (judge.running) return;
  if (judge.hasKey) {
    final scope = await showModalBottomSheet<ReviewScope>(
      context: context,
      backgroundColor: UtColors.card,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
          child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tr('Choose review period'), style: UtText.title),
              const SizedBox(height: 8),
              Text(
                  tr('Review new synchronized usage since your last successful review, or the full last 30 days. First run? Choose 30 days to establish a baseline.'),
                  style: UtText.body),
              const SizedBox(height: 16),
              UtButton(
                  label: tr('Since last successful review'),
                  actionName: 'Review new usage',
                  onPressed: () =>
                      Navigator.pop(sheet, ReviewScope.sinceLastReview)),
              const SizedBox(height: 10),
              UtButton(
                  label: tr('Last 30 days'),
                  actionName: 'Review 30 days',
                  style: UtButtonStyle.secondary,
                  onPressed: () =>
                      Navigator.pop(sheet, ReviewScope.last30Days)),
              const SizedBox(height: 10),
              Text(
                  tr('The baseline belongs to this account on this phone. Only synced usage is included; late uploads may include earlier activity.'),
                  style: UtText.caption),
            ]),
      )),
    );
    if (scope == null || !context.mounted) return;
    HapticFeedback.mediumImpact();
    await judge.run(
        uid: args.uid,
        repository: args.repository,
        language: aiLanguage(),
        scope: scope);
    if (judge.step == JudgeStep.done) HapticFeedback.lightImpact();
    return;
  }
  if (!context.mounted) return;
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: UtColors.card,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('Set up AI review'), style: UtText.title),
            const SizedBox(height: 6),
            Text(
                tr('Add your own API key and the review runs right on this phone. The key stays in this phone’s secure storage.'),
                style: UtText.body),
            const SizedBox(height: 20),
            UtButton(
                label: tr('Add API key'),
                actionName: 'Add API key',
                onPressed: () => Navigator.pop(sheet, 'setup')),
            const SizedBox(height: 10),
            UtButton(
                label: tr('Ask my computer instead'),
                actionName: 'Ask computer',
                style: UtButtonStyle.secondary,
                onPressed: () => Navigator.pop(sheet, 'desktop')),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted) return;
  if (choice == 'setup') {
    context.push('/ai-suggestions');
  } else if (choice == 'desktop') {
    try {
      await args.repository.requestSync(uid: args.uid, trigger: 'ai_review');
      if (context.mounted) {
        utShowNotice(context,
            tr('Asked your computer. The new review appears here when μToken desktop finishes.'));
      }
    } catch (e) {
      if (context.mounted) utShowNotice(context, friendlyStreamError(e));
    }
  }
}

class _InsightsBody extends StatelessWidget {
  const _InsightsBody({required this.args, required this.doc});
  final LiveArgs args;
  final InsightsDoc? doc;

  @override
  Widget build(BuildContext context) {
    final doc = this.doc;
    final prefs = LocalPrefs.instance;
    final items = [...?doc?.insights]..sort((a, b) {
        final r = (prefs.isReviewed(a.id) ? 1 : 0)
            .compareTo(prefs.isReviewed(b.id) ? 1 : 0);
        return r != 0
            ? r
            : _severityRank(a.severity).compareTo(_severityRank(b.severity));
      });
    final reviewed = items.where((i) => prefs.isReviewed(i.id)).length;
    final banner = _statusBanner(doc);
    return UtList(children: [
      _ScoreHeader(args: args, doc: doc),
      if (banner != null) ...[const SizedBox(height: 12), banner],
      if (doc != null) ...[
        const SizedBox(height: 28),
        UtSectionLabel(tr('What to fix first'),
            trailing: items.isEmpty
                ? null
                : Text(
                    tr('{done} of {all} reviewed',
                        {'done': reviewed, 'all': items.length}),
                    style: UtText.caption)),
        if (items.isEmpty)
          UtCard(
              child: Text(
                  doc.status == 'ok'
                      ? tr('No significant issues found. Nice work.')
                      : tr('No recommendations yet.'),
                  style: UtText.body)),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _InsightCard(
              insight: items[i], reviewed: prefs.isReviewed(items[i].id)),
        ],
        if (doc.dimensions.isNotEmpty) ...[
          const SizedBox(height: 28),
          UtSectionLabel(tr('Score breakdown')),
          UtCard(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: UtRowGroup(children: [
              for (final d in doc.dimensions) _DimensionRow(dimension: d),
            ]),
          ),
        ],
        const SizedBox(height: 24),
        Text(tr('How recommendations work'), style: UtText.label),
        const SizedBox(height: 8),
        Text(
            tr(
                '{provider} reads synchronized usage for the selected period only, never your prompts or code. Every recommendation must cite a metric, and the app re-checks each number. Nothing is changed automatically.',
                {
                  'provider':
                      '${aiProviderName(doc.provider)}${doc.model == null ? '' : ' (${doc.model})'}'
                }),
            style: UtText.caption),
      ],
    ]);
  }

  Widget? _statusBanner(InsightsDoc? doc) {
    final judge = PhoneJudge.instance;
    if (judge.step == JudgeStep.noNewUsage) {
      return _Banner(
          icon: Icons.check_circle_outline,
          color: UtColors.muted,
          text: tr(
              'No new synchronized usage since your last successful review. Sync desktop first if you have used more tokens.'));
    }
    if (judge.step == JudgeStep.failed && judge.errorCode != null) {
      return _Banner(
          icon: Icons.error_outline,
          color: UtColors.orange,
          text: friendlyAiError(judge.errorCode));
    }
    if (doc == null) return null;
    if (doc.status == 'failed') {
      return _Banner(
          icon: Icons.error_outline,
          color: UtColors.orange,
          text:
              '${friendlyAiError(doc.errorCode)} ${tr('Showing the previous review.')}');
    }
    if (doc.status == 'insufficient_data') {
      return _Banner(
          icon: Icons.hourglass_empty_rounded,
          color: UtColors.muted,
          text: tr(
              'Not enough usage yet: the AI review needs at least 3 days and 5 chats.'));
    }
    if (_isStale(doc) && !judge.running) {
      return _Banner(
          icon: Icons.schedule_rounded,
          color: UtColors.muted,
          text: tr(
              'This review is more than a day old. Run a new one for fresh advice.'));
    }
    return null;
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.35))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: UtText.body.copyWith(color: UtColors.text))),
        ]),
      );
}

/// Score, headline and the single "run review" action, with live progress.
class _ScoreHeader extends StatelessWidget {
  const _ScoreHeader({required this.args, required this.doc});
  final LiveArgs args;
  final InsightsDoc? doc;

  @override
  Widget build(BuildContext context) {
    final doc = this.doc;
    final judge = PhoneJudge.instance;
    final score = doc?.status == 'insufficient_data' ? null : doc?.score;
    final generated = doc == null ? null : _parseTime(doc.generatedAt);
    final saving = doc?.insights.fold<int>(
            0, (sum, i) => sum + (i.estimatedSavingMicroPerMonth ?? 0)) ??
        0;
    final high = doc?.insights.where((i) => i.severity == 'high').length ?? 0;
    final progress = switch (judge.step) {
      JudgeStep.reading => tr('Reading your usage…'),
      JudgeStep.asking =>
        tr('Asking {provider}…', {'provider': aiProviderName(judge.provider)}),
      JudgeStep.checking => tr('Checking every number…'),
      _ => null,
    };
    return UtCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            _ScoreRing(score: score, grade: doc?.grade),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      doc == null
                          ? tr('No AI review yet')
                          : doc.headline.isEmpty
                              ? tr('Your latest AI review')
                              : doc.headline,
                      style: UtText.bodyStrong.copyWith(fontSize: 15)),
                  const SizedBox(height: 6),
                  Text(
                      doc == null
                          ? tr(
                              'Choose new usage since your last successful review, or a 30-day overview. Only synchronized data is available.')
                          : [
                              tr(doc.reviewMode == 'sinceLastReview'
                                  ? 'Since last successful review'
                                  : 'Last 30 days'),
                              if (generated != null)
                                tr('Updated {when}', {
                                  'when':
                                      relativeTime(generated, DateTime.now())
                                }),
                              if (doc.reviewFrom != null &&
                                  doc.reviewThrough != null)
                                '${_reviewTime(doc.reviewFrom!)} – ${_reviewTime(doc.reviewThrough!)}'
                              else if (doc.periodStart != null &&
                                  doc.periodEnd != null)
                                '${shortDate(doc.periodStart!)} – ${shortDate(doc.periodEnd!)}',
                            ].join(' · '),
                      style: UtText.caption),
                ],
              ),
            ),
          ]),
          if (doc != null && doc.insights.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                  child: MiniStat(
                      value: saving == 0 ? '—' : usd(saving / 1e6),
                      label: tr('Possible savings / mo'))),
              Expanded(
                  child: MiniStat(value: '$high', label: tr('High priority'))),
              Expanded(
                  child: MiniStat(
                      value: '${doc.insights.length}',
                      label: tr('Recommendations'))),
            ]),
          ],
          const SizedBox(height: 16),
          if (progress != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: const LinearProgressIndicator(
                  minHeight: 4,
                  backgroundColor: UtColors.chip,
                  color: UtColors.green),
            ),
            const SizedBox(height: 10),
            Text(progress,
                style: UtText.caption.copyWith(color: UtColors.text)),
          ] else
            UtButton(
              label: doc == null ? tr('Run AI review') : tr('Run new review'),
              actionName: 'Run review',
              onPressed: () => runReview(context, args),
            ),
          if (progress == null && !judge.hasKey) ...[
            const SizedBox(height: 8),
            Text(tr('Needs an API key on this phone, or μToken desktop.'),
                textAlign: TextAlign.center, style: UtText.caption),
          ],
        ],
      ),
    );
  }
}

/// Circular 0–100 score with the grade in the middle.
class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.score, this.grade});
  final double? score;
  final String? grade;

  @override
  Widget build(BuildContext context) {
    final color = scoreColor(score);
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox.expand(
          child: CircularProgressIndicator(
            value: score == null ? 0 : (score! / 100).clamp(0, 1),
            strokeWidth: 6,
            strokeCap: StrokeCap.round,
            backgroundColor: UtColors.chip,
            color: color,
          ),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text(score == null ? '—' : score!.round().toString(),
              style: UtText.title.copyWith(fontSize: 22, color: color)),
          if (grade != null && grade!.isNotEmpty)
            Text(tr('Grade {g}', {'g': grade}), style: UtText.caption),
        ]),
      ]),
    );
  }
}

/// One dimension: icon, name, score badge and the full AI comment.
class _DimensionRow extends StatelessWidget {
  const _DimensionRow({required this.dimension});
  final InsightDimension dimension;

  @override
  Widget build(BuildContext context) {
    final d = dimension;
    final color = scoreColor(d.score);
    return Padding(
      key: ValueKey('dimension-${d.id}'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10)),
          child: Text(d.score == null ? '—' : '${d.score}',
              style: UtText.bodyStrong.copyWith(color: color)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(_categoryIcon(d.id), size: 15, color: UtColors.muted),
                const SizedBox(width: 6),
                Text(categoryName(d.id), style: UtText.bodyStrong),
              ]),
              if (d.comment.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(d.comment, style: UtText.caption.copyWith(height: 1.5)),
              ],
            ],
          ),
        ),
      ]),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight, required this.reviewed});
  final Insight insight;
  final bool reviewed;

  @override
  Widget build(BuildContext context) {
    final saving = insight.estimatedSavingMicroPerMonth;
    final color = reviewed ? UtColors.muted : _severityColor(insight.severity);
    return Material(
      color: UtColors.card,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: UtColors.cardBorder)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: utActionKey(insight.title),
        onTap: () => context.push('/insights/${insight.id}'),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 4, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(_categoryIcon(insight.category),
                          size: 14, color: color),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                            reviewed
                                ? '${tr('Reviewed')} · ${categoryName(insight.category)}'
                                : '${_severityLabel(insight.severity)} · ${categoryName(insight.category)}',
                            overflow: TextOverflow.ellipsis,
                            style: UtText.caption.copyWith(
                                color: color, fontWeight: FontWeight.w600)),
                      ),
                      if (insight.provider != null)
                        ProviderBadge(insight.provider!, size: 18),
                    ]),
                    const SizedBox(height: 8),
                    Text(insight.title,
                        style: UtText.bodyStrong.copyWith(
                            fontSize: 15,
                            color: reviewed ? UtColors.muted : UtColors.text)),
                    if (insight.evidence.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final e in insight.evidence.take(2))
                          _EvidenceChip(evidence: e),
                      ]),
                    ],
                    if (saving != null && saving > 0) ...[
                      const SizedBox(height: 10),
                      Text(
                          tr('Save ~{amount}/mo',
                              {'amount': usd(saving / 1e6)}),
                          style: UtText.caption.copyWith(
                              color: UtColors.green,
                              fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Icon(Icons.chevron_right_rounded,
                  size: 20, color: UtColors.muted),
            ),
          ]),
        ),
      ),
    );
  }
}

class _EvidenceChip extends StatelessWidget {
  const _EvidenceChip({required this.evidence});
  final Evidence evidence;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
            color: UtColors.chip, borderRadius: BorderRadius.circular(8)),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: '${evidence.label}  '),
            TextSpan(
                text: evidence.value,
                style: const TextStyle(
                    color: UtColors.text, fontWeight: FontWeight.w600)),
          ]),
          style: UtText.caption,
        ),
      );
}

// ---------------------------------------------------------------------------
// M08 — Insight detail.

/// M08 — Insight detail: what to do, why it was flagged, and what it saves.
class LiveInsightDetailScreen extends StatefulWidget {
  const LiveInsightDetailScreen(
      {super.key, required this.args, required this.insightId});
  final LiveArgs args;
  final String insightId;

  @override
  State<LiveInsightDetailScreen> createState() =>
      _LiveInsightDetailScreenState();
}

class _LiveInsightDetailScreenState extends State<LiveInsightDetailScreen> {
  LiveArgs get args => widget.args;
  String get insightId => widget.insightId;
  late Stream<InsightsDoc?> _stream =
      args.repository.watchInsights(uid: args.uid);
  void _retry() =>
      setState(() => _stream = args.repository.watchInsights(uid: args.uid));
  @override
  void didUpdateWidget(covariant LiveInsightDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.args.uid != args.uid ||
        oldWidget.args.repository != args.repository) {
      _stream = args.repository.watchInsights(uid: args.uid);
    }
  }

  Widget _recovery(String message) => UtMessage(
      title: tr('Insight unavailable'),
      message: tr(message),
      action: Column(children: [
        UtButton(label: tr('Retry'), onPressed: _retry),
        UtButton(
            label: tr('Back to Insights'),
            onPressed: () => liveBack(context, '/insights'))
      ]));
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocalPrefs.instance,
      builder: (context, _) {
        final reviewed = LocalPrefs.instance.isReviewed(insightId);
        return UtPage(
          title: tr('Insight detail'),
          onBack: () => liveBack(context, '/insights'),
          actions: [
            UtButton(
              label: reviewed ? tr('Reviewed') : tr('Mark as reviewed'),
              actionName: 'Mark reviewed',
              style: reviewed ? UtButtonStyle.secondary : UtButtonStyle.primary,
              onPressed: reviewed
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      LocalPrefs.instance.markReviewed(insightId);
                    },
            ),
          ],
          children: [
            StreamBuilder<InsightsDoc?>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _recovery(friendlyStreamError(snapshot.error!));
                }
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final doc = snapshot.data;
                final insight =
                    doc?.insights.where((i) => i.id == insightId).firstOrNull;
                if (doc == null || insight == null) {
                  return _recovery(doc == null
                      ? 'No AI review available yet.'
                      : 'This insight no longer exists in the latest review.');
                }
                return _InsightDetail(
                    args: args, doc: doc, insight: insight, reviewed: reviewed);
              },
            ),
          ],
        );
      },
    );
  }
}

class _InsightDetail extends StatelessWidget {
  const _InsightDetail(
      {required this.args,
      required this.doc,
      required this.insight,
      required this.reviewed});
  final LiveArgs args;
  final InsightsDoc doc;
  final Insight insight;
  final bool reviewed;

  @override
  Widget build(BuildContext context) {
    final dimension =
        doc.dimensions.where((d) => d.id == insight.category).firstOrNull;
    final saving = insight.estimatedSavingMicroPerMonth;
    final color = _severityColor(insight.severity);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (reviewed) UtPill(tr('Reviewed'), tone: UtTone.good),
          UtPill(_severityLabel(insight.severity),
              tone: switch (insight.severity) {
                'high' => UtTone.danger,
                'medium' => UtTone.review,
                _ => UtTone.neutral,
              }),
          UtPill(categoryName(insight.category)),
          if (insight.confidence.isNotEmpty)
            UtPill(_confidenceLabel(insight.confidence)),
        ]),
        const SizedBox(height: 14),
        Text(insight.title, style: UtText.title.copyWith(fontSize: 22)),
        if (insight.provider != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            ProviderBadge(insight.provider!, size: 18),
            const SizedBox(width: 6),
            Text(providerName(insight.provider!), style: UtText.caption),
          ]),
        ],
        if (insight.why.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(insight.why, style: UtText.body.copyWith(height: 1.5)),
        ],
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.3))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.lightbulb_outline_rounded, size: 18, color: color),
                const SizedBox(width: 8),
                Text(tr('What to do'),
                    style: UtText.label.copyWith(color: color)),
              ]),
              const SizedBox(height: 10),
              Text(
                  insight.recommendation.isEmpty ? '—' : insight.recommendation,
                  style: UtText.body.copyWith(
                      color: UtColors.text, fontSize: 15, height: 1.5)),
              for (final (i, step) in insight.steps.indexed) ...[
                const SizedBox(height: 10),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.18),
                        shape: BoxShape.circle),
                    child: Text('${i + 1}',
                        style: UtText.caption.copyWith(
                            color: color, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(step,
                          style: UtText.body
                              .copyWith(color: UtColors.text, height: 1.45))),
                ]),
              ],
            ],
          ),
        ),
        // Money as numbers, impact as text: a sentence squeezed into a
        // number tile wraps badly, and empty "—" tiles add nothing.
        if ((saving != null && saving > 0) ||
            insight.estimatedImpact != null) ...[
          const SizedBox(height: 12),
          UtCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (saving != null && saving > 0)
                  Row(children: [
                    Expanded(
                        child: MiniStat(
                            value: usd(saving / 1e6),
                            label: tr('Saving / month'))),
                    Expanded(
                        child: MiniStat(
                            value: usd(saving * 12 / 1e6),
                            label: tr('Saving / year'))),
                  ]),
                if (saving != null &&
                    saving > 0 &&
                    insight.estimatedImpact != null)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: UtDivider()),
                if (insight.estimatedImpact != null) ...[
                  Text(tr('Impact'), style: UtText.label),
                  const SizedBox(height: 6),
                  Text(insight.estimatedImpact!, style: UtText.bodyStrong),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 28),
        UtSectionLabel(tr('Why this was flagged')),
        if (insight.evidence.isEmpty)
          UtCard(child: Text(tr('No evidence attached.'), style: UtText.body)),
        if (insight.evidence.isNotEmpty)
          UtCard(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: UtRowGroup(children: [
              for (final e in insight.evidence)
                UtRow(
                    title: e.label.isEmpty ? e.metric : e.label,
                    subtitle: _evidenceHint(e.metric).isEmpty
                        ? null
                        : tr(_evidenceHint(e.metric)),
                    trailing: UtValue(e.value.isEmpty ? '—' : e.value)),
            ]),
          ),
        const SizedBox(height: 28),
        UtSectionLabel(tr('Where it comes from · last 30 days')),
        _Contributors(args: args, insight: insight),
        if (dimension != null) ...[
          const SizedBox(height: 28),
          UtSectionLabel(
              tr('{name} score', {'name': categoryName(dimension.id)})),
          UtCard(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: _DimensionRow(dimension: dimension),
          ),
        ],
        if (insight.provider != null) ...[
          const SizedBox(height: 28),
          UtSectionLabel(tr('{tool} · last 30 days',
              {'tool': providerName(insight.provider!)})),
          _ProviderContext(args: args, provider: insight.provider!),
        ],
        const SizedBox(height: 16),
        Text(
            tr('Based on aggregate metadata only. No prompt text is sent to the AI.'),
            style: UtText.caption),
      ],
    );
  }
}

/// Real usage for the provider an insight is about, from daily documents.
class _ProviderContext extends StatelessWidget {
  const _ProviderContext({required this.args, required this.provider});
  final LiveArgs args;
  final String provider;

  @override
  Widget build(BuildContext context) => UtStream<List<DailyDoc>>(
        stream: args.daily(),
        builder: (context, all) {
          final docs = filterLastDays(all, 30, DateTime.now());
          final total = sumTotals(docs);
          final mine = byProvider(docs)
              .where((e) => e.key == provider)
              .map((e) => e.value)
              .firstOrNull;
          if (mine == null) {
            return UtCard(
                child: Text(tr('No usage from this tool in the last 30 days.'),
                    style: UtText.body));
          }
          final hit = mine.input == 0 ? null : mine.cached / mine.input;
          final part = share(mine.tokens, total.tokens);
          return UtCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                      child: MiniStat(
                          value: compact(mine.tokens), label: tr('Tokens'))),
                  Expanded(
                      child: MiniStat(
                          value: usd(mine.costUsd), label: tr('Est. cost'))),
                  Expanded(
                      child: MiniStat(
                          value: hit == null ? '—' : pct(hit, digits: 0),
                          label: tr('Cache hit'))),
                ]),
                const SizedBox(height: 14),
                ShareBar(parts: [
                  (part, providerColorOf(provider)),
                  (1 - part, UtColors.chip),
                ]),
                const SizedBox(height: 6),
                Text(
                    tr('{share} of all tokens · {n} models', {
                      'share': pct(part, digits: 0),
                      'n': mine.models.length
                    }),
                    style: UtText.caption),
              ],
            ),
          );
        },
      );
}

/// Which models and projects drive the metric an insight is about, from the
/// user's own daily summaries (not from the AI).
class _Contributors extends StatelessWidget {
  const _Contributors({required this.args, required this.insight});
  final LiveArgs args;
  final Insight insight;

  /// The number that matters for this category, and how to print it.
  (String, int Function(UsageTotals), String Function(int)) get _metric =>
      switch (insight.category) {
        'cache' => (
            tr('Uncached input'),
            (t) => (t.input - t.cached).clamp(0, 1 << 62),
            compact
          ),
        'context' => (tr('Input tokens'), (t) => t.input, compact),
        'reasoning' => (tr('Thinking tokens'), (t) => t.thinking, compact),
        'reliability' => (
            tr('Failed requests'),
            (t) => t.errorRequests,
            (v) => '$v'
          ),
        _ => (tr('Est. cost'), (t) => t.cost, (v) => usd(v / 1e6)),
      };

  @override
  Widget build(BuildContext context) => StreamBuilder<Map<String, String>>(
        stream: args.projectNames(),
        initialData: const {},
        builder: (context, namesSnap) => UtStream<List<DailyDoc>>(
          stream: args.daily(),
          builder: (context, all) {
            final names = namesSnap.data ?? const <String, String>{};
            final docs = filterLastDays(all, 30, DateTime.now());
            final provider = insight.provider;
            bool mine(UsageKey k) => provider == null || k.provider == provider;
            final (label, value, format) = _metric;
            List<(String, int)> top(String? Function(UsageKey) keyOf) {
              final rows = [
                for (final e in groupBy(docs, (k) => mine(k) ? keyOf(k) : null))
                  (e.key, value(e.value))
              ].where((r) => r.$2 > 0).toList()
                ..sort((a, b) => b.$2.compareTo(a.$2));
              return rows;
            }

            final models = top((k) => k.model);
            final projects = top((k) => k.project ?? 'Unassigned');
            if (models.isEmpty && projects.isEmpty) {
              return UtCard(
                  child: Text(tr('No matching usage in the last 30 days.'),
                      style: UtText.body));
            }
            Widget group(String title, List<(String, int)> rows,
                String Function(String) name) {
              final total = rows.fold<int>(0, (s, r) => s + r.$2);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: UtText.label),
                  const SizedBox(height: 4),
                  for (final r in rows.take(3))
                    UtRow(
                        title: name(r.$1),
                        subtitle: tr('{share} of {metric}', {
                          'share': pct(share(r.$2, total), digits: 0),
                          'metric': label.toLowerCase()
                        }),
                        trailing: UtValue(format(r.$2))),
                ],
              );
            }

            return UtCard(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (models.isNotEmpty)
                    group(tr('Top models'), models, (m) => m),
                  if (models.isNotEmpty && projects.isNotEmpty)
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: UtDivider()),
                  if (projects.isNotEmpty)
                    group(tr('Top projects'), projects,
                        (p) => projectLabel(p, names)),
                ],
              ),
            );
          },
        ),
      );
}
