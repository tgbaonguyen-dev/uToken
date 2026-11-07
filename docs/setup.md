# Thiết lập môi trường

For opt-in tests against the real Firebase project, see [Real Firebase verification](firebase-live-check.md).

## Firebase
1. Tạo project Firebase (gói Spark), bật Authentication → Google, tạo Firestore (Native mode).
2. Android: thêm app Android, tải `google-services.json` vào `mobile/android/app/` (đã gitignore). Chạy `flutterfire configure` để sinh `lib/firebase_options.dart` (đã gitignore).
3. Desktop: tạo OAuth client loại **Desktop app** trong Google Cloud Console. Tạo `desktop/src/UToken.Desktop.App/appsettings.Local.json` (đã gitignore) theo mẫu `appsettings.Local.example.json`.
4. Deploy rules: `cd firebase && npx firebase deploy --only firestore:rules,firestore:indexes`.

## Secrets trên GitHub
Không cần secret để chạy CI (test dùng emulator và fixtures). Chỉ thêm secret khi làm workflow release.

## Desktop: Google sign-in on Windows

1. Open [Firebase Console](https://console.firebase.google.com/) and select the team's existing project. Do not create a separate project if the mobile app already uses one.
2. In Authentication > Sign-in method, enable Google, select a support email and save. See [Firebase Google provider setup](https://firebase.google.com/docs/auth/web/google-signin).
3. Open [Google Cloud Console](https://console.cloud.google.com/) with the **same project**. Configure Google Auth Platform > Branding and Audience. If the app is in Testing, add the Google account you will use under Test users.
4. In Google Auth Platform > Clients, create an OAuth client with application type **Desktop app**. Copy its client ID and client secret. A Web application client is not the desktop client required here. The app uses the system browser and a dynamic loopback redirect; see [Google desktop OAuth documentation](https://developers.google.com/identity/protocols/oauth2/native-app).
5. In Firebase > Project settings > General, obtain the Project ID and Web API key. If necessary, register a Web app to obtain the Firebase configuration. Do not use a service-account private key.
6. Run/build the desktop project once. If missing, `desktop/src/UToken.Desktop.App/appsettings.Local.json` is automatically created from `appsettings.Local.example.json` before build and copied beside the executable. Existing local settings are preserved. Open the generated source file and replace all four placeholders. Keep `UseEmulator` set to `false` for the real Firebase project. This local file is ignored by Git; do not commit it or paste tokens into chat.
7. For cloud sync, ensure the default Firestore database exists and the project's approved rules/indexes from `firebase/` are deployed. The deployment command above changes backend rules: have the project owner review and run it against the correct project. Sign-in itself does not require a Firestore write.
8. Stop and rerun the desktop app so MSBuild copies the local config beside the executable:

   ```powershell
   dotnet run --project desktop/src/UToken.Desktop.App
   ```

   `UTOKEN_` environment variables override JSON (for example `UTOKEN_Firebase__UseEmulator`). Remove stale overrides if the app still uses an emulator.
9. Choose Google sign-in, complete consent in the browser, and return to the app. Verify the account appears both in the app and Firebase Authentication > Users. Restart to check session restore, then sign out and restart to verify the account stays signed out. Use Sync now to check Firestore separately; a permission error is a rules/configuration failure, not proof that Google sign-in failed.

The configuration file is loaded from the executable directory, not the shell's working directory. Do not edit only a generated `bin/` copy; it can be overwritten on the next build.

Automated sync tests use fake Google/Firebase HTTP responses and do not establish that the real project's OAuth configuration works. A live sign-in still requires the local configuration and interactive browser consent.

On Windows, saved Firebase sessions are encrypted with DPAPI CurrentUser. Existing plaintext sessions are migrated during restore. A damaged session or one copied from another Windows account requires signing in again; the app does not fall back to saving plaintext when encryption fails. Google/Firebase sign-in failures show a safe, specific explanation without displaying raw server responses or tokens.
