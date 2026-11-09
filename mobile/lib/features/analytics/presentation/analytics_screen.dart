import 'package:flutter/material.dart';

import '../../../core/data/usage_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/real_screen_scaffold.dart';
import '../../../core/models/usage_docs.dart';

/// M05 process quality dashboard.
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen(
      {super.key, required this.uid, required this.repository});
  final String uid;
  final UsageRepository repository;

  @override
  Widget build(BuildContext context) => RealScreenScaffold(
        title: 'Analytics',
        selectedIndex: 1,
        body: StreamBuilder<EfficiencyDoc?>(
          stream: repository.watchEfficiency(uid: uid),
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
              return const Center(child: Text('Không có dữ liệu'));
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Process metrics', style: AppTypography.cardTitle),
                      const SizedBox(height: 8),
                      ...document.processMetrics.map(_MetricRow.new),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Setups', style: AppTypography.cardTitle),
                      ...document.setups.map(_SetupRow.new),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
}

class _MetricRow extends StatelessWidget {
  const _MetricRow(this.metric);
  final ProcessMetric metric;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        title:
            Text(_metricName(metric.metric), style: AppTypography.bulletTitle),
        subtitle: Text(metric.provider ?? 'Tổng',
            style: AppTypography.bulletSubtitle),
        trailing: _StatusChip(label: _statusName(metric.label)),
      );

  String _metricName(String value) => switch (value) {
        'success_rate' => 'Tỉ lệ thành công',
        'cache_hit_rate' => 'Tỉ lệ cache',
        'context_growth' => 'Tăng trưởng context',
        _ => value,
      };

  String _statusName(String value) => switch (value) {
        'good' => 'Tốt',
        'review' => 'Cần xem lại',
        _ => 'Không có dữ liệu',
      };
}

class _SetupRow extends StatelessWidget {
  const _SetupRow(this.setup);
  final SetupMetric setup;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('${setup.model} · ${setup.taskGroup}'),
        subtitle: Text(
          '${setup.provider} · SR ${setup.sr == null ? '—' : '${(setup.sr! * 100).toStringAsFixed(1)}%'}',
          style: AppTypography.bulletSubtitle,
        ),
        trailing: _StatusChip(label: setup.verdict),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Chip(
        label: Text(label),
        backgroundColor: AppColors.surfaceBorder,
        labelStyle: AppTypography.bulletSubtitle,
        visualDensity: VisualDensity.compact,
      );
}
