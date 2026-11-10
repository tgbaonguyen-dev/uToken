import 'package:flutter/material.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/real_screen_scaffold.dart';
import '../../domain/token_dashboard.dart';

class ProviderBreakdownSection extends StatelessWidget {
  const ProviderBreakdownSection({super.key, required this.dashboard});
  final TokenDashboard dashboard;
  static const _names = {
    'codex': 'Codex',
    'claude_code': 'Claude',
    'antigravity': 'Gemini'
  };

  @override
  Widget build(BuildContext context) {
    final total =
        dashboard.providers.fold<int>(0, (sum, item) => sum + item.tokens);
    return SectionCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Theo provider', style: AppTypography.cardTitle),
      const SizedBox(height: 10),
      for (final item in dashboard.providers)
        Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(child: Text(_names[item.label] ?? item.label)),
              Text(total == 0
                  ? '—'
                  : '${(item.tokens / total * 100).toStringAsFixed(1)}%'),
            ])),
      if (dashboard.providers.isEmpty) const Text('Chưa có dữ liệu provider'),
    ]));
  }
}
