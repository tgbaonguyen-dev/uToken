import 'package:go_router/go_router.dart';

import '../features/figma/presentation/figma_pixel_screen.dart';
import 'figma_routes.dart';

/// UI-only routes for Figma's M/O frames; S-state frames are excluded.
final appRouter = GoRouter(
  initialLocation: '/welcome',
  routes: [
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
