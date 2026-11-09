import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/usage_repository.dart';
import '../../../core/models/usage_docs.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/real_screen_scaffold.dart';

/// M07 live AI insight list.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen(
      {super.key, required this.uid, required this.repository});
  final String uid;
  final UsageRepository repository;

  @override
  Widget build(BuildContext context) => RealScreenScaffold(
        title: 'Insights',
        selectedIndex: 2,
        body: StreamBuilder<InsightsDoc?>(
          stream: repository.watchInsights(uid: uid),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                  child: Text('Không thể đọc dữ liệu: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final document = snapshot.data;
            if (document == null) {
              return const Center(
                child: Text(
                  'Chưa có đánh giá AI. Mở uToken trên máy tính và bấm Sync.',
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ScoreCard(document: document),
                if (document.status == 'insufficient_data')
                  const SectionCard(child: Text('Chưa đủ dữ liệu')),
                if (document.status == 'failed')
                  SectionCard(
                    child: Text(
                      'Đánh giá lỗi: ${document.errorCode ?? 'không rõ'}',
                    ),
                  ),
                ...document.insights.map(
                  (insight) => _InsightCard(
                    insight: insight,
                    onTap: () => context.push('/insights/${insight.id}'),
                  ),
                ),
              ],
            );
          },
        ),
      );
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.document});
  final InsightsDoc document;

  @override
  Widget build(BuildContext context) {
    final provider = switch (document.provider) {
      'google' => 'Gemini',
      'anthropic' => 'Claude',
      'openai' => 'OpenAI',
      _ => 'không rõ',
    };
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${document.grade ?? '—'} · ${document.score ?? '—'}',
            style: AppTypography.screenTitle,
          ),
          const SizedBox(height: 8),
          Text(document.headline, style: AppTypography.cardDescription),
          const SizedBox(height: 8),
          Text(
            'Đánh giá bởi $provider · ${document.model ?? 'model không rõ'} · ${document.generatedAt}',
            style: AppTypography.bulletSubtitle,
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight, required this.onTap});
  final Insight insight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: SectionCard(
          child: InkWell(
            onTap: onTap,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(insight.title, style: AppTypography.cardTitle),
                      const SizedBox(height: 5),
                      Text(insight.recommendation,
                          style: AppTypography.cardDescription),
                    ],
                  ),
                ),
                Chip(
                  label: Text(insight.severity),
                  backgroundColor: _severityColor(insight.severity),
                  labelStyle: AppTypography.bulletSubtitle,
                ),
              ],
            ),
          ),
        ),
      );

  Color _severityColor(String severity) => switch (severity) {
        'high' => AppColors.bulletRed,
        'medium' => AppColors.bulletWarning,
        _ => AppColors.bulletGreen,
      };
}

/// M08 live insight detail route.
class RealInsightDetailScreen extends StatelessWidget {
  const RealInsightDetailScreen({
    super.key,
    required this.uid,
    required this.repository,
    required this.insightId,
  });

  final String uid;
  final UsageRepository repository;
  final String insightId;

  @override
  Widget build(BuildContext context) => RealScreenScaffold(
        title: 'Insight detail',
        selectedIndex: 2,
        body: StreamBuilder<InsightsDoc?>(
          stream: repository.watchInsights(uid: uid),
          builder: (context, snapshot) {
            final insight = snapshot.data?.insights
                .where((item) => item.id == insightId)
                .firstOrNull;
            if (insight == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(insight.title, style: AppTypography.screenTitle),
                const SizedBox(height: 12),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Evidence', style: AppTypography.cardTitle),
                      ...insight.evidence.map(
                        (evidence) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(evidence.label),
                          trailing: Text(evidence.value),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  child: Text(insight.recommendation),
                ),
                if (insight.estimatedImpact != null)
                  SectionCard(child: Text(insight.estimatedImpact!)),
                if (insight.estimatedSavingMicroPerMonth != null)
                  SectionCard(
                    child: Text(
                      'Tiết kiệm: \$${(insight.estimatedSavingMicroPerMonth! / 1e6).toStringAsFixed(2)} USD/tháng',
                    ),
                  ),
                SectionCard(child: Text('Độ tin cậy: ${insight.confidence}')),
              ],
            );
          },
        ),
      );
}
