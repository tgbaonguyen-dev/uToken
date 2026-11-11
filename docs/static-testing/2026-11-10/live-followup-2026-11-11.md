# Follow-up verification — 2026-11-11

This supplements the execution report; earlier test results remain historical snapshots.

**Latest result:** the controlled production desktop/cloud/mobile roundtrip and
Android offline-preference checks passed. The patched tooling audit is now zero,
and a clean npm installation plus all 14 Firebase/tooling tests passed. Earlier
14-advisory and emulator-disconnection entries below are historical attempts.

## Real Firebase: utoken-78191

Ran `scripts/Test-FirebaseLive.ps1 -ProjectId utoken-78191` using the desktop's saved Windows session. Result: **2 passed, 1 skipped**.

- Confirmed daily schema v2, efficiency schema v1 and profile last_sync_at exist for the signed-in account.
- Confirmed the owner can create/read a disposable probe, anonymous requests are denied, and signed-in requests to a different UID namespace are denied. Probe cleanup completed without reported failures.
- Deployed Rules source comparison remains skipped: no Google management access token with Rules read permission. Firebase ID tokens cannot substitute for that permission. No Rules deployment performed.

These checks do not prove every production collection or second-account scenario.

## npm tooling

Ran `npm.cmd audit fix --ignore-scripts` without force. Compatible lockfile resolution changes were retained. Audit still reports **14 moderate, 0 high, 0 critical**. npm's remaining proposal downgrades firebase-tools to 13.11.2 with breaking changes, so it was not applied.

Ran `npm.cmd test` after the lockfile update: **10 passed, 0 failed** on Firestore Emulator. Node remains 24.11.0; Firebase SDK packages request >=24.12.0. No global Node installation was changed.

## Android

Started the installed Pixel_10 Android 17/API 37 emulator headlessly. It booted successfully; `adb install -r` returned Success for the existing debug APK, preserving app data. The emulator disconnected during the initial runtime inspection and was restarted.

On restart, boot completed and the app process was present (PID 1838). `am start -W` timed out rather than reporting a successful rendered launch. The inspected AndroidRuntime/flutter error log tail contained no entries. UI Automator showed **System UI isn't responding**, with Close app / Wait actions. This is an emulator System UI failure; it does not establish an app crash or a working login flow. Android UI/login/sync E2E remains unverified. Do not count APK installation or the live app process as an E2E pass.

No commit, publish, or production Rules deployment was performed.

## Android retry

Retried with a cold boot (`-no-snapshot-load`), 2048 MB RAM and two cores, preserving AVD/app data. APK reinstall succeeded. System UI ANR appeared again; after closing that dialog and restarting only uToken, `am start -W` reported **Status: ok, LaunchState: COLD** (about 12 seconds). No AndroidRuntime/flutter crash entries were observed in the inspected tail.

UI Automator subsequently confirmed the **Tokens** screen, **Refresh from Firebase** action and all four navigation tabs. This establishes that the app reached its main shell on Android during this retry. It does not verify usage values or fresh Google sign-in. Before the navigation interaction check could execute, the emulator disconnected again; tab interaction and full login/sync E2E remain unverified because of the unstable emulator session.

## User-started emulator: successful smoke check

The user then started the emulator interactively. ADB identified `emulator-5554`, Android x64; this was not a physical phone. This session remained connected throughout the following checks:

- Cold launch succeeded; Tokens loaded cloud-backed usage and the four navigation tabs.
- Tokens Day filter changed the total from the Month value 1,127,749,645 to zero. The UI explained that the phone date was 2026-11-11 and cloud data ended on 2026-11-10. Therefore zero Day usage was consistent with the displayed date range.
- Navigation reached Analytics, Insights (Suggestions empty state) and Settings, then returned to Tokens.
- Tapped Refresh from Firebase; the UI returned to loaded usage without a visible error. This does not prove server freshness because no controlled remote edit was made during this check.
- Force-stopped the app and cold-launched again; Tokens and the same usage reappeared without interactive Google sign-in, confirming saved-session restoration for this account/session.
- No AndroidRuntime/flutter crash entries appeared in the inspected log tail. This is a smoke test, not exhaustive crash/performance coverage.

Observed data/UI issue: Sources showed Codex 100.4% plus Gemini 3.0%; model shares likewise summed above 100%. Aggregate totals and per-source/model sums appear inconsistent. This check does not establish whether prior Console edits, aggregation, or presentation caused the mismatch. No normalization or data rewrite was applied to hide it.

Still not verified: fresh interactive Google sign-in, sign-out/revocation, controlled Console-edit propagation, new desktop upload received on mobile, or mobile-triggered desktop sync completion. No account preferences or usage documents were changed by these Android interactions.

## Controlled production roundtrip and offline checks

With the user's authorization, `LiveSyncRoundTripTests` invoked the real desktop
API and collectors against the existing SQLite store and saved Firebase session.
No desktop window automation or paid AI generation was used. There was no
separate running desktop app during this check.

The final opt-in roundtrip passed:

1. Explicit manual sync uploaded all 27 retained local daily documents. Every
   uploaded document was compared with the corresponding SQLite summary and
   matched. Across the cloud daily documents, token totals matched by_key sums.
2. A retained cloud daily document was changed through authenticated Firestore
   REST with an updateTime precondition: +1,000 to totals.input and a matching
   by_key.input. This models a Console numeric edit, but is not a test of Console
   administrative privileges.
3. Mobile Total displayed **1,772,429,529**, exactly the cloud test total
   **1,772,428,529 + 1,000**, without signing in again.
4. A second explicit manual desktop sync replaced that edit with the latest
   SQLite summary. New real usage arrived while testing, so the correct result
   was compared to current SQLite, not the pre-test total. Mobile displayed
   **1,772,598,119**, exactly the final cloud total. No artificial delta remained.

The first attempt timed out waiting for mobile observation and restored its
edit. A second test attempt incorrectly assumed no new usage would arrive; its
assertion/cleanup was corrected to compare regenerated local data and avoid
overwriting an intervening writer. The final run passed. These were verification
harness corrections, not evidence of a product sync failure.

The earlier >100% shares disappeared after uploading real local summaries:
Codex/Gemini showed **66.7% / 33.3%**, and cloud totals matched breakdown sums.
This supports stale/inconsistent cloud summaries as the observed cause; no UI
percentage clamping or normalization was added to disguise bad input. It does
not prove that no other aggregation defect can occur.

`scripts/Test-AndroidOffline.ps1` then disabled only emulator Wi-Fi/mobile data,
temporarily switched Compact to Full, force-stopped/reopened the app, checked UI,
and restored both network states and the original Compact setting in finally:

- Preference change worked offline.
- The change survived a full offline restart.
- Pending-save/retry UI was visible.
- Cached usage remained visible.
- Explicit Refresh displayed a connection error instead of reporting success.
- After reconnecting, Compact was restored and no save/retry error remained.

No account switch, revocation or fresh Google login was performed. Those checks,
deployed Rules source comparison, physical-device testing, and the complete
mobile-request/desktop-poll/finished-status path remain unverified in production.

## Patched dependency verification

Kept Firebase CLI 15.35.0 and added scoped overrides for glob >=14.0.4,
firebase-tools' PubSub >=6.4.1, and gaxios 6's uuid >=11.1.1, retaining the earlier
gRPC override. These cross upstream dependency major ranges deliberately; their
scope and removal condition are documented in firebase/README.md.

- `npm ci --ignore-scripts`: passed from the updated lockfile.
- `npm test`: **14 passed, 0 failed** (10 existing emulator checks plus four
  toolchain compatibility checks).
- `npm audit`: **0 total vulnerabilities** in this registry snapshot.
- Full .NET regression rerun: **265 passed, 0 failed, 4 opt-in skips**. The new
  roundtrip is one of those default skips; it passed in its separate authorized
  live run. Two existing production checks had also passed separately earlier.
- Compatibility coverage: glob sync/async/stream/cancellation and CLI file lists,
  ZIP file expansion, gaxios multipart/uuid construction, and local PubSub client
  construction/close. No production PubSub, Functions or Hosting deployment was
  attempted; do not infer support for all such workflows from these checks.
- Node remains 24.11.0; the SDK >=24.12.0 engine warning is separate from the
  resolved audit findings. Global Node installation was not changed.

Machine-readable summary: [live-verification-results-2026-11-11.json](live-verification-results-2026-11-11.json).
