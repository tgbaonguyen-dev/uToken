import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/real_screen_scaffold.dart';
import '../../domain/token_dashboard.dart';

class TokenTrendSection extends StatelessWidget {
  const TokenTrendSection({super.key, required this.points});
  final List<DailyTokenPoint> points;
  @override
  Widget build(BuildContext context) {
    final visible =
        points.length > 31 ? points.sublist(points.length - 31) : points;
    final maxValue =
        visible.fold<int>(0, (v, p) => v > p.tokens ? v : p.tokens);
    return SectionCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Xu hướng theo ngày', style: AppTypography.cardTitle),
      const SizedBox(height: 12),
      SizedBox(
          height: 90,
          child: visible.isEmpty
              ? const Center(child: Text('Chưa có dữ liệu'))
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: visible.map((point) {
                    final height =
                        maxValue == 0 ? 0.0 : point.tokens / maxValue * 64;
                    return Expanded(
                        child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Tooltip(
                              message: '${point.date}: ${point.tokens} tokens',
                              child: Container(
                                  height: height,
                                  decoration: BoxDecoration(
                                      color: AppColors.iconPrimaryBorder,
                                      borderRadius: BorderRadius.circular(3))),
                            )));
                  }).toList(),
                )),
    ]));
  }
}
