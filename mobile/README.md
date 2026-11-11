# Mobile — Flutter Android

Android uses `com.utoken_mobile`. Do not run `flutter create` over this project.
Place the ignored `android/app/google-services.json`, register the signing SHA
and enable Google Authentication in the team's Firebase project.

```powershell
flutter pub get
flutter run -d emulator-5554 -t lib/main.dart
```

`main.dart` initializes native Android Firebase resources and real Google login.
Android does not require `firebase_options.dart` for this setup. See
[FIREBASE_LOGIN.md](FIREBASE_LOGIN.md) for native setup. Browser/Windows Flutter
login is outside the supported mobile target.

## Live account linking and data

Desktop and mobile link by signing into the same Google/Firebase UID; no pairing
code is required in the live flow. One desktop collector is supported per account.
The first collector upload binds its installation identity; another desktop may
sign in but cannot overwrite usage. Keep the desktop's `desktop-id.txt` when
restoring that installation. Transferring the collector to another installation
is not an automated UI flow yet.

- `lib/features/live/`: widget screens for Tokens, Analytics, Insights, Settings,
  details and overlays. Router mapping lives in `lib/app/router.dart`.
- `lib/core/data/usage_repository.dart`: Firestore daily/efficiency/insights reads;
  writes only sync requests and mobile preferences. Usage is computed on desktop.
- `lib/core/models/`: validated Firestore field readers. Invalid daily documents
  are excluded and their warning is retained across live daily screens/exports.
- `lib/core/data/local_prefs.dart`: secure local cache and account preferences;
  pending changes survive restart per UID and expose Retry saving. They are not
  applied or uploaded to a different account.
- Refresh first reads the Firebase server, then requests a desktop upload. A
  request failure is reported. Desktop must be running and connected to process
  the request. Desktop polls every 15 seconds; this is not an end-to-end SLA.
- Phone AI review has two explicit scopes: new synchronized usage since the last
  successful phone review, or the last 30 days. Opening Insights does not make a
  paid call automatically. Run a successful 30-day review first to establish the
  per-UID baseline on this phone. Either successful scope becomes the new baseline;
  failure, insufficient data and no-new-usage do not advance it. The baseline
  survives app exit but is local to this phone/account, not shared across phones.
- New usage is a difference between synchronized daily counters at the two review
  boundaries, including same-day additions. It is not an exact event-time query:
  desktop uploads may arrive late and include earlier activity. Offline or invalid
  data cannot consume a window. Rollbacks require a new 30-day review to rebaseline.
  Reclassification/efficiency metrics for a full 30 days are not reused for a delta.
- Desktop fallback always reviews the last 30 days. Desktop upload retry reuses
  the saved result without calling AI again.
- Model pricing shows effective rates from uploaded cost/token summaries, not a
  separate provider billing API. Totals, by_key and cost fields are independent;
  a Console edit to one does not recalculate the others.

Artemis device tests use the real Android app: `flutter run -d emulator-5554 -t lib/main.dart`.
Sign in with a real Google test account in the configured Firebase project.
Preview launchers and the state gallery have been removed. Unit/widget tests can
still use isolated fixtures; their results do not count as real-device E2E.

## Checks

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

Unit/widget tests use fake repositories. Firebase emulator tests are under
`../firebase`. Passing these checks does not verify deployed Rules, signing SHA,
real Google login or every on-device interaction. See
`../docs/static-testing/2026-11-10/test-design-v2.md` for scope and execution plans.
