# Final UI Dark - screen/state coverage audit

Source: Figma file ULjJf6asJEKslR4Y4yT4QI, page 1:4 (07 - Final UI Dark). Checked 2026-11-08.

**Inventory result: 25/25 M/O/S screens and 74/74 named per-screen states have implementation entries. No missing inventory entries found.**

For the 24 exported frames, each dark fixture node ID was matched to the live Figma node ID, and the route manifest was checked. M08 uses the dedicated InsightDetailScreen and /insight-detail route.
For all 74 named states, the check matched screen ID + state type to an existing JSON fixture, traced its repository loader and confirmed a selector in main_preview.dart. The enum has 75 entries because insightDetailActive represents the normal M08 screen, not an additional Figma state.

## Scope and limits

- Rechecked live page 1:4 on 2026-11-08 after M05B/M05C and S01-S04 work: the 25 M/O/S frame IDs still match the 24-frame route manifest plus the dedicated M08 route. No additional main frame was found. This does not certify all named state layouts.
- S01-S04 now use the shared repository for sync preview data. S03 has a deterministic 64% arc and an added Complete demo sync button to return to M04; it does not run a collector or network sync. Dark render captures cover all 25 M/O/S frames.

- This establishes inventory and manual preview access, not pixel-perfect parity or automatic state transitions.
- The state gallery is reachable from the long-press screen index via UI state preview. Most states are manually selected there; they are not automatically triggered from normal screen actions.
- Updated 2026-11-08: M01-M04's 23 states, M05's seven, M06's five, M07's six, M08's three, M09's three, M10's eight, M11's six, M12's seven M13's five and M15's Invalid API key now use source-matched layout metadata and original SVG assets (74 reviewed states total). No named state remains to review. M05-M13 selectors, recovery destinations and bottom tabs are connected for mock preview; usage tabs retain the selected period. M07/M10 retry opens their progress fixtures; M08 preserves evidence; M09-M13 previews do not perform real permission, authentication, deletion or notification operations. M12 export count uses shared sample records. M13 verification/retry can be cancelled; account cleanup/status dialogs use clearly labeled mock resources and job IDs.
- Updated 2026-11-08: M08 now uses source-matched Dark layout JSON, original local SVGs and insight_detail_active.json through FigmaMockRepository. Its normal content is no longer hard-coded in the widget.
- Read-only Figma screenshots were sampled for M04 Initial loading and M05 No data. No full screenshot-to-render comparison of all 99 frames was performed. A later 2026-11-08 review compared the 16 M01-M13 main frames, including M04B/M05B/M05C; see FIGMA_DARK_MAIN_REVIEW.md.
- Resolved during the M01-M04 review: the Initial loading action now uses the light background/text colors from Figma. The other 22 reviewed state actions also use their source-specific colors and positions.
- Existing validation from the merge: flutter analyze passed, 90 mobile tests passed, and the preview Android APK built successfully. Those checks were not rerun solely for this read-only inventory review.

## Per-screen state counts

| Screen | Figma named states | Matched |
| --- | ---: | ---: |
| M01 | 5 | 5 |
| M02 | 8 | 8 |
| M03 | 4 | 4 |
| M04 | 6 | 6 |
| M05 | 7 | 7 |
| M06 | 5 | 5 |
| M07 | 6 | 6 |
| M08 | 3 | 3 |
| M09 | 3 | 3 |
| M10 | 8 | 8 |
| M11 | 6 | 6 |
| M12 | 7 | 7 |
| M13 | 5 | 5 |
| M15 | 1 | 1 |

## Main / overlay / S frames

| Figma frame | Source file in mobile/ | Status |
| --- | --- | --- |
| [M04 — Tokens Overview](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=6-134) | lib/core/mock/data/figma_dark_02.json | Present |
| [M05 — Analytics](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=6-233) | lib/core/mock/data/figma_dark_03.json | Present |
| [M06 — Daily Breakdown](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=6-295) | lib/core/mock/data/figma_dark_05.json | Present |
| [M07 — Insights](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=6-351) | lib/core/mock/data/figma_dark_05.json | Present |
| [M09 — Settings](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=6-440) | lib/core/mock/data/figma_dark_06.json | Present |
| [M10 — Desktop Connection](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=6-493) | lib/core/mock/data/figma_dark_06.json | Present |
| [M11 — Budget](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=6-528) | lib/core/mock/data/figma_dark_07.json | Present |
| [M12 — Privacy](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=6-562) | lib/core/mock/data/figma_dark_07.json | Present |
| [M13 — Account](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=6-597) | lib/core/mock/data/figma_dark_08.json | Present |
| [M01 — Welcome](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=6-628) | lib/core/mock/data/figma_dark_01.json | Present |
| [M02 — Connect Desktop](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=6-643) | lib/core/mock/data/figma_dark_01.json | Present |
| [M03 — Install Guide](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=6-669) | lib/core/mock/data/figma_dark_02.json | Present |
| [O01 — Confirmations](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=6-695) | lib/core/mock/data/figma_dark_08.json | Present |
| [O02 — Budget Alert](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=6-718) | lib/core/mock/data/figma_dark_09.json | Present |
| [M04B — Usage Details](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=11-14) | lib/core/mock/data/figma_dark_03.json | Present |
| [M14 — Model pricing](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=38-46) | lib/core/mock/data/figma_dark_09.json | Present |
| [O03 — Cost breakdown](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=38-100) | lib/core/mock/data/figma_dark_10.json | Present |
| [S01 — Desktop not connected](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=82-149) | lib/core/mock/data/figma_dark_11.json | Present |
| [S02 — Waiting for first usage](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=82-203) | lib/core/mock/data/figma_dark_11.json | Present |
| [S03 — Syncing usage](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=82-273) | lib/core/mock/data/figma_dark_12.json | Present |
| [S04 — Sync failed](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=82-325) | lib/core/mock/data/figma_dark_12.json | Present |
| [M08 — Insight Detail](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-3849) | lib/features/insights/presentation/insight_detail_screen.dart | Present |
| [M15 — AI Suggestions](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=149-3332) | lib/core/mock/data/figma_dark_10.json | Present |
| [M05B — Efficiency](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=158-3417) | lib/core/mock/data/figma_dark_04.json | Present |
| [M05C — Model comparison](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=161-3484) | lib/core/mock/data/figma_dark_04.json | Present |

## Named per-screen states

| Figma frame | Mock file in mobile/ | Enum / gallery selector |
| --- | --- | --- |
| [STATE / M01 / Signing in](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=93-258) | assets/data/mocks/auth_signing_in.json | signingIn |
| [STATE / M01 / Sign-in cancelled](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=93-289) | assets/data/mocks/auth_sign_in_cancelled.json | cancelled |
| [STATE / M01 / Sign-in failed](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=93-320) | assets/data/mocks/auth_sign_in_failed.json | failed |
| [STATE / M01 / Offline](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=93-351) | assets/data/mocks/auth_sign_in_offline.json | offline |
| [STATE / M01 / Session expired](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=93-382) | assets/data/mocks/auth_session_expired.json | sessionExpired |
| [STATE / M02 / Verifying](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=93-413) | assets/data/mocks/pairing_verifying.json | verifying |
| [STATE / M02 / Pairing success](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=93-445) | assets/data/mocks/pairing_connected.json | connected |
| [STATE / M02 / Wrong code](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=93-477) | assets/data/mocks/pairing_wrong_code.json | wrongCode |
| [STATE / M02 / Code expired](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=93-509) | assets/data/mocks/pairing_code_expired.json | codeExpired |
| [STATE / M02 / Code already used](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=93-541) | assets/data/mocks/pairing_code_already_used.json | codeAlreadyUsed |
| [STATE / M02 / Desktop no response](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=93-573) | assets/data/mocks/pairing_desktop_no_response.json | desktopNoResponse |
| [STATE / M02 / Existing desktop](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=93-605) | assets/data/mocks/pairing_existing_desktop.json | existingDesktop |
| [STATE / M02 / Network error](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=93-637) | assets/data/mocks/pairing_network_error.json | networkError |
| [STATE / M03 / Unsupported OS](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=93-669) | assets/data/mocks/install_unsupported_os.json | unsupportedOs |
| [STATE / M03 / App not installed](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=93-701) | assets/data/mocks/install_app_not_installed.json | appNotInstalled |
| [STATE / M03 / App not opened](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=93-733) | assets/data/mocks/install_app_not_opened.json | appNotOpened |
| [STATE / M03 / Permission denied](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=93-765) | assets/data/mocks/install_permission_denied.json | permissionDenied |
| [STATE / M04 / Initial loading](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=93-797) | assets/data/mocks/tokens_initial_loading.json | initialLoading |
| [STATE / M04 / Updating with data](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=93-878) | assets/data/mocks/tokens_updating_with_data.json | updatingWithData |
| [STATE / M04 / Partial data](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-514) | assets/data/mocks/tokens_partial_data.json | partialData |
| [STATE / M04 / Desktop offline](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-599) | assets/data/mocks/tokens_desktop_offline.json | desktopOffline |
| [STATE / M04 / Stale data](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-684) | assets/data/mocks/tokens_stale_data.json | staleData |
| [STATE / M04 / Cost unavailable](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-769) | assets/data/mocks/tokens_cost_unavailable.json | costUnavailable |
| [STATE / M05 / No data](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-854) | assets/data/mocks/analytics_no_data.json | analyticsNoData |
| [STATE / M05 / No filter results](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-963) | assets/data/mocks/analytics_no_filter_results.json | analyticsNoFilterResults |
| [STATE / M05 / Partial data](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-1072) | assets/data/mocks/analytics_partial_data.json | analyticsPartialData |
| [STATE / M05 / Unsupported metric](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-1181) | assets/data/mocks/analytics_unsupported_metric.json | analyticsUnsupportedMetric |
| [STATE / M05 / Cost unavailable](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-1290) | assets/data/mocks/analytics_cost_unavailable.json | analyticsCostUnavailable |
| [STATE / M05 / Query error](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-1399) | assets/data/mocks/analytics_query_error.json | analyticsQueryError |
| [STATE / M05 / Offline](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-1508) | assets/data/mocks/analytics_offline.json | analyticsOffline |
| [STATE / M06 / No usage](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-1617) | assets/data/mocks/breakdown_no_usage.json | breakdownNoUsage |
| [STATE / M06 / Today incomplete](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-1702) | assets/data/mocks/breakdown_today_incomplete.json | breakdownTodayIncomplete |
| [STATE / M06 / Missing data](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-1787) | assets/data/mocks/breakdown_missing_data.json | breakdownMissingData |
| [STATE / M06 / Cost unavailable](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-1872) | assets/data/mocks/breakdown_cost_unavailable.json | breakdownCostUnavailable |
| [STATE / M06 / Sync delayed](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-1957) | assets/data/mocks/breakdown_sync_delayed.json | breakdownSyncDelayed |
| [STATE / M07 / Analyzing](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-2042) | assets/data/mocks/insights_analyzing.json | insightsAnalyzing |
| [STATE / M07 / Insufficient data](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-2151) | assets/data/mocks/insights_insufficient_data.json | insightsInsufficientData |
| [STATE / M07 / No significant issues](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-2260) | assets/data/mocks/insights_no_significant_issues.json | insightsNoSignificantIssues |
| [STATE / M07 / Analysis failed](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-2369) | assets/data/mocks/insights_analysis_failed.json | insightsAnalysisFailed |
| [STATE / M07 / Insights stale](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-2478) | assets/data/mocks/insights_stale.json | insightsStale |
| [STATE / M08 / Insight stale](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-2587) | assets/data/mocks/insight_detail_stale.json | insightDetailStale |
| [STATE / M08 / Insight resolved](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-2672) | assets/data/mocks/insight_detail_resolved.json | insightDetailResolved |
| [STATE / M08 / Evidence unavailable](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-2757) | assets/data/mocks/insight_detail_evidence_unavailable.json | insightDetailEvidenceUnavailable |
| [STATE / M09 / No desktop](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-2842) | assets/data/mocks/settings_no_desktop.json | settingsNoDesktop |
| [STATE / M09 / Notifications denied](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-2951) | assets/data/mocks/settings_notifications_denied.json | settingsNotificationsDenied |
| [STATE / M09 / Reauthentication required](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-3060) | assets/data/mocks/settings_reauthentication_required.json | settingsReauthenticationRequired |
| [STATE / M10 / Syncing](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-3169) | assets/data/mocks/desktop_connection_syncing.json | desktopConnectionSyncing |
| [STATE / M10 / Offline](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-3254) | assets/data/mocks/desktop_connection_offline.json | desktopConnectionOffline |
| [STATE / M10 / Source not found](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-3339) | assets/data/mocks/desktop_connection_source_not_found.json | desktopConnectionSourceNotFound |
| [STATE / M10 / No usage](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-3424) | assets/data/mocks/desktop_connection_no_usage.json | desktopConnectionNoUsage |
| [STATE / M10 / Permission denied](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-3509) | assets/data/mocks/desktop_connection_permission_denied.json | desktopConnectionPermissionDenied |
| [STATE / M10 / Session revoked](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-3594) | assets/data/mocks/desktop_connection_session_revoked.json | desktopConnectionSessionRevoked |
| [STATE / M10 / Incompatible version](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-3679) | assets/data/mocks/desktop_connection_incompatible_version.json | desktopConnectionIncompatibleVersion |
| [STATE / M10 / Sync failed](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-3764) | assets/data/mocks/desktop_connection_sync_failed.json | desktopConnectionSyncFailed |
| [STATE / M11 / No budget](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-3929) | assets/data/mocks/budget_no_budget.json | budgetNoBudget |
| [STATE / M11 / Near threshold](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-4014) | assets/data/mocks/budget_near_threshold.json | budgetNearThreshold |
| [STATE / M11 / Threshold exceeded](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-4099) | assets/data/mocks/budget_threshold_exceeded.json | budgetThresholdExceeded |
| [STATE / M11 / Budget exceeded](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-4184) | assets/data/mocks/budget_budget_exceeded.json | budgetBudgetExceeded |
| [STATE / M11 / Cost unavailable](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-4269) | assets/data/mocks/budget_cost_unavailable.json | budgetCostUnavailable |
| [STATE / M11 / Notifications off](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-4354) | assets/data/mocks/budget_notifications_off.json | budgetNotificationsOff |
| [STATE / M12 / Export preparing](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-4439) | assets/data/mocks/privacy_export_preparing.json | privacyExportPreparing |
| [STATE / M12 / Export success](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-4524) | assets/data/mocks/privacy_export_success.json | privacyExportSuccess |
| [STATE / M12 / Export failed](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-4609) | assets/data/mocks/privacy_export_failed.json | privacyExportFailed |
| [STATE / M12 / Deleting usage](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-4694) | assets/data/mocks/privacy_deleting_usage.json | privacyDeletingUsage |
| [STATE / M12 / Delete success](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-4779) | assets/data/mocks/privacy_delete_success.json | privacyDeleteSuccess |
| [STATE / M12 / Delete partial](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-4864) | assets/data/mocks/privacy_delete_partial.json | privacyDeletePartial |
| [STATE / M12 / Reauthentication](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-4949) | assets/data/mocks/privacy_reauthentication.json | privacyReauthentication |
| [STATE / M13 / Reauthentication](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-5034) | assets/data/mocks/account_reauthentication.json | accountReauthentication |
| [STATE / M13 / Signing out](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-5119) | assets/data/mocks/account_signing_out.json | accountSigningOut |
| [STATE / M13 / Deleting account](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-5204) | assets/data/mocks/account_deleting_account.json | accountDeletingAccount |
| [STATE / M13 / Delete failed](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-5289) | assets/data/mocks/account_delete_failed.json | accountDeleteFailed |
| [STATE / M13 / Delete partial](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=94-5374) | assets/data/mocks/account_delete_partial.json | accountDeletePartial |
| [STATE / M07 / AI not set up](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=153-3329) | assets/data/mocks/insights_ai_not_set_up.json | insightsAiNotSetUp |
| [STATE / M15 / Invalid API key](https://www.figma.com/design/ULjJf6asJEKslR4Y4yT4QI?node-id=153-3383) | assets/data/mocks/ai_suggestions_invalid_api_key.json | aiSuggestionsInvalidApiKey |

## M01-M04 Dark review

Reviewed source contexts: M01, M02, M03, M04, M04B and all 23 states under M01-M04. Main canvases retain their exported layers and source assets. State layout now uses the source 390 x 844 reference canvas, 350 x 260 card at (20,142), source-specific illustrations/dots/divider, header colors, and actions at y=736 (M01-M03) or y=700 (M04). No screenshot is used as implementation artwork.

The original 20 SVG assets used by these states are stored in assets/figma/reviewed/. All state content remains in the mock JSON files, including layout metadata. Other screen-state designs were left on their original renderer.

Preview defaults to Dark. Hold a main-screen title, then select its M01/M02/M03/M04 UI states entry. The reviewed state title also opens a selector on long press. Continue with Google, pairing verification and Refresh open mock UI states; no real authentication, pairing or sync is claimed by these navigation helpers.

Verification: test/m01_m04_design_test.dart checks all 23 actual fixtures, source card/action geometry, local non-empty assets and clickable controls, then renders M01-M04/M04B and the states with real fonts. PNGs are generated under build/m01-m04-review/rendered/ for visual review. They are review artifacts, not a pixel-diff pass against approved golden images. The merged router test also checks navigation from a reviewed state tab and pairing-success action.

Latest M01-M04 verification: flutter analyze reports no issues; all 92 mobile tests pass, including Retry from M01, M04 state tab navigation, and M02 Connected -> waiting-first-usage. The updated APK was not rebuilt for this UI-only review; use the Flutter preview entrypoint to run the latest source.

## Final state audit ? 2026-11-08

Live Dark page metadata contains 25 main/overlay/S frames and 74 named states. All 74 state source node IDs match reviewed JSON layouts, with referenced local assets present. The 24 exported main-frame IDs match the live source; M08 remains the dedicated route. M15 uses source node 153:3383, the original Neutral illustration, source copy and the action at y=700. Edit API key opens the existing M15 demo configuration; it does not send credentials or detect real provider rejection.
