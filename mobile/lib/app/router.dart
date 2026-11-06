import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/analytics/presentation/analytics_screen.dart';
import '../features/auth/presentation/signing_in_screen.dart';
import '../features/efficiency/presentation/efficiency_screen.dart';
import '../features/insights/presentation/insights_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/tokens/presentation/tokens_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/tokens',
  routes: [
    GoRoute(
      path: '/auth/signing-in',
      builder: (_, __) => const SigningInScreen(),
    ),
    StatefulShellRoute.indexedStack(

      builder: (context, state, shell) => _Shell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/tokens', builder: (_, __) => const TokensScreen())]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/analytics',
            builder: (_, __) => const AnalyticsScreen(),
            routes: [GoRoute(path: 'efficiency', builder: (_, __) => const EfficiencyScreen())],
          ),
        ]),
        StatefulShellBranch(routes: [GoRoute(path: '/insights', builder: (_, __) => const InsightsScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen())]),
      ],
    ),
  ],
);

class _Shell extends StatelessWidget {
  const _Shell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: shell.goBranch,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.data_usage), label: 'Tokens'),
          NavigationDestination(icon: Icon(Icons.insights), label: 'Analytics'),
          NavigationDestination(icon: Icon(Icons.lightbulb_outline), label: 'Insights'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}
