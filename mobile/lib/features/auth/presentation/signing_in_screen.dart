import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/mock/figma_mock_repository.dart';
import '../data/auth_mock_repository.dart';
import '../domain/signing_in_state_model.dart';
import 'reviewed_state_view.dart';
import 'reviewed_state_navigation.dart';

class SigningInScreen extends ConsumerStatefulWidget {
  const SigningInScreen({
    super.key,
    this.initialState,
    this.onAction,
  });

  final AuthScreenState? initialState;
  final VoidCallback? onAction;

  @override
  ConsumerState<SigningInScreen> createState() => _SigningInScreenState();
}

class _SigningInScreenState extends ConsumerState<SigningInScreen> {
  bool _acting = false;
  AuthScreenState? get initialState => widget.initialState;
  VoidCallback? get onAction => widget.onAction;

  @override
  Widget build(BuildContext context) {
    if (initialState != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(currentAuthScreenStateProvider) != initialState) {
          ref.read(currentAuthScreenStateProvider.notifier).state =
              initialState!;
        }
      });
    }

    final stateAsync = ref.watch(authStateDataProvider);

    final reviewed = stateAsync.asData?.value;
    if (reviewed?.figmaLayout != null) {
      final data = reviewed!;
      final router = GoRouter.maybeOf(context);
      final selectedPeriod = router == null
          ? null
          : GoRouterState.of(context).uri.queryParameters['period'];
      final period =
          const ['Day', 'Week', 'Month', 'Total'].contains(selectedPeriod)
              ? selectedPeriod!
              : 'Month';
      void back() {
        if (router != null) {
          if (router.canPop()) {
            router.pop();
          } else {
            router.go(Uri(
                path: _baseRoute(data.screenId),
                queryParameters: {'period': period}).toString());
          }
        } else {
          Navigator.of(context).maybePop();
        }
      }

      final state = ref.watch(currentAuthScreenStateProvider);
      return PopScope(
          canPop: router == null || router.canPop(),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) back();
          },
          child: ReviewedStateView(
            onSimulateResult:
                router != null && demoProgressStates.contains(state.name)
                    ? () async {
                        if (_acting) return;
                        _acting = true;
                        try {
                          await showDemoOutcome(context, state.name,
                              period: period);
                        } finally {
                          _acting = false;
                        }
                      }
                    : null,
            data: data,
            onBack: back,
            onSelectState: () =>
                showReviewedStates(context, data.screenId, period: period),
            onTab: (index) => router?.go(Uri(
                    path: [
                      '/tokens',
                      '/analytics',
                      '/insights',
                      '/settings'
                    ][index],
                    queryParameters: index < 3 ? {'period': period} : null)
                .toString()),
            onAction: onAction ??
                () async {
                  if (_acting) return;
                  _acting = true;
                  FocusManager.instance.primaryFocus?.unfocus();
                  try {
                    if (router == null) {
                      back();
                      return;
                    }
                    if (data.screenId == 'M15') {
                      router.push(Uri(
                          path: '/ai-suggestions',
                          queryParameters: {'period': period}).toString());
                      return;
                    }
                    if (data.screenId == 'M13') {
                      if (data.stateType == 'signing_out') {
                        router.go('/welcome');
                        return;
                      }
                      final spec = (await FigmaMockRepository.extraData())[
                          'accountStateDialogs'][data.stateType] as Map;
                      if (!context.mounted) return;
                      final confirmLabel = spec['confirmLabel'];
                      final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dialog) => AlertDialog(
                                scrollable: true,
                                title: Text(spec['title']),
                                content: Text([
                                  spec['body'],
                                  if (spec['jobId'] != null) spec['jobId'],
                                  if (spec['items'] is List)
                                    ...(spec['items'] as List),
                                ].join('\n\n')),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialog, false),
                                      child: Text(confirmLabel == null
                                          ? 'Close'
                                          : 'Cancel')),
                                  if (confirmLabel != null)
                                    FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(dialog, true),
                                        child: Text(confirmLabel)),
                                ],
                              ));
                      if (confirmed != true || !context.mounted) return;
                      final retry = data.stateType == 'delete_failed';
                      final route = Uri(
                          path: retry
                              ? '/ui-state/accountDeletingAccount'
                              : '/account',
                          queryParameters: {'period': period}).toString();
                      if (retry) {
                        router.go(route);
                      } else {
                        router.push(route);
                      }
                    } else if (data.screenId == 'M12') {
                      var target = switch (data.stateType) {
                        'export_success' => '/confirmations',
                        'export_failed' => '/ui-state/privacyExportPreparing',
                        _ => '/privacy',
                      };
                      if (data.stateType == 'reauthentication' ||
                          data.stateType == 'delete_partial') {
                        final verification =
                            data.stateType == 'reauthentication';
                        final spec = (await FigmaMockRepository.extraData())[
                            verification
                                ? 'privacyVerification'
                                : 'privacyPartialDeletion'] as Map;
                        if (!context.mounted) return;
                        final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dialog) => AlertDialog(
                                  scrollable: true,
                                  title: Text(spec['title']),
                                  content: Text(verification
                                      ? spec['body']
                                      : '${spec['body']}\n\n${spec['jobId']}\n${(spec['items'] as List).join('\n')}'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialog, false),
                                        child: const Text('Cancel')),
                                    FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(dialog, true),
                                        child: Text(spec['confirmLabel'])),
                                  ],
                                ));
                        if (confirmed != true || !context.mounted) return;
                        target = verification
                            ? '/ui-state/privacyExportPreparing'
                            : '/ui-state/privacyDeletingUsage';
                      }
                      final route =
                          Uri(path: target, queryParameters: {'period': period})
                              .toString();
                      if (target.startsWith('/ui-state/')) {
                        router.go(route);
                      } else {
                        router.push(route);
                      }
                    } else if (data.screenId == 'M11') {
                      final target = switch (data.stateType) {
                        'threshold_exceeded' ||
                        'budget_exceeded' =>
                          '/analytics',
                        'cost_unavailable' => '/model-pricing',
                        _ => '/budget',
                      };
                      router.push(
                          Uri(path: target, queryParameters: {'period': period})
                              .toString());
                    } else if (data.screenId == 'M10') {
                      if (data.stateType == 'permission_denied') {
                        final help = (await FigmaMockRepository.extraData())[
                            'desktopPermissionHelp'] as Map;
                        if (!context.mounted) return;
                        await showDialog<void>(
                            context: context,
                            builder: (dialog) => AlertDialog(
                                  scrollable: true,
                                  title: Text(help['title']),
                                  content: Text(
                                      '${help['body']}\n\n${(help['steps'] as List).join('\n\n')}'),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(dialog),
                                        child: const Text('Close'))
                                  ],
                                ));
                        return;
                      }
                      final target = switch (data.stateType) {
                        'offline' ||
                        'sync_failed' =>
                          '/ui-state/desktopConnectionSyncing',
                        'source_not_found' ||
                        'incompatible_version' =>
                          '/install-guide',
                        'no_usage' => '/waiting-first-usage',
                        'session_revoked' => '/connect-desktop',
                        _ => '/desktop-connection',
                      };
                      final route =
                          Uri(path: target, queryParameters: {'period': period})
                              .toString();
                      if (data.stateType == 'offline' ||
                          data.stateType == 'sync_failed') {
                        router.go(route);
                      } else {
                        router.push(route);
                      }
                    } else if (data.screenId == 'M09') {
                      final target = switch (data.stateType) {
                        'no_desktop' => '/connect-desktop',
                        'notifications_denied' => '/budget',
                        _ => '/account',
                      };
                      router.push(
                          Uri(path: target, queryParameters: {'period': period})
                              .toString());
                    } else if (data.screenId == 'M08') {
                      router.go(Uri(
                          path: '/insights',
                          queryParameters: {'period': period}).toString());
                    } else if (data.screenId == 'M07') {
                      final target = switch (data.stateType) {
                        'insufficient_data' => '/tokens',
                        'no_significant_issues' => '/analytics',
                        'analysis_failed' ||
                        'insights_stale' =>
                          '/ui-state/insightsAnalyzing',
                        'ai_not_set_up' => '/ai-suggestions',
                        _ => '/insights',
                      };
                      final route =
                          Uri(path: target, queryParameters: {'period': period})
                              .toString();
                      if (data.stateType == 'ai_not_set_up') {
                        router.push(route);
                      } else {
                        router.go(route);
                      }
                    } else if (data.screenId == 'M06') {
                      String? selectedDay;
                      if (data.stateType == 'no_usage') {
                        final sample = await FigmaMockRepository.exportData();
                        if (!context.mounted) return;
                        selectedDay = await showModalBottomSheet<String>(
                            context: context,
                            showDragHandle: true,
                            builder: (sheet) => SafeArea(
                                    child: ListView(
                                  shrinkWrap: true,
                                  children: [
                                    const ListTile(
                                        title: Text('Choose another day'),
                                        subtitle: Text(
                                            'Available dates from sample usage')),
                                    for (final row in sample['records'] as List)
                                      ListTile(
                                          title: Text(row['date']),
                                          onTap: () => Navigator.pop(
                                              sheet, row['date'])),
                                  ],
                                )));
                        if (selectedDay == null || !context.mounted) return;
                      }
                      final target = switch (data.stateType) {
                        'cost_unavailable' => '/model-pricing',
                        'sync_delayed' => '/desktop-connection',
                        _ => '/daily-usage',
                      };
                      router.push(Uri(path: target, queryParameters: {
                        'period': period,
                        if (selectedDay != null) 'day': selectedDay
                      }).toString());
                    } else if (data.screenId == 'M05') {
                      var nextPeriod = period;
                      if (data.stateType == 'no_data') {
                        final choice = await showModalBottomSheet<String>(
                            context: context,
                            showDragHandle: true,
                            builder: (sheet) => SafeArea(
                                    child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const ListTile(
                                        title: Text('Change date range'),
                                        subtitle: Text(
                                            'Load sample analytics for this range')),
                                    for (final option in [
                                      'Day',
                                      'Week',
                                      'Month',
                                      'Total'
                                    ])
                                      ListTile(
                                          title: Text(option),
                                          trailing: option == period
                                              ? const Icon(Icons.check)
                                              : null,
                                          onTap: () =>
                                              Navigator.pop(sheet, option)),
                                  ],
                                )));
                        if (choice == null || !context.mounted) return;
                        nextPeriod = choice;
                      }
                      router.go(Uri(
                          path: '/analytics',
                          queryParameters: {'period': nextPeriod}).toString());
                    } else if (data.screenId == 'M01' &&
                        data.stateType != 'signing_in') {
                      ref.read(currentAuthScreenStateProvider.notifier).state =
                          AuthScreenState.signingIn;
                    } else if (data.screenId == 'M03' &&
                        const ['permission_denied', 'unsupported_os']
                            .contains(data.stateType)) {
                      final help = (await FigmaMockRepository.extraData())[
                          'installStateHelp'][data.stateType] as Map;
                      if (!context.mounted) return;
                      await showDialog<void>(
                          context: context,
                          builder: (dialog) => AlertDialog(
                                scrollable: true,
                                title: Text(help['title']),
                                content: Text(help['body']),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(dialog),
                                      child: const Text('Close'))
                                ],
                              ));
                    } else if (data.screenId == 'M02' &&
                        data.stateType == 'existing_desktop') {
                      router.push(Uri(
                          path: '/desktop-connection',
                          queryParameters: {'period': period}).toString());
                    } else if (data.screenId == 'M02' &&
                        data.stateType == 'connected') {
                      router.go(Uri(
                          path: '/waiting-first-usage',
                          queryParameters: {'period': period}).toString());
                    } else if (data.screenId == 'M04') {
                      final target = switch (data.stateType) {
                        'cost_unavailable' => '/model-pricing',
                        'desktop_offline' => '/desktop-connection',
                        'stale_data' => '/syncing-usage',
                        _ => '/tokens',
                      };
                      router.go(
                          Uri(path: target, queryParameters: {'period': period})
                              .toString());
                    } else {
                      router.go(Uri(
                          path: _baseRoute(data.screenId),
                          queryParameters: {'period': period}).toString());
                    }
                  } finally {
                    _acting = false;
                  }
                },
          ));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: stateAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.bulletBlue),
          ),
          error: (err, _) => Center(
            child: Text(
              'Error loading mock data: $err',
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
          data: (data) => _SigningInContent(
            data: data,
            onAction: onAction,
          ),
        ),
      ),
      bottomNavigationBar: stateAsync.whenOrNull(
        data: (data) => data.hasBottomNavigation
            ? _AppBottomNavigation(activeTab: data.activeTab)
            : null,
      ),
    );
  }

  String _baseRoute(String screenId) => switch (screenId) {
        'M01' => '/welcome',
        'M02' => '/connect-desktop',
        'M03' => '/install-guide',
        'M05' => '/analytics',
        'M06' => '/daily-usage',
        'M07' => '/insights',
        'M08' => '/insight-detail',
        'M09' => '/settings',
        'M10' => '/desktop-connection',
        'M11' => '/budget',
        'M12' => '/privacy',
        'M13' => '/account',
        'M15' => '/ai-suggestions',
        _ => '/tokens',
      };
}

class _SigningInContent extends StatelessWidget {
  const _SigningInContent({
    required this.data,
    this.onAction,
  });

  final SigningInStateData data;
  final VoidCallback? onAction;

  Color _parseColor(String hex) {
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    } else if (clean.length == 8) {
      return Color(int.parse(clean, radix: 16));
    }
    return AppColors.bulletBlue;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top State Badge (Figma: Top 28px, Left 20px, Width 350px, Align Right)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                data.badgeText,
                style: AppTypography.stateLabel,
              ),
            ),
            const SizedBox(height: 8),

            // Screen title (Figma: Top 52px, Left 20px, Size 22px SemiBold #F4F4F5)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (data.hasBackButton) ...[
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Padding(
                      padding: EdgeInsets.only(right: 6.0),
                      child: Icon(
                        Icons.chevron_left,
                        color: AppColors.backGlyph,
                        size: 28,
                      ),
                    ),
                  ),
                ],
                Text(
                  data.screenTitle,
                  style: AppTypography.screenTitle,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // State subtitle / context (Figma: Top 94px, Left 20px, Size 11px Medium #747984)
            Text(
              data.specificationSubtitle,
              style: AppTypography.stateContext,
            ),
            const SizedBox(height: 28),

            // Central Card (Figma: Width 350, Height ~260, Radius 20, Fill #121519, Border 1px #2A2F36)
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 260),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
              ),
              child: Column(
                children: [
                  // Illustration Icon dynamically rendered
                  _CardIconSwitcher(iconType: data.card.iconType),
                  const SizedBox(height: 12),

                  // Header copy (Figma: Width 302px, Gap 5px)
                  SizedBox(
                    width: 302,
                    child: Column(
                      children: [
                        Text(
                          data.card.title,
                          textAlign: TextAlign.center,
                          style: AppTypography.cardTitle,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          data.card.description,
                          textAlign: TextAlign.center,
                          style: AppTypography.cardDescription,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Divider line (Figma: Width 302px, Left 24px, Border 1px #2A2F36)
                  const SizedBox(
                    width: 302,
                    child: Divider(
                      color: Color(0xFF2A2F36),
                      thickness: 1,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Items list (Figma Detail rows: Dot 8x8 left 24px, Text width 278px left 48px, gap 8px)
                  ...data.card.items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final bulletColor =
                        _parseColor(item.bulletColor).withValues(alpha: 0.65);
                    final isLast = index == data.card.items.length - 1;

                    return Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0.0 : 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Detail dot (Figma: 8x8px, Color with 65% opacity)
                          Container(
                            margin: const EdgeInsets.only(top: 6, right: 16),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: bulletColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          // Detail text (Figma: Width 278px, Title 12px Medium #F4F4F5, Meta 10px Regular #989FA8)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: AppTypography.bulletTitle,
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  item.subtitle,
                                  style: AppTypography.bulletSubtitle,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 36),

            // BEHAVIOR Section (Figma: Top 438px, Left 20px)
            Text(
              data.behavior.label,
              style: AppTypography.behaviorLabel,
            ),
            const SizedBox(height: 4),
            Text(
              data.behavior.description,
              style: AppTypography.behaviorText,
            ),

            const SizedBox(height: 24),

            // Bottom Shared AppButton (Height 52px, Radius 14px, Font Be Vietnam Pro)
            Builder(
              builder: (context) {
                final isPreAppFlow = data.screenId == 'M01' ||
                    data.screenId == 'M02' ||
                    data.screenId == 'M03';
                final defaultBg = isPreAppFlow
                    ? const Color(0xFFF4F4F5)
                    : const Color(0xFF171717);
                final defaultText = isPreAppFlow
                    ? const Color(0xFF111214)
                    : const Color(0xFF9C9FAB);

                return AppButton(
                  label: data.action.buttonLabel,
                  backgroundColor: data.action.backgroundColor != null
                      ? _parseColor(data.action.backgroundColor!)
                      : defaultBg,
                  textColor: data.action.textColor != null
                      ? _parseColor(data.action.textColor!)
                      : defaultText,
                  onPressed: onAction ?? () => Navigator.of(context).maybePop(),
                );
              },
            ),
            SizedBox(height: data.hasBottomNavigation ? 16 : 8),
          ],
        ),
      ),
    );
  }
}

/// Điều phối hiển thị Icon phù hợp theo trạng thái
class _CardIconSwitcher extends StatelessWidget {
  const _CardIconSwitcher({required this.iconType});

  final String iconType;

  @override
  Widget build(BuildContext context) {
    switch (iconType) {
      case 'cancelled':
      case 'empty':
        return const _CancelledBoxIconWidget();
      case 'failed':
      case 'error':
        return const _FailedCloudIconWidget();
      case 'offline':
        return const _OfflineCloudIconWidget();
      case 'connected':
      case 'success':
        return const _SuccessCheckIconWidget();
      case 'signing_in':
      default:
        return const _DocumentIconWidget();
    }
  }
}

/// 1. Icon cho trạng thái "Signing you in" (Figma layer spec: Rectangle #222B4D, Rectangle_2 #151922, Border #6678E8, Lines #9AA7FF)
class _DocumentIconWidget extends StatelessWidget {
  const _DocumentIconWidget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // tile_background (Figma: Width 69.47px, Height 29.05px, Color #191F3C)
          Positioned(
            top: 14,
            child: Container(
              width: 69.5,
              height: 29.0,
              decoration: BoxDecoration(
                color: const Color(0xFF191F3C),
                borderRadius: BorderRadius.circular(14.5),
              ),
            ),
          ),

          // Back Document (Figma: Rectangle, Width 28.18px, Height 32.43px, Color #222B4D)
          Positioned(
            left: 19,
            top: 10,
            child: Container(
              width: 28.2,
              height: 32.4,
              decoration: BoxDecoration(
                color: const Color(0xFF222B4D),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: const Color(0xFF333E6E),
                  width: 1.5,
                ),
              ),
            ),
          ),

          // Front Primary Document (Figma: Rectangle_2, Width 26.83px, Height 33.82px, Fill #151922, Border 2.5px #6678E8)
          Positioned(
            left: 25,
            top: 4,
            child: Container(
              width: 26.8,
              height: 33.8,
              padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF151922),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: AppColors.iconPrimaryBorder, // #6678E8
                  width: 2.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(
                    width: 15,
                    height: 2.2,
                    decoration: BoxDecoration(
                      color: AppColors.iconTextLines, // #9AA7FF
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                  Container(
                    width: 16.5,
                    height: 2.2,
                    decoration: BoxDecoration(
                      color: AppColors.iconTextLines,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                  Container(
                    width: 12,
                    height: 2.2,
                    decoration: BoxDecoration(
                      color: AppColors.iconTextLines,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                  Container(
                    width: 9,
                    height: 2.2,
                    decoration: BoxDecoration(
                      color: AppColors.iconTextLines,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 2. Icon cho trạng thái "Sign-in was cancelled" (Figma spec: EmptyInbox, lines #AEB4BF 2.5px, Box #737985 2.5px)
class _CancelledBoxIconWidget extends StatelessWidget {
  const _CancelledBoxIconWidget();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/illustrations/empty_inbox.png',
      width: 92,
      height: 73,
      fit: BoxFit.contain,
    );
  }
}

/// 3. Icon cho trạng thái "Couldn't sign you in" (Asset gốc xuất từ Figma: Reference Illustration / Error 104x83)
class _FailedCloudIconWidget extends StatelessWidget {
  const _FailedCloudIconWidget();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/illustrations/cloud_error.png',
      width: 92,
      height: 73,
      fit: BoxFit.contain,
    );
  }
}

/// 4. Icon cho trạng thái "You're offline" (Asset gốc xuất từ Figma: Reference Illustration / Warning)
class _OfflineCloudIconWidget extends StatelessWidget {
  const _OfflineCloudIconWidget();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/illustrations/cloud_offline.png',
      width: 92,
      height: 73,
      fit: BoxFit.contain,
    );
  }
}

/// 5. Icon cho trạng thái "Desktop connected" (Asset gốc xuất từ Figma: Reference Illustration / Success 104x83)
class _SuccessCheckIconWidget extends StatelessWidget {
  const _SuccessCheckIconWidget();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/illustrations/check_success.png',
      width: 92,
      height: 73,
      fit: BoxFit.contain,
    );
  }
}

/// Bottom navigation bar 4-tab (Figma: Bottom navigation / Tokens active, Height 68px)
class _AppBottomNavigation extends StatelessWidget {
  const _AppBottomNavigation({this.activeTab = 'Tokens'});

  final String activeTab;

  static const Color _activeColor = AppColors.navActive;
  static const Color _inactiveColor = AppColors.navInactive;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      decoration: const BoxDecoration(
        color: AppColors.navSurface,
        border: Border(
          top: BorderSide(color: AppColors.dockDivider, width: 1.0),
        ),
      ),
      child: Row(
        children: [
          _buildTabItem(
            name: 'Tokens',
            iconPath: 'assets/images/icons/tab_tokens.png',
            isActive: activeTab == 'Tokens',
          ),
          _buildTabItem(
            name: 'Analytics',
            iconPath: 'assets/images/icons/tab_analytics.png',
            isActive: activeTab == 'Analytics',
          ),
          _buildTabItem(
            name: 'Insights',
            iconPath: 'assets/images/icons/tab_insights.png',
            isActive: activeTab == 'Insights',
          ),
          _buildTabItem(
            name: 'Settings',
            iconPath: 'assets/images/icons/tab_settings.png',
            isActive: activeTab == 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required String name,
    required String iconPath,
    required bool isActive,
  }) {
    return Expanded(
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Active rail at top edge (Figma spec: Width 56px, Height 4px, Radius 2px, Color #F2F3F5, Left 20.75px)
          if (isActive)
            Positioned(
              top: 0,
              child: Container(
                width: 56,
                height: 4,
                decoration: BoxDecoration(
                  color: _activeColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          Positioned(
            top: 10,
            child: Image.asset(
              iconPath,
              width: 22,
              height: 22,
              color: isActive ? _activeColor : _inactiveColor,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            top: 39,
            left: 0,
            right: 0,
            height: 18,
            child: Center(
              child: Text(
                name,
                textAlign: TextAlign.center,
                style: AppTypography.font(
                  fontSize: isActive ? 11 : 10.5,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive ? _activeColor : _inactiveColor,
                  height: 16 / (isActive ? 11 : 10.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
