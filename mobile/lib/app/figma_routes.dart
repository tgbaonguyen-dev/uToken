/// Route names correspond exactly to the 20 primary M/O frames in Figma.
/// S01–S04 are intentionally excluded: they are separate state designs.
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
};

String? figmaPathFor(String screenId) => figmaRoutes[screenId];
