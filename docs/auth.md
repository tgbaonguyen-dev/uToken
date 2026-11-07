# Google Login — FR-AUTH-001

## Hiện trạng và phạm vi

Nhánh `feat/oauth-setup` tách từ `origin/dev` tại `b8529b2`. Ở commit đó, mobile
đã khai báo Firebase/Google packages nhưng thư mục auth còn trống; desktop có
FirebaseOptions/FirestoreRestClient nhưng chưa có auth service. Google Login chưa được triển khai.

uToken đọc log Codex/Claude/Antigravity trên desktop, chuẩn hóa vào SQLite,
tính daily summary/efficiency rồi gửi aggregate lên Firestore. Mobile đọc kết quả
dưới `users/{uid}`. Input đã gồm cached, output đã gồm thinking; không cộng chồng
khi tính tổng. Auth tạo Firebase UID chung cho hai nền tảng, để Firestore Rules
cô lập dữ liệu. Không đưa transcript, lệnh, source code hoặc token đăng nhập vào document usage.

Đã đối chiếu SRS v0.10 §4.1, §5.3–5.4, §7.3 và báo cáo nghiên cứu: phép tính và
so sánh hiệu suất vẫn thuộc desktop; các ngưỡng nghiên cứu đang chờ chốt không
thay đổi trong task auth. Theo phạm vi được giao, nhánh này làm Google Login,
khôi phục/làm mới phiên và đăng xuất. Pairing, dữ liệu demo, mock aggregate và
sync mỗi 3 phút/nút Sync trong ảnh trao đổi là các phần việc riêng, chưa được nối vào auth.

## Desktop

`IAuthService` / `FirebaseAuthService` ở `UToken.Sync/Auth`:

1. Mở system browser đến Google với `openid email profile`, random `state`, S256 PKCE.
2. Nhận callback trên `127.0.0.1` với cổng ngẫu nhiên đã được bind; kiểm tra state,
   bỏ callback sai; có hủy và timeout 2 phút. Không dùng embedded webview/OOB.
3. Đổi authorization code kèm verifier lấy Google ID token, rồi gọi Firebase
   `accounts:signInWithIdp`. Firebase kiểm tra chữ ký và hiệu lực của Google token.
4. Giữ Firebase ID token trong RAM. Lưu refresh credential bằng DPAPI CurrentUser
   trên Windows hoặc Secret Service qua `secret-tool` trên Linux. Không fallback
   sang file plaintext. Kho lưu tách theo Firebase project và emulator/production.
5. `GetIdTokenAsync` làm mới trước hạn 1 phút; nhiều request đồng thời dùng một
   lần refresh. UID đổi hoặc refresh token bị thu hồi → xóa phiên, yêu cầu đăng nhập lại.
   Mất mạng/5xx giữ credential để thử lại. Đăng xuất xóa vault và bộ nhớ.

MainWindow có nút Google Login, hủy, khôi phục lại phiên và đăng xuất để thử tích hợp;
UI desktop đầy đủ ở nhánh khác không được đưa vào task này. Khi nối sync, truyền
`auth.GetIdTokenAsync` vào `FirestoreRestClient`; lấy UID từ `auth.CurrentUser`,
không dùng Google account ID/email hay Firebase Admin credentials.

Thiết lập:

```powershell
Copy-Item desktop/src/UToken.Desktop.App/appsettings.Local.example.json desktop/src/UToken.Desktop.App/appsettings.Local.json
# Điền Firebase web API key và Desktop OAuth client ID/secret trong file Local.
$env:UTOKEN_Firebase__UseEmulator = 'false'
dotnet run --project desktop/src/UToken.Desktop.App
```

OAuth client phải thuộc đúng Firebase/Google Cloud project và có loại Desktop app.
Nếu consent screen đang Testing, thêm tài khoản thử nghiệm trong Google Auth Platform.
Desktop client secret là cấu hình của public client, không thay thế PKCE.
Linux: cài `libsecret-tools`, đăng nhập desktop session có Secret Service/keyring
đã mở khóa. Không chạy app bằng root để đọc credential của người dùng khác.

## Android

1. Firebase Console → project → Add app → Android; package **`com.utoken.mobile`**.
2. Thêm SHA-1 và SHA-256 của debug keystore; thêm fingerprint của release/Play signing
   key nếu thử bản release. Có thể lấy fingerprint debug bằng lệnh dưới đây.
3. Authentication → Sign-in method → Google: bật provider, chọn support email.
4. Tải lại `google-services.json` sau khi bật Google/thêm fingerprint; đặt ở
   `mobile/android/app/google-services.json`. File phải có client khớp package và
   Web OAuth client (`client_type: 3`) cho `default_web_client_id`.
5. Chạy app trên thiết bị/emulator có Google Play Services:

```powershell
keytool -list -v -alias androiddebugkey -keystore "$env:USERPROFILE/.android/debug.keystore" -storepass android -keypass android
cd mobile
flutter pub get
flutter run
```

Nếu cần truyền Web OAuth client rõ ràng:
`flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=<web-client-id.apps.googleusercontent.com>`.
Không dùng Desktop OAuth client ID/secret cho Android. App dùng Google Sign-In 6.x
theo dependency hiện tại, đổi Google ID token bằng Firebase Auth SDK; token được SDK
quản lý. Router có màn chờ khôi phục phiên, Welcome khi signed out/hết phiên,
Account trong Settings để đăng xuất. Khi resume, app kiểm tra lại token; mất mạng
giữ phiên, token bị thu hồi khóa route và hiện `Session expired`.

Repository mobile chưa có cấu hình Android trước task này. File `appsettings.Local.json`
được cung cấp chỉ có cấu hình desktop, không chứa package/App ID/SHA Android;
không đủ để suy ra hoặc tạo `google-services.json` hợp lệ.

## Emulator và nghiệm thu

`Firebase:UseEmulator=true` trong desktop trỏ Firebase Auth đến `127.0.0.1:9099`,
Firestore đến `127.0.0.1:8080`. Google OAuth vẫn dùng Google thật; cờ này không tạo
tài khoản giả và không bypass xác thực Google. Mobile mặc định dùng Firebase thật;
đặt desktop `UseEmulator=false` để hai app có cùng UID/dữ liệu production.

Test tự động không sử dụng credential hoặc tài khoản thật:

```text
dotnet build desktop/UToken.Desktop.slnx
dotnet test desktop/UToken.Desktop.slnx
cd mobile
flutter analyze
flutter test
```

Test bao phủ callback loopback thực với state sai/đúng, PKCE vector RFC7636,
hủy callback, đổi Google credential → Firebase session, refresh đồng thời,
rotation, restore, UID mismatch, revoked/expired token, mất mạng/5xx,
DPAPI round-trip trên Windows, route guard và UI login → account → logout.

Nghiệm thu thật sau khi Firebase/Android đã được cấu hình: đăng nhập cùng Google
account trên desktop/mobile, đối chiếu UID; hủy account chooser; tắt mạng rồi thử lại;
khởi động lại app để kiểm tra restore; thu hồi phiên để kiểm tra `Session expired`;
đăng xuất rồi mở lại để chắc phiên không phục hồi. Kiểm tra Rules bằng hai UID
riêng biệt trước khi nối data repositories. Kiểm tra Linux keyring trên Ubuntu
và Android release ký bằng fingerprint đã đăng ký vẫn cần môi trường tương ứng.

Máy phát triển hiện có Flutter 3.29.3/Dart 3.7.2. `intl ^0.20.3` có sẵn trong dev
đòi Dart mới hơn và không resolve với Flutter này; chấp nhận `intl >=0.19.0 <0.21.0`
để flutter_localizations chọn bản tương thích trên cả SDK hiện tại và SDK mới hơn,
giữ API NumberFormat đang dùng. Gradle wrapper 8.10.2
cần JDK tương thích (khuyến nghị 17); Android Studio trên máy hiện dùng JDK 25.
Không đưa đường dẫn JDK/SDK riêng của máy hoặc credential vào Git.

Lượt build APK đầu tiên bị chặn bởi ổ C hết dung lượng khi Gradle tạo instrumented
Kotlin compiler JAR trong cache. Lượt kiểm tra tiếp theo đã có dung lượng trống;
cấu hình Android cũng bật core library desugaring cho thư viện thông báo có sẵn
trong pubspec. Vẫn cần thêm google-services.json hợp lệ, hoàn tất Android SDK
licenses nếu build yêu cầu và chạy Google Login trên thiết bị thật trước khi
nghiệm thu. Các bước này không được coi là đã pass chỉ dựa vào unit/widget test.

## Tài liệu API

- [Google OAuth for Desktop: PKCE và loopback](https://developers.google.com/identity/protocols/oauth2/native-app)
- [Firebase Auth REST: signInWithIdp và refresh token](https://firebase.google.com/docs/reference/rest/auth)
- [Firebase Auth với Google trên Flutter](https://firebase.google.com/docs/auth/flutter/federated-auth)
- [Google Sign-In 6.3.0](https://pub.dev/packages/google_sign_in/versions/6.3.0)
- [Google Services Gradle plugin](https://developers.google.com/android/guides/google-services-plugin)
- [Cấu hình Android của flutter_local_notifications 18.0.1](https://pub.dev/packages/flutter_local_notifications/versions/18.0.1)
