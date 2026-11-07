# Thiết lập môi trường

## Firebase
1. Tạo project Firebase (gói Spark), bật Authentication → Google, tạo Firestore (Native mode).
2. Android: đăng ký app với package **`com.utoken.mobile`**, thêm SHA-1/SHA-256 của khóa debug và khóa release dùng để ký app, bật Google provider rồi tải lại `google-services.json` vào `mobile/android/app/` (đã gitignore). Thư mục Android và Google Services Gradle plugin đã có trong repo. Dùng Android 9+, Flutter 3.29.3/Dart 3.7.2 hoặc mới hơn, JDK 17 và Android SDK. Xem quy trình chi tiết trong [auth.md](auth.md).
3. Desktop: tạo OAuth client loại **Desktop app** trong cùng Google Cloud project. Sao chép `desktop/src/UToken.Desktop.App/appsettings.Local.example.json` thành `appsettings.Local.json` cùng thư mục và điền giá trị thật (đã gitignore). App đọc `appsettings.json` → `appsettings.Local.json` → biến môi trường `UTOKEN_*`; đặt `Firebase:UseEmulator=false` khi dùng Firebase thật. Linux cần `libsecret-tools` và một Secret Service/keyring đang hoạt động; Windows dùng DPAPI của tài khoản hiện tại.
4. Deploy rules: `cd firebase && npx firebase deploy --only firestore:rules,firestore:indexes`.

## Secrets trên GitHub
Không cần secret để chạy CI (test dùng emulator và fixtures). Chỉ thêm secret khi làm workflow release.

Kiểm tra auth: `dotnet test desktop/UToken.Desktop.slnx`; trong `mobile/` chạy `flutter pub get`, `flutter analyze`, `flutter test`. Test auth dùng HTTP/repository giả lập và callback loopback thật, không cần tài khoản Google hay credential thật.

Kiểm tra tích hợp Auth/Firestore cần Node 24.12+, Java 21 và Firebase Emulator.
Xem [auth-verification.md](auth-verification.md) để bật 3 integration test và chạy
rules tests tuần tự. Không đặt biến `UTOKEN_TEST_AUTH_HOST` thì integration test
được đánh dấu skip; unit test vẫn chạy.
