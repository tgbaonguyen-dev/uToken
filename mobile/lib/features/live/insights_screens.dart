import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/local_prefs.dart';
import '../../core/data/stream_status.dart';
import '../../core/data/usage_aggregates.dart';
import '../../core/models/usage_docs.dart';
import '../../core/ui/ut_kit.dart';
import 'live_common.dart';

String aiProviderName(String? id) => switch (id) {
      'google' => 'Google Gemini',
      'anthropic' => 'Anthropic',
      'openai' => 'OpenAI',
      null => 'Not set',
      _ => id,
    };

String _categoryName(String c) => switch (c) {
      'cache' => 'Cache',
      'context' => 'Context',
      'reasoning' => 'Reasoning',
      'reliability' => 'Reliability',
      'outcomes' => 'Outcomes',
      'hidden_cost' => 'Hidden cost',
      _ => c,
    };

/// M07 — Suggestions written by the desktop AI review.
class LiveInsightsScreen extends StatelessWidget {
  const LiveInsightsScreen({super.key, required this.args});
  final LiveArgs args;

  @override
  Widget build(BuildContext context) {
    return UtTabPage(
      title: 'Suggestions',
      subtitle: 'Small changes based on your usage.',
      tabIndex: 2,
      onRefresh: args.refresh,
      body: UtStream<InsightsDoc?>(
        stream: args.repository.watchInsights(uid: args.uid),
        builder: (context, doc) {
          if (doc == null) {
            return const UtList(children: [
              UtMessage(
                icon: Icons.lightbulb_outline_rounded,
                title: 'No suggestions yet',
                message:
                    'Open μToken on your computer and press Sync now. The AI review runs after the upload.',
              ),
            ]);
          }
          final saving = doc.insights.fold<int>(
              0, (sum, i) => sum + (i.estimatedSavingMicroPerMonth ?? 0));
          final messages = [
            if (doc.headline.isNotEmpty) Text(doc.headline, style: UtText.body),
            if (doc.status == 'failed')
              Text(friendlyAiError(doc.errorCode),
                  style: UtText.body.copyWith(color: UtColors.orange)),
            if (doc.status == 'insufficient_data')
              const Text(
                  'Not enough usage yet for reliable suggestions. Keep using your tools and sync again.',
                  style: UtText.body),
          ];
          return UtList(children: [
            UtCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Potential savings', style: UtText.label),
                          const SizedBox(height: 8),
                          Text(saving == 0 ? '—' : usd(saving / 1e6),
                              style:
                                  UtText.code.copyWith(color: UtColors.green)),
                          const Text('per month', style: UtText.caption),
                        ],
                      ),
                    ),
                    Text(
                        '${doc.insights.length} suggestion${doc.insights.length == 1 ? '' : 's'}',
                        style: UtText.body),
                  ]),
                  const SizedBox(height: 18),
                  for (final m in messages) ...[
                    const UtDivider(),
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: m),
                  ],
                  ListenableBuilder(
                    listenable: LocalPrefs.instance,
                    builder: (context, _) => Column(children: [
                      for (var i = 0; i < doc.insights.length; i++) ...[
                        const UtDivider(),
                        _InsightTile(index: i, insight: doc.insights[i]),
                      ],
                    ]),
                  ),
                  const UtDivider(),
                  const SizedBox(height: 22),
                  const Text('How recommendations work', style: UtText.label),
                  const SizedBox(height: 12),
                  Text(
                      'Written by ${aiProviderName(doc.provider)}${doc.model == null ? '' : ' · ${doc.model}'} from aggregate usage only. '
                      'Review evidence before changing a mode.',
                      style: UtText.bodyStrong),
                  const SizedBox(height: 6),
                  const Text('No changes are applied automatically.',
                      style: UtText.bodyStrong),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({required this.index, required this.insight});
  final int index;
  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final reviewed = LocalPrefs.instance.isReviewed(insight.id);
    final detail = [
      if (insight.provider != null) providerName(insight.provider!),
      if (insight.estimatedImpact != null) insight.estimatedImpact!,
      if (insight.estimatedSavingMicroPerMonth != null)
        'save ${usd(insight.estimatedSavingMicroPerMonth! / 1e6)}',
    ].join(' · ');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: utActionKey(insight.title),
        onTap: () => context.push('/insights/${insight.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 22),
          child: Row(children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: UtColors.chip,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: UtColors.cardBorder)),
              child: reviewed
                  ? const Icon(Icons.check, size: 16, color: UtColors.green)
                  : Text('${index + 1}',
                      style: UtText.caption.copyWith(color: UtColors.text)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(insight.title, style: UtText.bodyStrong),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(detail, style: UtText.caption),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: UtColors.muted),
          ]),
        ),
      ),
    );
  }
}

/// M08 — Insight detail.
class LiveInsightDetailScreen extends StatelessWidget {
  const LiveInsightDetailScreen(
      {super.key, required this.args, required this.insightId});
  final LiveArgs args;
  final String insightId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocalPrefs.instance,
      builder: (context, _) {
        final reviewed = LocalPrefs.instance.isReviewed(insightId);
        return UtPage(
          title: 'Insight detail',
          onBack: () => liveBack(context, '/insights'),
          actions: [
            UtButton(
              label: reviewed ? 'Reviewed' : 'Mark as reviewed',
              actionName: 'Mark reviewed',
              style: reviewed ? UtButtonStyle.secondary : UtButtonStyle.primary,
              onPressed: reviewed
                  ? null
                  : () => LocalPrefs.instance.markReviewed(insightId),
            ),
          ],
          children: [
            UtStream<InsightsDoc?>(
              stream: args.repository.watchInsights(uid: args.uid),
              builder: (context, doc) {
                final insight =
                    doc?.insights.where((i) => i.id == insightId).firstOrNull;
                if (doc == null || insight == null) {
                  return const UtMessage(
                      title: 'Suggestion not found',
                      message:
                          'It may have been replaced by a newer AI review.');
                }
                final scope = [
                  if (insight.provider != null) providerName(insight.provider!),
                  _categoryName(insight.category),
                  if (doc.periodStart != null && doc.periodEnd != null)
                    '${doc.periodStart} – ${doc.periodEnd}',
                ].join(' · ');
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: UtPill(reviewed ? 'Reviewed' : 'Active',
                          tone: reviewed ? UtTone.neutral : UtTone.good),
                    ),
                    const SizedBox(height: 12),
                    Text(insight.title,
                        style: UtText.title.copyWith(fontSize: 22)),
                    const SizedBox(height: 8),
                    Text(scope, style: UtText.caption),
                    const SizedBox(height: 24),
                    UtCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Estimated impact', style: UtText.label),
                          const SizedBox(height: 8),
                          Text(insight.estimatedImpact ?? '—',
                              style: UtText.title),
                          if (insight.estimatedSavingMicroPerMonth != null)
                            Text(
                                '≈ ${usd(insight.estimatedSavingMicroPerMonth! / 1e6)} / month',
                                style: UtText.body
                                    .copyWith(color: UtColors.green)),
                          const SizedBox(height: 12),
                          Text(
                              'Confidence · ${insight.confidence[0].toUpperCase()}${insight.confidence.substring(1)}',
                              style: UtText.caption),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    const UtSectionLabel('Evidence'),
                    UtCard(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: UtRowGroup(children: [
                        if (insight.evidence.isEmpty)
                          const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('No evidence attached.',
                                  style: UtText.body)),
                        for (final e in insight.evidence)
                          UtRow(title: e.label, trailing: UtValue(e.value)),
                      ]),
                    ),
                    const SizedBox(height: 28),
                    const UtSectionLabel('Recommendation'),
                    UtCard(
                        child: Text(insight.recommendation,
                            style: UtText.body.copyWith(color: UtColors.text))),
                    const SizedBox(height: 16),
                    const Text(
                        'Based on aggregate metadata only — no prompt text is sent to the AI.',
                        style: UtText.caption),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}
