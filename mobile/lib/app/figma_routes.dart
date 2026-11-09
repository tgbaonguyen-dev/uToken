/// Routes for the 24 exported M/O/S Figma frames.
const Map<String, String> figmaRoutes = {
  'M01': '/welcome',
  'M02': '/connect-desktop',
  'M03': '/install-guide',
  'M04': '/tokens',
  'M04B': '/usage-details',
  'M05': '/analytics',
  'M05B': '/efficiency',
  'M05C': '/model-comparison',
  'M06': '/daily-usage',
  'M07': '/insights',
  'M09': '/settings',
  'M10': '/desktop-connection',
  'M11': '/budget',
  'M12': '/privacy',
  'M13': '/account',
  'O01': '/confirmations',
  'O02': '/budget-alert',
  'M14': '/model-pricing',
  'O03': '/cost-breakdown',
  'M15': '/ai-suggestions',
  'S01': '/desktop-not-connected',
  'S02': '/waiting-first-usage',
  'S03': '/syncing-usage',
  'S04': '/sync-failed',
};

// Hand-built screens contributed by the other UI branch.
const supplementalUiRoutes = {
  'M08 - Insight detail': '/insight-detail',
  'UI state preview': '/state-preview',
};

String? figmaPathFor(String screenId) =>
    screenId == 'M08' ? '/insight-detail' : figmaRoutes[screenId];
