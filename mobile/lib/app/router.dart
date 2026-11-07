import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/firebase/providers.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/welcome_screen.dart';
import '../features/auth/presentation/account_screen.dart';

import '../features/analytics/presentation/analytics_screen.dart';
import '../features/efficiency/presentation/efficiency_screen.dart';
import '../features/insights/presentation/insights_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/tokens/presentation/tokens_screen.dart';

String? authRedirect(AuthState auth, String location) {
  if (auth.initializing) return location == '/loading' ? null : '/loading';
  if (!auth.signedIn) return location == '/welcome' ? null : '/welcome';
  if (location == '/welcome' || location == '/loading') return '/tokens';
  return null;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authControllerProvider, (_, __) => refresh.value++);
  final router = GoRouter(
    initialLocation: '/tokens',
    refreshListenable: refresh,
    redirect: (_, state) =>
        authRedirect(ref.read(authControllerProvider), state.matchedLocation),
    routes: [
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(
          path: '/loading',
          builder: (_, __) =>
              const Scaffold(body: Center(child: CircularProgressIndicator()))),
      GoRoute(path: '/account', builder: (_, __) => const AccountScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _Shell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/tokens', builder: (_, __) => const TokensScreen())
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/analytics',
              builder: (_, __) => const AnalyticsScreen(),
              routes: [
                GoRoute(
                    path: 'efficiency',
                    builder: (_, __) => const EfficiencyScreen())
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/insights', builder: (_, __) => const InsightsScreen())
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/settings', builder: (_, __) => const SettingsScreen())
          ]),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

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
          NavigationDestination(
              icon: Icon(Icons.lightbulb_outline), label: 'Insights'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}
