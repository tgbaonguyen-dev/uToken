import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_colors.dart';
import 'features/auth/data/auth_mock_repository.dart';
import 'features/auth/domain/signing_in_state_model.dart';
import 'features/auth/presentation/signing_in_screen.dart';
import 'features/insights/presentation/insight_detail_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: PreviewApp()));
}

class PreviewApp extends ConsumerWidget {
  const PreviewApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentState = ref.watch(currentAuthScreenStateProvider);

    return MaterialApp(
      title: 'μToken UI Preview',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF07090C),
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFF14171E),
        body: SafeArea(
          child: Column(
            children: [
              // Top State Switcher Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: const Color(0xFF0E1117),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Figma State Preview: ',
                        style: TextStyle(
                          color: Color(0xFF8F9CAE),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StateChip(
                        label: 'Signing in',
                        isSelected: currentState == AuthScreenState.signingIn,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.signingIn,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Cancelled',
                        isSelected: currentState == AuthScreenState.cancelled,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.cancelled,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Failed',
                        isSelected: currentState == AuthScreenState.failed,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.failed,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Offline',
                        isSelected: currentState == AuthScreenState.offline,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.offline,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Session expired',
                        isSelected: currentState == AuthScreenState.sessionExpired,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.sessionExpired,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Verifying',
                        isSelected: currentState == AuthScreenState.verifying,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.verifying,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Connected',
                        isSelected: currentState == AuthScreenState.connected,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.connected,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Wrong code',
                        isSelected: currentState == AuthScreenState.wrongCode,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.wrongCode,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Code expired',
                        isSelected: currentState == AuthScreenState.codeExpired,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.codeExpired,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Code used',
                        isSelected: currentState == AuthScreenState.codeAlreadyUsed,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.codeAlreadyUsed,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'No response',
                        isSelected: currentState == AuthScreenState.desktopNoResponse,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.desktopNoResponse,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Existing desktop',
                        isSelected: currentState == AuthScreenState.existingDesktop,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.existingDesktop,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Network error',
                        isSelected: currentState == AuthScreenState.networkError,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.networkError,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Unsupported OS',
                        isSelected: currentState == AuthScreenState.unsupportedOs,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.unsupportedOs,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Not installed',
                        isSelected: currentState == AuthScreenState.appNotInstalled,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.appNotInstalled,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Not opened',
                        isSelected: currentState == AuthScreenState.appNotOpened,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.appNotOpened,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Permission denied',
                        isSelected: currentState == AuthScreenState.permissionDenied,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.permissionDenied,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Initial loading (M04)',
                        isSelected: currentState == AuthScreenState.initialLoading,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.initialLoading,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Updating with data (M04)',
                        isSelected: currentState == AuthScreenState.updatingWithData,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.updatingWithData,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Partial data (M04)',
                        isSelected: currentState == AuthScreenState.partialData,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.partialData,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Desktop offline (M04)',
                        isSelected: currentState == AuthScreenState.desktopOffline,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.desktopOffline,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Stale data (M04)',
                        isSelected: currentState == AuthScreenState.staleData,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.staleData,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Cost unavailable (M04)',
                        isSelected: currentState == AuthScreenState.costUnavailable,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.costUnavailable,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'No data (M05)',
                        isSelected: currentState == AuthScreenState.analyticsNoData,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.analyticsNoData,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'No filter results (M05)',
                        isSelected: currentState == AuthScreenState.analyticsNoFilterResults,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.analyticsNoFilterResults,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Partial data (M05)',
                        isSelected: currentState == AuthScreenState.analyticsPartialData,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.analyticsPartialData,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Unsupported metric (M05)',
                        isSelected: currentState == AuthScreenState.analyticsUnsupportedMetric,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.analyticsUnsupportedMetric,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Cost unavailable (M05)',
                        isSelected: currentState == AuthScreenState.analyticsCostUnavailable,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.analyticsCostUnavailable,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Query error (M05)',
                        isSelected: currentState == AuthScreenState.analyticsQueryError,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.analyticsQueryError,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Offline (M05)',
                        isSelected: currentState == AuthScreenState.analyticsOffline,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.analyticsOffline,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'No usage (M06)',
                        isSelected: currentState == AuthScreenState.breakdownNoUsage,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.breakdownNoUsage,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Today in progress (M06)',
                        isSelected: currentState == AuthScreenState.breakdownTodayIncomplete,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.breakdownTodayIncomplete,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Missing data (M06)',
                        isSelected: currentState == AuthScreenState.breakdownMissingData,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.breakdownMissingData,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Cost unavailable (M06)',
                        isSelected: currentState == AuthScreenState.breakdownCostUnavailable,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.breakdownCostUnavailable,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Sync delayed (M06)',
                        isSelected: currentState == AuthScreenState.breakdownSyncDelayed,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.breakdownSyncDelayed,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Analyzing (M07)',
                        isSelected: currentState == AuthScreenState.insightsAnalyzing,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.insightsAnalyzing,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Not enough data (M07)',
                        isSelected: currentState == AuthScreenState.insightsInsufficientData,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.insightsInsufficientData,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'All clear (M07)',
                        isSelected: currentState == AuthScreenState.insightsNoSignificantIssues,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.insightsNoSignificantIssues,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Analysis failed (M07)',
                        isSelected: currentState == AuthScreenState.insightsAnalysisFailed,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.insightsAnalysisFailed,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Insights stale (M07)',
                        isSelected: currentState == AuthScreenState.insightsStale,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.insightsStale,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Insight stale (M08)',
                        isSelected: currentState == AuthScreenState.insightDetailStale,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.insightDetailStale,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Insight resolved (M08)',
                        isSelected: currentState == AuthScreenState.insightDetailResolved,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.insightDetailResolved,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Evidence unavailable (M08)',
                        isSelected: currentState == AuthScreenState.insightDetailEvidenceUnavailable,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.insightDetailEvidenceUnavailable,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Insight detail active (M08)',
                        isSelected: currentState == AuthScreenState.insightDetailActive,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.insightDetailActive,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'No desktop (M09)',
                        isSelected: currentState == AuthScreenState.settingsNoDesktop,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.settingsNoDesktop,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Notifications off (M09)',
                        isSelected: currentState == AuthScreenState.settingsNotificationsDenied,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.settingsNotificationsDenied,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Reauthenticate (M09)',
                        isSelected: currentState == AuthScreenState.settingsReauthenticationRequired,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.settingsReauthenticationRequired,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Desktop syncing (M10)',
                        isSelected: currentState == AuthScreenState.desktopConnectionSyncing,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.desktopConnectionSyncing,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Desktop offline (M10)',
                        isSelected: currentState == AuthScreenState.desktopConnectionOffline,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.desktopConnectionOffline,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Desktop not found (M10)',
                        isSelected: currentState == AuthScreenState.desktopConnectionSourceNotFound,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.desktopConnectionSourceNotFound,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Desktop no usage (M10)',
                        isSelected: currentState == AuthScreenState.desktopConnectionNoUsage,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.desktopConnectionNoUsage,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Desktop permission denied (M10)',
                        isSelected: currentState == AuthScreenState.desktopConnectionPermissionDenied,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.desktopConnectionPermissionDenied,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Desktop session revoked (M10)',
                        isSelected: currentState == AuthScreenState.desktopConnectionSessionRevoked,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.desktopConnectionSessionRevoked,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Desktop update required (M10)',
                        isSelected: currentState == AuthScreenState.desktopConnectionIncompatibleVersion,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.desktopConnectionIncompatibleVersion,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Desktop sync failed (M10)',
                        isSelected: currentState == AuthScreenState.desktopConnectionSyncFailed,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.desktopConnectionSyncFailed,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'No budget (M11)',
                        isSelected: currentState == AuthScreenState.budgetNoBudget,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.budgetNoBudget,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Near threshold (M11)',
                        isSelected: currentState == AuthScreenState.budgetNearThreshold,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.budgetNearThreshold,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Threshold exceeded (M11)',
                        isSelected: currentState == AuthScreenState.budgetThresholdExceeded,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.budgetThresholdExceeded,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Budget exceeded (M11)',
                        isSelected: currentState == AuthScreenState.budgetBudgetExceeded,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.budgetBudgetExceeded,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Cost unavailable (M11)',
                        isSelected: currentState == AuthScreenState.budgetCostUnavailable,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.budgetCostUnavailable,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Notifications off (M11)',
                        isSelected: currentState == AuthScreenState.budgetNotificationsOff,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.budgetNotificationsOff,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Export preparing (M12)',
                        isSelected: currentState == AuthScreenState.privacyExportPreparing,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.privacyExportPreparing,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Export ready (M12)',
                        isSelected: currentState == AuthScreenState.privacyExportSuccess,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.privacyExportSuccess,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Export failed (M12)',
                        isSelected: currentState == AuthScreenState.privacyExportFailed,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.privacyExportFailed,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Deleting usage (M12)',
                        isSelected: currentState == AuthScreenState.privacyDeletingUsage,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.privacyDeletingUsage,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Delete success (M12)',
                        isSelected: currentState == AuthScreenState.privacyDeleteSuccess,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.privacyDeleteSuccess,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Delete partial (M12)',
                        isSelected: currentState == AuthScreenState.privacyDeletePartial,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.privacyDeletePartial,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Reauth (M12)',
                        isSelected: currentState == AuthScreenState.privacyReauthentication,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.privacyReauthentication,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Reauth (M13)',
                        isSelected: currentState == AuthScreenState.accountReauthentication,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.accountReauthentication,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Signing out (M13)',
                        isSelected: currentState == AuthScreenState.accountSigningOut,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.accountSigningOut,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Deleting account (M13)',
                        isSelected: currentState == AuthScreenState.accountDeletingAccount,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.accountDeletingAccount,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Delete failed (M13)',
                        isSelected: currentState == AuthScreenState.accountDeleteFailed,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.accountDeleteFailed,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Delete partial (M13)',
                        isSelected: currentState == AuthScreenState.accountDeletePartial,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.accountDeletePartial,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'AI not set up (M07)',
                        isSelected: currentState == AuthScreenState.insightsAiNotSetUp,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.insightsAiNotSetUp,
                      ),
                      const SizedBox(width: 6),
                      _StateChip(
                        label: 'Invalid API key (M15)',
                        isSelected: currentState == AuthScreenState.aiSuggestionsInvalidApiKey,
                        onTap: () => ref.read(currentAuthScreenStateProvider.notifier).state =
                            AuthScreenState.aiSuggestionsInvalidApiKey,
                      ),
                    ],
                  ),
                ),
              ),

              // Mobile Device Mockup Frame: 390px x 844px, Radius 28px (Figma Spec)
              Expanded(
                child: Center(
                  child: Container(
                    width: 390,
                    height: 844,
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppColors.background, // #090A0B
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFF2C3242), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 30,
                          spreadRadius: 8,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: currentState == AuthScreenState.insightDetailActive
                        ? const InsightDetailScreen()
                        : const SigningInScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF1E2432),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF818CF8) : const Color(0xFF2E384D),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFFA6B2C4),
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
