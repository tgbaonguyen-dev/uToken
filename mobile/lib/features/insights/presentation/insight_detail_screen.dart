import 'package:flutter/material.dart';

import '../../figma/presentation/figma_pixel_screen.dart';

/// M08 Dark: original design layers with content loaded by the mock repository.
class InsightDetailScreen extends StatelessWidget {
  const InsightDetailScreen(
      {super.key,
      this.onBack,
      this.onMarkReviewed,
      this.initialPeriod = 'Month'});

  final VoidCallback? onBack;
  final VoidCallback? onMarkReviewed;
  final String initialPeriod;

  @override
  Widget build(BuildContext context) => FigmaPixelScreen(
      screenId: 'M08',
      initialPeriod: initialPeriod,
      onBack: onBack,
      onMarkReviewed: onMarkReviewed);
}
