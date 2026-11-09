# μToken Mobile UI – Figma implementation

## Scope

Live `main.dart` now replaces M02/M10/S02 with real Firebase pairing views; all
usage screens remain fixtures. `main_ui_preview.dart` preserves the original
Figma canvases and mock pairing/state controls. See [PAIRING.md](../PAIRING.md).

24 Figma frames (20 M/O screens and 4 S01-S04 state screens) are implemented for Light and Dark at the 390 x 844 source size.

The original Figma file was accessed in read-only mode. No Figma layers or styles were modified.

## Source of truth

- lib/core/mock/data/figma_light_01.json through figma_light_12.json: original Light layers.
- lib/core/mock/data/figma_dark_01.json through figma_dark_12.json: original Dark layers.
- lib/core/mock/data/figma_proto_hotspots.json: clickable prototype regions.
- lib/core/mock/data/figma_navigation_targets.json: navigation targets.
- assets/figma/*.svg: original exported vector layers and provider icons.
- assets/fonts/: Be Vietnam Pro font (including its OFL license).

The FigmaMockRepository loads presentation fixtures. The FigmaPixelScreen widget renders source layers without hard-coding sample numbers, labels, text, colors, or images in the widget implementation.

## Local development

After combining the UI branches, `main_ui_preview.dart` opens the shared router without Firebase credentials. The 24 exported frames are preserved. The hand-built M08 Insight Detail and the state gallery from `main_preview.dart` are also available: hold a screen title and choose `M08 - Insight detail` or `UI state preview`. Tapping `Trim repeated context` on Insights opens M08. The `/auth/signing-in` route and the former `/analytics/efficiency` link are retained.

Both branches' mock assets and fonts are included in pubspec.yaml. Android retains the existing `com.example.utoken_mobile` application ID and Gradle/plugin versions, while including the incoming Android 9 minimum and notification desugaring support.

The live Figma Light/Dark pages include M08 and additional per-screen states beyond the exported 24-frame manifest. Passing widget tests establishes render/navigation behavior, not pixel-perfect parity for every state or backend functionality. A full visual review of the combined implementation is still needed.

To preview the UI without Firebase credentials, run flutter pub get, then flutter run -t lib/main_ui_preview.dart.

To verify, run flutter analyze and flutter test.

The real app entrypoint requires team-provided Firebase configuration. Prototype navigation is available, while actual Google sign-in, syncing, export, deletion, budget saving and AI API calls belong to their respective backend features; UI tap targets do not fake those operations.

## Included frames

M01, M02, M03, M04, M04B, M05, M05B, M05C, M06, M07, M09, M10, M11, M12, M13, M14, M15, O01, O02, O03, S01, S02, S03, S04.

S01, S02, S03 and S04 are now included and reachable through the preview screen index.

## UI preview interactions

Presentation-layer interactions are configured in lib/core/mock/data/figma_demo_interactions.json, separate from the original read-only Figma exports. Tokens and Analytics period chips, dashboard drill-downs, suggestion cards, Settings entries, and primary bottom tabs respond to taps. Test these with flutter test test/figma_interaction_test.dart.

Actions that need real backend access (Google authentication, sync, delete, export and API-key connectivity) show a preview-only notice instead of silently ignoring taps or claiming to have succeeded. M04 Tokens period selection loads separate Day/Week/Month/Total fixtures from lib/core/mock/data/tokens_periods.json through FigmaMockRepository.tokensScreen. Metrics, source shares/model counts and chart update together; the selected tab uses the original design highlight. The 7-day and 30-day comparison cards remain rolling summaries. M05 Analytics now shares those period totals; M04B usage details, M05B efficiency and M07 suggestions receive the chosen period through navigation. M05C task sizes and M06 Daily/Project grouping also load business fixtures. M06 column headers toggle ascending/descending sort. Data for these six screens is in lib/core/mock/data/usage_explorer.json and loaded through FigmaMockRepository.usageScreen. M04B activity/recent days and M06 show the fixture history independently of the overview period. Comparison ranks are task-size fixtures; they do not vary by period. M01-M03 have no usage period filter. These are deterministic UI fixtures, not live API data.

## Exported frame navigation and testing

- All 24 Figma frames (20 M/O, S01-S04) have Light and Dark mock fixtures.
- All original click targets and destinations were checked against the source Figma file and saved in lib/core/mock/data/figma_verified_prototype_graph.json.
- The four bottom navigation items have viewport-aligned 68-unit touch targets. Tests assert actual route changes.
- Long-press the title at the top of any page to open the screen index: 24 exported frame IDs plus the dedicated M08 route (25 main/overlay/S screens). This allows direct inspection of screens with no incoming prototype transition.
- Actions needing backend services show an explicit demo-only notice rather than claiming a real sync, login, download or deletion.
- No Figma file content was modified. No merge into main.

## M09-M13 session mocks

Settings/account defaults and option lists are in `lib/core/mock/data/settings_session.json`, loaded through `FigmaMockRepository.settingsData/settingsScreen`. Choices are shared in memory for this preview session and reset on app restart. Language selection changes the preference label only; preview copy remains English. Compact/Full updates usage number formatting across M04-M07 and M10. Sync interval, background sync and diagnostics are mock flags, not OS/background services.

M11 edits a local draft; Save applies it to the session and updates M09. Back discards it. Budget progress is calculated from the Month fixture and capped at the bar width when over budget. M10 disconnect/reconnect updates M09/M13 connection labels; Sync now retains the existing S03 navigation and only updates the mock timestamp. Delete confirmations simulate a request and keep real data and fixtures intact. Export and sign-out retain their existing UI routes; no Firebase calls or file export were added.

M08 Dark was reviewed against live Figma on 2026-11-08. It now reads `insight_detail_active.json` through the shared repository and uses `figma_dark_13.json` plus original local SVGs. Back, bottom navigation and Mark reviewed are connected for UI preview. See `FIGMA_DARK_MAIN_REVIEW.md` for main-screen review scope and retained mock differences.

Main-screen follow-up: Full numbers in the usage renderer keep their design font size and use a one-line scale-down fit to the field width. Recommendation savings now have separate `contextSavings` and `cacheSavings` fields in `usage_explorer.json`; M07 computes their sum and M08 formats its cost from the Month `contextSavings` value. The Month total is $13.60 ($8.40 context + $5.20 caching). State screens were not changed.

## O01-O03 and M14-M15 mock interactions

`lib/core/mock/data/extra_screens.json` contains the sample catalog, cost-example inputs, alert preview values and AI model/key choices. `FigmaMockRepository.extraScreen` binds those to the existing design exports.

- O01 generates CSV/JSON preview text from the same eight sample daily records used to calculate its count, totals and provider mix. The preview can be copied; no file is saved and no cloud export runs.
- O02 is reachable through the notification preview button in Budget. It uses the saved mock limit and a clearly labeled simulated alert. View usage and Dismiss remain connected.
- O03 calculates the three cost components from the same sample rate catalog displayed by M14. Close/outside tap returns to the previous route, or Tokens when opened directly.
- M14 displays sample rates, not verified current provider prices. Back to settings returns to M09.
- M15 provider/model choices update the session mock and the M09 AI summary. Demo-key controls use presets only; no real key is entered, stored or transmitted. Test connection stays on M15 and simulates success/missing-key results without network requests.
- All changes target main screens/overlays; named state screens were not changed.

Validation for O01-O03/M14-M15: all 114 mobile tests pass; analyzer reports no issues. Dark render captures now include all 21 main/overlay frames in the review scope. No native-device run or real provider request was performed.

## M05B/M05C and S01-S04 follow-up

Reviewed these six Dark frames against live Figma on 2026-11-08. M05B retains the period-specific efficiency mock; M05C retains Small/Medium/Large task fixtures and navigation back to Efficiency / onward to Insights.

`lib/core/mock/data/sync_preview.json` supplies provider readiness, sample progress, last successful sync and queued events through `FigmaMockRepository.syncScreen`. S01 Connect desktop opens M02; S02 Refresh and S04 Retry open S03; S04 Desktop connection opens M10. An added Complete demo sync button on S03 updates the session's mock timestamp and returns to M04. Progress stays deterministic for design review; no timer, collector or Firebase sync runs. Sample usage totals remain unchanged.

Fixed the S03 full-circle export to render its 64% arc, S02's oval halo, and zero-height horizontal SVG strokes in S01-S04. Render capture coverage now includes all 25 main/overlay/S frames. The named per-screen state implementation is outside this follow-up.

Validation: 116 mobile tests passed; `flutter analyze --no-pub` reports no issues. No native-device run or real sync was performed.

## M05 Analytics states

Reviewed all seven M05 Dark state frames against live Figma on 2026-11-08: No data, No filter results, Partial data, Unsupported metric, Cost unavailable, Query error and Offline. Their existing JSON fixtures now contain source-matched copy and layout metadata for `ReviewedStateView`, including original local SVG illustrations/dots and the active Analytics navigation icons.

Hold the Analytics title, choose M05 - UI states, then select a state. The date period is passed into the state route. Change date range opens a Day/Week/Month/Total picker; cancelling keeps the state. Recovery buttons return to the normal M05 sample analytics for the selected period, and bottom tabs retain the period on usage screens. Clear filters / retry / metric recovery are UI preview destinations, not real filter or query operations; they do not mutate usage fixtures or claim a real sync.

M01-M04's 23 reviewed states remain covered separately. With the seven M05 states reviewed, 30 of the 74 named states have source-matched review coverage; 44 remain to review (M06 onward).

Validation: all 118 mobile tests passed; analyzer reports no issues. `analytics_states_test.dart` renders all seven real fixtures, checks source anchors/local assets/active tab, and exercises recovery, date-range selection, navigation and the Analytics state picker. Render artifacts are under `build/dark-review/m05-states/`; they are visual review captures, not an approved pixel-diff golden test. No device or real backend test was performed.

## M06 Daily Breakdown states

Reviewed the five Dark frames against live Figma on 2026-11-08: No usage, Today incomplete, Missing data, Cost unavailable and Sync delayed. The `breakdown_*.json` fixtures now supply matching copy, original local SVGs, Analytics active navigation and source action placement (y=708) to the shared reviewed renderer.

Hold the Daily usage title, choose M06 - UI states, then select a state. Choose another day opens dates from the shared usage mock; cancellation leaves the state unchanged. Choosing a date opens M06 and highlights that record's date/tokens/chats in green. Sorting preserves the selected record; Project grouping hides the date highlight. The date is a selection, not a filter or a change to usage data. View current totals / View available data open the existing sample table, View model pricing opens M14 and View connection opens M10. These routes can return to the state with Back. Directly opened state Back returns to M06 with the selected period; bottom tabs and the state picker retain period context.

No collector, sync service, model-price request or data repair runs. The provisional/missing/delayed conditions are manual preview fixtures. Source review coverage is now 35/74 named states; 39 remain from M07 onward.

Validation: all 121 mobile tests passed; analyzer reports no issues. `breakdown_states_test.dart` checks all five source canvases/assets, selected-day sorting and fixture preservation, date-picker cancellation/selection, recovery destinations, Back, state picker and bottom tabs. Captures are in `build/dark-review/m06-states/`. No device or real backend test was performed.

## M07 Insights states

Reviewed all six Dark frames against live Figma on 2026-11-08: Analyzing, Insufficient data, No significant issues, Analysis failed, Insights stale and AI not set up. Their `insights_*.json` fixtures contain source copy/layout metadata and original local illustrations/dots, including the active Insights navigation SVG. The AI-not-set-up fixture now uses the canonical nested format rather than duplicate legacy fields with stale text encoding.

Hold the Insights title, choose M07 - UI states, then select a state. View current insights returns to the period's sample recommendations; View usage opens M04; Review analytics opens M05. Analyze again / Analyze latest usage open the Analyzing fixture with the same period. Its action returns to sample recommendations; no timed analysis or provider request runs. Set up AI suggestions opens the existing M15 mock configuration, and Back returns to the originating state. Opening this manual fixture does not erase existing demo AI settings or derive readiness from them. Bottom tabs and the picker retain the selected usage period.

These are manual mock scenarios; there is no live AI analysis, history-threshold enforcement or key transmission. Source review coverage is now 41/74 named states; 33 remain from M08 onward.

Validation: all 123 mobile tests passed; analyzer reports no issues. `insights_states_test.dart` renders all six source canvases and checks local assets, Unicode copy, active navigation, retry/re-analysis, recovery routes, AI setup/Back, picker and period retention. Captures are under `build/dark-review/m07-states/`. No device or real backend test was performed.

## M08 Insight Detail states

Reviewed the three Dark frames against live Figma on 2026-11-08: Insight stale, Insight resolved and Evidence unavailable. `insight_detail_stale/resolved/evidence_unavailable.json` now supply source copy, local illustrations/dots, Insights active navigation and action placement (y=708) to the shared reviewed renderer.

Hold the Insight detail title, choose M08 - UI states, then select a state. Back pops to the originating detail route, or opens normal M08 with the same period when a state was opened directly. Back to insights opens M07 for that period. Bottom tabs retain period context. The dedicated M08 route now receives the period from M07; this is navigation context only and does not re-date or recalculate the historical Month evidence fixture. Evidence unavailable shows the source explanatory state without estimated savings or a new recommendation action.

These are manual mock scenarios. Resolved is separate from the normal detail's existing Mark reviewed UI action, and viewing states does not rewrite evidence or change the recommendation's stored status. Review coverage is now 44/74 named states; 30 remain from M09 onward.

Validation: all 125 mobile tests passed; analyzer reports no issues. `insight_detail_states_test.dart` captures all three source canvases, checks missing-evidence presentation and exercises M07-to-M08 period transfer, state picker, Back/deep-link fallback, recovery, bottom tabs and evidence immutability. Captures are under `build/dark-review/m08-states/`. No device or real backend test was performed.

## M09 Settings states

Reviewed all three Dark frames against live Figma on 2026-11-08: No desktop, Notifications denied and Reauthentication required. `settings_no_desktop/notifications_denied/reauthentication_required.json` contain source copy, local illustration/dots, active Settings navigation and action layout. Legacy flattened fields were normalized so obsolete text encoding cannot override the source copy.

Hold the Settings title, choose M09 - UI states, then select a state. Connect desktop opens M02, Review budget alerts opens M11 and Open account opens M13. Back returns to the originating preview state. Bottom tabs retain the state route's period on usage screens; Settings itself has no period filter. Opening a preview does not disconnect the sample desktop, change budget settings or sign out the sample account.

These are independent manual mock scenarios, not permission requests or authentication enforcement. Budget tracking remains available while previewing notification denial; OS notification permissions are not changed. Reauthentication is not performed and sensitive-operation authorization is not implemented by these UI fixtures. Source review coverage is now 47/74 named states; 27 remain from M10 onward.

Validation: all 127 mobile tests passed; analyzer reports no issues. `settings_states_test.dart` checks all three source canvases/assets, Unicode copy, active Settings tab, recovery/Back, picker, usage navigation and preference preservation. The render test loads Windows Arial as a fallback for the source's Greek mu character. Captures are under `build/dark-review/m09-states/`. No device, OS-permission or real authentication test was performed.

## M10 Desktop Connection states

Reviewed all eight Dark frames against live Figma on 2026-11-08: Syncing, Offline, Source not found, No usage, Permission denied, Session revoked, Incompatible version and Sync failed. The `desktop_connection_*.json` fixtures now use source copy, original local illustrations/dots, Settings active navigation and action placement (y=708); duplicate legacy fields were removed.

Hold the Desktop connection title, choose M10 - UI states, then select a state. Offline/Sync failed Retry opens M10's Syncing fixture; View connection opens normal M10. Source not found/Incompatible version open M03, No usage opens S02 (waiting for first activity), and Session revoked opens M02 for fresh pairing. Destination screens support return via Back; S02 uses the system Back gesture/button. A directly opened state's Back falls back to M10 with its period. The picker and usage tabs retain period context.

View permission help opens a dismissible demo popup; its text is centralized in `extra_screens.json` under `desktopPermissionHelp`. It does not open OS settings, request permissions, run a sync job or restore a revoked session. Preview navigation leaves the mock connection/settings intact; no automatic retry timer, reconnect or data upload runs. Source review coverage is now 55/74 named states; 19 remain from M11 onward.

Validation: all 129 mobile tests passed; analyzer reports no issues. `desktop_connection_states_test.dart` captures all eight source canvases and checks recovery/retry transitions, pairing/install guides, empty usage, help-popup dismissal, Back/deep-link fallback, state picker, tabs and preference preservation. Captures are under `build/dark-review/m10-states/`. No device, real sync, permission or session-revocation test was performed.

## M11 Budget states

Reviewed the six Dark frames against live Figma on 2026-11-08: No budget, Near threshold, Threshold exceeded, Budget exceeded, Cost unavailable and Notifications off. The `budget_*.json` fixtures now contain source copy, original local illustrations/dots, Settings active navigation and source action layout (y=708), without duplicate legacy fields. Near threshold now correctly displays 74% of $60 used and $15.60 remaining; Budget exceeded uses the source's $63.20 of $60 example. These fixed scenario examples are independent of the editable session limit.

Hold the Budget title, choose M11 - UI states, then select a state. Set budget / View budget / Review alert settings open normal M11's existing session editor. Contributing/review usage opens M05, and View model pricing opens M14. Back returns to the source state; Analytics uses system Back. A directly opened state's Back falls back to M11. The state picker and usage navigation preserve period context. Draft changes are discarded by Back; the existing Save action remains the way to commit session-only budget settings.

These are manual mock previews: opening a state does not overwrite the saved limit, issue notifications, deduplicate alerts, restrict AI tools or recalculate the source examples. Cost unavailable does not display a $0.00 placeholder. Permission changes and actual alert delivery remain unimplemented. Source review coverage is now 61/74 named states; 13 remain from M12 onward.

Validation: all 131 mobile tests passed; analyzer reports no issues. `budget_states_test.dart` renders all six source canvases, checks source amounts and remaining-budget arithmetic, missing-cost presentation, recovery routes, draft discard, Back/deep-link fallback, state picker, tabs and preference preservation. Captures are under `build/dark-review/m11-states/`. No device or actual notification/billing test was performed.

## M12 Privacy states

Reviewed all seven Dark frames against live Figma on 2026-11-08: Export preparing, Export success, Export failed, Deleting usage, Delete success, Delete partial and Reauthentication. `privacy_*.json` now supply source copy/layout metadata, original local illustrations/dots, Settings active navigation and action placement (y=708), without stale duplicate fields.

Hold the Privacy title, choose M12 - UI states, then select a state. Preparing/deleting/Done actions open normal M12; Back returns to the source state. Retry export opens the Preparing fixture. Open export opens O01's existing CSV/JSON previews; no file is saved. Export-ready count is dynamically bound by AuthMockRepository to the same sample records used by O01 and its CSV/JSON payloads (eight records rather than Figma's illustrative 12,842). Other source copy about export generation/download expiry is illustrative; no job or download link exists.

Review remaining data opens a cancellable demo popup with a mock job ID and pending-scope labels; Preview retry opens Deleting usage without removing records. Verify with Google opens a separate cancellable demo popup; Simulate verified opens Preparing export, representing a pending export in this manual scenario. No OAuth session is created or refreshed. Popup copy is centralized under `privacyVerification` / `privacyPartialDeletion` in `extra_screens.json`.

The state picker, Back/deep-link fallback and usage tabs preserve period context. These previews do not execute deletion, revoke sessions, create background jobs or mutate export records/preferences. Source review coverage is now 68/74 named states; six remain across M13 and M15.

Validation: all 134 mobile tests passed; analyzer reports no issues. `privacy_states_test.dart` checks shared export counts, all seven source canvases/assets, CSV/JSON previews, retry, popup cancellation/confirmation, Back/deep-link fallback, state picker, tabs and unchanged records/preferences. Captures are under `build/dark-review/m12-states/`. No device, file-download, real deletion or Google reauthentication test was performed.

## M13 Account states

Reviewed all five Dark frames against live Figma on 2026-11-08: Reauthentication, Signing out, Deleting account, Delete failed and Delete partial. The `account_*.json` fixtures now contain source copy/layout metadata, local illustrations/dots, active Settings navigation and source action placement (y=708), without duplicate legacy fields.

Hold the Account title, choose M13 - UI states, then select a state. Verify account opens a cancellable demo popup; Simulate verified opens normal M13 and Back returns to the state. Return to welcome navigates to M01 only. Retry deletion opens a cancellable demo popup; confirmation opens the Deleting account fixture. View account status / Review account open read-only demo dialogs with a mock job reference and pending/remaining resource labels. Copy is centralized under `accountStateDialogs` in `extra_screens.json`.

The state picker, Back/deep-link fallback and usage tabs retain period context. No verification, sign-out, device revocation, cleanup or deletion is executed; source wording describes the selected scenario. Dialogs do not auto-complete a deletion or restore deleted data. Record payloads and mock account/settings remain unchanged. Review coverage is now 73/74 named states; only M15 Invalid API key remains.

Validation: all 136 mobile tests passed; analyzer reports no issues. `account_states_test.dart` captures all five source canvases, checks verification/retry cancellation and confirmation, Welcome navigation, deletion status/remaining-resource dialogs, Back/deep-link fallback, state picker, tabs and unchanged records/preferences. Captures are under `build/dark-review/m13-states/`. No device, actual sign-out, Google verification or account-deletion test was performed.

## M15 Invalid API key ? final Dark state review (2026-11-08)

- Source node 153:3383: original SVGs, source copy/model, Settings dock and action at y=700.
- Long-press AI suggestions title, then M15 - UI states. Edit API key opens the existing demo configuration and Back returns to the preview. Viewing this state does not clear usage or change the saved demo key.
- Live inventory audit: 25 main/overlay/S frames and 74 named states; no missing source IDs or referenced state assets. All named states now have reviewed layouts and selectors.
- Provider errors remain manually selected mock previews. No real API key submission, scheduled AI run or device/backend validation is included.
- Final validation: all 138 Flutter tests pass; flutter analyze --no-pub reports no issues. git diff --check passes (existing line-ending warning only). No physical-device validation performed.

## Navigation audit (2026-11-08)

- Checked the main route manifest, all 74 reviewed state recovery actions, shared Back/tab handling, and 62 navigation/demo route entries. All configured destinations resolve. Existing M05-M15 tests cover recovery/pickers/dialog cancellation; the added navigation_recovery_test covers earlier-state gaps.
- Fixed M04 View connection -> M10, Sync now -> S03, M02 Review connection -> M10. M03 permission/requirements actions now show session-only help from the shared mock data.
- Retain the selected period through intermediary routes, Refresh states and Complete demo sync. Direct-entry Back/Close/Dismiss replaces the fallback destination instead of pushing a return loop.
- No automatic simulation of every asynchronous result: progress/error states remain manually selectable unless the existing action explicitly opens a preview. No backend or native-system operations were added. This is a route/interaction audit, not an exhaustive physical-device tap-through of every state combination.
- Validation after navigation fixes: 139 Flutter tests pass; analyzer reports no issues; git diff --check passes (existing line-ending warning only).

## UI handoff polish (2026-11-08)

- Shared FigmaViewport respects system safe areas and scrolls vertically on short/landscape windows instead of shrinking the entire screen to fit its height. Canvas width is capped at reference size on large displays. Large system text enlarges the whole fixed canvas with horizontal/vertical panning, while avoiding a second text scale inside its positioned layers. This is magnification, not native responsive text reflow.
- Budget limit dialog validates as the user types, disables Apply for invalid amounts, supports Done submission and outside-tap focus dismissal, and uses a scrollable dialog with wrapping error text. Budget is the editable text input in the current mock UI; pairing codes and AI keys remain fixture/picker interactions.
- Main hotspot actions and state recovery/outcome actions reject repeated taps while their async operation or popup is pending. Option sheets and dialogs can scroll; existing cancellation behavior is retained.
- Android/system Back now returns a directly opened detail/state route to its logical parent, while root tabs retain normal exit behavior. This has widget-test coverage, not physical Android back-gesture certification.
- Invisible Figma hotspots use InkWell for focus/interaction feedback and labeled button semantics; tabs expose selected semantics, and state Back/action controls have button semantics. Source colors/contrast remain unchanged. No TalkBack or formal contrast certification is claimed.
- Progress states offer Choose demo outcome only in preview mode. Outcome labels/paths are centralized in extra_screens.json. Sign-in, pairing, usage refresh, insights analysis, desktop sync, privacy export/deletion and account deletion can be completed with deterministic mock outcomes. They do not perform real authentication, network calls or deletion.
- main.dart explicitly disables the screen gallery, state picker, budget-alert preview button and outcome controls, and blocks the /state-preview gallery route. main_ui_preview.dart explicitly enables them. Both entry points use Dark mode. Required navigation/demo completion controls remain available. This separates preview tools, not a production/backend-ready build; main.dart still initializes Firebase.

Run the UI-only demo without Firebase credentials:

```powershell
flutter run -t lib/main_ui_preview.dart
```

Tests include 320x568 with keyboard insets and 1.5x text, safe areas, canvas panning, validation boundaries, duplicate taps, system Back, preview/handoff separation and outcome destinations. Physical-device, TalkBack and pixel-by-pixel comparison still need manual verification.

- Follow-up during regression testing: bottom tabs are pinned outside the scrolling canvas in both main screens and reviewed states, preserving source dock layers and rounded corners. The wide LDPlayer test and a short-height state test cover visibility and taps.
- Validation: all 139 existing tests passed in the full regression run. All 6 new handoff tests passed in the final targeted rerun after correcting a touch-area assertion that incorrectly included the dock border. Analyzer reports no issues; git diff --check passes with the pre-existing line-ending warning. No production code changed after that regression run.

## Live Android authentication (2026-11-08)

`main.dart` now creates an injected Firebase/Google auth session and guarded router. Google sign-in, session restoration, sign-out and live profile binding are connected. `main_ui_preview.dart` retains the independent mock router and previews. Usage/pairing/sync remain mock. See FIREBASE_LOGIN.md for setup, execution, validation and device checks. Full suite: 151 tests passed; analyzer clean; debug APK builds. Real-account/device verification remains pending.
