# μToken Admin

Web console for admins: system overview, users (search, detail, suspend), crash reports
(resolve/reopen), desktop sync health, AI reviews, and an append-only admin audit log.

There is no server: the page talks to Firestore directly and **Firestore Rules decide who is
an admin** (`firebase/firestore.rules`, `isAdmin()` = a document `admins/{uid}` exists).
Admins can read every user's data but cannot edit usage; they can only suspend/unsuspend
accounts (`suspended/{uid}`, which blocks the owner's access) and change a crash report's status.
Every change is written to `admin_audit`.

## Run

```bash
npm install
npm run dev          # http://localhost:5174, real Firebase project
npm test             # unit tests for the aggregations
npm run build        # → ../firebase/admin-dist
```

Against the emulator: start `firebase emulators:start --only firestore,auth --project utoken-78191`
in `firebase/`, then `VITE_USE_EMULATOR=1 npm run dev` (an email/password form appears for test logins).

## First admin

1. Deploy rules and indexes: in `firebase/`, `npx firebase deploy --only firestore:rules,firestore:indexes`.
2. Open the console and sign in with Google; it shows your UID.
3. In Firebase Console → Firestore, create `admins/<UID>` with a field `email`. Reload.

## Deploy

`npm run build` (writes `firebase/admin-dist`), then in `firebase/`: `npx firebase deploy --only hosting` →
https://utoken-78191.web.app

## Data notes

- User list comes from `users/{uid}`: the phone writes `email`, `display_name`,
  `mobile_app_version`, `last_seen_at` on launch; the desktop writes `email`, `desktop_name`,
  `desktop_os`, `last_sync_at` on sync. Older accounts show only a UID until they open a new build.
- Crash rows are the app's own `crash_reports`; stack traces stay in Crashlytics (linked).
