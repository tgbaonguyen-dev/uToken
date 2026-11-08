enum AuthScreenState {
  signingIn,
  cancelled,
  failed,
  offline,
  sessionExpired,
  verifying,
  connected,
  wrongCode,
  codeExpired,
  codeAlreadyUsed,
  desktopNoResponse,
  existingDesktop,
  networkError,
  unsupportedOs,
  appNotInstalled,
  appNotOpened,
  permissionDenied,
  initialLoading,
  updatingWithData,
  partialData,
  desktopOffline,
  staleData,
  costUnavailable,
  analyticsNoData,
  analyticsNoFilterResults,
  analyticsPartialData,
  analyticsUnsupportedMetric,
  analyticsCostUnavailable,
  analyticsQueryError,
  analyticsOffline,
  breakdownNoUsage,
  breakdownTodayIncomplete,
  breakdownMissingData,
  breakdownCostUnavailable,
  breakdownSyncDelayed,
  insightsAnalyzing,
  insightsInsufficientData,
  insightsNoSignificantIssues,
  insightsAnalysisFailed,
  insightsStale,
  insightDetailStale,
  insightDetailResolved,
  insightDetailEvidenceUnavailable,
  insightDetailActive,
  settingsNoDesktop,
  settingsNotificationsDenied,
  settingsReauthenticationRequired,
  desktopConnectionSyncing,
  desktopConnectionOffline,
  desktopConnectionSourceNotFound,
  desktopConnectionNoUsage,
  desktopConnectionPermissionDenied,
  desktopConnectionSessionRevoked,
  desktopConnectionIncompatibleVersion,
  desktopConnectionSyncFailed,
  budgetNoBudget,
  budgetNearThreshold,
  budgetThresholdExceeded,
  budgetBudgetExceeded,
  budgetCostUnavailable,
  budgetNotificationsOff,
  privacyExportPreparing,
  privacyExportSuccess,
  privacyExportFailed,
  privacyDeletingUsage,
  privacyDeleteSuccess,
  privacyDeletePartial,
  privacyReauthentication,
  accountReauthentication,
  accountSigningOut,
  accountDeletingAccount,
  accountDeleteFailed,
  accountDeletePartial,
  insightsAiNotSetUp,
  aiSuggestionsInvalidApiKey,
}

class SigningInStateData {
  const SigningInStateData({
    required this.screenId,
    this.stateType = 'signing_in',
    this.figmaLayout,
    required this.screenTitle,
    this.hasBackButton = false,
    this.hasBottomNavigation = false,
    this.activeTab = 'Tokens',
    required this.badgeText,
    required this.specificationSubtitle,
    required this.card,
    required this.behavior,
    required this.action,
  });

  final String screenId;
  final String stateType;
  final Map<String, dynamic>? figmaLayout;
  final String screenTitle;
  final bool hasBackButton;
  final bool hasBottomNavigation;
  final String activeTab;
  final String badgeText;
  final String specificationSubtitle;
  final SigningInCardData card;
  final SigningInBehaviorData behavior;
  final SigningInActionData action;

  factory SigningInStateData.fromJson(Map<String, dynamic> json) {
    // Support both flattened and nested formats
    final cardJson = json['card'] as Map<String, dynamic>?;
    final behaviorJson = json['behavior'] as Map<String, dynamic>?;
    final actionJson = json['action'] as Map<String, dynamic>?;

    final card = cardJson != null
        ? SigningInCardData.fromJson(cardJson)
        : SigningInCardData(
            iconType: json['icon_type'] as String? ?? 'signing_in',
            title: json['card_title'] as String? ?? '',
            description: json['card_description'] as String? ?? '',
            items: ((json['bullet_points'] as List<dynamic>?) ?? [])
                .map((item) =>
                    SigningInItemData.fromJson(item as Map<String, dynamic>))
                .toList(),
          );

    final behavior = behaviorJson != null
        ? SigningInBehaviorData.fromJson(behaviorJson)
        : SigningInBehaviorData(
            label: json['behavior_label'] as String? ?? 'BEHAVIOR',
            description: json['behavior_text'] as String? ?? '',
          );

    final screenId = json['screen_id'] as String? ?? 'M01';
    final isPreAppFlow =
        screenId == 'M01' || screenId == 'M02' || screenId == 'M03';
    final defaultButtonBg = isPreAppFlow ? '#F4F4F5' : '#171717';
    final defaultTextColor = isPreAppFlow ? '#111214' : '#9C9FAB';

    final action = actionJson != null
        ? SigningInActionData(
            buttonLabel: (actionJson['button_label'] as String?) ??
                (actionJson['cancel_label'] as String?) ??
                (actionJson['action_text'] as String?) ??
                'Action',
            backgroundColor:
                (actionJson['background_color'] as String?) ?? defaultButtonBg,
            textColor:
                (actionJson['text_color'] as String?) ?? defaultTextColor,
          )
        : SigningInActionData(
            buttonLabel: (json['action_text'] as String?) ??
                (json['button_label'] as String?) ??
                'Action',
            backgroundColor:
                (json['background_color'] as String?) ?? defaultButtonBg,
            textColor: (json['text_color'] as String?) ?? defaultTextColor,
          );

    final defaultHasBottomNav = !isPreAppFlow;
    final hasBottomNavigation =
        json['has_bottom_navigation'] as bool? ?? defaultHasBottomNav;

    return SigningInStateData(
      screenId: screenId,
      figmaLayout: (json['figma_layout'] as Map?)?.cast<String, dynamic>(),
      stateType: json['state_type'] as String? ?? 'signing_in',
      screenTitle: json['screen_title'] as String? ?? 'Sign in',
      hasBackButton: json['has_back_button'] as bool? ?? false,
      hasBottomNavigation: hasBottomNavigation,
      activeTab: json['active_tab'] as String? ?? 'Tokens',
      badgeText: (json['state_label'] as String?) ??
          (json['badge_text'] as String?) ??
          'SIGNING IN',
      specificationSubtitle: (json['state_context'] as String?) ??
          (json['specification_subtitle'] as String?) ??
          'State specification',
      card: card,
      behavior: behavior,
      action: action,
    );
  }
}

class SigningInCardData {
  const SigningInCardData({
    this.iconType = 'signing_in',
    required this.title,
    required this.description,
    required this.items,
  });

  final String iconType;
  final String title;
  final String description;
  final List<SigningInItemData> items;

  factory SigningInCardData.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List<dynamic>? ?? [];
    return SigningInCardData(
      iconType: json['icon_type'] as String? ?? 'signing_in',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      items: list
          .map(
            (item) => SigningInItemData.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class SigningInItemData {
  const SigningInItemData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.bulletColor,
  });

  final String id;
  final String title;
  final String subtitle;
  final String bulletColor;

  factory SigningInItemData.fromJson(Map<String, dynamic> json) {
    return SigningInItemData(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      bulletColor: json['bullet_color'] as String? ?? '#6366F1',
    );
  }
}

class SigningInBehaviorData {
  const SigningInBehaviorData({
    required this.label,
    required this.description,
  });

  final String label;
  final String description;

  factory SigningInBehaviorData.fromJson(Map<String, dynamic> json) {
    return SigningInBehaviorData(
      label: json['label'] as String? ?? 'BEHAVIOR',
      description: json['description'] as String? ?? '',
    );
  }
}

class SigningInActionData {
  const SigningInActionData({
    required this.buttonLabel,
    this.backgroundColor = '#171717',
    this.textColor = '#9C9FAB',
  });

  final String buttonLabel;
  final String? backgroundColor;
  final String? textColor;
  String get cancelLabel => buttonLabel;

  factory SigningInActionData.fromJson(Map<String, dynamic> json) {
    return SigningInActionData(
      buttonLabel: (json['button_label'] as String?) ??
          (json['cancel_label'] as String?) ??
          (json['action_text'] as String?) ??
          'Action',
      backgroundColor: (json['background_color'] as String?) ?? '#171717',
      textColor: (json['text_color'] as String?) ?? '#9C9FAB',
    );
  }
}
