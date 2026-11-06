import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../data/auth_mock_repository.dart';
import '../domain/signing_in_state_model.dart';

class SigningInScreen extends ConsumerWidget {
  const SigningInScreen({
    super.key,
    this.initialState,
    this.onAction,
  });

  final AuthScreenState? initialState;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (initialState != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(currentAuthScreenStateProvider) != initialState) {
          ref.read(currentAuthScreenStateProvider.notifier).state = initialState!;
        }
      });
    }

    final stateAsync = ref.watch(authStateDataProvider);

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
                            final bulletColor = _parseColor(item.bulletColor).withValues(alpha: 0.65);
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
                        final isPreAppFlow = data.screenId == 'M01' || data.screenId == 'M02' || data.screenId == 'M03';
                        final defaultBg = isPreAppFlow ? const Color(0xFFF4F4F5) : const Color(0xFF171717);
                        final defaultText = isPreAppFlow ? const Color(0xFF111214) : const Color(0xFF9C9FAB);

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
