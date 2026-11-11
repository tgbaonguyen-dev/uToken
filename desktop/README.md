# Desktop (.NET 10 + Avalonia)

| Project | Trách nhiệm | Phụ thuộc |
|---|---|---|
| `UToken.Core` | Model, chuẩn hóa token, chi phí, phân loại kết quả task, thống kê, luật kết luận | (không) |
| `UToken.Collectors` | Tìm và đọc log Codex, Claude Code, Antigravity theo luồng | Core, ZstdSharp |
| `UToken.Storage` | SQLite: schema, migration, truy vấn | Core, Microsoft.Data.Sqlite, Dapper |
| `UToken.Sync` | Firebase Auth (REST), Firestore REST, hàng đợi gửi | Core, Storage |
| `UToken.Desktop.App` | Avalonia UI, tray, dịch vụ chạy nền | tất cả |

Quy tắc: `Core` không phụ thuộc gì khác; mọi công thức trong SRS §10.1 nằm ở `Core` và có unit test.

```bash
dotnet restore
dotnet test
dotnet run --project src/UToken.Desktop.App
```

## Real data (default)

The app now runs on real local data. `App.axaml.cs` builds `RealDesktopApi` (`Services/RealDesktopApi*.cs`):

- Usage numbers come from `UsageEngine`: Codex and Claude Code logs are read incrementally into SQLite at `%LOCALAPPDATA%/uToken/utoken.db` (Linux: `~/.local/share/uToken/utoken.db`). See `../docs/core.md` for formulas.
- Enabled sources and log folders come from `appsettings.json` (`Collectors.Enabled`, `CodexHome`, `ClaudeHome`). Gemini/Antigravity shows *Paused* unless enabled; its local logs have no token data yet (OQ-10).
- Sources check the real log folder: missing → *Not found*, unreadable → *Permission required*. Rescan scans each provider and reports progress.
- Activity lists real usage events (newest 1,000 per query); Export writes them to CSV.
- **Sync now** scans local logs, reconciles retained daily summaries and uploads dirty daily documents plus the efficiency report through Firebase REST. It reports upload failures and keeps summaries queued. Desktop and mobile use the same Google account; pairing codes are not required. Manual and background sync refresh Sources and the selected source detail.
- Static UI copy (setup steps, preview-state scenarios, permission instructions) lives in `src/UToken.Desktop.App/UiContent/*.json`. The *Preview state* selectors only preview screen states; they never change stored usage.

The mock implementation (`MockDesktopApi`) and its JSON fixtures moved to `tests/UToken.Desktop.Tests/Mock` and `tests/UToken.Desktop.Tests/MockData`. They are used only by UI tests; the sections below describe that mock behaviour.

## Configuration recovery and last upload

Invalid JSON or configuration value types at startup open a recovery window.
Correct `appsettings.json`, `appsettings.Local.json` beside the running executable,
or the `UTOKEN_` environment overrides, then choose Retry. Files are not reset and
raw configuration errors/credentials are not displayed. If changing a source
configuration file, rebuild so it is copied into the executable's output directory.

Successful upload times are saved in `%LOCALAPPDATA%/uToken/sync-status.json`, keyed
by Firebase project, emulator/production mode and UID. They restore after a full
exit; a failed upload does not advance the saved timestamp. Corrupt status metadata
does not block authentication or upload. This records this computer's uploads,
not an online-presence signal; sync history and transferred byte counters remain
per session. Activity displays at most 1,000 matching rows, while CSV export includes
all matching retained rows using the same filters.

## Desktop UI with mock data (tests only; D02, D05, D06, D04, D07, D03)

- Overview displays the dashboard. Sources opens the provider list; select a card to open its detail, then use Back to sources.
- Rescan sources simulates a scan and reloads JSON. Settings remains disabled until its screen is implemented.
- The demo does not read local AI logs or contact Firebase. Gemini and all collector statuses are sample data.
- `src/UToken.Desktop.App/MockData/overview.json` contains collector state, sync timestamp, reference time and privacy rows. Dashboard totals are computed from `sources.json`; recent activity is taken from `activity.json`. `sources.json` holds discovered sources and their authoritative 30-day usage, model lists, health and coverage.
- `MockData/source-periods.json` contains separate usage responses for 1 day, Week and Total (30 days uses `sources.json`) for each provider. The detail selector reloads tokens, cost, cache metrics, models, chart and axis labels through `IDesktopApi.GetSourceAsync`. Selection is retained between providers; a failed request keeps the last successful range and data.
- Collector/source/device states determine status labels and dot colors. Coverage uses numeric available/total counts; zero coverage remains gray. Provider icons are 32 px and navigation icons are 22 px.
- ViewModels call `Services/IDesktopApi.cs`; `MockDesktopApi.cs` reads JSON asynchronously with simulated latency. This is an API-shaped service, not an HTTP server.
- JSON is copied to the build output. After editing source JSON, run `dotnet run` again to copy changes. To demonstrate a rescan live, edit `bin/Debug/net10.0/MockData/sources.json`, then click Rescan sources.
- To demonstrate an error, temporarily rename an output JSON file and click Rescan sources; restore it and click Try again. Empty `sources` in `sources.json` or `events` in `activity.json` demonstrate empty states.
- The Figma example has inconsistent provider totals. Demo totals use 4.26M Gemini + 1.97M Codex + 0.60M Claude = 6.83M; costs also sum to $42.18.
- Shared sidebar and existing bundled Inter font are used across the screens. Layout uses grids and scrolling, with a minimum window size of 1020 x 650.

`dotnet test` includes JSON, cancellation, error handling, navigation, and headless render checks. Rendered screenshots are written to `tests/UToken.Desktop.Tests/bin/Debug/net10.0/Screenshots/`.

### Activity, Sync and Pairing

- From Overview, click **View all** to open D04 Activity. Select source/model/time filters, then click Search (or press Enter in the search box). Select a row to inspect its metadata. Collected and Warnings load separate event lists. Export saves the filtered list as CSV through the system save dialog; cancel leaves files untouched.
- `MockData/activity.json` contains events and the demo reference time used by period filters, so old sample dates do not disappear as the real clock advances. Input includes cached tokens; total = input + output. No prompt or response content is present.
- **Sync** in the sidebar opens D07. Sync now adds a sample history row. Disconnect asks for confirmation and retains history. With a connected device, the header shows **Device information** and opens device metadata and supported-source badges without creating a pairing session. After disconnecting, it shows **Pair new device** and opens the six-digit form. Connection changes last for the current process and reset to fixtures on restart.
- `MockData/sync.json` defines the initial device, privacy labels and history. Set `nextSync.state` in the output JSON to `success`, `failed` or `no_new_usage` to demonstrate each outcome without restarting. No metadata is actually sent to a phone or Firebase.
- `MockData/pairing.json` defines demo codes, device metadata and expiry. The default valid code is **482913**; **000000** simulates expiry, other six-digit codes are rejected. A session also expires after ten real minutes and successful codes are consumed for that session. Start new pairing session resets the input and expiry.
- Pairing accepts typing, backspace and pasting the entire six-digit code into any box. Successful pairing remains visible until Open Sync is clicked. API errors show a retry message rather than a success state.
- Activity row backgrounds appear only on pointer hover; selection still updates Event details. Green dots mark the source filter, active Collected tab and the prompt-privacy note.
- New headless tests cover activity filtering/selection, CSV escaping, sync/disconnect, pairing validation/expiry, and rendering at two window sizes. The native save dialog itself is not exercised by headless tests.

### Raw mock data and status scenarios

Mock JSON now stores numeric token counts, decimal USD amounts, byte counts, nullable durationMs and ISO 8601 timestamps. Strings such as 6.83M, $42.18 and 2 min are generated by the UI. The migrated fixtures keep the main demo totals and pairing codes; old copies with formatted numeric strings must be updated to the new schema.

- `supported-sources.json` is the mock capability catalogue and is independent of discovered sources. Removing a discovered source does not remove its supported-source badge. This catalogue is demo data, not evidence that every real collector is implemented.
- In `overview.json`, set `collector.state` to `running`, `stopped` or `error`; use ISO timestamps for `lastSyncAt` (or null) and `referenceTime`. Rescan sources reloads the dashboard and sidebar state.
- In `sources.json`, `collectorState` supports `running`, `paused`, `permission_required`, `not_found` and `error`. `health.hasLogAccess`, `parserState`, `lastReadAt` and `collectsPrompt` drive health rows. A denied log permission changes the source badge and health text instead of displaying a fixed healthy state.
- Each model has a numeric token count; model count is `Models.Length` and model shares are calculated from that list. Source shares are calculated from discovered sources. The baseline fixtures keep model totals and trend totals equal to each source's token total.
- Trend points contain `timestamp`, `tokens` and `cached`; period boundaries and granularity determine the axis labels. The UI scales bars against the maximum token count and formats tooltips. No pixel heights are stored in JSON. Cached tokens cannot exceed total tokens and zero/empty series are safe.
- In `sync.json`, `device.isOnline` is independent of pairing: false keeps the device paired, shows Offline and blocks a successful sync. Set it before starting the demo process; connection state is held in memory after loading. `lastSyncAt` may be null, and `transferredBytes`, history `bytes` and `nextSync.bytes` are numeric. Successful sync adds bytes, updates timestamps and refreshes the dashboard sync indicator.
- Fixture reference times make relative labels deterministic. UI clocks use +07:00; simulated sync/pairing actions use the injected real/test clock. Labels refresh when data is loaded or an action completes, not on a continuous timer.
- Activity events are a sample stream, not a complete monthly ledger. Dashboard monthly totals come from source summaries, while its recent-event list shares the Activity fixture.

### D08 Settings

The desktop app stores preferences in `%LOCALAPPDATA%/uToken/settings.json` on Windows (the .NET LocalApplicationData directory on other platforms). Defaults and supported retention choices still come from `MockData/settings.json`. Save changes writes through a temporary file and replaces the configuration only after serialization succeeds. Restore defaults persists defaults without changing usage fixtures. Invalid local JSON is reported and preserved until you explicitly restore defaults.

Open folder uses the system folder launcher. The version comes from the running assembly. Open diagnostics shows the runtime, OS, architecture, mock JSON syntax checks and recent local application log. `diagnostics.log` records settings operations and JSON error types, without recording JSON payloads, prompts or responses; it rotates above 256 KiB and retains one previous file. Syntax checks do not prove collector health.

Export data saves all collected and warning metadata to CSV. Startup, provider data collection, notifications, updates, retention enforcement and clearing usage records are still simulated; Windows tray behavior is implemented as described below. The mock service can run without a local settings store for isolated tests; production app startup injects the local store.

### First Run and window/tray behavior

D01 uses `MockData/first-run.json`. On the first production launch it shows the three-step checklist. Google sign-in and log access advance UI demo states only; the last step opens the existing pairing/device-information page. Sidebar navigation is locked throughout setup. Skip setup appears after the simulated Google sign-in step and opens Overview; it cannot bypass sign-in. Completion is stored separately in `setup-complete` under the local app data directory. Settings > Review setup reopens D01; Restore defaults does not reset onboarding.

On Windows the native tray menu has Open uToken and Quit. Closing the window hides it when the **saved** Background collection preference is enabled. Open restores the window without reloading data; Quit exits. Disabling the preference and saving makes closing exit normally. OS/application shutdown is not intercepted. Platforms without the installed Windows tray always close normally. This keeps the UI process alive only; no background provider collector is started.

Launch at startup is a saved UI preference only. No Windows startup registration, real Google authentication or provider file permissions are implemented in this UI scope.

### Overview state previews

Overview > Demo state switches between Normal, D09 Offline, D11 Empty Usage and D24 Update Required. Source and Sync states are excluded from this menu; D19 Scanning, D21 Source Not Found and D22 No New Usage are accessed through Sources; D23 Session Revoked and D25 Network Error are accessed through Sync. Shared copy and detail values remain in `MockData/overview-states.json`; the mock service returns a separate preview response. Empty previews have zero usage and no activity; offline retains recent sample activity. The normal overview and source/activity fixtures remain unchanged.

Restart collector and Retry sync restore Normal using mock responses, without process restart or network calls. Check collector keeps Empty Usage and reports a mock check. View diagnostics opens an owned modal popup over Overview (Close or Escape dismisses it), preserving the selected state; sources/settings/setup buttons navigate to those screens. Pair again explicitly disconnects the mock mobile device and opens a fresh mock pairing session; local usage history is retained. Scanning is a stable review state with an animated indicator, not a real log scan. State selection is kept for this session and is not a persisted setting.

The Windows tray menu is positioned above its click anchor and clamped to the monitor working area, including DPI scaling. This placement hook targets only uToken's Avalonia 11.3 tray popup name; review the hook if Avalonia is upgraded.

### D10 Permission Required

Sources > Demo state offers Normal, D10 Retry succeeds and D10 Still denied. The mock service overrides only the affected provider's log-access status in memory; usage totals and JSON fixtures are retained. D10 also appears when the source response already reports missing log access.

Copy, instructions, affected provider and retry outcomes come from `MockData/source-permission.json`. Open System Settings (demo) and Show instructions open a modal over Sources. The instructions are platform-neutral UI copy, not macOS or Windows permission changes. Retry access stays on D10 for a denied response; a granted response returns to normal Sources and updates source detail health. Rescan alone does not grant permissions. These scenarios reset when the application process restarts.

A denied Retry access response displays a persistent red failure notification and changes the D10 hero accent/icon to red/X. It has no dismissal timer. Closing the notification restores the amber permission-required appearance; it does not grant access. Rescanning does not dismiss the failure notification.

### Sources Scanning

Rescan sources enters the D19-style Scanning view on Sources. The mock service reports the current provider, completed count and per-provider result through `IProgress<SourceScanProgress>`. Copy and per-provider delay come from `MockData/source-scan.json`. It checks JSON source responses only; no provider files are scanned.

Navigation and repeat scans are blocked during scanning. Cancel scan cancels the request and retains the previous source/overview results. Successful completion commits the updated source list and overview together; sources that still lack access return to D10. Read errors leave the previous results available and allow another scan. Late progress reports from canceled/previous scans are ignored.

### Sources Not Found

Sources > Demo state adds D21 Still not found and D21 Found after rescan. Both initially mark all providers as not found while preserving historical usage. Rescan enters Scanning; the first scenario stays missing, the second returns discovered providers and resets the selector to Normal. Cancel does not apply the planned discovery result.

The Sources view also enters this state automatically for an empty provider response or when all providers have `collectorState: not_found`. A partial result stays on the provider cards. Missing-source entries are not treated as permission failures; a discovered provider with missing access still opens D10.

Configure sources opens a modal with the setup guide and sample paths; Open settings navigates to app settings. Guide copy is shared with the existing not-found scenario in `MockData/overview-states.json`; discovery outcomes are configured alongside the Sources demo options in `MockData/source-permission.json`. No provider files or installed applications are inspected.

### Section demo states

Sources > Demo state includes D19 Scanning (runs the cancellable mock rescan), D21 discovery outcomes, D10 permissions and D22 No New Usage. D22 preserves historical usage and its primary action opens Overview. Sync > Demo state includes Normal, D23 Session Revoked and D25 Network Error. Pair again disconnects the demo device and opens the pairing form; Retry sync returns to the existing mock sync flow. Returning through the section navigation resets these section previews. Copy and details are read from the existing JSON fixtures; no network or provider log access is introduced.

### Windows Sync states (D12, D13, D20)

Sync > Demo state now includes D12 Sync Failed, D13 Not Paired and D20 Syncing alongside D23/D25. `MockData/sync-states.json` supplies screen copy, detail rows and the D12 sample queue (numeric event/byte counts). Previewing these states does not disconnect the device, add history or alter usage fixtures. Start pairing/Re-pair device explicitly disconnects the mock device and opens a fresh pairing form, retaining sync history.

Sync now displays D20 with an indeterminate progress bar while the existing service request runs. No upload percentage is fabricated. A failed/offline response displays D12; Retry sync repeats the configured outcome and only a successful mock result adds a history row. An unpaired device displays D13 automatically after disconnect or reopening Sync. D20 selected from the menu is a stable UI preview; View sync restores the current connection view. Native sync, encryption and phone connectivity are not implemented by these screens.

### Windows Pairing states (D14-D18)

Pairing/Device information > Demo state previews D14 Waiting, D15 Verifying, D16 Expired, D17 Rejected and D18 Success. Text, colors, actions and detail rows are read through `IDesktopApi.GetPairingScenariosAsync` from `MockData/pairing-states.json`. Previews leave the currently paired device and usage history unchanged; they are labeled as previews. Normal returns to the existing form or device-information page.

The real mock-code flow shows D15 while validating, D16 for expired codes, D17 for rejected codes and D18 after successful pairing. Start new pairing session clears the digits and renews expiry; Try again returns to the same input session. D18 keeps the newly paired device summary visible and Open Sync opens its connection. Reopening Device information shows the existing device, without starting another pairing session. Input validation and IO errors retain the entry form with a message. Typing, pasting and backspace behavior is preserved.

D14 copy follows the existing desktop-entry flow (code comes from mobile), rather than the reverse-direction text in the Figma state. No mobile approval or actual cloud authentication is introduced. This UI targets Windows; D10L is out of scope.

### Windows visual audit

`WindowsVisualAuditTests` renders D01-D25 at 1180x760 and 1020x650. Output files are `Screenshots/audit-D01.png` through `audit-D25-small.png` under the selected test output directory. The audit checks visible status dots, state-header colors, the empty-usage healthy badge, nonzero chart-bar widths and the Sources permission-guide popup.

The UI retains navigation and demo controls (Back, View all, Retry, pairing actions, period selectors and demo-state menus). Visual corrections include Pairing/D22 header badges, state code/detail panels for D22/D23/D25, provider dots and security check tiles in Pairing, the D11 healthy badge, D12 sidebar status, Sources permission access, search/connection/history borders and navigation icons. Usage totals and mock connection behavior are retained; some copy and data differ intentionally from Figma to match the desktop code-entry flow and numeric JSON responses. Screenshots are a manual review aid, not pixel-diff approval or native Windows interaction tests.

### Local UI features

The production Windows app saves window placement, maximized state, Activity filters/search and the source-detail period to `%LOCALAPPDATA%/uToken/ui-state.json`, independently of collector settings and usage fixtures. Window coordinates are checked against available monitor working areas and DPI on restore. Normal bounds are retained while maximized/minimized; closing to tray and Quit both save preferences. Invalid UI-state JSON falls back to defaults and records an error type in diagnostics. Unknown saved providers/models fall back to All sources/All models when Activity loads. UI preferences are not cleared by Restore defaults for Collector settings.

Pairing displays an actual remaining-time counter derived from the service session's `ExpiresAt`. A one-second UI timer refreshes the label and enters D16 on expiry without requiring Submit. Restart creates a new session and resets the counter. Preview states do not expire automatically or alter the connection. This is real local timing around the existing mock pairing service, not a real mobile pairing implementation.

Diagnostics popups and Settings diagnostics include Copy report and Save report. Copy uses the system clipboard; Save uses the native file picker and writes a UTF-8 text file. Canceling does not write a file; errors leave the report available for retry. The diagnostic fixture check now also includes `sync-states.json` and `pairing-states.json`.

`LocalFeaturesTests` covers expiry/restart and stable previews with an injected clock, preference restoration/stale selections, corrupt JSON and atomic-save failure, DPI/off-screen placement, maximized/minimized normal bounds, clipboard transfer and UTF-8 report truncation. Native Windows file-picker interaction and physical monitor changes still require a manual check.

### Mobile-triggered sync recovery

Desktop polls pending and running sync requests. A running request records `started_at`; after 30 minutes without completion it can be reclaimed on a later poll, including after app restart. Legacy running requests without a timestamp are recoverable immediately. Claims use the Firestore document update time as a write precondition to prevent two desktops claiming the same version. Syncs longer than 30 minutes need lease renewal before supporting that workload.

Mobile-triggered sync holds the desktop busy guard through request handling and refresh, and refreshes Overview, Sources, the open provider/period and Activity through the same path as manual sync.

### One collector and 30-day AI reviews

One desktop collector is supported per Firebase account. The first upload claims `users/{uid}.collector_id` using an atomic Firestore existence/update-time precondition before any daily write. Other installations cannot upload daily/AI reports or claim mobile sync requests for that account. `desktop-id.txt` is a stable random installation ID beside the session file, not a token; retain it when restoring the same installation. Moving to another installation needs an explicit collector reassignment procedure; there is no automatic takeover UI. This client guard is not device attestation: the account owner/admin can still edit their profile in Console. Legacy profiles bind on their first upload from the updated app.

Every desktop AI review uses the last 30 days of retained usage, including repeated manual reviews and requests from mobile. Desktop no longer keeps an incremental review boundary; an old LastReviewedThrough value in persisted JSON is ignored. Scheduled reviews still respect their interval. Upload retries reuse the queued result without another model call. Clear local usage invalidates the cached snapshot; existing review/pending deletion policy is unchanged. Original source logs are not deleted and may be reimported.
