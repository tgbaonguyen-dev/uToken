import 'package:flutter/material.dart';
import '../../../../core/format/token_format.dart';
import '../../../../core/widgets/real_screen_scaffold.dart';
import '../../domain/token_dashboard.dart';

class TokenSummarySection extends StatelessWidget {
  const TokenSummarySection({super.key, required this.dashboard});
  final TokenDashboard dashboard;
  @override
  Widget build(BuildContext context) {
    final cost = dashboard.costMicro;
    return Row(children: [
      Expanded(
          child: MetricCard(
              label: 'Tổng token',
              value: dashboard.totalTokens == 0
                  ? '—'
                  : formatTokens(dashboard.totalTokens, TokenFormat.compact))),
      const SizedBox(width: 8),
      Expanded(
          child: MetricCard(
              label: 'Chi phí',
              value:
                  cost == null ? '—' : '\$${(cost / 1e6).toStringAsFixed(2)}')),
      const SizedBox(width: 8),
      Expanded(
          child: MetricCard(
              label: 'Cached',
              value: dashboard.cachedTokens == 0
                  ? '—'
                  : formatTokens(dashboard.cachedTokens, TokenFormat.compact))),
    ]);
  }
}
