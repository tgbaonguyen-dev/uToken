# Android Google login

The Android app uses Firebase Authentication in project `utoken-78191`, with package `com.utoken_mobile`. The production entrypoint reads usage from Firebase. Desktop and mobile link through the same Google account; code pairing is no longer required.

## Run

From `mobile/`:

```powershell
flutter run -t lib/main.dart
```

Use a device or emulator with Google Play services. Artemis must run `lib/main.dart` with a real Google test account. Preview launchers have been removed.

## Configuration

- Enable the Google provider in Firebase Authentication.
- Register the Android package and the signing certificate SHA-1 in Firebase Project settings.
- Download the updated `google-services.json` into `mobile/android/app/`. It is ignored by Git and must be configured on another developer's machine too.
- Google Services generates the Android Firebase resources and web OAuth client ID. No desktop OAuth client secret is used or bundled in mobile code.
- Current setup and checks target the debug signing key. A separately signed release needs its own registered signing certificate.

Official references: [Flutter authentication](https://firebase.google.com/docs/auth/flutter/start), [Google sign-in on Android](https://firebase.google.com/docs/auth/android/google-signin).

## Behavior

- Continue with Google opens the native account picker, then exchanges Google credentials for a Firebase session.
- Interactive success opens Connect desktop, which creates a real expiring code and listens for desktop confirmation from Firestore.
- A restored session opens Tokens. The router waits for Firebase's first auth event before choosing a destination.
- Firebase's native SDK retains sessions across normal process termination and handles token refresh. The app does not write ID/refresh tokens into its JSON fixtures or preferences.
- Signed-out users cannot open private routes. Sign out requires confirmation and returns to Sign in. This route guard is a UI control, not a replacement for server authorization.
- Settings and Account use the signed-in profile's name/email; Account uses the provider photo with an initial fallback. Shared mock preferences are not overwritten with the live profile.
- Cancelled/failed sign-in remains on Sign in with a dismissible message and retry. Duplicate requests are blocked while busy. Startup configuration failures show Retry instead of leaving an empty screen.

## Check on a device

1. Sign in using `main.dart`; verify the account appears under Firebase Authentication > Users.
2. Check the name/email in Settings and Account.
3. Fully terminate the app and reopen it. The existing session should restore without opening the Google picker.
4. Sign out, reopen, and verify private routes stay inaccessible.
5. Cancel the Google picker, retry, and test a disconnected network. Confirm errors never display credentials.

Automated tests use an injected auth gateway, not a Google account. They cover session events, duplicate requests, cancellation/errors/retry, logout failure, disposal, private-route guarding and live profile binding without fixture mutation. Actual Google OAuth, process-restart persistence and physical-device behavior still need the manual checks above.

## Validation (2026-11-08)

- `flutter analyze --no-pub`: no issues.
- Full mobile suite: 151 tests passed, including 6 auth integration/controller tests.
- `flutter build apk --debug --no-pub`: succeeded; artifact `build/app/outputs/flutter-apk/app-debug.apk`.
- Real Google account sign-in and process-restart persistence have not been exercised on a device.

## Earlier post-login navigation fix (2026-11-09; superseded for live pairing)

Connect desktop Back exits to Tokens for a live signed-in session. Live pairing now replaces the earlier mock paired-button path: it waits for server confirmation and opens connection information automatically. Skip for now only changes navigation and never marks a device as paired. The UI preview entrypoint retains the old mock flow. Attempts to open preview-only routes in live auth mode fall back to Tokens, rather than repeatedly reopening Connect desktop.

The supplied Android debug log showed Firebase auth-state notification, skipped frames/surface synchronization stalls and a lost device connection, without a Dart/FATAL exception in that excerpt. Rendering performance and the cause of ADB disconnection have not been diagnosed from a trace; these are separate from the confirmed router loop.

## Live-route follow-up audit (2026-11-09)

Checked all 74 preview-state URLs plus the preview hub/auth placeholder under a fresh interactive session whose initial destination is Connect desktop: blocked preview routes resolve to Tokens without reopening setup. Exercised direct-entry Back/Dismiss for 14 detail/overlay screens. Live Tokens Refresh now reloads the sample data in place instead of pushing a redirected preview route; repeated refresh does not grow the page stack. SnackBars are scoped to their owning screen so a refresh notice cannot follow navigation and obscure Account sign-out.

Validation: 15 targeted tests pass (live-route audit, auth, recovery, merged router and extra-screen interactions); analyzer clean. This verifies widget/router behavior, not a new device tap-through or real pairing/backend operation.


## Login/pairing recovery update (2026-11-09)

Live pairing now uses schema version 2 under `users/{uid}/pairing/current` and
`connections/{connectionId}`. Codes are alphanumeric without 0/O/1/I; expiry comes
from server-created time. New pair confirmation opens live S02; existing desktop,
30-second no-response, cancel and revoked states have recovery actions. Disconnect
retains history. View demo now opens fixtures without authentication or pairing
requests; the normal app still initializes the Firebase SDK before Welcome.
See [PAIRING.md](../PAIRING.md) for deployment and SRS clarifications. Earlier
validation counts above describe previous revisions, not the current verification run.
