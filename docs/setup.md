# Thiết lập môi trường

## Firebase
1. Tạo project Firebase (gói Spark), bật Authentication → Google, tạo Firestore (Native mode).
2. Android: thêm app Android, tải `google-services.json` vào `mobile/android/app/` (đã gitignore). Chạy `flutterfire configure` để sinh `lib/firebase_options.dart` (đã gitignore).
3. Desktop: tạo OAuth client loại **Desktop app** trong Google Cloud Console. Tạo `desktop/src/UToken.Desktop.App/firebase.desktop.json` (đã gitignore) theo mẫu `firebase.desktop.example.json`.
4. Deploy rules: `cd firebase && npx firebase deploy --only firestore:rules,firestore:indexes`.

## Secrets trên GitHub
Không cần secret để chạy CI (test dùng emulator và fixtures). Chỉ thêm secret khi làm workflow release.
