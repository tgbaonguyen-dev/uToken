import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/figma/presentation/figma_pixel_screen.dart';
import 'figma_routes.dart';
import '../features/auth/domain/mobile_auth.dart';
import '../features/auth/presentation/signing_in_screen.dart';
import '../features/auth/data/auth_mock_repository.dart';
import '../features/auth/domain/signing_in_state_model.dart';
import '../features/insights/presentation/insight_detail_screen.dart';
import '../core/data/usage_repository.dart';
import '../features/onboarding/presentation/onboarding_screens.dart';
import '../core/data/local_prefs.dart';
import '../core/data/offline_monitor.dart';
import '../core/firebase/crash_reporter.dart';
import '../core/data/usage_aggregates.dart';
import '../features/live/analytics_screens.dart';
import '../features/live/insights_screens.dart';
import '../features/live/live_common.dart';
import '../features/live/notices.dart';
import '../features/live/settings_screens.dart';
import '../features/live/tokens_screens.dart';

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
        if (auth.user == null) {
          LocalPrefs.instance.unbindAccount();
          OfflineMonitor.unbind();
          SyncCenter.resetAll();
        }
        if (auth.user == null && !auth.demoMode) {
          return path == '/welcome' ? null : '/welcome';
        }
        // Account UID links both apps; code-pairing screens are preview-only.
        if (auth.user != null && !auth.demoMode) {
          if (path == '/connect-desktop' ||
              path == '/desktop-not-connected' ||
              path == '/waiting-first-usage' ||
              path == '/syncing-usage' ||
              path == '/sync-failed') {
            return '/tokens';
          }
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
          redirect: (_, __) => '/welcome',
        ),
        GoRoute(
          path: '/auth/signing-in',
          builder: (_, __) => const SigningInScreen(),
        ),
        GoRoute(
          path: '/insights/:id',
          builder: (_, state) {
            final args = _liveArgs(auth, usage);
            if (args != null) {
              return _live(LiveInsightDetailScreen(
                  args: args, insightId: state.pathParameters['id']!));
            }
            return InsightDetailScreen(
              initialPeriod: state.uri.queryParameters['period'] ?? 'Month',
            );
          },
        ),
        GoRoute(
          path: '/insight-detail',
          builder: (_, route) {
            final args = _liveArgs(auth, usage);
            final id = route.uri.queryParameters['id'];
            if (args != null) {
              return _live(id == null
                  ? LiveInsightsScreen(args: args)
                  : LiveInsightDetailScreen(args: args, insightId: id));
            }
            return InsightDetailScreen(
                initialPeriod: route.uri.queryParameters['period'] ?? 'Month');
          },
        ),
        GoRoute(
          path: '/notifications',
          builder: (_, __) {
            final args = _liveArgs(auth, usage);
            return args == null
                ? const SizedBox.shrink()
                : _live(LiveNoticesScreen(args: args));
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
            pageBuilder: (context, state) {
              Widget screen() {
                final args = _liveArgs(auth, usage);
                if (args != null) {
                  final live = _liveScreen(entry.key, args, state);
                  if (live != null) return _live(live);
                }
                final widgetScreen = _widgetScreens[entry.key];
                if (widgetScreen != null) return widgetScreen;
                return FigmaPixelScreen(
                    screenId: entry.key,
                    initialPeriod:
                        state.uri.queryParameters['period'] ?? 'Month',
                    selectedDay: state.uri.queryParameters['day']);
              }

              return _tabScreens.contains(entry.key)
                  ? _TabPage(key: state.pageKey, child: screen())
                  : MaterialPage(key: state.pageKey, child: screen());
            },
          ),
      ],
    );

/// Bottom-bar tabs: switching between them cross-fades in place instead of
/// sliding, so the tab bar stays still like a native app.
const _tabScreens = {'M04', 'M05', 'M07', 'M09'};

class _TabPage extends CustomTransitionPage<void> {
  _TabPage({super.key, required super.child})
      : super(
          transitionDuration: const Duration(milliseconds: 220),
          reverseTransitionDuration: const Duration(milliseconds: 160),
          transitionsBuilder: (context, animation, _, child) => FadeTransition(
            opacity:
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.985, end: 1).animate(
                  CurvedAnimation(
                      parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
          ),
        );
}

/// Figma frames rebuilt with layout widgets; the rest still use the
/// coordinate-based FigmaPixelScreen.
const Map<String, Widget> _widgetScreens = {
  'M01': WelcomeScreen(),
  'M02': ConnectDesktopScreen(),
  'M03': InstallGuideScreen(),
};

bool _hasRealUser(MobileAuthController? auth, UsageRepository? usage) =>
    auth?.user != null && !auth!.demoMode && usage != null;

/// Firestore reader for a signed-in, non-demo user; null in demo/preview.
LiveArgs? _liveArgs(MobileAuthController? auth, UsageRepository? usage) {
  if (!_hasRealUser(auth, usage)) return null;
  final uid = auth!.user!.uid;
  LocalPrefs.instance.bindAccount(uid, usage!);
  OfflineMonitor.bind(uid, usage);
  _touchProfileOnce(uid, auth.user!, usage);
  return LiveArgs(uid: uid, repository: usage);
}

/// Rebuilds live screens when phone-only preferences change.
/// Remounts the page when the app language changes so every string updates.
Widget _live(Widget child) => ListenableBuilder(
    listenable: LocalPrefs.instance,
    builder: (_, __) => KeyedSubtree(
        key: ValueKey('lang-${LocalPrefs.instance.language}'), child: child));

/// Live (Firestore) screen for a Figma frame. Onboarding frames and the
/// S01–S04 states are handled by the router redirect and Tokens screen.
Widget? _liveScreen(String id, LiveArgs args, GoRouterState state) {
  final query = state.uri.queryParameters['period'];
  final period =
      query == null ? lastUsagePeriod : UsagePeriodLabel.parse(query);
  // Links to a custom period carry their own range (see withPeriod).
  final range = UsageRange.tryParse(
      state.uri.queryParameters['from'], state.uri.queryParameters['to']);
  if (period == UsagePeriod.custom && range != null) customUsageRange = range;
  return switch (id) {
    'M04' => LiveTokensScreen(args: args, initialPeriod: period),
    'M04B' => LiveUsageDetailsScreen(args: args, period: period),
    'M05' => LiveAnalyticsScreen(args: args, initialPeriod: period),
    'M05B' => LiveEfficiencyScreen(args: args),
    'M05C' => LiveModelComparisonScreen(args: args),
    'M06' => LiveDailyUsageScreen(args: args),
    'M07' => LiveInsightsScreen(args: args),
    'M09' => LiveSettingsScreen(args: args),
    'M10' => LiveDesktopScreen(args: args),
    'M11' => LiveBudgetScreen(args: args),
    'M12' => const LivePrivacyScreen(),
    'M13' => LiveAccountScreen(args: args),
    'M14' => LiveModelPricingScreen(args: args),
    'M15' => LiveAiSuggestionsScreen(args: args),
    'O01' => LiveExportScreen(args: args),
    'O02' => LiveBudgetAlertScreen(args: args),
    'O03' => LiveCostBreakdownScreen(args: args, period: period),
    _ => null,
  };
}

final _touchedProfiles = <String>{};

/// Once per account per launch: tell the admin console this user is active.
void _touchProfileOnce(String uid, MobileAuthUser user, UsageRepository usage) {
  CrashReporter.bindUser(uid, version: appVersion);
  if (!_touchedProfiles.add(uid)) return;
  usage
      .touchProfile(
          uid: uid,
          email: user.email,
          name: user.name,
          appVersion: appVersion,
          platform: defaultTargetPlatform.name)
      .catchError((Object e) => debugPrint('Profile update failed: $e'));
}
