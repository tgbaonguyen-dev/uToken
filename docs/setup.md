# Thiết lập môi trường

## Firebase
1. Tạo project Firebase (gói Spark), bật Authentication → Google, tạo Firestore (Native mode).
2. Android: register `com.utoken_mobile` and the signing SHA, then put `google-services.json` in `mobile/android/app/` (gitignored). Android uses native Google Services resources; generating `firebase_options.dart` is not required.
3. Desktop: tạo OAuth client loại **Desktop app** trong Google Cloud Console. Tạo `desktop/src/UToken.Desktop.App/firebase.desktop.json` (đã gitignore) theo mẫu `firebase.desktop.example.json`.
4. Deploy rules: `cd firebase && npx firebase deploy --only firestore:rules,firestore:indexes`.

## Secrets trên GitHub
Không cần secret để chạy CI (test dùng emulator và fixtures). Chỉ thêm secret khi làm workflow release.


## Current Android / Windows login and pairing

Follow [PAIRING.md](../PAIRING.md) before publishing Rules. The Android app uses
native Google Services resources, so this setup does not require generating
`firebase_options.dart`. Deploy pairing and connection rules together and exclude
both collections from any owner catch-all. Review the whole rule file against the
team's production version before deploying; no cloud deployment was performed here.
