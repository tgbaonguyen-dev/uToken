import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/mock/figma_mock_repository.dart';

import '../data/auth_mock_repository.dart';
import '../domain/signing_in_state_model.dart';

const demoProgressStates = {
  'signingIn',
  'verifying',
  'initialLoading',
  'updatingWithData',
  'insightsAnalyzing',
  'desktopConnectionSyncing',
  'privacyExportPreparing',
  'privacyDeletingUsage',
  'accountDeletingAccount',
};

Future<void> showDemoOutcome(BuildContext context, String state,
    {required String period}) async {
  final options =
      (await FigmaMockRepository.extraData())['statePreviewOutcomes'][state]
          as List;
  if (!context.mounted) return;
  final router = GoRouter.maybeOf(context);
  final path = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
      const ListTile(
          title: Text('Complete demo operation'),
          subtitle: Text(
              'Choose a mock result. No network or deletion is performed.')),
      for (final option in options)
        ListTile(
            title: Text(option['label']),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pop(sheet, option['path'] as String)),
    ]))),
  );
  if (path != null && context.mounted) {
    router?.go(Uri(path: path, queryParameters: {'period': period}).toString());
  }
}

const reviewedStates = <String, List<AuthScreenState>>{
  'M01': [
    AuthScreenState.signingIn,
    AuthScreenState.cancelled,
    AuthScreenState.failed,
    AuthScreenState.offline,
    AuthScreenState.sessionExpired
  ],
  'M02': [
    AuthScreenState.verifying,
    AuthScreenState.connected,
    AuthScreenState.wrongCode,
    AuthScreenState.codeExpired,
    AuthScreenState.codeAlreadyUsed,
    AuthScreenState.desktopNoResponse,
    AuthScreenState.existingDesktop,
    AuthScreenState.networkError
  ],
  'M03': [
    AuthScreenState.unsupportedOs,
    AuthScreenState.appNotInstalled,
    AuthScreenState.appNotOpened,
    AuthScreenState.permissionDenied
  ],
  'M04': [
    AuthScreenState.initialLoading,
    AuthScreenState.updatingWithData,
    AuthScreenState.partialData,
    AuthScreenState.desktopOffline,
    AuthScreenState.staleData,
    AuthScreenState.costUnavailable
  ],
  'M05': [
    AuthScreenState.analyticsNoData,
    AuthScreenState.analyticsNoFilterResults,
    AuthScreenState.analyticsPartialData,
    AuthScreenState.analyticsUnsupportedMetric,
    AuthScreenState.analyticsCostUnavailable,
    AuthScreenState.analyticsQueryError,
    AuthScreenState.analyticsOffline,
  ],
  'M06': [
    AuthScreenState.breakdownNoUsage,
    AuthScreenState.breakdownTodayIncomplete,
    AuthScreenState.breakdownMissingData,
    AuthScreenState.breakdownCostUnavailable,
    AuthScreenState.breakdownSyncDelayed,
  ],
  'M07': [
    AuthScreenState.insightsAnalyzing,
    AuthScreenState.insightsInsufficientData,
    AuthScreenState.insightsNoSignificantIssues,
    AuthScreenState.insightsAnalysisFailed,
    AuthScreenState.insightsStale,
    AuthScreenState.insightsAiNotSetUp,
  ],
  'M08': [
    AuthScreenState.insightDetailStale,
    AuthScreenState.insightDetailResolved,
    AuthScreenState.insightDetailEvidenceUnavailable,
  ],
  'M09': [
    AuthScreenState.settingsNoDesktop,
    AuthScreenState.settingsNotificationsDenied,
    AuthScreenState.settingsReauthenticationRequired,
  ],
  'M10': [
    AuthScreenState.desktopConnectionSyncing,
    AuthScreenState.desktopConnectionOffline,
    AuthScreenState.desktopConnectionSourceNotFound,
    AuthScreenState.desktopConnectionNoUsage,
    AuthScreenState.desktopConnectionPermissionDenied,
    AuthScreenState.desktopConnectionSessionRevoked,
    AuthScreenState.desktopConnectionIncompatibleVersion,
    AuthScreenState.desktopConnectionSyncFailed,
  ],
  'M11': [
    AuthScreenState.budgetNoBudget,
    AuthScreenState.budgetNearThreshold,
    AuthScreenState.budgetThresholdExceeded,
    AuthScreenState.budgetBudgetExceeded,
    AuthScreenState.budgetCostUnavailable,
    AuthScreenState.budgetNotificationsOff,
  ],
  'M12': [
    AuthScreenState.privacyExportPreparing,
    AuthScreenState.privacyExportSuccess,
    AuthScreenState.privacyExportFailed,
    AuthScreenState.privacyDeletingUsage,
    AuthScreenState.privacyDeleteSuccess,
    AuthScreenState.privacyDeletePartial,
    AuthScreenState.privacyReauthentication,
  ],
  'M13': [
    AuthScreenState.accountReauthentication,
    AuthScreenState.accountSigningOut,
    AuthScreenState.accountDeletingAccount,
    AuthScreenState.accountDeleteFailed,
    AuthScreenState.accountDeletePartial,
  ],
  'M15': [AuthScreenState.aiSuggestionsInvalidApiKey],
};

Future<void> showReviewedStates(BuildContext context, String screenId,
    {String period = 'Month'}) async {
  final states = reviewedStates[screenId];
  if (states == null) return;
  final data =
      await Future.wait(states.map(const AuthMockRepository().getStateData));
  if (!context.mounted) return;
  final router = GoRouter.maybeOf(context);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
      ListTile(
          title: Text('$screenId - UI states'),
          subtitle: const Text('Preview with mock data')),
      for (var i = 0; i < states.length; i++)
        ListTile(
          title: Text(data[i].badgeText),
          subtitle: Text(data[i].card.title),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(sheetContext).pop();
            router?.push(Uri(
                path: '/ui-state/${states[i].name}',
                queryParameters: {'period': period}).toString());
          },
        ),
    ])),
  );
}
