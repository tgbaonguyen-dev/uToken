import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/signing_in_state_model.dart';

abstract class AuthRepository {
  Future<SigningInStateData> getSigningInStateData();
  Future<SigningInStateData> getCancelledStateData();
  Future<SigningInStateData> getFailedStateData();
  Future<SigningInStateData> getOfflineStateData();
  Future<SigningInStateData> getSessionExpiredStateData();
  Future<SigningInStateData> getVerifyingStateData();
  Future<SigningInStateData> getConnectedStateData();
  Future<SigningInStateData> getStateData(AuthScreenState state);
}

class AuthMockRepository implements AuthRepository {
  const AuthMockRepository();

  static const String _signingInPath = 'assets/data/mocks/auth_signing_in.json';
  static const String _cancelledPath = 'assets/data/mocks/auth_sign_in_cancelled.json';
  static const String _failedPath = 'assets/data/mocks/auth_sign_in_failed.json';
  static const String _offlinePath = 'assets/data/mocks/auth_sign_in_offline.json';
  static const String _sessionExpiredPath = 'assets/data/mocks/auth_session_expired.json';
  static const String _verifyingPath = 'assets/data/mocks/pairing_verifying.json';
  static const String _connectedPath = 'assets/data/mocks/pairing_connected.json';
  static const String _wrongCodePath = 'assets/data/mocks/pairing_wrong_code.json';
  static const String _codeExpiredPath = 'assets/data/mocks/pairing_code_expired.json';
  static const String _codeAlreadyUsedPath = 'assets/data/mocks/pairing_code_already_used.json';
  static const String _desktopNoResponsePath = 'assets/data/mocks/pairing_desktop_no_response.json';
  static const String _existingDesktopPath = 'assets/data/mocks/pairing_existing_desktop.json';
  static const String _networkErrorPath = 'assets/data/mocks/pairing_network_error.json';
  static const String _unsupportedOsPath = 'assets/data/mocks/install_unsupported_os.json';
  static const String _appNotInstalledPath = 'assets/data/mocks/install_app_not_installed.json';
  static const String _appNotOpenedPath = 'assets/data/mocks/install_app_not_opened.json';
  static const String _permissionDeniedPath = 'assets/data/mocks/install_permission_denied.json';
  static const String _initialLoadingPath = 'assets/data/mocks/tokens_initial_loading.json';
  static const String _updatingWithDataPath = 'assets/data/mocks/tokens_updating_with_data.json';
  static const String _partialDataPath = 'assets/data/mocks/tokens_partial_data.json';
  static const String _desktopOfflinePath = 'assets/data/mocks/tokens_desktop_offline.json';
  static const String _staleDataPath = 'assets/data/mocks/tokens_stale_data.json';
  static const String _costUnavailablePath = 'assets/data/mocks/tokens_cost_unavailable.json';
  static const String _analyticsNoDataPath = 'assets/data/mocks/analytics_no_data.json';
  static const String _analyticsNoFilterResultsPath = 'assets/data/mocks/analytics_no_filter_results.json';
  static const String _analyticsPartialDataPath = 'assets/data/mocks/analytics_partial_data.json';
  static const String _analyticsUnsupportedMetricPath = 'assets/data/mocks/analytics_unsupported_metric.json';
  static const String _analyticsCostUnavailablePath = 'assets/data/mocks/analytics_cost_unavailable.json';
  static const String _analyticsQueryErrorPath = 'assets/data/mocks/analytics_query_error.json';
  static const String _analyticsOfflinePath = 'assets/data/mocks/analytics_offline.json';
  static const String _breakdownNoUsagePath = 'assets/data/mocks/breakdown_no_usage.json';
  static const String _breakdownTodayIncompletePath = 'assets/data/mocks/breakdown_today_incomplete.json';
  static const String _breakdownMissingDataPath = 'assets/data/mocks/breakdown_missing_data.json';
  static const String _breakdownCostUnavailablePath = 'assets/data/mocks/breakdown_cost_unavailable.json';
  static const String _breakdownSyncDelayedPath = 'assets/data/mocks/breakdown_sync_delayed.json';
  static const String _insightsAnalyzingPath = 'assets/data/mocks/insights_analyzing.json';
  static const String _insightsInsufficientDataPath = 'assets/data/mocks/insights_insufficient_data.json';
  static const String _insightsNoSignificantIssuesPath = 'assets/data/mocks/insights_no_significant_issues.json';
  static const String _insightsAnalysisFailedPath = 'assets/data/mocks/insights_analysis_failed.json';
  static const String _insightsStalePath = 'assets/data/mocks/insights_stale.json';
  static const String _insightDetailStalePath = 'assets/data/mocks/insight_detail_stale.json';
  static const String _insightDetailResolvedPath = 'assets/data/mocks/insight_detail_resolved.json';
  static const String _insightDetailEvidenceUnavailablePath = 'assets/data/mocks/insight_detail_evidence_unavailable.json';
  static const String _insightDetailActivePath = 'assets/data/mocks/insight_detail_active.json';
  static const String _settingsNoDesktopPath = 'assets/data/mocks/settings_no_desktop.json';
  static const String _settingsNotificationsDeniedPath = 'assets/data/mocks/settings_notifications_denied.json';
  static const String _settingsReauthenticationRequiredPath = 'assets/data/mocks/settings_reauthentication_required.json';
  static const String _desktopConnectionSyncingPath = 'assets/data/mocks/desktop_connection_syncing.json';
  static const String _desktopConnectionOfflinePath = 'assets/data/mocks/desktop_connection_offline.json';
  static const String _desktopConnectionSourceNotFoundPath = 'assets/data/mocks/desktop_connection_source_not_found.json';
  static const String _desktopConnectionNoUsagePath = 'assets/data/mocks/desktop_connection_no_usage.json';
  static const String _desktopConnectionPermissionDeniedPath = 'assets/data/mocks/desktop_connection_permission_denied.json';
  static const String _desktopConnectionSessionRevokedPath = 'assets/data/mocks/desktop_connection_session_revoked.json';
  static const String _desktopConnectionIncompatibleVersionPath = 'assets/data/mocks/desktop_connection_incompatible_version.json';
  static const String _desktopConnectionSyncFailedPath = 'assets/data/mocks/desktop_connection_sync_failed.json';
  static const String _budgetNoBudgetPath = 'assets/data/mocks/budget_no_budget.json';
  static const String _budgetNearThresholdPath = 'assets/data/mocks/budget_near_threshold.json';
  static const String _budgetThresholdExceededPath = 'assets/data/mocks/budget_threshold_exceeded.json';
  static const String _budgetBudgetExceededPath = 'assets/data/mocks/budget_budget_exceeded.json';
  static const String _budgetCostUnavailablePath = 'assets/data/mocks/budget_cost_unavailable.json';
  static const String _budgetNotificationsOffPath = 'assets/data/mocks/budget_notifications_off.json';
  static const String _privacyExportPreparingPath = 'assets/data/mocks/privacy_export_preparing.json';
  static const String _privacyExportSuccessPath = 'assets/data/mocks/privacy_export_success.json';
  static const String _privacyExportFailedPath = 'assets/data/mocks/privacy_export_failed.json';
  static const String _privacyDeletingUsagePath = 'assets/data/mocks/privacy_deleting_usage.json';
  static const String _privacyDeleteSuccessPath = 'assets/data/mocks/privacy_delete_success.json';
  static const String _privacyDeletePartialPath = 'assets/data/mocks/privacy_delete_partial.json';
  static const String _privacyReauthenticationPath = 'assets/data/mocks/privacy_reauthentication.json';
  static const String _accountReauthenticationPath = 'assets/data/mocks/account_reauthentication.json';
  static const String _accountSigningOutPath = 'assets/data/mocks/account_signing_out.json';
  static const String _accountDeletingAccountPath = 'assets/data/mocks/account_deleting_account.json';
  static const String _accountDeleteFailedPath = 'assets/data/mocks/account_delete_failed.json';
  static const String _accountDeletePartialPath = 'assets/data/mocks/account_delete_partial.json';
  static const String _insightsAiNotSetUpPath = 'assets/data/mocks/insights_ai_not_set_up.json';
  static const String _aiSuggestionsInvalidApiKeyPath = 'assets/data/mocks/ai_suggestions_invalid_api_key.json';

  Future<SigningInStateData> _load(String path) async {
    final jsonString = await rootBundle.loadString(path);
    final map = jsonDecode(jsonString) as Map<String, dynamic>;
    return SigningInStateData.fromJson(map);
  }

  @override
  Future<SigningInStateData> getSigningInStateData() => _load(_signingInPath);

  @override
  Future<SigningInStateData> getCancelledStateData() => _load(_cancelledPath);

  @override
  Future<SigningInStateData> getFailedStateData() => _load(_failedPath);

  @override
  Future<SigningInStateData> getOfflineStateData() => _load(_offlinePath);

  @override
  Future<SigningInStateData> getSessionExpiredStateData() => _load(_sessionExpiredPath);

  @override
  Future<SigningInStateData> getVerifyingStateData() => _load(_verifyingPath);

  @override
  Future<SigningInStateData> getConnectedStateData() => _load(_connectedPath);

  @override
  Future<SigningInStateData> getStateData(AuthScreenState state) {
    switch (state) {
      case AuthScreenState.signingIn:
        return getSigningInStateData();
      case AuthScreenState.cancelled:
        return getCancelledStateData();
      case AuthScreenState.failed:
        return getFailedStateData();
      case AuthScreenState.offline:
        return getOfflineStateData();
      case AuthScreenState.sessionExpired:
        return getSessionExpiredStateData();
      case AuthScreenState.verifying:
        return getVerifyingStateData();
      case AuthScreenState.connected:
        return getConnectedStateData();
      case AuthScreenState.wrongCode:
        return _load(_wrongCodePath);
      case AuthScreenState.codeExpired:
        return _load(_codeExpiredPath);
      case AuthScreenState.codeAlreadyUsed:
        return _load(_codeAlreadyUsedPath);
      case AuthScreenState.desktopNoResponse:
        return _load(_desktopNoResponsePath);
      case AuthScreenState.existingDesktop:
        return _load(_existingDesktopPath);
      case AuthScreenState.networkError:
        return _load(_networkErrorPath);
      case AuthScreenState.unsupportedOs:
        return _load(_unsupportedOsPath);
      case AuthScreenState.appNotInstalled:
        return _load(_appNotInstalledPath);
      case AuthScreenState.appNotOpened:
        return _load(_appNotOpenedPath);
      case AuthScreenState.permissionDenied:
        return _load(_permissionDeniedPath);
      case AuthScreenState.initialLoading:
        return _load(_initialLoadingPath);
      case AuthScreenState.updatingWithData:
        return _load(_updatingWithDataPath);
      case AuthScreenState.partialData:
        return _load(_partialDataPath);
      case AuthScreenState.desktopOffline:
        return _load(_desktopOfflinePath);
      case AuthScreenState.staleData:
        return _load(_staleDataPath);
      case AuthScreenState.costUnavailable:
        return _load(_costUnavailablePath);
      case AuthScreenState.analyticsNoData:
        return _load(_analyticsNoDataPath);
      case AuthScreenState.analyticsNoFilterResults:
        return _load(_analyticsNoFilterResultsPath);
      case AuthScreenState.analyticsPartialData:
        return _load(_analyticsPartialDataPath);
      case AuthScreenState.analyticsUnsupportedMetric:
        return _load(_analyticsUnsupportedMetricPath);
      case AuthScreenState.analyticsCostUnavailable:
        return _load(_analyticsCostUnavailablePath);
      case AuthScreenState.analyticsQueryError:
        return _load(_analyticsQueryErrorPath);
      case AuthScreenState.analyticsOffline:
        return _load(_analyticsOfflinePath);
      case AuthScreenState.breakdownNoUsage:
        return _load(_breakdownNoUsagePath);
      case AuthScreenState.breakdownTodayIncomplete:
        return _load(_breakdownTodayIncompletePath);
      case AuthScreenState.breakdownMissingData:
        return _load(_breakdownMissingDataPath);
      case AuthScreenState.breakdownCostUnavailable:
        return _load(_breakdownCostUnavailablePath);
      case AuthScreenState.breakdownSyncDelayed:
        return _load(_breakdownSyncDelayedPath);
      case AuthScreenState.insightsAnalyzing:
        return _load(_insightsAnalyzingPath);
      case AuthScreenState.insightsInsufficientData:
        return _load(_insightsInsufficientDataPath);
      case AuthScreenState.insightsNoSignificantIssues:
        return _load(_insightsNoSignificantIssuesPath);
      case AuthScreenState.insightsAnalysisFailed:
        return _load(_insightsAnalysisFailedPath);
      case AuthScreenState.insightsStale:
        return _load(_insightsStalePath);
      case AuthScreenState.insightDetailStale:
        return _load(_insightDetailStalePath);
      case AuthScreenState.insightDetailResolved:
        return _load(_insightDetailResolvedPath);
      case AuthScreenState.insightDetailEvidenceUnavailable:
        return _load(_insightDetailEvidenceUnavailablePath);
      case AuthScreenState.insightDetailActive:
        return _load(_insightDetailActivePath);
      case AuthScreenState.settingsNoDesktop:
        return _load(_settingsNoDesktopPath);
      case AuthScreenState.settingsNotificationsDenied:
        return _load(_settingsNotificationsDeniedPath);
      case AuthScreenState.settingsReauthenticationRequired:
        return _load(_settingsReauthenticationRequiredPath);
      case AuthScreenState.desktopConnectionSyncing:
        return _load(_desktopConnectionSyncingPath);
      case AuthScreenState.desktopConnectionOffline:
        return _load(_desktopConnectionOfflinePath);
      case AuthScreenState.desktopConnectionSourceNotFound:
        return _load(_desktopConnectionSourceNotFoundPath);
      case AuthScreenState.desktopConnectionNoUsage:
        return _load(_desktopConnectionNoUsagePath);
      case AuthScreenState.desktopConnectionPermissionDenied:
        return _load(_desktopConnectionPermissionDeniedPath);
      case AuthScreenState.desktopConnectionSessionRevoked:
        return _load(_desktopConnectionSessionRevokedPath);
      case AuthScreenState.desktopConnectionIncompatibleVersion:
        return _load(_desktopConnectionIncompatibleVersionPath);
      case AuthScreenState.desktopConnectionSyncFailed:
        return _load(_desktopConnectionSyncFailedPath);
      case AuthScreenState.budgetNoBudget:
        return _load(_budgetNoBudgetPath);
      case AuthScreenState.budgetNearThreshold:
        return _load(_budgetNearThresholdPath);
      case AuthScreenState.budgetThresholdExceeded:
        return _load(_budgetThresholdExceededPath);
      case AuthScreenState.budgetBudgetExceeded:
        return _load(_budgetBudgetExceededPath);
      case AuthScreenState.budgetCostUnavailable:
        return _load(_budgetCostUnavailablePath);
      case AuthScreenState.budgetNotificationsOff:
        return _load(_budgetNotificationsOffPath);
      case AuthScreenState.privacyExportPreparing:
        return _load(_privacyExportPreparingPath);
      case AuthScreenState.privacyExportSuccess:
        return _load(_privacyExportSuccessPath);
      case AuthScreenState.privacyExportFailed:
        return _load(_privacyExportFailedPath);
      case AuthScreenState.privacyDeletingUsage:
        return _load(_privacyDeletingUsagePath);
      case AuthScreenState.privacyDeleteSuccess:
        return _load(_privacyDeleteSuccessPath);
      case AuthScreenState.privacyDeletePartial:
        return _load(_privacyDeletePartialPath);
      case AuthScreenState.privacyReauthentication:
        return _load(_privacyReauthenticationPath);
      case AuthScreenState.accountReauthentication:
        return _load(_accountReauthenticationPath);
      case AuthScreenState.accountSigningOut:
        return _load(_accountSigningOutPath);
      case AuthScreenState.accountDeletingAccount:
        return _load(_accountDeletingAccountPath);
      case AuthScreenState.accountDeleteFailed:
        return _load(_accountDeleteFailedPath);
      case AuthScreenState.accountDeletePartial:
        return _load(_accountDeletePartialPath);
      case AuthScreenState.insightsAiNotSetUp:
        return _load(_insightsAiNotSetUpPath);
      case AuthScreenState.aiSuggestionsInvalidApiKey:
        return _load(_aiSuggestionsInvalidApiKeyPath);
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return const AuthMockRepository();
});

/// Provider lưu trạng thái hiển thị hiện tại (mặc định là signingIn)
final currentAuthScreenStateProvider = StateProvider<AuthScreenState>((ref) {
  return AuthScreenState.signingIn;
});

/// Provider tự động cập nhật data tương ứng với state đang chọn
final authStateDataProvider = FutureProvider<SigningInStateData>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  final state = ref.watch(currentAuthScreenStateProvider);
  return repo.getStateData(state);
});

/// Giữ backward-compatible với provider cũ
final signingInStateDataProvider = FutureProvider<SigningInStateData>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  return repo.getSigningInStateData();
});
