# Deferred UI integration bugs

Recorded 2026-11-10 after merge 4257b41. These are deferred, not fixed by the
same-account login navigation change.

Update 2026-11-10: UI-01 and UI-02 are now fixed in the live Tokens screen.
Calendar filters include today and the previous 6/29 dates; Total reads all
available cloud history. UI-03 and UI-04 remain deferred.

| ID | Finding | Location | Acceptance criterion |
| --- | --- | --- | --- |
| UI-01 | Day includes yesterday; Week/Month can include an extra date | mobile/lib/features/tokens/presentation/tokens_screen.dart, _filter | Day includes today only; Week/Month include exactly the intended calendar dates; boundary tests |
| UI-02 | Total query fetches only the previous 365 days | tokens_screen.dart, _watchDaily | Total covers all retained history or explicitly labels its limited range |
| UI-03 | Missing/removed insight or stream error leaves detail loading indefinitely | insights_screen.dart, RealInsightDetailScreen | Separate loading, error, no-data and missing-ID states with recovery |
| UI-04 | Live Analytics has no entry to Efficiency/model comparison | analytics_screen.dart | Appropriate navigation is reachable; comparisons must distinguish real and sample data |

## Current priority: account-based linking

No pairing code is required. Windows uploads and Android reads documents below
`users/{Firebase UID}` in the same Firebase project. Signing in with the same Google
account gives access to that account's data; different accounts remain isolated.
Data appears after a successful desktop upload, not merely after signing in.

Desktop already implements this flow. Mobile interactive sign-in now opens Tokens;
obsolete pairing/sync-preview paths redirect signed-in, non-demo users to Tokens.
Figma demo/preview screens remain available for design reference.

Live end-to-end upload/read and deployed Security Rules have not been verified by
this navigation change. UI-03 and UI-04 remain open.

## Historical upload correction

Sources/Rescan can consume log changes before the sync engine runs. Previously,
Run rebuilt only its newly touched dates plus today/yesterday, leaving older
daily summaries missing or stale. Run now reconciles every retained date from
the first stored event through today. Unchanged summaries remain clean, so this
does not re-upload unchanged daily documents. Rebuilding local history adds work
proportional to retained days; local retention still applies.

The live mobile screen uses Text widgets, not SVG numbers. Exact token totals
are displayed alongside compact metrics so small updates remain visible.
Rescan reads logs; Sync now uploads summaries. Live cloud verification is still
required to confirm a particular device/account's data.
