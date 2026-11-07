import 'package:go_router/go_router.dart';

import '../features/figma/presentation/figma_pixel_screen.dart';
import 'figma_routes.dart';
import '../features/auth/presentation/signing_in_screen.dart';
import '../features/insights/presentation/insight_detail_screen.dart';

/// UI-only routes for Figma's M/O frames; S-state frames are excluded.
final appRouter = GoRouter(
  initialLocation: '/welcome',
  routes: [
    GoRoute(
      path: '/auth/signing-in',
      builder: (_, __) => const SigningInScreen(),
    ),
    GoRoute(
      path: '/insight-detail',
      builder: (_, __) => const InsightDetailScreen(),
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
        builder: (context, state) => FigmaPixelScreen(screenId: entry.key),
      ),
  ],
);
