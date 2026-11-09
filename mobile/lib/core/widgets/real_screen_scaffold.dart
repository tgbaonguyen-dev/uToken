import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Shared dark frame and tab navigation for Firestore-backed screens.
class RealScreenScaffold extends StatelessWidget {
  const RealScreenScaffold({
    super.key,
    required this.title,
    required this.selectedIndex,
    required this.body,
  });

  final String title;
  final int selectedIndex;
  final Widget body;

  static const _routes = ['/tokens', '/analytics', '/insights', '/settings'];

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text(title, style: AppTypography.screenTitle),
        ),
        body: body,
        bottomNavigationBar: NavigationBar(
          backgroundColor: AppColors.navSurface,
          indicatorColor: AppColors.surface,
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) => context.go(_routes[index]),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.data_usage),
              label: 'Tokens',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights),
              label: 'Analytics',
            ),
            NavigationDestination(
              icon: Icon(Icons.lightbulb_outline),
              label: 'Insights',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              label: 'Settings',
            ),
          ],
        ),
      );
}

/// Consistent rounded card used by real data screens.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Card(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      );
}

/// Small value card for totals and rates.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.caption,
  });

  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) => SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTypography.cardDescription),
            const SizedBox(height: 6),
            Text(value, style: AppTypography.cardTitle),
            if (caption != null) ...[
              const SizedBox(height: 4),
              Text(caption!, style: AppTypography.bulletSubtitle),
            ],
          ],
        ),
      );
}
