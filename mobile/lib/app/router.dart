import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/figma/presentation/figma_pixel_screen.dart';
import 'figma_routes.dart';
import '../features/auth/domain/mobile_auth.dart';
import '../core/widgets/ui_preview_scope.dart';
import '../main_preview.dart';
import '../features/auth/presentation/signing_in_screen.dart';
import '../features/auth/data/auth_mock_repository.dart';
import '../features/auth/domain/signing_in_state_model.dart';
import '../features/insights/presentation/insight_detail_screen.dart';
import '../features/tokens/presentation/tokens_screen.dart';
import '../features/analytics/presentation/analytics_screen.dart';
import '../features/efficiency/presentation/efficiency_screen.dart';
import '../features/insights/presentation/insights_screen.dart';
import '../features/settings/presentation/last_sync_screen.dart';
import '../core/data/usage_repository.dart';

/// Combined UI routes: exported Figma frames, hand-built states and insight detail.
final appRouter = createAppRouter();

/// Desktop và mobile kết nối bằng cách đăng nhập cùng tài khoản Google (không dùng mã ghép đôi).
GoRouter createAppRouter(
        {MobileAuthController? auth, UsageRepository? usage}) =>
    GoRouter(
      refreshListenable: auth,
      redirect: (_, state) {
        if (auth == null) return null;
        final path = state.uri.path;
        if (!auth.ready) {
          return path == '/auth/loading' ? null : '/auth/loading';
        }
        if (auth.user == null && !auth.demoMode) {
          return path == '/welcome' ? null : '/welcome';
        }
        if (path == '/state-preview' ||
            path.startsWith('/ui-state/') ||
            path == '/auth/signing-in') {
          return '/tokens';
        }
        if (path == '/welcome' || path == '/auth/loading') {
          return auth.signedInDestination;
        }
        return null;
      },
      initialLocation: '/welcome',
      routes: [
        GoRoute(
            path: '/auth/loading',
            builder: (_, __) => const Scaffold(
                body: Center(
                    child: CircularProgressIndicator(
                        semanticsLabel: 'Restoring session')))),
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
          builder: (_, route) {
            final real = _hasRealUser(auth, usage);
            final uid = auth?.user?.uid;
            return real && uid != null
                ? InsightsScreen(uid: uid, repository: usage!)
                : InsightDetailScreen(
                    initialPeriod:
                        route.uri.queryParameters['period'] ?? 'Month');
          },
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
            builder: (context, state) {
              final real = _hasRealUser(auth, usage);
              final uid = auth?.user?.uid;
              if (real && uid != null) {
                final repository = usage!;
                if (entry.key == 'M04') {
                  return TokensScreen(uid: uid, repository: repository);
                }
                if (entry.key == 'M05') {
                  return AnalyticsScreen(uid: uid, repository: repository);
                }
                if (entry.key == 'M05B') {
                  return EfficiencyScreen(uid: uid, repository: repository);
                }
                if (entry.key == 'M07') {
                  return InsightsScreen(uid: uid, repository: repository);
                }
                if (entry.key == 'M10') {
                  return LastSyncScreen(uid: uid, repository: repository);
                }
              }
              return FigmaPixelScreen(
                  screenId: entry.key,
                  initialPeriod: state.uri.queryParameters['period'] ?? 'Month',
                  selectedDay: state.uri.queryParameters['day']);
            },
          ),
      ],
    );

bool _hasRealUser(MobileAuthController? auth, UsageRepository? usage) =>
    auth?.user != null && !auth!.demoMode && usage != null;
