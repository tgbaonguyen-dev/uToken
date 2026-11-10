# Real Firebase verification on Windows

## Mobile does not update after desktop Sync

The current backend uses `desktop/src/UToken.Desktop.App/appsettings.Local.json`
(nested `Firebase` settings), not the older `firebase.desktop.json` file. Confirm
`Firebase:ProjectId` matches Android's `google-services.json` and
`Firebase:UseEmulator` is `false`. Environment variables prefixed `UTOKEN_` override
these files. Do not share OAuth secrets or session files when diagnosing this.

1. Sign in with the same Google account in both current builds.
2. On desktop, press Sync now. Check for a successful upload, not just a completed
   local analysis. Pending summaries must not remain queued due to an upload error.
3. Check Firestore Console under that account's `users/{uid}`: daily documents,
   `efficiency/current` and `last_sync_at` should be present/updated. A successful
   sync with no collected logs can legitimately have no daily usage documents.
4. Mobile listens to those documents automatically. The refresh icon on Tokens,
   Analytics, Efficiency, Insights and Desktop connection explicitly reads Firebase
   **server** data. It reports offline/permission failures instead of treating a
   cached response as success. It does not remotely trigger desktop collection.
5. If desktop reports permission denied, reconcile the deployed Rules with
   `firebase/firestore.rules`. The local daily write rule was corrected on
   2026-11-10 to remove invalid `request.resource.size()`. Firestore enforces its
   own document-size limit. This local fix has not been deployed by this change.

Tokens now reads all available daily history for Total; Day/Week/Month use
calendar dates. Exact token totals are shown so rounding does not hide small
updates. After updating desktop, Sync now also rebuilds retained historical
summaries already scanned by Sources before uploading changed daily documents.

Local diagnosis on 2026-11-10: SQLite daily_local contained only 2026-11-06
(55,926,191 tokens) and 2026-11-07 (89,964,091 tokens), both marked clean. Their
sum, 145,890,282, matched the reported mobile total. Recent diagnostics showed
Initial scan/Rescan, with no Analysis/Sync run after 2026-11-07. This is evidence
of stale local summaries, not a live Firestore verification. Sources now offers
Sync now directly and shows its result. Mobile displays the received daily date
range. Week/Month/Total can match when all documents fall in the same week;
changing a filter cannot create missing history.

Run from the repository root after signing in to the current desktop app and clicking **Sync now**:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Test-FirebaseLive.ps1 -ProjectId utoken-78191
```

The local config must select that exact project with `UseEmulator: false`. The check reads the saved app session under the current Windows user, refreshes an ID token in memory, and does not sign out or rewrite the app session. Restart the current desktop build to migrate any legacy plaintext session to DPAPI before normal use.

The script runs three tests:

| Test | What it proves |
| --- | --- |
| Deployed rules enforce isolation | A normal Firebase user can create/read a random probe under their own UID. Anonymous access and access to a different, randomly generated UID namespace are denied. |
| Real sync documents exist | The user's daily summaries have schema v2, efficiency/current has schema v1, and the profile contains last_sync_at. It only reads existing usage documents. |
| Deployed source matches repository | The active default-database Rules source matches firebase/firestore.rules after normalizing whitespace. Requires separate management access; otherwise explicitly skipped. |

The isolation test writes only randomly named `_rules_probe` documents. Create preconditions prevent overwrites; cleanup uses update-time preconditions. It does not overwrite daily, efficiency/current, profiles, pricing, or other existing documents. If cleanup fails, the test fails and prints only the affected paths so the project owner can remove those probe documents manually. The cross-UID test uses a synthetic namespace, not a second real Google account; it does not prove all possible Rules paths, queries or business validations are secure.

The tests use normal Firebase ID tokens for Firestore requests, so they exercise the deployed Security Rules. They never use an Admin SDK credential to bypass those Rules and never deploy Rules. They intentionally do not run during ordinary `dotnet test`; without explicit opt-in they are reported as skipped, not passed.

## Compare the deployed Rules source

A Firebase app user's login does not provide management permission to download Rules. A project member with Firebase Rules read permission can use a Google OAuth access token locally. If Google Cloud CLI is already installed and authenticated as that member:

```powershell
# Do not print or paste this token into chat or commit it.
$env:UTOKEN_RULES_ACCESS_TOKEN = (gcloud auth print-access-token)
try {
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Test-FirebaseLive.ps1 -ProjectId utoken-78191
}
finally {
    Remove-Item Env:UTOKEN_RULES_ACCESS_TOKEN -ErrorAction SilentlyContinue
}
```

The token must have access to the Firebase Rules management API. A 401/403 on that API is a management permission problem and does not establish that Firestore client Rules are incorrect. Do not put a service-account private key in the app config. The active release and its source are downloaded read-only through the [Firebase Rules management API](https://firebase.google.com/docs/rules/manage-deploy).

## Findings from the first live run

On 2026-11-07, against `utoken-78191` using the saved local app session:

- **Passed:** owner probe create/read, anonymous read/write denied, cross-UID read/write denied; created probe documents were successfully deleted.
- **Not verified:** usage sync, because no daily summaries existed under this account. Click Sync now in the app and rerun. This result alone does not distinguish "never synced" from "no local usage" or "sync failed".
- **Skipped:** deployed Rules source comparison, because no Google management access token was available. The successful access checks do not establish that deployed source matches the repository.

No Rules were deployed and no existing usage documents were changed by this run.
