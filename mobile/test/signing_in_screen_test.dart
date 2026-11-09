import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utoken_mobile/features/auth/data/auth_mock_repository.dart';
import 'package:utoken_mobile/features/auth/domain/signing_in_state_model.dart';
import 'package:utoken_mobile/features/auth/presentation/signing_in_screen.dart';

void main() {
  const signingInJson = '''
{
  "screen_id": "M01",
  "screen_title": "Sign in",
  "badge_text": "SIGNING IN",
  "specification_subtitle": "State specification · Signing in",
  "card": {
    "icon_type": "signing_in",
    "title": "Signing you in",
    "description": "We're verifying your Google account and restoring your μToken session.",
    "items": [
      {
        "id": "secure_auth",
        "title": "Secure authentication",
        "subtitle": "Handled by Google and Firebase Auth",
        "bullet_color": "#6678E8"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Keep this screen focused until authentication finishes."
  },
  "action": {
    "button_label": "Cancel"
  }
}
''';

  const cancelledJson = '''
{
  "screen_id": "M01",
  "screen_title": "Sign in",
  "badge_text": "CANCELLED",
  "specification_subtitle": "State specification · Cancelled",
  "card": {
    "icon_type": "cancelled",
    "title": "Sign-in was cancelled",
    "description": "No account changes were made. You can restart whenever you're ready.",
    "items": [
      {
        "id": "nothing_connected",
        "title": "Nothing was connected",
        "subtitle": "Desktop and cloud data remain unchanged",
        "bullet_color": "#7B7F88"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Do not show this as a destructive error."
  },
  "action": {
    "button_label": "Try again"
  }
}
''';

  const failedJson = '''
{
  "screen_id": "M01",
  "screen_title": "Sign in",
  "badge_text": "FAILED",
  "specification_subtitle": "State specification · Failed",
  "card": {
    "icon_type": "failed",
    "title": "Couldn’t sign you in",
    "description": "Google authentication did not finish successfully.",
    "items": [
      {
        "id": "account_not_connected",
        "title": "Account not connected",
        "subtitle": "No usage data was loaded",
        "bullet_color": "#E0525B"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Keep the error actionable and preserve privacy."
  },
  "action": {
    "button_label": "Retry sign-in"
  }
}
''';

  const offlineJson = '''
{
  "screen_id": "M01",
  "state_type": "offline",
  "screen_title": "Sign in",
  "badge_text": "OFFLINE",
  "specification_subtitle": "State specification · Offline",
  "card": {
    "icon_type": "offline",
    "title": "You’re offline",
    "description": "μToken needs a network connection to verify your account.",
    "items": [
      {
        "id": "auth_paused",
        "title": "Authentication paused",
        "subtitle": "No credentials are stored while offline",
        "bullet_color": "#C27A20"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Never replace network failure with a generic auth error."
  },
  "action": {
    "button_label": "Try again"
  }
}
''';

  const sessionExpiredJson = '''
{
  "screen_id": "M01",
  "state_type": "session_expired",
  "screen_title": "Sign in",
  "has_back_button": false,
  "badge_text": "SESSION EXPIRED",
  "specification_subtitle": "State specification · Session expired",
  "card": {
    "icon_type": "offline",
    "title": "Sign in again",
    "description": "Your session expired before μToken could load your account.",
    "items": [
      {
        "id": "reauth_required",
        "title": "Re-authentication required",
        "subtitle": "Google confirms that it is still you",
        "bullet_color": "#C27A20"
      },
      {
        "id": "usage_in_cloud",
        "title": "Usage remains in cloud",
        "subtitle": "Nothing is deleted when a session expires",
        "bullet_color": "#C27A20"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Return the user to their previous destination after sign-in."
  },
  "action": {
    "button_label": "Continue with Google"
  }
}
''';

  const verifyingJson = '''
{
  "screen_id": "M02",
  "state_type": "verifying",
  "screen_title": "Connect desktop",
  "has_back_button": true,
  "badge_text": "VERIFYING",
  "specification_subtitle": "State specification · Verifying",
  "card": {
    "icon_type": "signing_in",
    "title": "Verifying this desktop",
    "description": "Checking the one-time code and desktop identity.",
    "items": [
      {
        "id": "pairing_code_received",
        "title": "Pairing code received",
        "subtitle": "Codes expire after 10 minutes",
        "bullet_color": "#6678E8"
      },
      {
        "id": "waiting_desktop",
        "title": "Waiting for desktop",
        "subtitle": "Keep the companion app open",
        "bullet_color": "#6678E8"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Disable duplicate code submits while verification is running."
  },
  "action": {
    "button_label": "Cancel pairing"
  }
}
''';

  const connectedJson = '''
{
  "screen_id": "M02",
  "state_type": "connected",
  "screen_title": "Connect desktop",
  "has_back_button": true,
  "badge_text": "CONNECTED",
  "specification_subtitle": "State specification · Connected",
  "card": {
    "icon_type": "connected",
    "title": "Desktop connected",
    "description": "The desktop companion can now send aggregate usage metadata.",
    "items": [
      {
        "id": "collector_authorized",
        "title": "Collector authorized",
        "subtitle": "Prompt and response content remain local",
        "bullet_color": "#22A575"
      },
      {
        "id": "initial_sync_pending",
        "title": "Initial sync pending",
        "subtitle": "Usage appears after the first claim",
        "bullet_color": "#22A575"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Move into the empty-data state before showing zero values."
  },
  "action": {
    "button_label": "Continue"
  }
}
''';

  const wrongCodeJson = '''
{
  "screen_id": "M02",
  "state_type": "wrong_code",
  "screen_title": "Connect desktop",
  "has_back_button": true,
  "badge_text": "INVALID CODE",
  "specification_subtitle": "State specification · Invalid code",
  "card": {
    "icon_type": "failed",
    "title": "That code isn’t valid",
    "description": "Check every character and enter the latest code shown on desktop.",
    "items": [
      {
        "id": "code_rejected",
        "title": "Code rejected",
        "subtitle": "It may have been typed incorrectly",
        "bullet_color": "#E0525B"
      },
      {
        "id": "attempts_safe",
        "title": "Attempts are safe",
        "subtitle": "Generate a new code if needed",
        "bullet_color": "#E0525B"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Keep the input and point to the exact field."
  },
  "action": {
    "button_label": "Enter another code"
  }
}
''';

  const codeExpiredJson = '''
{
  "screen_id": "M02",
  "state_type": "code_expired",
  "screen_title": "Connect desktop",
  "has_back_button": true,
  "badge_text": "EXPIRED",
  "specification_subtitle": "State specification · Expired",
  "card": {
    "icon_type": "offline",
    "title": "Pairing code expired",
    "description": "One-time codes are valid for 10 minutes.",
    "items": [
      {
        "id": "old_code_disabled",
        "title": "Old code disabled",
        "subtitle": "It can no longer be reused",
        "bullet_color": "#C27A20"
      },
      {
        "id": "new_code_required",
        "title": "New code required",
        "subtitle": "Generate it from the desktop companion",
        "bullet_color": "#C27A20"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Show expiry before the user submits again."
  },
  "action": {
    "button_label": "Generate new code"
  }
}
''';

  const codeAlreadyUsedJson = '''
{
  "screen_id": "M02",
  "state_type": "code_already_used",
  "screen_title": "Connect desktop",
  "has_back_button": true,
  "badge_text": "CODE USED",
  "specification_subtitle": "State specification · Code used",
  "card": {
    "icon_type": "offline",
    "title": "This code was already used",
    "description": "A pairing code can connect only one authenticated session.",
    "items": [
      {
        "id": "code_no_longer_active",
        "title": "Code is no longer active",
        "subtitle": "This prevents accidental desktop linking",
        "bullet_color": "#C27A20"
      },
      {
        "id": "create_another_code",
        "title": "Create another code",
        "subtitle": "Use the desktop companion to restart pairing",
        "bullet_color": "#C27A20"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Do not imply that a desktop was connected to this account."
  },
  "action": {
    "button_label": "Use a new code"
  }
}
''';

  const desktopNoResponseJson = '''
{
  "screen_id": "M02",
  "state_type": "desktop_no_response",
  "screen_title": "Connect desktop",
  "has_back_button": true,
  "badge_text": "NO RESPONSE",
  "specification_subtitle": "State specification · No response",
  "card": {
    "icon_type": "offline",
    "title": "Desktop didn’t respond",
    "description": "The companion may be closed, asleep or blocked by the network.",
    "items": [
      {
        "id": "mobile_request_received",
        "title": "Mobile request received",
        "subtitle": "Desktop confirmation is still missing",
        "bullet_color": "#C27A20"
      },
      {
        "id": "local_data_unchanged",
        "title": "Local data remains unchanged",
        "subtitle": "Open the companion and retry",
        "bullet_color": "#C27A20"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Allow retry without generating a new code immediately."
  },
  "action": {
    "button_label": "Retry pairing"
  }
}
''';

  const existingDesktopJson = '''
{
  "screen_id": "M02",
  "state_type": "existing_desktop",
  "screen_title": "Connect desktop",
  "has_back_button": true,
  "badge_text": "REPLACE DEVICE",
  "specification_subtitle": "State specification · Replace device",
  "card": {
    "icon_type": "offline",
    "title": "Another desktop is connected",
    "description": "μToken supports one active desktop companion in the MVP.",
    "items": [
      {
        "id": "current_device",
        "title": "Current device",
        "subtitle": "Corneliya's Mac · last seen 2 m ago",
        "bullet_color": "#C27A20"
      },
      {
        "id": "replacing_revokes_old",
        "title": "Replacing revokes the old session",
        "subtitle": "Historic usage will be kept",
        "bullet_color": "#C27A20"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Require explicit confirmation before replacement."
  },
  "action": {
    "button_label": "Review connection"
  }
}
''';

  const networkErrorJson = '''
{
  "screen_id": "M02",
  "state_type": "network_error",
  "screen_title": "Connect desktop",
  "has_back_button": true,
  "badge_text": "NETWORK ERROR",
  "specification_subtitle": "State specification · Network error",
  "card": {
    "icon_type": "failed",
    "title": "Pairing couldn’t finish",
    "description": "The account is valid, but the pairing service could not be reached.",
    "items": [
      {
        "id": "no_partial_connection",
        "title": "No partial connection",
        "subtitle": "The desktop token was not issued",
        "bullet_color": "#E0525B"
      },
      {
        "id": "safe_to_retry",
        "title": "Safe to retry",
        "subtitle": "Use the same code while it remains valid",
        "bullet_color": "#E0525B"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Differentiate network errors from invalid pairing codes."
  },
  "action": {
    "button_label": "Retry"
  }
}
''';

  const unsupportedOsJson = '''
{
  "screen_id": "M03",
  "state_type": "unsupported_os",
  "screen_title": "Install guide",
  "has_back_button": true,
  "badge_text": "UNSUPPORTED OS",
  "specification_subtitle": "State specification · Unsupported",
  "card": {
    "icon_type": "failed",
    "title": "This system isn’t supported",
    "description": "The desktop companion cannot run on this operating system version.",
    "items": [
      {
        "id": "installation_blocked",
        "title": "Installation blocked",
        "subtitle": "No collector can be started here",
        "bullet_color": "#E0525B"
      },
      {
        "id": "check_supported_systems",
        "title": "Check supported systems",
        "subtitle": "Use a compatible desktop to continue",
        "bullet_color": "#E0525B"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "State the minimum supported OS clearly."
  },
  "action": {
    "button_label": "View requirements"
  }
}
''';

  const appNotInstalledJson = '''
{
  "screen_id": "M03",
  "state_type": "app_not_installed",
  "screen_title": "Install guide",
  "has_back_button": true,
  "badge_text": "NOT INSTALLED",
  "specification_subtitle": "State specification · Not installed",
  "card": {
    "icon_type": "cancelled",
    "title": "Desktop app not detected",
    "description": "Install the companion before trying to pair this device.",
    "items": [
      {
        "id": "no_local_collector",
        "title": "No local collector found",
        "subtitle": "Antigravity usage cannot be read yet",
        "bullet_color": "#7B7F88"
      },
      {
        "id": "official_download",
        "title": "Official download only",
        "subtitle": "Do not require admin passwords or API keys",
        "bullet_color": "#7B7F88"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Keep the official source prominent."
  },
  "action": {
    "button_label": "Download desktop app"
  }
}
''';

  const appNotOpenedJson = '''
{
  "screen_id": "M03",
  "state_type": "app_not_opened",
  "screen_title": "Install guide",
  "has_back_button": true,
  "badge_text": "NOT RUNNING",
  "specification_subtitle": "State specification · Not running",
  "card": {
    "icon_type": "offline",
    "title": "Open the desktop companion",
    "description": "The app is installed but has not started a pairing session.",
    "items": [
      {
        "id": "installation_detected",
        "title": "Installation detected",
        "subtitle": "No active companion process found",
        "bullet_color": "#C27A20"
      },
      {
        "id": "pairing_appear_after_launch",
        "title": "Pairing will appear after launch",
        "subtitle": "Keep the companion in the background",
        "bullet_color": "#C27A20"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Recheck desktop presence after the CTA."
  },
  "action": {
    "button_label": "I opened it"
  }
}
''';

  const permissionDeniedJson = '''
{
  "screen_id": "M03",
  "state_type": "permission_denied",
  "screen_title": "Install guide",
  "has_back_button": true,
  "badge_text": "PERMISSION DENIED",
  "specification_subtitle": "State specification · Permission denied",
  "card": {
    "icon_type": "failed",
    "title": "Local usage access is blocked",
    "description": "The companion needs permission to read Antigravity usage metadata.",
    "items": [
      {
        "id": "no_prompt_content",
        "title": "No prompt content requested",
        "subtitle": "Only token usage metadata is processed",
        "bullet_color": "#E0525B"
      },
      {
        "id": "permission_can_change",
        "title": "Permission can be changed",
        "subtitle": "Open system settings and allow access",
        "bullet_color": "#E0525B"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Explain the exact permission and why it is needed."
  },
  "action": {
    "button_label": "Open permission guide"
  }
}
''';

  const initialLoadingJson = '''
{
  "screen_id": "M04",
  "state_type": "initial_loading",
  "screen_title": "Tokens",
  "has_back_button": false,
  "badge_text": "LOADING",
  "specification_subtitle": "State specification · Loading",
  "card": {
    "icon_type": "signing_in",
    "title": "Loading your usage",
    "description": "Fetching the latest daily summaries and pricing metadata.",
    "items": [
      {
        "id": "account_verified",
        "title": "Account verified",
        "subtitle": "Usage is being prepared",
        "bullet_color": "#6678E8"
      },
      {
        "id": "no_zero_values",
        "title": "No zero values shown",
        "subtitle": "Unknown metrics remain unavailable",
        "bullet_color": "#6678E8"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Use skeletons only for metrics that are actually loading."
  },
  "action": {
    "button_label": "Back to overview"
  },
  "has_bottom_navigation": true
}
''';

  const updatingWithDataJson = '''
{
  "screen_id": "M04",
  "state_type": "updating_with_data",
  "screen_title": "Tokens",
  "has_back_button": false,
  "badge_text": "REFRESHING",
  "specification_subtitle": "State specification · Refreshing",
  "card": {
    "icon_type": "signing_in",
    "title": "Updating latest usage",
    "description": "The current dashboard remains visible while new desktop data is processed.",
    "items": [
      {
        "id": "existing_totals_readable",
        "title": "Existing totals stay readable",
        "subtitle": "Never replace valid data with a blank screen",
        "bullet_color": "#6678E8"
      },
      {
        "id": "last_sync_visible",
        "title": "Last sync remains visible",
        "subtitle": "Fresh values replace it when complete",
        "bullet_color": "#6678E8"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Show progress without blocking exploration."
  },
  "action": {
    "button_label": "View current data"
  },
  "has_bottom_navigation": true
}
''';

  const partialDataJson = '''
{
  "screen_id": "M04",
  "state_type": "partial_data",
  "screen_title": "Tokens",
  "has_back_button": false,
  "badge_text": "PARTIAL DATA",
  "specification_subtitle": "State specification · Partial data",
  "card": {
    "icon_type": "offline",
    "title": "Some metrics are missing",
    "description": "Token totals are available, but one or more sources did not provide complete metadata.",
    "items": [
      {
        "id": "available_metrics_visible",
        "title": "Available metrics remain visible",
        "subtitle": "Missing values are labelled, not shown as zero",
        "bullet_color": "#C27A20"
      },
      {
        "id": "analysis_limited",
        "title": "Analysis is limited",
        "subtitle": "Insights explain which evidence is incomplete",
        "bullet_color": "#C27A20"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Name the affected provider, project or time range."
  },
  "action": {
    "button_label": "View available data",
    "background_color": "#171717",
    "text_color": "#9C9FA8"
  },
  "has_bottom_navigation": true
}
''';

  const desktopOfflineJson = '''
{
  "screen_id": "M04",
  "state_type": "desktop_offline",
  "screen_title": "Tokens",
  "has_back_button": false,
  "badge_text": "OFFLINE",
  "specification_subtitle": "State specification · Offline",
  "card": {
    "icon_type": "offline",
    "title": "Desktop is offline",
    "description": "Showing the last successfully synced usage while the companion is unavailable.",
    "items": [
      {
        "id": "last_sync",
        "title": "Last sync · Today, 10:42",
        "subtitle": "Historical details still available",
        "bullet_color": "#C27A20"
      },
      {
        "id": "new_activity_pending",
        "title": "New activity is pending",
        "subtitle": "Open the desktop companion to continue",
        "bullet_color": "#C27A20"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Preserve cached data and mark its freshness."
  },
  "action": {
    "button_label": "View connection",
    "background_color": "#171717",
    "text_color": "#9C9FA8"
  },
  "has_bottom_navigation": true,
  "active_tab": "Tokens"
}
''';

  const staleDataJson = '''
{
  "screen_id": "M04",
  "state_type": "stale_data",
  "screen_title": "Tokens",
  "has_back_button": false,
  "badge_text": "DATA IS STALE",
  "specification_subtitle": "State specification · Data is stale",
  "card": {
    "icon_type": "offline",
    "title": "Usage hasn’t updated recently",
    "description": "The dashboard is more than 24 hours behind the desktop activity.",
    "items": [
      {
        "id": "last_sync",
        "title": "Last successful sync · 26h ago",
        "subtitle": "Displayed totals may be incomplete",
        "bullet_color": "#C27A20"
      },
      {
        "id": "manual_sync",
        "title": "Manual sync recommended",
        "subtitle": "Desktop must be online",
        "bullet_color": "#C27A20"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Keep stale data visible with an explicit timestamp."
  },
  "action": {
    "button_label": "Sync now",
    "background_color": "#171717",
    "text_color": "#9C9FA8"
  },
  "has_bottom_navigation": true,
  "active_tab": "Tokens"
}
''';

  const costUnavailableJson = r'''
{
  "screen_id": "M04",
  "state_type": "cost_unavailable",
  "screen_title": "Tokens",
  "has_back_button": false,
  "badge_text": "COST UNAVAILABLE",
  "specification_subtitle": "State specification · Cost unavailable",
  "card": {
    "icon_type": "empty",
    "title": "Cost can’t be estimated",
    "description": "Token usage is available, but pricing is missing for one or more models.",
    "items": [
      {
        "id": "token_totals_unaffected",
        "title": "Token totals are unaffected",
        "subtitle": "Usage counts remain accurate",
        "bullet_color": "#7B7F88"
      },
      {
        "id": "pricing_catalog_missing",
        "title": "Pricing catalog missing",
        "subtitle": "Never substitute $0.00",
        "bullet_color": "#7B7F88"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Separate token accuracy from cost availability."
  },
  "action": {
    "button_label": "View model pricing",
    "background_color": "#171717",
    "text_color": "#9C9FA8"
  },
  "has_bottom_navigation": true,
  "active_tab": "Tokens"
}
''';

  const analyticsNoDataJson = '''
{
  "screen_id": "M05",
  "state_type": "no_data",
  "screen_title": "Analytics",
  "has_back_button": false,
  "badge_text": "NO DATA",
  "specification_subtitle": "State specification · No data",
  "card": {
    "icon_type": "empty",
    "title": "No usage to analyze",
    "description": "There are no records in the selected time range.",
    "items": [
      {
        "id": "current_range_empty",
        "title": "Current range is empty",
        "subtitle": "Try a wider date range",
        "bullet_color": "#7B7F88"
      },
      {
        "id": "filters_not_cause",
        "title": "Filters are not the cause",
        "subtitle": "Desktop connection was still active",
        "bullet_color": "#7B7F88"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Do not render an empty chart with zero labels."
  },
  "action": {
    "button_label": "Change date range",
    "background_color": "#171717",
    "text_color": "#9C9FA8"
  },
  "has_bottom_navigation": true,
  "active_tab": "Analytics"
}
''';

  const analyticsNoFilterResultsJson = '''
{
  "screen_id": "M05",
  "state_type": "no_filter_results",
  "screen_title": "Analytics",
  "has_back_button": false,
  "badge_text": "NO RESULTS",
  "specification_subtitle": "State specification · No results",
  "card": {
    "icon_type": "empty",
    "title": "No results match these filters",
    "description": "Usage exists, but not for this source, model or project combination.",
    "items": [
      {
        "id": "filters_active",
        "title": "Filters are active",
        "subtitle": "Original data is unchanged",
        "bullet_color": "#7B7F88"
      },
      {
        "id": "clear_filters_recover",
        "title": "Clear filters to recover",
        "subtitle": "Keep the selected time range",
        "bullet_color": "#7B7F88"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Differentiate filter-empty from no usage."
  },
  "action": {
    "button_label": "Clear filters",
    "background_color": "#171717",
    "text_color": "#9C9FA8"
  },
  "has_bottom_navigation": true,
  "active_tab": "Analytics"
}
''';

  const analyticsPartialDataJson = '''
{
  "screen_id": "M05",
  "state_type": "partial_data",
  "screen_title": "Analytics",
  "has_back_button": false,
  "badge_text": "PARTIAL DATA",
  "specification_subtitle": "State specification · Partial data",
  "card": {
    "icon_type": "offline",
    "title": "Analysis is incomplete",
    "description": "Some days or sources are missing one or more metrics.",
    "items": [
      {
        "id": "trend_uses_available",
        "title": "Trend uses available records",
        "subtitle": "Gaps remain visible in the chart",
        "bullet_color": "#C27A20"
      },
      {
        "id": "comparison_confidence_reduced",
        "title": "Comparison confidence reduced",
        "subtitle": "Contribution ranking may change after sync",
        "bullet_color": "#C27A20"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Never interpolate missing provider data silently."
  },
  "action": {
    "button_label": "View available analysis",
    "background_color": "#171717",
    "text_color": "#9C9FA8"
  },
  "has_bottom_navigation": true,
  "active_tab": "Analytics"
}
''';

  const analyticsUnsupportedMetricJson = '''
{
  "screen_id": "M05",
  "state_type": "unsupported_metric",
  "screen_title": "Analytics",
  "has_back_button": false,
  "badge_text": "UNSUPPORTED",
  "specification_subtitle": "State specification · Unsupported",
  "card": {
    "icon_type": "empty",
    "title": "This metric isn’t supported",
    "description": "The selected source does not provide latency, error or cache information.",
    "items": [
      {
        "id": "source_limitation",
        "title": "Source limitation",
        "subtitle": "Not a value of zero",
        "bullet_color": "#7B7F88"
      },
      {
        "id": "other_metrics_still_work",
        "title": "Other metrics still work",
        "subtitle": "Switch to tokens, requests or cost",
        "bullet_color": "#7B7F88"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Explain unsupported source capability."
  },
  "action": {
    "button_label": "Choose another metric",
    "background_color": "#171717",
    "text_color": "#9C9FA8"
  },
  "has_bottom_navigation": true,
  "active_tab": "Analytics"
}
''';

  const analyticsCostUnavailableJson = '''
{
  "screen_id": "M05",
  "state_type": "cost_unavailable",
  "screen_title": "Analytics",
  "has_back_button": false,
  "badge_text": "COST UNAVAILABLE",
  "specification_subtitle": "State specification · Cost unavailable",
  "card": {
    "icon_type": "empty",
    "title": "Cost analysis is unavailable",
    "description": "Pricing could not be resolved for the current model selection.",
    "items": [
      {
        "id": "token_analysis_remains_available",
        "title": "Token analysis remains available",
        "subtitle": "No records are discarded",
        "bullet_color": "#7B7F88"
      },
      {
        "id": "missing_pricing_version",
        "title": "Missing pricing version",
        "subtitle": "Historical costs are never recalculated silently",
        "bullet_color": "#7B7F88"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Keep the active filters when switching metrics."
  },
  "action": {
    "button_label": "View token analytics",
    "background_color": "#171717",
    "text_color": "#9C9FA8"
  },
  "has_bottom_navigation": true,
  "active_tab": "Analytics"
}
''';

  const analyticsQueryErrorJson = '''
{
  "screen_id": "M05",
  "state_type": "query_error",
  "screen_title": "Analytics",
  "has_back_button": false,
  "badge_text": "QUERY FAILED",
  "specification_subtitle": "State specification · Query failed",
  "card": {
    "icon_type": "failed",
    "title": "Couldn’t load this analysis",
    "description": "The analytics query failed before results were returned.",
    "items": [
      {
        "id": "no_partial_chart_shown",
        "title": "No partial chart shown",
        "subtitle": "No previous valid model data is preserved",
        "bullet_color": "#E0525B"
      },
      {
        "id": "safe_to_retry",
        "title": "Safe to retry",
        "subtitle": "Filters and date range remain selected",
        "bullet_color": "#E0525B"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Expose a clear retry action."
  },
  "action": {
    "button_label": "Retry analysis",
    "background_color": "#171717",
    "text_color": "#9C9FA8"
  },
  "has_bottom_navigation": true,
  "active_tab": "Analytics"
}
''';

  const analyticsOfflineJson = '''
{
  "screen_id": "M05",
  "state_type": "offline",
  "screen_title": "Analytics",
  "has_back_button": false,
  "badge_text": "OFFLINE",
  "specification_subtitle": "State specification · Offline",
  "card": {
    "icon_type": "offline",
    "title": "Analytics needs a connection",
    "description": "This filtered view is not available from the local cache.",
    "items": [
      {
        "id": "dashboard_may_still_work",
        "title": "Dashboard may still work",
        "subtitle": "Previously loaded summaries remain available",
        "bullet_color": "#C27A20"
      },
      {
        "id": "query_is_paused",
        "title": "Query is paused",
        "subtitle": "Reconnect to load this breakdown",
        "bullet_color": "#C27A20"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Distinguish cached overview from uncached analytics."
  },
  "action": {
    "button_label": "Try again",
    "background_color": "#171717",
    "text_color": "#9C9FA8"
  },
  "has_bottom_navigation": true,
  "active_tab": "Analytics"
}
''';

  const breakdownNoUsageJson = '''
{
  "screen_id": "M06",
  "state_type": "no_usage",
  "screen_title": "Daily breakdown",
  "has_back_button": true,
  "badge_text": "NO USAGE",
  "specification_subtitle": "State specification · No usage",
  "card": {
    "icon_type": "empty",
    "title": "No activity on this day",
    "description": "No supported AI usage was recorded for the selected date.",
    "items": [
      {
        "id": "daily_total_unknown",
        "title": "Daily total is unknown",
        "subtitle": "Do not display zero unless confirmed",
        "bullet_color": "#7B7F88"
      },
      {
        "id": "choose_another_day",
        "title": "Choose another day",
        "subtitle": "Nearby days may contain activity",
        "bullet_color": "#7B7F88"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Keep date navigation available."
  },
  "action": {
    "button_label": "Choose another day",
    "background_color": "#171717",
    "text_color": "#9C9FA8"
  },
  "has_bottom_navigation": true,
  "active_tab": "Analytics"
}
''';

  const breakdownTodayIncompleteJson = '''
{
  "screen_id": "M06",
  "state_type": "today_incomplete",
  "screen_title": "Daily breakdown",
  "has_back_button": true,
  "badge_text": "IN PROGRESS",
  "specification_subtitle": "State specification · In progress",
  "card": {
    "icon_type": "signing_in",
    "title": "Today is still in progress",
    "description": "New usage can continue to arrive until the local day ends.",
    "items": [
      {
        "id": "totals_provisional",
        "title": "Totals are provisional",
        "subtitle": "Time stamps follow the device timezone",
        "bullet_color": "#6678E8"
      },
      {
        "id": "sync_may_update",
        "title": "Sync may update the chart",
        "subtitle": "New bars appear after day close",
        "bullet_color": "#6678E8"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Mark incomplete periods without hiding current data."
  },
  "action": {
    "button_label": "View current totals",
    "background_color": "#171717",
    "text_color": "#9C9FA8"
  },
  "has_bottom_navigation": true,
  "active_tab": "Analytics"
}
''';

  const breakdownMissingDataJson = '''
{
  "screen_id": "M06",
  "state_type": "missing_data",
  "screen_title": "Daily breakdown",
  "has_back_button": true,
  "badge_text": "PARTIAL DATA",
  "specification_subtitle": "State specification · Partial data",
  "card": {
    "icon_type": "offline",
    "title": "Part of this day is missing",
    "description": "One source or time window did not sync completely.",
    "items": [
      {
        "id": "available_activity_shown",
        "title": "Available activity is shown",
        "subtitle": "Missing intervals stay explicit",
        "bullet_color": "#C27A20"
      },
      {
        "id": "contributor_totals_may_differ",
        "title": "Contributor totals may differ",
        "subtitle": "Retry when desktop is online",
        "bullet_color": "#C27A20"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Show the affected interval and source."
  },
  "action": {
    "button_label": "View available data",
    "background_color": "#171717",
    "text_color": "#9C9FA8"
  },
  "has_bottom_navigation": true,
  "active_tab": "Analytics"
}
''';

  const breakdownCostUnavailableJson = r'''
{
  "screen_id": "M06",
  "state_type": "cost_unavailable",
  "screen_title": "Daily breakdown",
  "has_back_button": true,
  "badge_text": "COST UNAVAILABLE",
  "specification_subtitle": "State specification · Cost unavailable",
  "card": {
    "icon_type": "empty",
    "title": "Daily cost can’t be calculated",
    "description": "Token and request data are present, but model pricing is unavailable.",
    "items": [
      {
        "id": "daily_token_valid",
        "title": "Daily token total is valid",
        "subtitle": "Only the cost field is unavailable",
        "bullet_color": "#7B7F88"
      },
      {
        "id": "pricing_review_available",
        "title": "Pricing review available",
        "subtitle": "No $0.00 placeholder is used",
        "bullet_color": "#7B7F88"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Keep token evidence visible."
  },
  "action": {
    "button_label": "View model pricing",
    "background_color": "#171717",
    "text_color": "#9C9FA8"
  },
  "has_bottom_navigation": true,
  "active_tab": "Analytics"
}
''';

  const insightsAnalyzingJson = '''
{
  "screen_id": "M07",
  "state_type": "analyzing",
  "screen_title": "Insights",
  "has_back_button": false,
  "badge_text": "ANALYZING",
  "specification_subtitle": "State specification · Analyzing",
  "card": {
    "icon_type": "signing_in",
    "title": "Analyzing recent usage",
    "description": "The optimizer is reviewing aggregate token, cost, latency and error patterns.",
    "items": [
      {
        "id": "privacy_safe_evidence",
        "title": "Privacy-safe evidence",
        "subtitle": "No prompts, responses or source code",
        "bullet_color": "#6678E8"
      },
      {
        "id": "minimum_history_required",
        "title": "Minimum history required",
        "subtitle": "Results appear after analysis completes",
        "bullet_color": "#6678E8"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Keep existing insights visible during re-analysis."
  },
  "action": {
    "button_label": "View current insights",
    "background_color": "#171717",
    "text_color": "#9C9FA8"
  },
  "has_bottom_navigation": true,
  "active_tab": "Insights"
}
''';

  const insightsInsufficientDataJson = '''
{
  "screen_id": "M07",
  "state_type": "insufficient_data",
  "screen_title": "Insights",
  "has_back_button": false,
  "badge_text": "NOT ENOUGH DATA",
  "specification_subtitle": "State specification · Not enough data",
  "card": {
    "icon_type": "empty",
    "title": "More usage is needed",
    "description": "Insights require at least 3 days or 10 daily model records.",
    "items": [
      {
        "id": "current_history_too_short",
        "title": "Current history is too short",
        "subtitle": "No recommendations generated yet",
        "bullet_color": "#7B7F88"
      },
      {
        "id": "tracking_is_active",
        "title": "Tracking is active",
        "subtitle": "Continue using supported AI tools",
        "bullet_color": "#7B7F88"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Explain the threshold instead of showing an empty feed."
  },
  "action": {
    "button_label": "View usage",
    "background_color": "#171717",
    "text_color": "#9C9FA8"
  },
  "has_bottom_navigation": true,
  "active_tab": "Insights"
}
''';

  const insightsNoSignificantIssuesJson = '''
{
  "screen_id": "M07",
  "state_type": "no_significant_issues",
  "screen_title": "Insights",
  "has_back_button": false,
  "badge_text": "ALL CLEAR",
  "specification_subtitle": "State specification · All clear",
  "card": {
    "icon_type": "success",
    "title": "No significant issues found",
    "description": "Recent usage is within its normal pattern and no reliable optimization stands out.",
    "items": [
      {
        "id": "analysis_completed",
        "title": "Analysis completed",
        "subtitle": "Models and projects were compared",
        "bullet_color": "#22A575"
      },
      {
        "id": "keep_collecting_usage",
        "title": "Keep collecting usage",
        "subtitle": "New activity may reveal opportunities later",
        "bullet_color": "#22A575"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "A positive empty state should still show analysis freshness."
  },
  "action": {
    "button_label": "Review analytics",
    "background_color": "#171717",
    "text_color": "#9C9FA8"
  },
  "has_bottom_navigation": true,
  "active_tab": "Insights"
}
''';

  const insightsAnalysisFailedJson = '''
{
  "screen_id": "M07",
  "state_type": "analysis_failed",
  "screen_title": "Insights",
  "has_back_button": false,
  "badge_text": "ANALYSIS FAILED",
  "specification_subtitle": "State specification · Analysis failed",
  "card": {
    "icon_type": "failed",
    "title": "Insights couldn’t be generated",
    "description": "The aggregate usage analysis did not complete.",
    "items": [
      {
        "id": "usage_data_safe",
        "title": "Usage data is still safe",
        "subtitle": "No records were changed",
        "bullet_color": "#E0525B"
      },
      {
        "id": "retry_available",
        "title": "Retry available",
        "subtitle": "The same analysis window will be used",
        "bullet_color": "#E0525B"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Do not surface unverified partial recommendations."
  },
  "action": {
    "button_label": "Analyze again",
    "background_color": "#171717",
    "text_color": "#9C9FA8"
  },
  "has_bottom_navigation": true,
  "active_tab": "Insights"
}
''';

  const insightsStaleJson = '''
{
  "screen_id": "M07",
  "state_type": "insights_stale",
  "screen_title": "Insights",
  "has_back_button": false,
  "badge_text": "INSIGHTS ARE STALE",
  "specification_subtitle": "State specification · Insights are stale",
  "card": {
    "icon_type": "offline",
    "title": "New usage isn’t reflected yet",
    "description": "These recommendations were generated before the latest desktop sync.",
    "items": [
      {
        "id": "last_analyzed",
        "title": "Last analyzed · 2 days ago",
        "subtitle": "Evidence may have changed",
        "bullet_color": "#C27A20"
      },
      {
        "id": "reanalysis_recommended",
        "title": "Re-analysis recommended",
        "subtitle": "Old insights remain readable",
        "bullet_color": "#C27A20"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Show generated and last-sync timestamps together."
  },
  "action": {
    "button_label": "Analyze latest usage",
    "background_color": "#171717",
    "text_color": "#9C9FA8"
  },
  "has_bottom_navigation": true,
  "active_tab": "Insights"
}
''';

  const insightDetailStaleJson = '''
{
  "screen_id": "M08",
  "state_type": "insight_stale",
  "screen_title": "Insight detail",
  "has_back_button": true,
  "badge_text": "STALE",
  "specification_subtitle": "State specification · Stale",
  "card": {
    "icon_type": "offline",
    "title": "This insight may be outdated",
    "description": "Its evidence period ends before the most recent usage update.",
    "items": [
      {
        "id": "original_finding_preserved",
        "title": "Original finding preserved",
        "subtitle": "You can still inspect the prior evidence",
        "bullet_color": "#C27A20"
      },
      {
        "id": "confidence_reduced",
        "title": "Confidence reduced",
        "subtitle": "Re-analysis may change the recommendation",
        "bullet_color": "#C27A20"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Never silently rewrite historical evidence."
  },
  "action": {
    "button_label": "Back to insights",
    "background_color": "#171717",
    "text_color": "#9C9FA8"
  },
  "has_bottom_navigation": true,
  "active_tab": "Insights"
}
''';

  const insightDetailResolvedJson = '''
{
  "screen_id": "M08",
  "state_type": "insight_resolved",
  "screen_title": "Insight detail",
  "has_back_button": true,
  "badge_text": "RESOLVED",
  "specification_subtitle": "State specification · Resolved",
  "card": {
    "icon_type": "success",
    "title": "Marked as addressed",
    "description": "This recommendation is no longer active in the current workflow.",
    "items": [
      {
        "id": "resolution_recorded",
        "title": "Resolution recorded",
        "subtitle": "The underlying evidence remains available",
        "bullet_color": "#22A575"
      },
      {
        "id": "can_be_revisited",
        "title": "Can be revisited",
        "subtitle": "New data may create a separate insight",
        "bullet_color": "#22A575"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Keep status, created date and resolution date visible."
  },
  "action": {
    "button_label": "Back to insights",
    "background_color": "#171717",
    "text_color": "#9C9FA8"
  },
  "has_bottom_navigation": true,
  "active_tab": "Insights"
}
''';

  const insightDetailEvidenceUnavailableJson = '''
{
  "screen_id": "M08",
  "state_type": "evidence_unavailable",
  "screen_title": "Insight detail",
  "has_back_button": true,
  "badge_text": "EVIDENCE UNAVAILABLE",
  "specification_subtitle": "State specification · Evidence unavailable",
  "card": {
    "icon_type": "failed",
    "title": "Supporting data isn’t available",
    "description": "The source records for this recommendation were removed or are no longer accessible.",
    "items": [
      {
        "id": "recommendation_preserved",
        "title": "Recommendation is preserved",
        "subtitle": "It cannot be independently verified",
        "bullet_color": "#E0525B"
      },
      {
        "id": "no_new_action",
        "title": "No new action suggested",
        "subtitle": "Re-analyze current usage instead",
        "bullet_color": "#E0525B"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Avoid presenting estimated savings without evidence."
  },
  "action": {
    "button_label": "Back to insights",
    "background_color": "#171717",
    "text_color": "#9C9FA8"
  },
  "has_bottom_navigation": true,
  "active_tab": "Insights"
}
''';

  const settingsNoDesktopJson = '''
{
  "screen_id": "M09",
  "state_type": "no_desktop",
  "screen_title": "Settings",
  "has_back_button": false,
  "badge_text": "NOT CONNECTED",
  "specification_subtitle": "State specification · Not connected",
  "card": {
    "icon_type": "offline",
    "title": "No desktop companion connected",
    "description": "Automatic usage tracking requires a paired desktop.",
    "items": [
      {
        "id": "historical_data_remains",
        "title": "Historical data remains",
        "subtitle": "Existing usage is still available",
        "bullet_color": "#C27A20"
      },
      {
        "id": "new_usage_paused",
        "title": "New usage paused",
        "subtitle": "Connect a desktop to resume collection",
        "bullet_color": "#C27A20"
      }
    ]
  },
  "behavior": {
    "label": "BEHAVIOR",
    "description": "Show the state in the settings summary row."
  },
  "action": {
    "button_label": "Connect desktop",
    "background_color": "#171717",
    "text_color": "#9C9FA8"
  },
  "has_bottom_navigation": true,
  "active_tab": "Settings"
}
''';

  const settingsNotificationsDeniedJson = '''
{
  "screen_id": "M09",
  "screen_title": "Settings",
  "has_back_button": false,
  "state_type": "notifications_denied",
  "state_label": "NOTIFICATIONS OFF",
  "state_context": "State specification · Notifications off",
  "card_title": "Budget alerts are disabled",
  "card_description": "μToken cannot display system notifications for budget thresholds.",
  "icon_type": "offline",
  "bullet_points": [
    {
      "title": "Budgets still calculate",
      "subtitle": "Alert history remains inside the app",
      "bullet_color": "#C27A20"
    },
    {
      "title": "OS permission required",
      "subtitle": "Enable notifications in system settings",
      "bullet_color": "#C27A20"
    }
  ],
  "behavior_label": "BEHAVIOR",
  "behavior_text": "Do not imply budget tracking is disabled.",
  "action_text": "Review budget alerts",
  "active_tab": "Settings"
}
''';

  const settingsReauthenticationRequiredJson = '''
{
  "screen_id": "M09",
  "screen_title": "Settings",
  "has_back_button": false,
  "state_type": "reauthentication_required",
  "state_label": "REAUTHENTICATE",
  "state_context": "State specification · Reauthenticate",
  "card_title": "Account verification required",
  "card_description": "A sensitive account or data action needs a fresh Google sign-in.",
  "icon_type": "offline",
  "bullet_points": [
    {
      "title": "Current session is read-only",
      "subtitle": "Dashboard previews are available",
      "bullet_color": "#C27A20"
    },
    {
      "title": "Sensitive actions paused",
      "subtitle": "Re-authenticate to continue",
      "bullet_color": "#C27A20"
    }
  ],
  "behavior_label": "BEHAVIOR",
  "behavior_text": "Block only actions that require fresh authentication.",
  "action_text": "Open account",
  "active_tab": "Settings"
}
''';

  const desktopConnectionSyncingJson = '''
{
  "screen_id": "M10",
  "screen_title": "Desktop connection",
  "has_back_button": true,
  "state_type": "syncing",
  "state_label": "SYNCING",
  "state_context": "State specification · Syncing",
  "card_title": "Syncing from desktop",
  "card_description": "The companion is scanning local Antigravity usage and uploading aggregate changes.",
  "icon_type": "signing_in",
  "bullet_points": [
    {
      "title": "Collector is online",
      "subtitle": "Only changed aggregates are uploaded",
      "bullet_color": "#6678E8"
    },
    {
      "title": "Current data remains visible",
      "subtitle": "Last successful sync is preserved",
      "bullet_color": "#6678E8"
    }
  ],
  "behavior_label": "BEHAVIOR",
  "behavior_text": "Prevent duplicate sync jobs.",
  "action_text": "View connection",
  "active_tab": "Settings"
}
''';

  const desktopConnectionOfflineJson = '''
{
  "screen_id": "M10",
  "screen_title": "Desktop connection",
  "has_back_button": true,
  "state_type": "offline",
  "state_label": "OFFLINE",
  "state_context": "State specification · Offline",
  "card_title": "Desktop companion is offline",
  "card_description": "No new usage can be collected until the desktop app reconnects.",
  "icon_type": "offline",
  "bullet_points": [
    {
      "title": "Last seen · 26m ago",
      "subtitle": "Historical usage remains available",
      "bullet_color": "#C27A20"
    },
    {
      "title": "New events stay local",
      "subtitle": "Open the desktop companion",
      "bullet_color": "#C27A20"
    }
  ],
  "behavior_label": "BEHAVIOR",
  "behavior_text": "Show last seen and last successful sync separately.",
  "action_text": "Retry connection",
  "active_tab": "Settings"
}
''';

  const desktopConnectionSourceNotFoundJson = '''
{
  "screen_id": "M10",
  "screen_title": "Desktop connection",
  "has_back_button": true,
  "state_type": "source_not_found",
  "state_label": "SOURCE MISSING",
  "state_context": "State specification · Source missing",
  "card_title": "Antigravity wasn’t found",
  "card_description": "The companion cannot locate a supported local Antigravity installation.",
  "icon_type": "failed",
  "bullet_points": [
    {
      "title": "Collector is running",
      "subtitle": "Ensure path could not be resolved",
      "bullet_color": "#E0525B"
    },
    {
      "title": "Setup help available",
      "subtitle": "Check installation and sign-in",
      "bullet_color": "#E0525B"
    }
  ],
  "behavior_label": "BEHAVIOR",
  "behavior_text": "Do not describe this as a permission error.",
  "action_text": "Open setup guide",
  "active_tab": "Settings"
}
''';

  const desktopConnectionNoUsageJson = '''
{
  "screen_id": "M10",
  "screen_title": "Desktop connection",
  "has_back_button": true,
  "state_type": "no_usage",
  "state_label": "NO USAGE YET",
  "state_context": "State specification · No usage yet",
  "card_title": "Connected, but no usage found",
  "card_description": "The collector is ready and the source is accessible.",
  "icon_type": "empty",
  "bullet_points": [
    {
      "title": "Permission granted",
      "subtitle": "No supported activity was logged or recorded",
      "bullet_color": "#7B7F88"
    },
    {
      "title": "Waiting for first session",
      "subtitle": "Start using Antigravity on desktop",
      "bullet_color": "#7B7F88"
    }
  ],
  "behavior_label": "BEHAVIOR",
  "behavior_text": "Never show all metrics to zero before first activity.",
  "action_text": "View usage",
  "active_tab": "Settings"
}
''';

  const desktopConnectionPermissionDeniedJson = '''
{
  "screen_id": "M10",
  "screen_title": "Desktop connection",
  "has_back_button": true,
  "state_type": "permission_denied",
  "state_label": "PERMISSION DENIED",
  "state_context": "State specification · Permission denied",
  "card_title": "Usage permission is blocked",
  "card_description": "The desktop companion cannot read local usage metadata.",
  "icon_type": "failed",
  "bullet_points": [
    {
      "title": "Collector is connected",
      "subtitle": "Cloud account remains linked",
      "bullet_color": "#E0525B"
    },
    {
      "title": "User action required",
      "subtitle": "Grant access in desktop settings",
      "bullet_color": "#E0525B"
    }
  ],
  "behavior_label": "BEHAVIOR",
  "behavior_text": "State the exact affected permission.",
  "action_text": "View permission help",
  "active_tab": "Settings"
}
''';

  const desktopConnectionSessionRevokedJson = '''
{
  "screen_id": "M10",
  "screen_title": "Desktop connection",
  "has_back_button": true,
  "state_type": "session_revoked",
  "state_label": "SESSION REVOKED",
  "state_context": "State specification · Session revoked",
  "card_title": "Desktop session was revoked",
  "card_description": "This companion can no longer upload usage for the account.",
  "icon_type": "failed",
  "bullet_points": [
    {
      "title": "New syncs are rejected",
      "subtitle": "Past data is preserved",
      "bullet_color": "#E0525B"
    },
    {
      "title": "Pair again required",
      "subtitle": "Create a new one-time code",
      "bullet_color": "#E0525B"
    }
  ],
  "behavior_label": "BEHAVIOR",
  "behavior_text": "Do not auto-restore a revoked session.",
  "action_text": "Pair desktop again",
  "active_tab": "Settings"
}
''';

  const desktopConnectionIncompatibleVersionJson = '''
{
  "screen_id": "M10",
  "screen_title": "Desktop connection",
  "has_back_button": true,
  "state_type": "incompatible_version",
  "state_label": "UPDATE REQUIRED",
  "state_context": "State specification · Update required",
  "card_title": "Desktop app needs an update",
  "card_description": "This companion version is no longer compatible with the sync service.",
  "icon_type": "offline",
  "bullet_points": [
    {
      "title": "Collection paused",
      "subtitle": "Local usage is not deleted",
      "bullet_color": "#C27A20"
    },
    {
      "title": "Update required",
      "subtitle": "Install the latest official version",
      "bullet_color": "#C27A20"
    }
  ],
  "behavior_label": "BEHAVIOR",
  "behavior_text": "Keep the minimum supported version visible.",
  "action_text": "View install guide",
  "active_tab": "Settings"
}
''';

  const desktopConnectionSyncFailedJson = '''
{
  "screen_id": "M10",
  "screen_title": "Desktop connection",
  "has_back_button": true,
  "state_type": "sync_failed",
  "state_label": "SYNC FAILED",
  "state_context": "State specification · Sync failed",
  "card_title": "Latest sync failed",
  "card_description": "The collector could read local usage but could not finish the upload.",
  "icon_type": "failed",
  "bullet_points": [
    {
      "title": "Local queue retained",
      "subtitle": "Events will not be lost",
      "bullet_color": "#E0525B"
    },
    {
      "title": "Retry available",
      "subtitle": "Network or service issue detected",
      "bullet_color": "#E0525B"
    }
  ],
  "behavior_label": "BEHAVIOR",
  "behavior_text": "Separate collection success from upload failure.",
  "action_text": "Retry sync",
  "active_tab": "Settings"
}
''';

  const budgetNoBudgetJson = '''
{
  "screen_id": "M11",
  "screen_title": "Budget & alerts",
  "has_back_button": true,
  "state_type": "no_budget",
  "state_label": "NOT SET",
  "state_context": "State specification · Not set",
  "card_title": "Set a monthly budget",
  "card_description": "Choose a spending limit to track estimated AI cost against it.",
  "icon_type": "empty",
  "bullet_points": [
    {
      "title": "Optional for tracking",
      "subtitle": "Usage analysis works without a budget",
      "bullet_color": "#7B7F88"
    },
    {
      "title": "Alerts need a threshold",
      "subtitle": "Notifications can be enabled afterward",
      "bullet_color": "#7B7F88"
    }
  ],
  "behavior_label": "BEHAVIOR",
  "behavior_text": "Do not show a zero-dollar budget as an active limit.",
  "action_text": "Set budget",
  "active_tab": "Settings"
}
''';

  const budgetNearThresholdJson = r'''
{
  "screen_id": "M11",
  "screen_title": "Budget & alerts",
  "has_back_button": true,
  "state_type": "near_threshold",
  "state_label": "NEAR THRESHOLD",
  "state_context": "State specification · Near threshold",
  "card_title": "Approaching your alert level",
  "card_description": "Estimated cost is close to the next configured threshold.",
  "icon_type": "offline",
  "bullet_points": [
    {
      "title": "74% of $50 used",
      "subtitle": "$36.82 estimated remaining",
      "bullet_color": "#C27A20"
    },
    {
      "title": "Largest contributor · Gemini",
      "subtitle": "Review usage before changing threshold",
      "bullet_color": "#C27A20"
    }
  ],
  "behavior_label": "BEHAVIOR",
  "behavior_text": "Use estimated cost language consistently.",
  "action_text": "View budget",
  "active_tab": "Settings"
}
''';

  const budgetThresholdExceededJson = '''
{
  "screen_id": "M11",
  "screen_title": "Budget & alerts",
  "has_back_button": true,
  "state_type": "threshold_exceeded",
  "state_label": "ALERT TRIGGERED",
  "state_context": "State specification · Alert triggered",
  "card_title": "Budget alert threshold reached",
  "card_description": "Estimated monthly cost crossed a configured alert level.",
  "icon_type": "offline",
  "bullet_points": [
    {
      "title": "90% threshold reached",
      "subtitle": "One notification created for this month",
      "bullet_color": "#C27A20"
    },
    {
      "title": "Budget is not exceeded yet",
      "subtitle": "Tracking continues normally",
      "bullet_color": "#C27A20"
    }
  ],
  "behavior_label": "BEHAVIOR",
  "behavior_text": "Deduplicate alerts per threshold and month.",
  "action_text": "View contributing usage",
  "active_tab": "Settings"
}
''';

  const budgetBudgetExceededJson = r'''
{
  "screen_id": "M11",
  "screen_title": "Budget & alerts",
  "has_back_button": true,
  "state_type": "budget_exceeded",
  "state_label": "BUDGET EXCEEDED",
  "state_context": "State specification · Budget exceeded",
  "card_title": "Estimated cost is over budget",
  "card_description": "Current usage has exceeded the monthly spending limit.",
  "icon_type": "failed",
  "bullet_points": [
    {
      "title": "$63.20 of $50 estimated",
      "subtitle": "This is not a provider invoice",
      "bullet_color": "#E0525B"
    },
    {
      "title": "Collection continues",
      "subtitle": "μToken does not block AI tools",
      "bullet_color": "#E0525B"
    }
  ],
  "behavior_label": "BEHAVIOR",
  "behavior_text": "Never imply that model access was restricted.",
  "action_text": "Review usage",
  "active_tab": "Settings"
}
''';

  const budgetCostUnavailableJson = '''
{
  "screen_id": "M11",
  "screen_title": "Budget & alerts",
  "has_back_button": true,
  "state_type": "cost_unavailable",
  "state_label": "COST UNAVAILABLE",
  "state_context": "State specification · Cost unavailable",
  "card_title": "Budget status can’t be calculated",
  "card_description": "One or more models are missing a valid pricing version.",
  "icon_type": "empty",
  "bullet_points": [
    {
      "title": "Budget remains configured",
      "subtitle": "Thresholds are not evaluated",
      "bullet_color": "#7B7F88"
    },
    {
      "title": "Token tracking continues",
      "subtitle": "Resolve pricing to restore alerts",
      "bullet_color": "#7B7F88"
    }
  ],
  "behavior_label": "BEHAVIOR",
  "behavior_text": "Suspend cost alerts instead of treating cost as zero.",
  "action_text": "View model pricing",
  "active_tab": "Settings"
}
''';

  const budgetNotificationsOffJson = '''
{
  "screen_id": "M11",
  "screen_title": "Budget & alerts",
  "has_back_button": true,
  "state_type": "notifications_off",
  "state_label": "NOTIFICATIONS OFF",
  "state_context": "State specification · Notifications off",
  "card_title": "System alerts are disabled",
  "card_description": "Budget thresholds still calculate, but push notifications cannot be delivered.",
  "icon_type": "offline",
  "bullet_points": [
    {
      "title": "In-app history remains",
      "subtitle": "Alerts appear when the app is opened",
      "bullet_color": "#C27A20"
    },
    {
      "title": "OS permission required",
      "subtitle": "Turn on notifications in system settings",
      "bullet_color": "#C27A20"
    }
  ],
  "behavior_label": "BEHAVIOR",
  "behavior_text": "Separate notification delivery from threshold calculation.",
  "action_text": "Review alert settings",
  "active_tab": "Settings"
}
''';

  const privacyExportPreparingJson = '''
{
  "screen_id": "M12",
  "screen_title": "Privacy & data",
  "has_back_button": true,
  "state_type": "export_preparing",
  "state_label": "PREPARING EXPORT",
  "state_context": "State specification · Preparing export",
  "card_title": "Preparing your export",
  "card_description": "Collecting usage summaries into machine-readable files.",
  "icon_type": "signing_in",
  "bullet_points": [
    {
      "title": "CSV and JSON requested",
      "subtitle": "Prompts and response content are never stored",
      "bullet_color": "#6678E8"
    },
    {
      "title": "Keep the app open",
      "subtitle": "Download becomes available when ready",
      "bullet_color": "#6678E8"
    }
  ],
  "behavior_label": "BEHAVIOR",
  "behavior_text": "Prevent duplicate export jobs.",
  "action_text": "Back to data settings",
  "active_tab": "Settings"
}
''';

  const privacyExportSuccessJson = '''
{
  "screen_id": "M12",
  "screen_title": "Privacy & data",
  "has_back_button": true,
  "state_type": "export_success",
  "state_label": "EXPORT READY",
  "state_context": "State specification · Export ready",
  "card_title": "Your export is ready",
  "card_description": "Usage data was prepared successfully.",
  "icon_type": "success",
  "bullet_points": [
    {
      "title": "12,842 usage records",
      "subtitle": "CSV and JSON are available",
      "bullet_color": "#22A575"
    },
    {
      "title": "Generated just now",
      "subtitle": "File download link expires for security",
      "bullet_color": "#22A575"
    }
  ],
  "behavior_label": "BEHAVIOR",
  "behavior_text": "Show scope, record count, and generation time.",
  "action_text": "Open export",
  "active_tab": "Settings"
}
''';

  const privacyExportFailedJson = '''
{
  "screen_id": "M12",
  "screen_title": "Privacy & data",
  "has_back_button": true,
  "state_type": "export_failed",
  "state_label": "EXPORT FAILED",
  "state_context": "State specification · Export failed",
  "card_title": "Couldn’t prepare the export",
  "card_description": "The data job stopped before the files were created.",
  "icon_type": "failed",
  "bullet_points": [
    {
      "title": "No incomplete file downloaded",
      "subtitle": "Your cloud data is unchanged",
      "bullet_color": "#E0525B"
    },
    {
      "title": "Safe to retry",
      "subtitle": "Another local copy may be requested",
      "bullet_color": "#E0525B"
    }
  ],
  "behavior_label": "BEHAVIOR",
  "behavior_text": "Retain the selected export format.",
  "action_text": "Retry export",
  "active_tab": "Settings"
}
''';

  const privacyDeletingUsageJson = '''
{
  "screen_id": "M12",
  "screen_title": "Privacy & data",
  "has_back_button": true,
  "state_type": "deleting_usage",
  "state_label": "DELETING",
  "state_context": "State specification · Deleting",
  "card_title": "Deleting usage data",
  "card_description": "Removing cloud usage summaries while keeping the account active.",
  "icon_type": "offline",
  "bullet_points": [
    {
      "title": "Desktop connection remains",
      "subtitle": "New usage may arrive after delete",
      "bullet_color": "#C27A20"
    },
    {
      "title": "This can’t be undone",
      "subtitle": "The operation may take a moment",
      "bullet_color": "#C27A20"
    }
  ],
  "behavior_label": "BEHAVIOR",
  "behavior_text": "Disable repeated destructive actions while running.",
  "action_text": "View data settings",
  "active_tab": "Settings"
}
''';

  const privacyDeleteSuccessJson = '''
{
  "screen_id": "M12",
  "screen_title": "Privacy & data",
  "has_back_button": true,
  "state_type": "delete_success",
  "state_label": "DELETED",
  "state_context": "State specification · Deleted",
  "card_title": "Usage data deleted",
  "card_description": "The selected cloud usage history has been removed.",
  "icon_type": "success",
  "bullet_points": [
    {
      "title": "Account remains active",
      "subtitle": "Google sign-in was not removed",
      "bullet_color": "#22A575"
    },
    {
      "title": "Desktop may collect new usage",
      "subtitle": "Disconnect it to stop future syncs",
      "bullet_color": "#22A575"
    }
  ],
  "behavior_label": "BEHAVIOR",
  "behavior_text": "State exactly what remains after deletion.",
  "action_text": "Done",
  "active_tab": "Settings"
}
''';

  const privacyDeletePartialJson = '''
{
  "screen_id": "M12",
  "screen_title": "Privacy & data",
  "has_back_button": true,
  "state_type": "delete_partial",
  "state_label": "PARTIAL DELETION",
  "state_context": "State specification · Partial deletion",
  "card_title": "Some data couldn’t be deleted",
  "card_description": "The deletion completed only for part of the selected scope.",
  "icon_type": "failed",
  "bullet_points": [
    {
      "title": "Completed items are gone",
      "subtitle": "They will not be restored automatically",
      "bullet_color": "#E0525B"
    },
    {
      "title": "Remaining items need attention",
      "subtitle": "Retry or contact support with the job ID",
      "bullet_color": "#E0525B"
    }
  ],
  "behavior_label": "BEHAVIOR",
  "behavior_text": "Expose partial completion instead of generic failure.",
  "action_text": "Review remaining data",
  "active_tab": "Settings"
}
''';

  const privacyReauthenticationJson = '''
{
  "screen_id": "M12",
  "screen_title": "Privacy & data",
  "has_back_button": true,
  "state_type": "reauthentication",
  "state_label": "REAUTHENTICATE",
  "state_context": "State specification · Reauthenticate",
  "card_title": "Verify your account to continue",
  "card_description": "Exporting or deleting sensitive account data requires a fresh Google sign-in.",
  "icon_type": "offline",
  "bullet_points": [
    {
      "title": "Current data is unchanged",
      "subtitle": "No operation has started",
      "bullet_color": "#C27A20"
    },
    {
      "title": "Verification expires",
      "subtitle": "Complete the action promptly after sign-in",
      "bullet_color": "#C27A20"
    }
  ],
  "behavior_label": "BEHAVIOR",
  "behavior_text": "Return to the pending action after verification.",
  "action_text": "Verify with Google",
  "active_tab": "Settings"
}
''';

  const accountReauthenticationJson = '''
{
  "screen_id": "M13",
  "screen_title": "Account",
  "has_back_button": true,
  "state_type": "reauthentication",
  "state_label": "REAUTHENTICATE",
  "state_context": "State specification · Reauthenticate",
  "card_title": "Confirm it’s you",
  "card_description": "This account action requires a recent Google authentication.",
  "icon_type": "offline",
  "bullet_points": [
    {
      "title": "Profile remains signed in",
      "subtitle": "Normal analytics is still available",
      "bullet_color": "#C27A20"
    },
    {
      "title": "Sensitive action paused",
      "subtitle": "Continues after verification",
      "bullet_color": "#C27A20"
    }
  ],
  "behavior_label": "BEHAVIOR",
  "behavior_text": "Do not wipe the local account prematurely.",
  "action_text": "Verify account",
  "active_tab": "Settings"
}
''';

  const accountSigningOutJson = '''
{
  "screen_id": "M13",
  "screen_title": "Account",
  "has_back_button": true,
  "state_type": "signing_out",
  "state_label": "SIGNING OUT",
  "state_context": "State specification · Signing out",
  "card_title": "Signing out of this phone",
  "card_description": "Ending the mobile session without deleting cloud usage.",
  "icon_type": "signing_in",
  "bullet_points": [
    {
      "title": "Cloud data is retained",
      "subtitle": "You can sign in again later",
      "bullet_color": "#6678E8"
    },
    {
      "title": "Desktop remains linked",
      "subtitle": "Revoke it separately if needed",
      "bullet_color": "#6678E8"
    }
  ],
  "behavior_label": "BEHAVIOR",
  "behavior_text": "Make sign-out and account deletion visibly different.",
  "action_text": "Return to welcome",
  "active_tab": "Settings"
}
''';

  const accountDeletingAccountJson = '''
{
  "screen_id": "M13",
  "screen_title": "Account",
  "has_back_button": true,
  "state_type": "deleting_account",
  "state_label": "DELETING ACCOUNT",
  "state_context": "State specification · Deleting account",
  "card_title": "Deleting your account",
  "card_description": "Revoking connected devices and removing account-owned cloud data.",
  "icon_type": "offline",
  "bullet_points": [
    {
      "title": "Desktop access revoked",
      "subtitle": "New syncs will be rejected",
      "bullet_color": "#C27A20"
    },
    {
      "title": "Deletion is permanent",
      "subtitle": "Some backend cleanup may continue",
      "bullet_color": "#C27A20"
    }
  ],
  "behavior_label": "BEHAVIOR",
  "behavior_text": "Block navigation until the backend confirms completion.",
  "action_text": "View account status",
  "active_tab": "Settings"
}
''';

  const accountDeleteFailedJson = '''
{
  "screen_id": "M13",
  "screen_title": "Account",
  "has_back_button": true,
  "state_type": "delete_failed",
  "state_label": "DELETION FAILED",
  "state_context": "State specification · Deletion failed",
  "card_title": "Account deletion didn’t finish",
  "card_description": "The account is still active because a required cleanup step failed.",
  "icon_type": "failed",
  "bullet_points": [
    {
      "title": "Sign-in remains valid",
      "subtitle": "Data is safe",
      "bullet_color": "#E0525B"
    },
    {
      "title": "No silent partial deletion",
      "subtitle": "Review the error before trying again",
      "bullet_color": "#E0525B"
    }
  ],
  "behavior_label": "BEHAVIOR",
  "behavior_text": "Keep the user informed of retained access.",
  "action_text": "Retry deletion",
  "active_tab": "Settings"
}
''';

  const accountDeletePartialJson = '''
{
  "screen_id": "M13",
  "screen_title": "Account",
  "has_back_button": true,
  "state_type": "delete_partial",
  "state_label": "PARTIAL DELETION",
  "state_context": "State specification · Partial deletion",
  "card_title": "Account cleanup is incomplete",
  "card_description": "Some account data or device sessions still require removal.",
  "icon_type": "failed",
  "bullet_points": [
    {
      "title": "Completed cleanup is permanent",
      "subtitle": "Removed items cannot be restored",
      "bullet_color": "#E0525B"
    },
    {
      "title": "Follow-up required",
      "subtitle": "A job reference is available for support",
      "bullet_color": "#E0525B"
    }
  ],
  "behavior_label": "BEHAVIOR",
  "behavior_text": "List remaining resources explicitly in log/export status.",
  "action_text": "Review account",
  "active_tab": "Settings"
}
''';

  const insightsAiNotSetUpJson = '''
{
  "screen_id": "M07",
  "screen_title": "Insights",
  "has_back_button": false,
  "state_type": "ai_not_set_up",
  "state_label": "AI NOT SET UP",
  "state_context": "State specification · AI not set up",
  "card_title": "Choose an AI model",
  "card_description": "Suggestions are written by an LLM you pick. Add a provider and API key to start.",
  "icon_type": "empty",
  "bullet_points": [
    {
      "title": "No provider configured",
      "subtitle": "Settings > AI suggestions",
      "bullet_color": "#7B7F88"
    },
    {
      "title": "Your usage is still tracked",
      "subtitle": "Key stays on this phone",
      "bullet_color": "#7B7F88"
    }
  ],
  "behavior_label": "BEHAVIOR",
  "behavior_text": "Show this instead of the feed when no API key is saved. The button opens M15.",
  "action_text": "Set up AI suggestions",
  "active_tab": "Insights"
}
''';

  const aiSuggestionsInvalidApiKeyJson = '''
{
  "screen_id": "M15",
  "screen_title": "AI suggestions",
  "has_back_button": false,
  "state_type": "invalid_api_key",
  "state_label": "KEY REJECTED",
  "state_context": "State specification · Invalid API key",
  "card_title": "The provider rejected this key",
  "card_description": "Check the key or quota, then test the connection again.",
  "icon_type": "empty",
  "bullet_points": [
    {
      "title": "Provider",
      "subtitle": "OpenAI · gpt-4.5-mini",
      "bullet_color": "#7B7F88"
    },
    {
      "title": "Previous suggestions",
      "subtitle": "Still present in Insights",
      "bullet_color": "#7B7F88"
    }
  ],
  "behavior_label": "BEHAVIOR",
  "behavior_text": "Keep old suggestions visible and show AI_PROVIDER_ERROR here after Test connection or scheduled run.",
  "action_text": "Edit API key",
  "active_tab": "Settings"
}
''';

  group('M01 All States Tests', () {
    testWidgets('renders Signing In state accurately', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(signingInJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('SIGNING IN'), findsOneWidget);
      expect(find.text('Signing you in'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('renders Cancelled state accurately', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(cancelledJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('CANCELLED'), findsOneWidget);
      expect(find.text('Sign-in was cancelled'), findsOneWidget);
      expect(find.text('Nothing was connected'), findsOneWidget);
      expect(find.text('Do not show this as a destructive error.'),
          findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('renders Failed state accurately', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(failedJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('FAILED'), findsOneWidget);
      expect(find.text('Couldn’t sign you in'), findsOneWidget);
      expect(find.text('Account not connected'), findsOneWidget);
      expect(find.text('Keep the error actionable and preserve privacy.'),
          findsOneWidget);
      expect(find.text('Retry sign-in'), findsOneWidget);
    });

    testWidgets('renders Offline state accurately', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(offlineJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('OFFLINE'), findsOneWidget);
      expect(find.text('You’re offline'), findsOneWidget);
      expect(find.text('Authentication paused'), findsOneWidget);
      expect(
          find.text('Never replace network failure with a generic auth error.'),
          findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('renders Session Expired state accurately', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(sessionExpiredJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('SESSION EXPIRED'), findsOneWidget);
      expect(find.text('Sign in again'), findsOneWidget);
      expect(
          find.text(
              'Your session expired before μToken could load your account.'),
          findsOneWidget);
      expect(find.text('Re-authentication required'), findsOneWidget);
      expect(find.text('Google confirms that it is still you'), findsOneWidget);
      expect(find.text('Usage remains in cloud'), findsOneWidget);
      expect(find.text('Nothing is deleted when a session expires'),
          findsOneWidget);
      expect(
          find.text(
              'Return the user to their previous destination after sign-in.'),
          findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('renders Verifying state accurately with back chevron',
        (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(verifyingJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Connect desktop'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('VERIFYING'), findsOneWidget);
      expect(find.text('Verifying this desktop'), findsOneWidget);
      expect(find.text('Checking the one-time code and desktop identity.'),
          findsOneWidget);
      expect(find.text('Pairing code received'), findsOneWidget);
      expect(find.text('Codes expire after 10 minutes'), findsOneWidget);
      expect(find.text('Waiting for desktop'), findsOneWidget);
      expect(find.text('Keep the companion app open'), findsOneWidget);
      expect(
          find.text(
              'Disable duplicate code submits while verification is running.'),
          findsOneWidget);
      expect(find.text('Cancel pairing'), findsOneWidget);
    });

    testWidgets('renders Connected state accurately with success illustration',
        (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(connectedJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Connect desktop'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('CONNECTED'), findsOneWidget);
      expect(find.text('Desktop connected'), findsOneWidget);
      expect(
          find.text(
              'The desktop companion can now send aggregate usage metadata.'),
          findsOneWidget);
      expect(find.text('Collector authorized'), findsOneWidget);
      expect(find.text('Prompt and response content remain local'),
          findsOneWidget);
      expect(find.text('Initial sync pending'), findsOneWidget);
      expect(find.text('Usage appears after the first claim'), findsOneWidget);
      expect(
          find.text(
              'Move into the empty-data state before showing zero values.'),
          findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('renders Wrong code state accurately', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(wrongCodeJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Connect desktop'), findsOneWidget);
      expect(find.text('INVALID CODE'), findsOneWidget);
      expect(find.text('That code isn’t valid'), findsOneWidget);
      expect(
          find.text(
              'Check every character and enter the latest code shown on desktop.'),
          findsOneWidget);
      expect(find.text('Code rejected'), findsOneWidget);
      expect(find.text('It may have been typed incorrectly'), findsOneWidget);
      expect(find.text('Attempts are safe'), findsOneWidget);
      expect(find.text('Generate a new code if needed'), findsOneWidget);
      expect(find.text('Keep the input and point to the exact field.'),
          findsOneWidget);
      expect(find.text('Enter another code'), findsOneWidget);
    });

    testWidgets('renders Code expired state accurately', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(codeExpiredJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Connect desktop'), findsOneWidget);
      expect(find.text('EXPIRED'), findsOneWidget);
      expect(find.text('Pairing code expired'), findsOneWidget);
      expect(find.text('One-time codes are valid for 10 minutes.'),
          findsOneWidget);
      expect(find.text('Old code disabled'), findsOneWidget);
      expect(find.text('It can no longer be reused'), findsOneWidget);
      expect(find.text('New code required'), findsOneWidget);
      expect(
          find.text('Generate it from the desktop companion'), findsOneWidget);
      expect(find.text('Show expiry before the user submits again.'),
          findsOneWidget);
      expect(find.text('Generate new code'), findsOneWidget);
    });

    testWidgets('renders Code already used state accurately', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(codeAlreadyUsedJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Connect desktop'), findsOneWidget);
      expect(find.text('CODE USED'), findsOneWidget);
      expect(find.text('This code was already used'), findsOneWidget);
      expect(
          find.text(
              'A pairing code can connect only one authenticated session.'),
          findsOneWidget);
      expect(find.text('Code is no longer active'), findsOneWidget);
      expect(find.text('This prevents accidental desktop linking'),
          findsOneWidget);
      expect(find.text('Create another code'), findsOneWidget);
      expect(find.text('Use the desktop companion to restart pairing'),
          findsOneWidget);
      expect(
          find.text(
              'Do not imply that a desktop was connected to this account.'),
          findsOneWidget);
      expect(find.text('Use a new code'), findsOneWidget);
    });

    testWidgets('renders Desktop no response state accurately', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(desktopNoResponseJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Connect desktop'), findsOneWidget);
      expect(find.text('NO RESPONSE'), findsOneWidget);
      expect(find.text('Desktop didn’t respond'), findsOneWidget);
      expect(
          find.text(
              'The companion may be closed, asleep or blocked by the network.'),
          findsOneWidget);
      expect(find.text('Mobile request received'), findsOneWidget);
      expect(
          find.text('Desktop confirmation is still missing'), findsOneWidget);
      expect(find.text('Local data remains unchanged'), findsOneWidget);
      expect(find.text('Open the companion and retry'), findsOneWidget);
      expect(
          find.text('Allow retry without generating a new code immediately.'),
          findsOneWidget);
      expect(find.text('Retry pairing'), findsOneWidget);
    });

    testWidgets('renders Existing desktop state accurately', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(existingDesktopJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Connect desktop'), findsOneWidget);
      expect(find.text('REPLACE DEVICE'), findsOneWidget);
      expect(find.text('Another desktop is connected'), findsOneWidget);
      expect(
          find.text('μToken supports one active desktop companion in the MVP.'),
          findsOneWidget);
      expect(find.text('Current device'), findsOneWidget);
      expect(find.text("Corneliya's Mac · last seen 2 m ago"), findsOneWidget);
      expect(find.text('Replacing revokes the old session'), findsOneWidget);
      expect(find.text('Historic usage will be kept'), findsOneWidget);
      expect(find.text('Require explicit confirmation before replacement.'),
          findsOneWidget);
      expect(find.text('Review connection'), findsOneWidget);
    });

    testWidgets('renders Network error state accurately', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(networkErrorJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Connect desktop'), findsOneWidget);
      expect(find.text('NETWORK ERROR'), findsOneWidget);
      expect(find.text('Pairing couldn’t finish'), findsOneWidget);
      expect(
          find.text(
              'The account is valid, but the pairing service could not be reached.'),
          findsOneWidget);
      expect(find.text('No partial connection'), findsOneWidget);
      expect(find.text('Safe to retry'), findsOneWidget);
      expect(
          find.text('Differentiate network errors from invalid pairing codes.'),
          findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('renders Unsupported OS state accurately', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(unsupportedOsJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Install guide'), findsOneWidget);
      expect(find.text('UNSUPPORTED OS'), findsOneWidget);
      expect(find.text('This system isn’t supported'), findsOneWidget);
      expect(
          find.text(
              'The desktop companion cannot run on this operating system version.'),
          findsOneWidget);
      expect(find.text('Installation blocked'), findsOneWidget);
      expect(find.text('Check supported systems'), findsOneWidget);
      expect(
          find.text('State the minimum supported OS clearly.'), findsOneWidget);
      expect(find.text('View requirements'), findsOneWidget);
    });

    testWidgets('renders App not installed state accurately', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(appNotInstalledJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Install guide'), findsOneWidget);
      expect(find.text('NOT INSTALLED'), findsOneWidget);
      expect(find.text('Desktop app not detected'), findsOneWidget);
      expect(
          find.text('Install the companion before trying to pair this device.'),
          findsOneWidget);
      expect(find.text('No local collector found'), findsOneWidget);
      expect(find.text('Official download only'), findsOneWidget);
      expect(find.text('Keep the official source prominent.'), findsOneWidget);
      expect(find.text('Download desktop app'), findsOneWidget);
    });

    testWidgets('renders App not opened state accurately', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(appNotOpenedJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Install guide'), findsOneWidget);
      expect(find.text('NOT RUNNING'), findsOneWidget);
      expect(find.text('Open the desktop companion'), findsOneWidget);
      expect(
          find.text(
              'The app is installed but has not started a pairing session.'),
          findsOneWidget);
      expect(find.text('Installation detected'), findsOneWidget);
      expect(find.text('Pairing will appear after launch'), findsOneWidget);
      expect(
          find.text('Recheck desktop presence after the CTA.'), findsOneWidget);
      expect(find.text('I opened it'), findsOneWidget);
    });

    testWidgets('renders Permission denied state accurately', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(permissionDeniedJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Install guide'), findsOneWidget);
      expect(find.text('PERMISSION DENIED'), findsOneWidget);
      expect(find.text('Local usage access is blocked'), findsOneWidget);
      expect(
          find.text(
              'The companion needs permission to read Antigravity usage metadata.'),
          findsOneWidget);
      expect(find.text('No prompt content requested'), findsOneWidget);
      expect(find.text('Permission can be changed'), findsOneWidget);
      expect(find.text('Explain the exact permission and why it is needed.'),
          findsOneWidget);
      expect(find.text('Open permission guide'), findsOneWidget);
    });

    testWidgets(
        'renders Initial loading state with bottom navigation bar and elevated button',
        (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(initialLoadingJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tokens'), findsAtLeastNWidgets(1));
      expect(find.text('LOADING'), findsOneWidget);
      expect(find.text('Loading your usage'), findsOneWidget);
      expect(
          find.text(
              'Fetching the latest daily summaries and pricing metadata.'),
          findsOneWidget);
      expect(find.text('Account verified'), findsOneWidget);
      expect(find.text('Usage is being prepared'), findsOneWidget);
      expect(find.text('No zero values shown'), findsOneWidget);
      expect(find.text('Unknown metrics remain unavailable'), findsOneWidget);
      expect(
          find.text(
              'Use skeletons only for metrics that are actually loading.'),
          findsOneWidget);
      expect(find.text('Back to overview'), findsOneWidget);

      // Verify bottom navigation bar tabs exist
      expect(find.text('Analytics'), findsOneWidget);
      expect(find.text('Insights'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('renders Updating with data state accurately', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(updatingWithDataJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tokens'), findsAtLeastNWidgets(1));
      expect(find.text('REFRESHING'), findsOneWidget);
      expect(find.text('Updating latest usage'), findsOneWidget);
      expect(
          find.text(
              'The current dashboard remains visible while new desktop data is processed.'),
          findsOneWidget);
      expect(find.text('Existing totals stay readable'), findsOneWidget);
      expect(find.text('Never replace valid data with a blank screen'),
          findsOneWidget);
      expect(find.text('Last sync remains visible'), findsOneWidget);
      expect(
          find.text('Fresh values replace it when complete'), findsOneWidget);
      expect(find.text('Show progress without blocking exploration.'),
          findsOneWidget);
      expect(find.text('View current data'), findsOneWidget);
    });

    testWidgets(
        'renders Partial data state accurately with custom button colors',
        (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(partialDataJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tokens'), findsAtLeastNWidgets(1));
      expect(find.text('PARTIAL DATA'), findsOneWidget);
      expect(find.text('Some metrics are missing'), findsOneWidget);
      expect(
          find.text(
              'Token totals are available, but one or more sources did not provide complete metadata.'),
          findsOneWidget);
      expect(find.text('Available metrics remain visible'), findsOneWidget);
      expect(find.text('Missing values are labelled, not shown as zero'),
          findsOneWidget);
      expect(find.text('Analysis is limited'), findsOneWidget);
      expect(find.text('Insights explain which evidence is incomplete'),
          findsOneWidget);
      expect(find.text('Name the affected provider, project or time range.'),
          findsOneWidget);
      expect(find.text('View available data'), findsOneWidget);
    });

    testWidgets('renders Desktop offline state accurately', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(desktopOfflineJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tokens'), findsAtLeastNWidgets(1));
      expect(find.text('OFFLINE'), findsOneWidget);
      expect(find.text('State specification · Offline'), findsOneWidget);
      expect(find.text('Desktop is offline'), findsOneWidget);
      expect(
          find.text(
              'Showing the last successfully synced usage while the companion is unavailable.'),
          findsOneWidget);
      expect(find.text('Last sync · Today, 10:42'), findsOneWidget);
      expect(find.text('Historical details still available'), findsOneWidget);
      expect(find.text('New activity is pending'), findsOneWidget);
      expect(
          find.text('Open the desktop companion to continue'), findsOneWidget);
      expect(find.text('Preserve cached data and mark its freshness.'),
          findsOneWidget);
      expect(find.text('View connection'), findsOneWidget);

      // Bottom nav exists
      expect(find.text('Analytics'), findsOneWidget);
      expect(find.text('Insights'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('renders Stale data state accurately', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(staleDataJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tokens'), findsAtLeastNWidgets(1));
      expect(find.text('DATA IS STALE'), findsOneWidget);
      expect(find.text('State specification · Data is stale'), findsOneWidget);
      expect(find.text('Usage hasn’t updated recently'), findsOneWidget);
      expect(
          find.text(
              'The dashboard is more than 24 hours behind the desktop activity.'),
          findsOneWidget);
      expect(find.text('Last successful sync · 26h ago'), findsOneWidget);
      expect(find.text('Displayed totals may be incomplete'), findsOneWidget);
      expect(find.text('Manual sync recommended'), findsOneWidget);
      expect(find.text('Desktop must be online'), findsOneWidget);
      expect(find.text('Keep stale data visible with an explicit timestamp.'),
          findsOneWidget);
      expect(find.text('Sync now'), findsOneWidget);
    });

    testWidgets('renders Cost unavailable state accurately', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(costUnavailableJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tokens'), findsAtLeastNWidgets(1));
      expect(find.text('COST UNAVAILABLE'), findsOneWidget);
      expect(
          find.text('State specification · Cost unavailable'), findsOneWidget);
      expect(find.text('Cost can’t be estimated'), findsOneWidget);
      expect(
          find.text(
              'Token usage is available, but pricing is missing for one or more models.'),
          findsOneWidget);
      expect(find.text('Token totals are unaffected'), findsOneWidget);
      expect(find.text('Usage counts remain accurate'), findsOneWidget);
      expect(find.text('Pricing catalog missing'), findsOneWidget);
      expect(find.text('Never substitute \$0.00'), findsOneWidget);
      expect(find.text('Separate token accuracy from cost availability.'),
          findsOneWidget);
      expect(find.text('View model pricing'), findsOneWidget);
    });

    testWidgets('renders M05 No data state with Analytics tab active',
        (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(analyticsNoDataJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Analytics'), findsAtLeastNWidgets(1));
      expect(find.text('NO DATA'), findsOneWidget);
      expect(find.text('State specification · No data'), findsOneWidget);
      expect(find.text('No usage to analyze'), findsOneWidget);
      expect(find.text('There are no records in the selected time range.'),
          findsOneWidget);
      expect(find.text('Current range is empty'), findsOneWidget);
      expect(find.text('Try a wider date range'), findsOneWidget);
      expect(find.text('Filters are not the cause'), findsOneWidget);
      expect(find.text('Desktop connection was still active'), findsOneWidget);
      expect(find.text('Do not render an empty chart with zero labels.'),
          findsOneWidget);
      expect(find.text('Change date range'), findsOneWidget);

      // Bottom nav exists
      expect(find.text('Tokens'), findsOneWidget);
      expect(find.text('Insights'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('renders M05 No filter results state accurately',
        (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(analyticsNoFilterResultsJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Analytics'), findsAtLeastNWidgets(1));
      expect(find.text('NO RESULTS'), findsOneWidget);
      expect(find.text('State specification · No results'), findsOneWidget);
      expect(find.text('No results match these filters'), findsOneWidget);
      expect(
          find.text(
              'Usage exists, but not for this source, model or project combination.'),
          findsOneWidget);
      expect(find.text('Filters are active'), findsOneWidget);
      expect(find.text('Original data is unchanged'), findsOneWidget);
      expect(find.text('Clear filters to recover'), findsOneWidget);
      expect(find.text('Keep the selected time range'), findsOneWidget);
      expect(find.text('Differentiate filter-empty from no usage.'),
          findsOneWidget);
      expect(find.text('Clear filters'), findsOneWidget);
    });

    testWidgets('renders M05 Partial data state accurately', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(analyticsPartialDataJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Analytics'), findsAtLeastNWidgets(1));
      expect(find.text('PARTIAL DATA'), findsOneWidget);
      expect(find.text('State specification · Partial data'), findsOneWidget);
      expect(find.text('Analysis is incomplete'), findsOneWidget);
      expect(find.text('Some days or sources are missing one or more metrics.'),
          findsOneWidget);
      expect(find.text('Trend uses available records'), findsOneWidget);
      expect(find.text('Gaps remain visible in the chart'), findsOneWidget);
      expect(find.text('Comparison confidence reduced'), findsOneWidget);
      expect(find.text('Contribution ranking may change after sync'),
          findsOneWidget);
      expect(find.text('Never interpolate missing provider data silently.'),
          findsOneWidget);
      expect(find.text('View available analysis'), findsOneWidget);
    });

    testWidgets('renders M05 Unsupported metric state accurately',
        (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(analyticsUnsupportedMetricJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Analytics'), findsAtLeastNWidgets(1));
      expect(find.text('UNSUPPORTED'), findsOneWidget);
      expect(find.text('State specification · Unsupported'), findsOneWidget);
      expect(find.text('This metric isn’t supported'), findsOneWidget);
      expect(
          find.text(
              'The selected source does not provide latency, error or cache information.'),
          findsOneWidget);
      expect(find.text('Source limitation'), findsOneWidget);
      expect(find.text('Not a value of zero'), findsOneWidget);
      expect(find.text('Other metrics still work'), findsOneWidget);
      expect(find.text('Switch to tokens, requests or cost'), findsOneWidget);
      expect(
          find.text('Explain unsupported source capability.'), findsOneWidget);
      expect(find.text('Choose another metric'), findsOneWidget);
    });

    testWidgets('renders M05 Cost unavailable state accurately',
        (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(analyticsCostUnavailableJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Analytics'), findsAtLeastNWidgets(1));
      expect(find.text('COST UNAVAILABLE'), findsOneWidget);
      expect(
          find.text('State specification · Cost unavailable'), findsOneWidget);
      expect(find.text('Cost analysis is unavailable'), findsOneWidget);
      expect(
          find.text(
              'Pricing could not be resolved for the current model selection.'),
          findsOneWidget);
      expect(find.text('Token analysis remains available'), findsOneWidget);
      expect(find.text('No records are discarded'), findsOneWidget);
      expect(find.text('Missing pricing version'), findsOneWidget);
      expect(find.text('Historical costs are never recalculated silently'),
          findsOneWidget);
      expect(find.text('Keep the active filters when switching metrics.'),
          findsOneWidget);
      expect(find.text('View token analytics'), findsOneWidget);
    });

    testWidgets('renders M05 Query error state accurately', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(analyticsQueryErrorJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Analytics'), findsAtLeastNWidgets(1));
      expect(find.text('QUERY FAILED'), findsOneWidget);
      expect(find.text('State specification · Query failed'), findsOneWidget);
      expect(find.text('Couldn’t load this analysis'), findsOneWidget);
      expect(
          find.text('The analytics query failed before results were returned.'),
          findsOneWidget);
      expect(find.text('No partial chart shown'), findsOneWidget);
      expect(find.text('No previous valid model data is preserved'),
          findsOneWidget);
      expect(find.text('Safe to retry'), findsOneWidget);
      expect(
          find.text('Filters and date range remain selected'), findsOneWidget);
      expect(find.text('Expose a clear retry action.'), findsOneWidget);
      expect(find.text('Retry analysis'), findsOneWidget);
    });

    testWidgets('renders M05 Offline state accurately', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(analyticsOfflineJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Analytics'), findsAtLeastNWidgets(1));
      expect(find.text('OFFLINE'), findsOneWidget);
      expect(find.text('State specification · Offline'), findsOneWidget);
      expect(find.text('Analytics needs a connection'), findsOneWidget);
      expect(
          find.text(
              'This filtered view is not available from the local cache.'),
          findsOneWidget);
      expect(find.text('Dashboard may still work'), findsOneWidget);
      expect(find.text('Previously loaded summaries remain available'),
          findsOneWidget);
      expect(find.text('Query is paused'), findsOneWidget);
      expect(find.text('Reconnect to load this breakdown'), findsOneWidget);
      expect(find.text('Distinguish cached overview from uncached analytics.'),
          findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('renders M06 No usage state with back chevron accurately',
        (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(breakdownNoUsageJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Daily breakdown'), findsOneWidget);
      expect(find.text('NO USAGE'), findsOneWidget);
      expect(find.text('State specification · No usage'), findsOneWidget);
      expect(find.text('No activity on this day'), findsOneWidget);
      expect(
          find.text(
              'No supported AI usage was recorded for the selected date.'),
          findsOneWidget);
      expect(find.text('Daily total is unknown'), findsOneWidget);
      expect(find.text('Do not display zero unless confirmed'), findsOneWidget);
      expect(find.text('Choose another day'), findsAtLeastNWidgets(1));
      expect(find.text('Nearby days may contain activity'), findsOneWidget);
      expect(find.text('Keep date navigation available.'), findsOneWidget);
    });

    testWidgets('renders M06 Today incomplete state accurately',
        (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(breakdownTodayIncompleteJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Daily breakdown'), findsOneWidget);
      expect(find.text('IN PROGRESS'), findsOneWidget);
      expect(find.text('State specification · In progress'), findsOneWidget);
      expect(find.text('Today is still in progress'), findsOneWidget);
      expect(
          find.text(
              'New usage can continue to arrive until the local day ends.'),
          findsOneWidget);
      expect(find.text('Totals are provisional'), findsOneWidget);
      expect(
          find.text('Time stamps follow the device timezone'), findsOneWidget);
      expect(find.text('Sync may update the chart'), findsOneWidget);
      expect(find.text('New bars appear after day close'), findsOneWidget);
      expect(find.text('Mark incomplete periods without hiding current data.'),
          findsOneWidget);
      expect(find.text('View current totals'), findsOneWidget);
    });

    testWidgets('renders M06 Missing data state accurately', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(breakdownMissingDataJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Daily breakdown'), findsOneWidget);
      expect(find.text('PARTIAL DATA'), findsOneWidget);
      expect(find.text('State specification · Partial data'), findsOneWidget);
      expect(find.text('Part of this day is missing'), findsOneWidget);
      expect(find.text('One source or time window did not sync completely.'),
          findsOneWidget);
      expect(find.text('Available activity is shown'), findsOneWidget);
      expect(find.text('Missing intervals stay explicit'), findsOneWidget);
      expect(find.text('Contributor totals may differ'), findsOneWidget);
      expect(find.text('Retry when desktop is online'), findsOneWidget);
      expect(
          find.text('Show the affected interval and source.'), findsOneWidget);
      expect(find.text('View available data'), findsOneWidget);
    });

    testWidgets('renders M06 Cost unavailable state accurately',
        (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(breakdownCostUnavailableJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Daily breakdown'), findsOneWidget);
      expect(find.text('COST UNAVAILABLE'), findsOneWidget);
      expect(
          find.text('State specification · Cost unavailable'), findsOneWidget);
      expect(find.text('Daily cost can’t be calculated'), findsOneWidget);
      expect(
          find.text(
              'Token and request data are present, but model pricing is unavailable.'),
          findsOneWidget);
      expect(find.text('Daily token total is valid'), findsOneWidget);
      expect(find.text('Only the cost field is unavailable'), findsOneWidget);
      expect(find.text('Pricing review available'), findsOneWidget);
      expect(find.text('No \$0.00 placeholder is used'), findsOneWidget);
      expect(find.text('Keep token evidence visible.'), findsOneWidget);
      expect(find.text('View model pricing'), findsOneWidget);
    });

    testWidgets('renders M07 Analyzing state with Insights tab active',
        (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(insightsAnalyzingJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Insights'), findsAtLeastNWidgets(1));
      expect(find.text('ANALYZING'), findsOneWidget);
      expect(find.text('State specification · Analyzing'), findsOneWidget);
      expect(find.text('Analyzing recent usage'), findsOneWidget);
      expect(
          find.text(
              'The optimizer is reviewing aggregate token, cost, latency and error patterns.'),
          findsOneWidget);
      expect(find.text('Privacy-safe evidence'), findsOneWidget);
      expect(find.text('No prompts, responses or source code'), findsOneWidget);
      expect(find.text('Minimum history required'), findsOneWidget);
      expect(
          find.text('Results appear after analysis completes'), findsOneWidget);
      expect(find.text('Keep existing insights visible during re-analysis.'),
          findsOneWidget);
      expect(find.text('View current insights'), findsOneWidget);

      // Verify bottom navigation tabs
      expect(find.text('Tokens'), findsOneWidget);
      expect(find.text('Analytics'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('renders M07 Insufficient data state accurately',
        (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(insightsInsufficientDataJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Insights'), findsAtLeastNWidgets(1));
      expect(find.text('NOT ENOUGH DATA'), findsOneWidget);
      expect(
          find.text('State specification · Not enough data'), findsOneWidget);
      expect(find.text('More usage is needed'), findsOneWidget);
      expect(
          find.text(
              'Insights require at least 3 days or 10 daily model records.'),
          findsOneWidget);
      expect(find.text('Current history is too short'), findsOneWidget);
      expect(find.text('No recommendations generated yet'), findsOneWidget);
      expect(find.text('Tracking is active'), findsOneWidget);
      expect(find.text('Continue using supported AI tools'), findsOneWidget);
      expect(
          find.text('Explain the threshold instead of showing an empty feed.'),
          findsOneWidget);
      expect(find.text('View usage'), findsOneWidget);
    });

    testWidgets('renders M07 No significant issues state accurately',
        (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(insightsNoSignificantIssuesJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Insights'), findsAtLeastNWidgets(1));
      expect(find.text('ALL CLEAR'), findsOneWidget);
      expect(find.text('State specification · All clear'), findsOneWidget);
      expect(find.text('No significant issues found'), findsOneWidget);
      expect(
          find.text(
              'Recent usage is within its normal pattern and no reliable optimization stands out.'),
          findsOneWidget);
      expect(find.text('Analysis completed'), findsOneWidget);
      expect(find.text('Models and projects were compared'), findsOneWidget);
      expect(find.text('Keep collecting usage'), findsOneWidget);
      expect(find.text('New activity may reveal opportunities later'),
          findsOneWidget);
      expect(
          find.text(
              'A positive empty state should still show analysis freshness.'),
          findsOneWidget);
      expect(find.text('Review analytics'), findsOneWidget);
    });

    testWidgets('renders M07 Analysis failed state accurately', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(insightsAnalysisFailedJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Insights'), findsAtLeastNWidgets(1));
      expect(find.text('ANALYSIS FAILED'), findsOneWidget);
      expect(
          find.text('State specification · Analysis failed'), findsOneWidget);
      expect(find.text('Insights couldn’t be generated'), findsOneWidget);
      expect(find.text('The aggregate usage analysis did not complete.'),
          findsOneWidget);
      expect(find.text('Usage data is still safe'), findsOneWidget);
      expect(find.text('No records were changed'), findsOneWidget);
      expect(find.text('Retry available'), findsOneWidget);
      expect(
          find.text('The same analysis window will be used'), findsOneWidget);
      expect(find.text('Do not surface unverified partial recommendations.'),
          findsOneWidget);
      expect(find.text('Analyze again'), findsOneWidget);
    });

    testWidgets('renders M07 Insights stale state accurately', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(insightsStaleJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Insights'), findsAtLeastNWidgets(1));
      expect(find.text('INSIGHTS ARE STALE'), findsOneWidget);
      expect(find.text('State specification · Insights are stale'),
          findsOneWidget);
      expect(find.text('New usage isn’t reflected yet'), findsOneWidget);
      expect(
          find.text(
              'These recommendations were generated before the latest desktop sync.'),
          findsOneWidget);
      expect(find.text('Last analyzed · 2 days ago'), findsOneWidget);
      expect(find.text('Evidence may have changed'), findsOneWidget);
      expect(find.text('Re-analysis recommended'), findsOneWidget);
      expect(find.text('Old insights remain readable'), findsOneWidget);
      expect(find.text('Show generated and last-sync timestamps together.'),
          findsOneWidget);
      expect(find.text('Analyze latest usage'), findsOneWidget);
    });

    testWidgets('renders M08 Insight stale state accurately', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(insightDetailStaleJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Insight detail'), findsOneWidget);
      expect(find.text('STALE'), findsOneWidget);
      expect(find.text('State specification · Stale'), findsOneWidget);
      expect(find.text('This insight may be outdated'), findsOneWidget);
      expect(
          find.text(
              'Its evidence period ends before the most recent usage update.'),
          findsOneWidget);
      expect(find.text('Original finding preserved'), findsOneWidget);
      expect(find.text('You can still inspect the prior evidence'),
          findsOneWidget);
      expect(find.text('Confidence reduced'), findsOneWidget);
      expect(find.text('Re-analysis may change the recommendation'),
          findsOneWidget);
      expect(find.text('Never silently rewrite historical evidence.'),
          findsOneWidget);
      expect(find.text('Back to insights'), findsOneWidget);
    });

    testWidgets('renders M08 Insight resolved state accurately',
        (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(insightDetailResolvedJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Insight detail'), findsOneWidget);
      expect(find.text('RESOLVED'), findsOneWidget);
      expect(find.text('State specification · Resolved'), findsOneWidget);
      expect(find.text('Marked as addressed'), findsOneWidget);
      expect(
          find.text(
              'This recommendation is no longer active in the current workflow.'),
          findsOneWidget);
      expect(find.text('Resolution recorded'), findsOneWidget);
      expect(find.text('The underlying evidence remains available'),
          findsOneWidget);
      expect(find.text('Can be revisited'), findsOneWidget);
      expect(
          find.text('New data may create a separate insight'), findsOneWidget);
      expect(
          find.text('Keep status, created date and resolution date visible.'),
          findsOneWidget);
      expect(find.text('Back to insights'), findsOneWidget);
    });

    testWidgets('renders M08 Evidence unavailable state accurately',
        (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(insightDetailEvidenceUnavailableJson)
            as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Insight detail'), findsOneWidget);
      expect(find.text('EVIDENCE UNAVAILABLE'), findsOneWidget);
      expect(find.text('State specification · Evidence unavailable'),
          findsOneWidget);
      expect(find.text('Supporting data isn’t available'), findsOneWidget);
      expect(
          find.text(
              'The source records for this recommendation were removed or are no longer accessible.'),
          findsOneWidget);
      expect(find.text('Recommendation is preserved'), findsOneWidget);
      expect(find.text('It cannot be independently verified'), findsOneWidget);
      expect(find.text('No new action suggested'), findsOneWidget);
      expect(find.text('Re-analyze current usage instead'), findsOneWidget);
      expect(find.text('Avoid presenting estimated savings without evidence.'),
          findsOneWidget);
      expect(find.text('Back to insights'), findsOneWidget);
    });

    testWidgets('renders M09 No desktop state with Settings tab active',
        (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(settingsNoDesktopJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsAtLeastNWidgets(1));
      expect(find.text('NOT CONNECTED'), findsOneWidget);
      expect(find.text('State specification · Not connected'), findsOneWidget);
      expect(find.text('No desktop companion connected'), findsOneWidget);
      expect(find.text('Automatic usage tracking requires a paired desktop.'),
          findsOneWidget);
      expect(find.text('Historical data remains'), findsOneWidget);
      expect(find.text('Existing usage is still available'), findsOneWidget);
      expect(find.text('New usage paused'), findsOneWidget);
      expect(
          find.text('Connect a desktop to resume collection'), findsOneWidget);
      expect(find.text('Show the state in the settings summary row.'),
          findsOneWidget);
      expect(find.text('Connect desktop'), findsOneWidget);

      // Verify bottom nav items
      expect(find.text('Tokens'), findsOneWidget);
      expect(find.text('Analytics'), findsOneWidget);
      expect(find.text('Insights'), findsOneWidget);
    });

    testWidgets('renders M09 Notifications denied state', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(settingsNotificationsDeniedJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsNothing);
      expect(find.text('Settings'), findsAtLeastNWidgets(1));
      expect(find.text('NOTIFICATIONS OFF'), findsOneWidget);
      expect(
          find.text('State specification · Notifications off'), findsOneWidget);
      expect(find.text('Budget alerts are disabled'), findsOneWidget);
      expect(
          find.text(
              'μToken cannot display system notifications for budget thresholds.'),
          findsOneWidget);
      expect(find.text('Budgets still calculate'), findsOneWidget);
      expect(find.text('Alert history remains inside the app'), findsOneWidget);
      expect(find.text('OS permission required'), findsOneWidget);
      expect(
          find.text('Enable notifications in system settings'), findsOneWidget);
      expect(find.text('Do not imply budget tracking is disabled.'),
          findsOneWidget);
      expect(find.text('Review budget alerts'), findsOneWidget);
    });

    testWidgets('renders M09 Reauthentication required state', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(settingsReauthenticationRequiredJson)
            as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsNothing);
      expect(find.text('Settings'), findsAtLeastNWidgets(1));
      expect(find.text('REAUTHENTICATE'), findsOneWidget);
      expect(find.text('State specification · Reauthenticate'), findsOneWidget);
      expect(find.text('Account verification required'), findsOneWidget);
      expect(
          find.text(
              'A sensitive account or data action needs a fresh Google sign-in.'),
          findsOneWidget);
      expect(find.text('Current session is read-only'), findsOneWidget);
      expect(find.text('Dashboard previews are available'), findsOneWidget);
      expect(find.text('Sensitive actions paused'), findsOneWidget);
      expect(find.text('Re-authenticate to continue'), findsOneWidget);
      expect(find.text('Block only actions that require fresh authentication.'),
          findsOneWidget);
      expect(find.text('Open account'), findsOneWidget);
    });

    testWidgets('renders M10 Syncing state', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(desktopConnectionSyncingJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Desktop connection'), findsOneWidget);
      expect(find.text('SYNCING'), findsOneWidget);
      expect(find.text('State specification · Syncing'), findsOneWidget);
      expect(find.text('Syncing from desktop'), findsOneWidget);
      expect(
          find.text(
              'The companion is scanning local Antigravity usage and uploading aggregate changes.'),
          findsOneWidget);
      expect(find.text('Collector is online'), findsOneWidget);
      expect(find.text('Only changed aggregates are uploaded'), findsOneWidget);
      expect(find.text('Current data remains visible'), findsOneWidget);
      expect(find.text('Last successful sync is preserved'), findsOneWidget);
      expect(find.text('Prevent duplicate sync jobs.'), findsOneWidget);
      expect(find.text('View connection'), findsOneWidget);
    });

    testWidgets('renders M10 Offline state', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(desktopConnectionOfflineJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Desktop connection'), findsOneWidget);
      expect(find.text('OFFLINE'), findsOneWidget);
      expect(find.text('State specification · Offline'), findsOneWidget);
      expect(find.text('Desktop companion is offline'), findsOneWidget);
      expect(
          find.text(
              'No new usage can be collected until the desktop app reconnects.'),
          findsOneWidget);
      expect(find.text('Last seen · 26m ago'), findsOneWidget);
      expect(find.text('Historical usage remains available'), findsOneWidget);
      expect(find.text('New events stay local'), findsOneWidget);
      expect(find.text('Open the desktop companion'), findsOneWidget);
      expect(find.text('Show last seen and last successful sync separately.'),
          findsOneWidget);
      expect(find.text('Retry connection'), findsOneWidget);
    });

    testWidgets('renders M10 Source not found state', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(desktopConnectionSourceNotFoundJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Desktop connection'), findsOneWidget);
      expect(find.text('SOURCE MISSING'), findsOneWidget);
      expect(find.text('State specification · Source missing'), findsOneWidget);
      expect(find.text('Antigravity wasn’t found'), findsOneWidget);
      expect(
          find.text(
              'The companion cannot locate a supported local Antigravity installation.'),
          findsOneWidget);
      expect(find.text('Collector is running'), findsOneWidget);
      expect(find.text('Ensure path could not be resolved'), findsOneWidget);
      expect(find.text('Setup help available'), findsOneWidget);
      expect(find.text('Check installation and sign-in'), findsOneWidget);
      expect(find.text('Do not describe this as a permission error.'),
          findsOneWidget);
      expect(find.text('Open setup guide'), findsOneWidget);
    });

    testWidgets('renders M10 No usage state', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(desktopConnectionNoUsageJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Desktop connection'), findsOneWidget);
      expect(find.text('NO USAGE YET'), findsOneWidget);
      expect(find.text('State specification · No usage yet'), findsOneWidget);
      expect(find.text('Connected, but no usage found'), findsOneWidget);
      expect(find.text('The collector is ready and the source is accessible.'),
          findsOneWidget);
      expect(find.text('Permission granted'), findsOneWidget);
      expect(find.text('No supported activity was logged or recorded'),
          findsOneWidget);
      expect(find.text('Waiting for first session'), findsOneWidget);
      expect(find.text('Start using Antigravity on desktop'), findsOneWidget);
      expect(find.text('Never show all metrics to zero before first activity.'),
          findsOneWidget);
      expect(find.text('View usage'), findsOneWidget);
    });

    testWidgets('renders M10 Permission denied state', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(desktopConnectionPermissionDeniedJson)
            as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Desktop connection'), findsOneWidget);
      expect(find.text('PERMISSION DENIED'), findsOneWidget);
      expect(
          find.text('State specification · Permission denied'), findsOneWidget);
      expect(find.text('Usage permission is blocked'), findsOneWidget);
      expect(
          find.text('The desktop companion cannot read local usage metadata.'),
          findsOneWidget);
      expect(find.text('Collector is connected'), findsOneWidget);
      expect(find.text('Cloud account remains linked'), findsOneWidget);
      expect(find.text('User action required'), findsOneWidget);
      expect(find.text('Grant access in desktop settings'), findsOneWidget);
      expect(find.text('State the exact affected permission.'), findsOneWidget);
      expect(find.text('View permission help'), findsOneWidget);
    });

    testWidgets('renders M10 Session revoked state', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(desktopConnectionSessionRevokedJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Desktop connection'), findsOneWidget);
      expect(find.text('SESSION REVOKED'), findsOneWidget);
      expect(
          find.text('State specification · Session revoked'), findsOneWidget);
      expect(find.text('Desktop session was revoked'), findsOneWidget);
      expect(
          find.text(
              'This companion can no longer upload usage for the account.'),
          findsOneWidget);
      expect(find.text('New syncs are rejected'), findsOneWidget);
      expect(find.text('Past data is preserved'), findsOneWidget);
      expect(find.text('Pair again required'), findsOneWidget);
      expect(find.text('Create a new one-time code'), findsOneWidget);
      expect(
          find.text('Do not auto-restore a revoked session.'), findsOneWidget);
      expect(find.text('Pair desktop again'), findsOneWidget);
    });

    testWidgets('renders M10 Incompatible version state', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(desktopConnectionIncompatibleVersionJson)
            as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Desktop connection'), findsOneWidget);
      expect(find.text('UPDATE REQUIRED'), findsOneWidget);
      expect(
          find.text('State specification · Update required'), findsOneWidget);
      expect(find.text('Desktop app needs an update'), findsOneWidget);
      expect(
          find.text(
              'This companion version is no longer compatible with the sync service.'),
          findsOneWidget);
      expect(find.text('Collection paused'), findsOneWidget);
      expect(find.text('Local usage is not deleted'), findsOneWidget);
      expect(find.text('Update required'), findsOneWidget);
      expect(find.text('Install the latest official version'), findsOneWidget);
      expect(find.text('Keep the minimum supported version visible.'),
          findsOneWidget);
      expect(find.text('View install guide'), findsOneWidget);
    });

    testWidgets('renders M10 Sync failed state', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(desktopConnectionSyncFailedJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Desktop connection'), findsOneWidget);
      expect(find.text('SYNC FAILED'), findsOneWidget);
      expect(find.text('State specification · Sync failed'), findsOneWidget);
      expect(find.text('Latest sync failed'), findsOneWidget);
      expect(
          find.text(
              'The collector could read local usage but could not finish the upload.'),
          findsOneWidget);
      expect(find.text('Local queue retained'), findsOneWidget);
      expect(find.text('Events will not be lost'), findsOneWidget);
      expect(find.text('Retry available'), findsOneWidget);
      expect(find.text('Network or service issue detected'), findsOneWidget);
      expect(find.text('Separate collection success from upload failure.'),
          findsOneWidget);
      expect(find.text('Retry sync'), findsOneWidget);
    });

    testWidgets('renders M11 No budget state', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(budgetNoBudgetJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Budget & alerts'), findsOneWidget);
      expect(find.text('NOT SET'), findsOneWidget);
      expect(find.text('State specification · Not set'), findsOneWidget);
      expect(find.text('Set a monthly budget'), findsOneWidget);
      expect(
          find.text(
              'Choose a spending limit to track estimated AI cost against it.'),
          findsOneWidget);
      expect(find.text('Optional for tracking'), findsOneWidget);
      expect(
          find.text('Usage analysis works without a budget'), findsOneWidget);
      expect(find.text('Alerts need a threshold'), findsOneWidget);
      expect(
          find.text('Notifications can be enabled afterward'), findsOneWidget);
      expect(find.text('Do not show a zero-dollar budget as an active limit.'),
          findsOneWidget);
      expect(find.text('Set budget'), findsOneWidget);
    });

    testWidgets('renders M11 Near threshold state', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(budgetNearThresholdJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Budget & alerts'), findsOneWidget);
      expect(find.text('NEAR THRESHOLD'), findsOneWidget);
      expect(find.text('State specification · Near threshold'), findsOneWidget);
      expect(find.text('Approaching your alert level'), findsOneWidget);
      expect(
          find.text(
              'Estimated cost is close to the next configured threshold.'),
          findsOneWidget);
      expect(find.text(r'74% of $50 used'), findsOneWidget);
      expect(find.text(r'$36.82 estimated remaining'), findsOneWidget);
      expect(find.text('Largest contributor · Gemini'), findsOneWidget);
      expect(
          find.text('Review usage before changing threshold'), findsOneWidget);
      expect(find.text('Use estimated cost language consistently.'),
          findsOneWidget);
      expect(find.text('View budget'), findsOneWidget);
    });

    testWidgets('renders M11 Threshold exceeded state', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(budgetThresholdExceededJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Budget & alerts'), findsOneWidget);
      expect(find.text('ALERT TRIGGERED'), findsOneWidget);
      expect(
          find.text('State specification · Alert triggered'), findsOneWidget);
      expect(find.text('Budget alert threshold reached'), findsOneWidget);
      expect(
          find.text('Estimated monthly cost crossed a configured alert level.'),
          findsOneWidget);
      expect(find.text('90% threshold reached'), findsOneWidget);
      expect(
          find.text('One notification created for this month'), findsOneWidget);
      expect(find.text('Budget is not exceeded yet'), findsOneWidget);
      expect(find.text('Tracking continues normally'), findsOneWidget);
      expect(find.text('Deduplicate alerts per threshold and month.'),
          findsOneWidget);
      expect(find.text('View contributing usage'), findsOneWidget);
    });

    testWidgets('renders M11 Budget exceeded state', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(budgetBudgetExceededJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Budget & alerts'), findsOneWidget);
      expect(find.text('BUDGET EXCEEDED'), findsOneWidget);
      expect(
          find.text('State specification · Budget exceeded'), findsOneWidget);
      expect(find.text('Estimated cost is over budget'), findsOneWidget);
      expect(
          find.text('Current usage has exceeded the monthly spending limit.'),
          findsOneWidget);
      expect(find.text(r'$63.20 of $50 estimated'), findsOneWidget);
      expect(find.text('This is not a provider invoice'), findsOneWidget);
      expect(find.text('Collection continues'), findsOneWidget);
      expect(find.text('μToken does not block AI tools'), findsOneWidget);
      expect(find.text('Never imply that model access was restricted.'),
          findsOneWidget);
      expect(find.text('Review usage'), findsOneWidget);
    });

    testWidgets('renders M11 Cost unavailable state', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(budgetCostUnavailableJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Budget & alerts'), findsOneWidget);
      expect(find.text('COST UNAVAILABLE'), findsOneWidget);
      expect(
          find.text('State specification · Cost unavailable'), findsOneWidget);
      expect(find.text('Budget status can’t be calculated'), findsOneWidget);
      expect(
          find.text('One or more models are missing a valid pricing version.'),
          findsOneWidget);
      expect(find.text('Budget remains configured'), findsOneWidget);
      expect(find.text('Thresholds are not evaluated'), findsOneWidget);
      expect(find.text('Token tracking continues'), findsOneWidget);
      expect(find.text('Resolve pricing to restore alerts'), findsOneWidget);
      expect(find.text('Suspend cost alerts instead of treating cost as zero.'),
          findsOneWidget);
      expect(find.text('View model pricing'), findsOneWidget);
    });

    testWidgets('renders M11 Notifications off state', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(budgetNotificationsOffJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Budget & alerts'), findsOneWidget);
      expect(find.text('NOTIFICATIONS OFF'), findsOneWidget);
      expect(
          find.text('State specification · Notifications off'), findsOneWidget);
      expect(find.text('System alerts are disabled'), findsOneWidget);
      expect(
          find.text(
              'Budget thresholds still calculate, but push notifications cannot be delivered.'),
          findsOneWidget);
      expect(find.text('In-app history remains'), findsOneWidget);
      expect(find.text('Alerts appear when the app is opened'), findsOneWidget);
      expect(find.text('OS permission required'), findsOneWidget);
      expect(find.text('Turn on notifications in system settings'),
          findsOneWidget);
      expect(
          find.text(
              'Separate notification delivery from threshold calculation.'),
          findsOneWidget);
      expect(find.text('Review alert settings'), findsOneWidget);
    });

    testWidgets('renders M12 Export preparing state', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(privacyExportPreparingJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Privacy & data'), findsOneWidget);
      expect(find.text('PREPARING EXPORT'), findsOneWidget);
      expect(
          find.text('State specification · Preparing export'), findsOneWidget);
      expect(find.text('Preparing your export'), findsOneWidget);
      expect(
          find.text('Collecting usage summaries into machine-readable files.'),
          findsOneWidget);
      expect(find.text('CSV and JSON requested'), findsOneWidget);
      expect(find.text('Prompts and response content are never stored'),
          findsOneWidget);
      expect(find.text('Keep the app open'), findsOneWidget);
      expect(
          find.text('Download becomes available when ready'), findsOneWidget);
      expect(find.text('Prevent duplicate export jobs.'), findsOneWidget);
      expect(find.text('Back to data settings'), findsOneWidget);
    });

    testWidgets('renders M12 Export ready state', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(privacyExportSuccessJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Privacy & data'), findsOneWidget);
      expect(find.text('EXPORT READY'), findsOneWidget);
      expect(find.text('State specification · Export ready'), findsOneWidget);
      expect(find.text('Your export is ready'), findsOneWidget);
      expect(
          find.text('Usage data was prepared successfully.'), findsOneWidget);
      expect(find.text('12,842 usage records'), findsOneWidget);
      expect(find.text('CSV and JSON are available'), findsOneWidget);
      expect(find.text('Generated just now'), findsOneWidget);
      expect(
          find.text('File download link expires for security'), findsOneWidget);
      expect(find.text('Show scope, record count, and generation time.'),
          findsOneWidget);
      expect(find.text('Open export'), findsOneWidget);
    });

    testWidgets('renders M12 Export failed state', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(privacyExportFailedJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Privacy & data'), findsOneWidget);
      expect(find.text('EXPORT FAILED'), findsOneWidget);
      expect(find.text('State specification · Export failed'), findsOneWidget);
      expect(find.text('Couldn’t prepare the export'), findsOneWidget);
      expect(find.text('The data job stopped before the files were created.'),
          findsOneWidget);
      expect(find.text('No incomplete file downloaded'), findsOneWidget);
      expect(find.text('Your cloud data is unchanged'), findsOneWidget);
      expect(find.text('Safe to retry'), findsOneWidget);
      expect(find.text('Another local copy may be requested'), findsOneWidget);
      expect(find.text('Retain the selected export format.'), findsOneWidget);
      expect(find.text('Retry export'), findsOneWidget);
    });

    testWidgets('renders M12 Deleting usage state', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(privacyDeletingUsageJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Privacy & data'), findsOneWidget);
      expect(find.text('DELETING'), findsOneWidget);
      expect(find.text('State specification · Deleting'), findsOneWidget);
      expect(find.text('Deleting usage data'), findsOneWidget);
      expect(
          find.text(
              'Removing cloud usage summaries while keeping the account active.'),
          findsOneWidget);
      expect(find.text('Desktop connection remains'), findsOneWidget);
      expect(find.text('New usage may arrive after delete'), findsOneWidget);
      expect(find.text('This can’t be undone'), findsOneWidget);
      expect(find.text('The operation may take a moment'), findsOneWidget);
      expect(find.text('Disable repeated destructive actions while running.'),
          findsOneWidget);
      expect(find.text('View data settings'), findsOneWidget);
    });

    testWidgets('renders M12 Delete success state', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(privacyDeleteSuccessJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Privacy & data'), findsOneWidget);
      expect(find.text('DELETED'), findsOneWidget);
      expect(find.text('State specification · Deleted'), findsOneWidget);
      expect(find.text('Usage data deleted'), findsOneWidget);
      expect(find.text('The selected cloud usage history has been removed.'),
          findsOneWidget);
      expect(find.text('Account remains active'), findsOneWidget);
      expect(find.text('Google sign-in was not removed'), findsOneWidget);
      expect(find.text('Desktop may collect new usage'), findsOneWidget);
      expect(find.text('Disconnect it to stop future syncs'), findsOneWidget);
      expect(find.text('State exactly what remains after deletion.'),
          findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('renders M12 Delete partial state', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(privacyDeletePartialJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Privacy & data'), findsOneWidget);
      expect(find.text('PARTIAL DELETION'), findsOneWidget);
      expect(
          find.text('State specification · Partial deletion'), findsOneWidget);
      expect(find.text('Some data couldn’t be deleted'), findsOneWidget);
      expect(
          find.text(
              'The deletion completed only for part of the selected scope.'),
          findsOneWidget);
      expect(find.text('Completed items are gone'), findsOneWidget);
      expect(
          find.text('They will not be restored automatically'), findsOneWidget);
      expect(find.text('Remaining items need attention'), findsOneWidget);
      expect(find.text('Retry or contact support with the job ID'),
          findsOneWidget);
      expect(find.text('Expose partial completion instead of generic failure.'),
          findsOneWidget);
      expect(find.text('Review remaining data'), findsOneWidget);
    });

    testWidgets('renders M12 Reauthentication state', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(privacyReauthenticationJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Privacy & data'), findsOneWidget);
      expect(find.text('REAUTHENTICATE'), findsOneWidget);
      expect(find.text('State specification · Reauthenticate'), findsOneWidget);
      expect(find.text('Verify your account to continue'), findsOneWidget);
      expect(
          find.text(
              'Exporting or deleting sensitive account data requires a fresh Google sign-in.'),
          findsOneWidget);
      expect(find.text('Current data is unchanged'), findsOneWidget);
      expect(find.text('No operation has started'), findsOneWidget);
      expect(find.text('Verification expires'), findsOneWidget);
      expect(find.text('Complete the action promptly after sign-in'),
          findsOneWidget);
      expect(find.text('Return to the pending action after verification.'),
          findsOneWidget);
      expect(find.text('Verify with Google'), findsOneWidget);
    });

    testWidgets('renders M13 Reauthentication state', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(accountReauthenticationJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('REAUTHENTICATE'), findsOneWidget);
      expect(find.text('State specification · Reauthenticate'), findsOneWidget);
      expect(find.text('Confirm it’s you'), findsOneWidget);
      expect(
          find.text(
              'This account action requires a recent Google authentication.'),
          findsOneWidget);
      expect(find.text('Profile remains signed in'), findsOneWidget);
      expect(find.text('Normal analytics is still available'), findsOneWidget);
      expect(find.text('Sensitive action paused'), findsOneWidget);
      expect(find.text('Continues after verification'), findsOneWidget);
      expect(find.text('Do not wipe the local account prematurely.'),
          findsOneWidget);
      expect(find.text('Verify account'), findsOneWidget);
    });

    testWidgets('renders M13 Signing out state', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(accountSigningOutJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('SIGNING OUT'), findsOneWidget);
      expect(find.text('State specification · Signing out'), findsOneWidget);
      expect(find.text('Signing out of this phone'), findsOneWidget);
      expect(
          find.text('Ending the mobile session without deleting cloud usage.'),
          findsOneWidget);
      expect(find.text('Cloud data is retained'), findsOneWidget);
      expect(find.text('You can sign in again later'), findsOneWidget);
      expect(find.text('Desktop remains linked'), findsOneWidget);
      expect(find.text('Revoke it separately if needed'), findsOneWidget);
      expect(find.text('Make sign-out and account deletion visibly different.'),
          findsOneWidget);
      expect(find.text('Return to welcome'), findsOneWidget);
    });

    testWidgets('renders M13 Deleting account state', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(accountDeletingAccountJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('DELETING ACCOUNT'), findsOneWidget);
      expect(
          find.text('State specification · Deleting account'), findsOneWidget);
      expect(find.text('Deleting your account'), findsOneWidget);
      expect(
          find.text(
              'Revoking connected devices and removing account-owned cloud data.'),
          findsOneWidget);
      expect(find.text('Desktop access revoked'), findsOneWidget);
      expect(find.text('New syncs will be rejected'), findsOneWidget);
      expect(find.text('Deletion is permanent'), findsOneWidget);
      expect(find.text('Some backend cleanup may continue'), findsOneWidget);
      expect(
          find.text('Block navigation until the backend confirms completion.'),
          findsOneWidget);
      expect(find.text('View account status'), findsOneWidget);
    });

    testWidgets('renders M13 Delete failed state', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(accountDeleteFailedJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('DELETION FAILED'), findsOneWidget);
      expect(
          find.text('State specification · Deletion failed'), findsOneWidget);
      expect(find.text('Account deletion didn’t finish'), findsOneWidget);
      expect(
          find.text(
              'The account is still active because a required cleanup step failed.'),
          findsOneWidget);
      expect(find.text('Sign-in remains valid'), findsOneWidget);
      expect(find.text('Data is safe'), findsOneWidget);
      expect(find.text('No silent partial deletion'), findsOneWidget);
      expect(find.text('Review the error before trying again'), findsOneWidget);
      expect(find.text('Keep the user informed of retained access.'),
          findsOneWidget);
      expect(find.text('Retry deletion'), findsOneWidget);
    });

    testWidgets('renders M13 Delete partial state', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(accountDeletePartialJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('PARTIAL DELETION'), findsOneWidget);
      expect(
          find.text('State specification · Partial deletion'), findsOneWidget);
      expect(find.text('Account cleanup is incomplete'), findsOneWidget);
      expect(
          find.text(
              'Some account data or device sessions still require removal.'),
          findsOneWidget);
      expect(find.text('Completed cleanup is permanent'), findsOneWidget);
      expect(find.text('Removed items cannot be restored'), findsOneWidget);
      expect(find.text('Follow-up required'), findsOneWidget);
      expect(find.text('A job reference is available for support'),
          findsOneWidget);
      expect(
          find.text(
              'List remaining resources explicitly in log/export status.'),
          findsOneWidget);
      expect(find.text('Review account'), findsOneWidget);
    });

    testWidgets('renders M07 AI not set up state', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(insightsAiNotSetUpJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsNothing);
      expect(find.text('Insights'), findsWidgets);
      expect(find.text('AI NOT SET UP'), findsOneWidget);
      expect(find.text('State specification · AI not set up'), findsOneWidget);
      expect(find.text('Choose an AI model'), findsOneWidget);
      expect(
          find.text(
              'Suggestions are written by an LLM you pick. Add a provider and API key to start.'),
          findsOneWidget);
      expect(find.text('No provider configured'), findsOneWidget);
      expect(find.text('Settings > AI suggestions'), findsOneWidget);
      expect(find.text('Your usage is still tracked'), findsOneWidget);
      expect(find.text('Key stays on this phone'), findsOneWidget);
      expect(
          find.text(
              'Show this instead of the feed when no API key is saved. The button opens M15.'),
          findsOneWidget);
      expect(find.text('Set up AI suggestions'), findsOneWidget);
    });

    testWidgets('renders M15 Invalid API key state', (tester) async {
      final mockData = SigningInStateData.fromJson(
        jsonDecode(aiSuggestionsInvalidApiKeyJson) as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateDataProvider.overrideWith((ref) => mockData),
          ],
          child: const MaterialApp(home: SigningInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsNothing);
      expect(find.text('AI suggestions'), findsOneWidget);
      expect(find.text('KEY REJECTED'), findsOneWidget);
      expect(
          find.text('State specification · Invalid API key'), findsOneWidget);
      expect(find.text('The provider rejected this key'), findsOneWidget);
      expect(
          find.text('Check the key or quota, then test the connection again.'),
          findsOneWidget);
      expect(find.text('Provider'), findsOneWidget);
      expect(find.text('OpenAI · gpt-4.5-mini'), findsOneWidget);
      expect(find.text('Previous suggestions'), findsOneWidget);
      expect(find.text('Still present in Insights'), findsOneWidget);
      expect(
          find.text(
              'Keep old suggestions visible and show AI_PROVIDER_ERROR here after Test connection or scheduled run.'),
          findsOneWidget);
      expect(find.text('Edit API key'), findsOneWidget);
    });
  });
}
