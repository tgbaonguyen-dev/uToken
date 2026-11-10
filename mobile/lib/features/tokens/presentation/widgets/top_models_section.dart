import 'package:flutter/material.dart';
import '../../../../core/format/token_format.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/real_screen_scaffold.dart';
import '../../domain/token_dashboard.dart';

class TopModelsSection extends StatelessWidget {
  const TopModelsSection({super.key, required this.models, this.limit = 5});
  final List<TokenMetric> models;
  final int limit;
  @override
  Widget build(BuildContext context) => SectionCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Top models', style: AppTypography.cardTitle),
        for (final model in models.take(limit))
          ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(model.label),
              trailing: Text(formatTokens(model.tokens, TokenFormat.compact))),
        if (models.isEmpty) const Text('Chưa có dữ liệu model'),
      ]));
}
