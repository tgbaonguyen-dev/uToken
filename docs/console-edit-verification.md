# Verify Firebase Console edits on mobile

Scope: daily usage and current insights. Console edits are cloud-to-mobile tests;
desktop still derives its numbers from local logs/SQLite. No production Console
data was edited by the automated tests below.

## Manual test on the team's project

Use a test account and the same Firebase project on both apps.

1. Run desktop Sync now successfully. Fully quit desktop while testing so its
   background sync cannot overwrite manual changes. Keep mobile Tokens open.
2. In Firestore Console, select the signed-in user's `users/{uid}/daily/{date}`.
   Choose a date included by the mobile filter; Total includes older dates too.
3. Record the original values and types of `totals.input` and one matching
   `by_key` entry's `input`. Keep `schema_version: 2` and the document date intact.
4. Add 1,000,000 to both input fields, keeping their integer type. The mobile
   exact total must rise by 1,000,000 and the selected model's usage must change
   without another login. Refresh explicitly reads the server if needed.
   Editing totals alone does not recalculate by_key, cached tokens or cost_micro.
5. On the test account only, temporarily change `totals.input` to a string.
   Mobile must show an invalid-summary warning, preserve display of valid days,
   and remain navigable. It must not silently interpret the string as zero.
6. Restore the integer field. The warning must disappear and that day's data
   must return without restarting the app. Restore both original input values
   after completing the test.

Also verify that a removed insight ID shows a missing-item message, and a missing
`insights/current` document shows a no-review message instead of endless loading.
Back to Insights and Retry are available. Avoid deleting real insights without
a recoverable copy; the automated test covers this case using synthetic data.

Expected limitations: Console changes do not edit desktop SQLite or original
logs. A future desktop upload of that daily document may overwrite them. Console
administrative writes bypass client Rules, so this does not prove upload
permissions or cross-user isolation.

## Automated coverage

- `mobile/test/live/console_edits_test.dart`: numeric edit, invalid type,
  recovery and deletion using the same daily parser as the Firestore repository;
  valid days continue rendering. Also covers midnight/resume and Insight recovery.
- `firebase/tests/console-edit.test.js`: emulator administrative create/update,
  wrong-type update, correction and deletion delivered to an authenticated SDK
  listener. The project is **demo-utoken**, never the production project.
- The emulator delivery test and Dart parser/widget tests exercise separate
  layers; they do not replace a manual two-device or real Console verification.

## Related backend behavior

- Raw retention prunes whole local calendar days. Unsynced daily summaries remain
  queued beyond retention until successfully uploaded; later retention removes
  acknowledged summaries. Explicit Clear local data still deletes queued usage.
- AI review uploads are persisted in judge-state.json by project/environment/UID.
  A failed upload retries on the next successful Sync, even when a new AI review
  is not due or review generation is disabled. This retry does not call the model
  again. A result generated while signed out has no cloud target and stays local.
- Tokens reopens its date-bounded listener at local midnight and when the app
  resumes on a different date. Malformed daily documents are isolated and counted
  in a warning; malformed report fields return a data-format error with recovery.

## Restore real usage after a Console edit

Desktop Sync now, or a manual sync requested from mobile while desktop is running, reuploads all daily summaries still retained locally. Background sync uploads only changed/queued days. A failed manual upload remains queued for retry. This does not download Console edits into desktop SQLite, restore locally expired history, delete cloud-only dates, or regenerate AI Insights. Manual sync causes extra Firestore writes for retained days.
