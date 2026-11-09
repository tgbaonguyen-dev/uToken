# Real Android / Windows login and pairing

Scope: Google login and one same-account desktop connection. Usage, analytics,
notifications and usage synchronization remain mock/not enabled. No Cloud Functions.
The SRS baseline is `docs/srs/PRM323.SRS.v0.10.pdf` pages 5, 11-13 and 15.

## Configure and run

- Firebase project: enable Google Authentication and the `(default)` Firestore database.
- Android package: `com.utoken_mobile`; register the signing SHA, download
  `google-services.json` into `mobile/android/app/` (ignored by Git).
- Desktop: copy `firebase.desktop.example.json` to `firebase.desktop.json` in
  `desktop/src/UToken.Desktop.App/`. Set flattened `ProjectId`, `ApiKey`,
  `OAuthClientId`, `OAuthClientSecret`, `UseEmulator: false`. Use a **Desktop app**
  OAuth client from the same project. No service-account key belongs in either app.
- Deploy/review **both** `users/{uid}/pairing` and `users/{uid}/connections` rules
  from `firebase/firestore.rules`; the owner catch-all must exclude both paths.
  Publishing only one block will not work. Preserve the team's other production rules.
  No production rules have been deployed by this change.
- Missing desktop configuration deliberately selects UI demo. Invalid configuration
  shows a recovery window instead of crashing. Retry reads the file in the running
  app's output directory; alternatively fix the source file and rerun `dotnet run`.

```powershell
# root, terminal 1
 dotnet run --project desktop/src/UToken.Desktop.App
# terminal 2
 cd mobile
 flutter run -d emulator-5554 -t lib/main.dart
```

1. Sign in with the **same Google account** in both apps. On desktop, D01 now
   performs real sign-in when live configuration is present; Sync also offers sign-in/out.
2. Mobile: Connect desktop shows an unambiguous six-character code (`XXX - XXX`).
   Copy it and enter it in desktop Sync > Pair new device. The alphabet excludes
   `0`, `O`, `1`, `I`; lowercase/pasted separators are normalized by desktop.
3. Codes expire ten minutes after `createdAt` assigned by Firestore. Neither
   client can extend expiry by changing its device clock. The countdown is advisory;
   Rules enforce the server deadline.
4. A server-confirmed new pairing opens live S02 Waiting for first usage on mobile.
   It offers View connection / Continue to Tokens and never simulates an upload.
   Existing desktop opens an explicit existing-connection view with disconnect.
5. Pending for 30 seconds shows Desktop no response and a Retry action. This is a
   waiting hint, not proof that the desktop is offline. Cancel pairing invalidates
   a pending request; Generate new code replaces it. Skip only leaves the screen.
6. Disconnect atomically marks current request and connection history `revoked`.
   Desktop polls every four seconds while signed in on Sync/Pairing (no usage writes). Network
   failure retains the last known connection and reports unavailable status.
   No hard five-second delivery guarantee is possible while disconnected.

Refresh tokens persist across app exits: native Firebase on Android and Windows
DPAPI under `%LOCALAPPDATA%\uToken\firebase-session.bin` on desktop. Sign out clears
local authentication, not the association. Explicit Disconnect revokes it.
The desktop installation ID remains `%LOCALAPPDATA%\uToken\desktop-id.txt`.

## Version 2 contract

- Pending/current request: `users/{uid}/pairing/current`.
- Durable connection history: `users/{uid}/connections/{connectionId}` (UUID).
- Fields: `schemaVersion`, `state`, `code`, `connectionId`, `mobileName`,
  `desktopName`, `desktopId`, `createdAt`, `pairedAt`, `revokedAt`, `cancelledAt`.
- States: `pending` (SRS Pairing), `paired` (Connected), `revoked` (Revoked),
  `cancelled` (Disconnected). Expired pending requests cannot be confirmed.
- `connectionId` maps to SRS `connection_id`. Every re-pair creates a new UUID;
  revoked history is retained. A consumed UUID cannot be reused.
- Confirmation/revocation writes the current record and matching connection in
  one commit. Rules require `getAfter()` equality. Desktop additionally supplies
  the read document's `updateTime`; stale/concurrent confirmations are rejected.
- A completed request retried by its same desktop/code returns the current result
  without a new write. A successful commit does not require a follow-up read.
  A lost commit response reports `PAIRING_STATUS_UNKNOWN` until reconciled, rather
  than inventing a failed or successful connection.
- JSON schemas: `contracts/firestore/pairing.schema.json`, `connection.schema.json`.

### Upgrade from the earlier local prototype

Version 1 used `device_pairings/{uid}` with numeric codes. Version 2 intentionally
uses the SRS user subcollections. Old records are not automatically deleted or
imported. Deploy both new rule blocks and generate a fresh code with both updated
apps. Do not deploy mixed v1/v2 clients; review any real legacy association before
removing it. Legacy connection import is not implemented.

## Error semantics and remaining limits

`PAIRING_INVALID`, `PAIRING_EXPIRED`, `PAIRING_USED`, `PAIRING_CHANGED`,
`PAIRING_NOT_FOUND`, `PAIRING_STATUS_UNKNOWN`, `AUTH_INVALID` and
`RESOURCE_NOT_FOUND` have distinct recovery messages. Expired/rejected Firebase
sessions expose sign-in recovery. Offline failures do not automatically log users out.

`ACCOUNT_MISMATCH` cannot be proven from an own-UID-only lookup: a missing request
may be another account's code or no request at all. The UI instructs users to check
both Google accounts; it never queries other users or falsely labels the cause.
This is a documented SRS clarification, not a claim that cross-account discovery exists.
The Google account is the authorization boundary; the code confirms intent within
that account. Multiple phones signed into that account see its one association.
Device attestation, presence/online tracking and usage uploads are not implemented.

Mobile View demo opens bundled fixtures without signing in or calling the pairing
service. The main entrypoint initializes Firebase before Welcome, but entering demo
makes no Firebase data requests. Every demo page carries a DEMO banner; the separate
`main_ui_preview.dart` entrypoint remains available without live login/pairing.

## Verify

```powershell
 dotnet test desktop/tests/UToken.Desktop.Tests --filter "FullyQualifiedName~FirebasePairingTests|FullyQualifiedName~DesktopGoogleAuthTests|FullyQualifiedName~FirstRunTrayTests"
 cd mobile
 flutter analyze --no-pub
 flutter test --no-pub
 cd ../firebase
 npm.cmd ci --ignore-scripts --no-audit --no-fund
 node_modules/.bin/firebase.cmd emulators:exec --only firestore --project demo-utoken "npm.cmd test"
```

Local HTTP/widget/rules tests do not prove deployed Firebase configuration. Before
handoff, test two real clients: sign in, restart both, pair, cancel/expire/renew,
wrong code/account, existing desktop, disconnect from each side, and lose the network
during confirmation. Production rules deployment and real two-device testing remain
manual verification tasks. No DOCX was found in the repository; the original SRS PDF
is preserved and these implementation differences are recorded here.

Local checks for this update (2026-11-09): full mobile suite 162 passed; the
subsequent missing-connection label regression was also verified in the 8-test
pairing suite. Analyzer clean. Desktop auth/pairing 20 tests and related UI/setup
11 tests passed. All 14 Firestore Rules/REST emulator tests passed. Both JSON
schemas compiled with the installed Ajv validator; valid samples passed and
invalid alphabet/pending history were rejected. Desktop and Android debug builds
passed. These checks do not replace the real two-client verification above.

References: [Desktop OAuth/PKCE](https://developers.google.com/identity/protocols/oauth2/native-app),
[Firebase Auth REST](https://firebase.google.com/docs/reference/rest/auth),
[Firestore atomic operations](https://firebase.google.com/docs/firestore/manage-data/transactions).
