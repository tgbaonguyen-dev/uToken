import 'package:go_router/go_router.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/figma/presentation/figma_pixel_screen.dart';
import 'figma_routes.dart';
import '../core/widgets/ui_preview_scope.dart';
import '../main_preview.dart';
import '../features/auth/presentation/signing_in_screen.dart';
import '../features/auth/data/auth_mock_repository.dart';
import '../features/auth/domain/signing_in_state_model.dart';
import '../features/insights/presentation/insight_detail_screen.dart';

/// Combined UI routes: exported Figma frames, hand-built states and insight detail.
final appRouter = GoRouter(
  initialLocation: '/welcome',
  routes: [
    GoRoute(
      path: '/ui-state/:state',
      builder: (_, route) {
        final state = AuthScreenState.values.firstWhere(
          (s) => s.name == route.pathParameters['state'],
          orElse: () => AuthScreenState.signingIn,
        );
        return ProviderScope(
          key: ValueKey(state),
          overrides: [
            currentAuthScreenStateProvider.overrideWith((ref) => state)
          ],
          child: const SigningInScreen(),
        );
      },
    ),
    GoRoute(
      path: '/state-preview',
      redirect: (context, _) =>
          UiPreviewScope.enabledOf(context) ? null : '/welcome',
      builder: (_, __) => const PreviewApp(),
    ),
    GoRoute(
      path: '/auth/signing-in',
      builder: (_, __) => const SigningInScreen(),
    ),
    GoRoute(
      path: '/insight-detail',
      builder: (_, route) => InsightDetailScreen(
          initialPeriod: route.uri.queryParameters['period'] ?? 'Month'),
    ),
    GoRoute(
      path: '/analytics/efficiency',
      redirect: (_, __) => '/efficiency',
    ),
    GoRoute(
      path: '/',
      redirect: (context, state) => '/welcome',
    ),
    for (final entry in figmaRoutes.entries)
      GoRoute(
        path: entry.value,
        builder: (context, state) => FigmaPixelScreen(
          screenId: entry.key,
          initialPeriod: state.uri.queryParameters['period'] ?? 'Month',
          selectedDay: state.uri.queryParameters['day'],
        ),
      ),
  ],
);
