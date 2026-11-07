# Google Login — kết quả kiểm tra 2026-11-07

## Kết luận

Phần code auth, hồi quy và tích hợp Firebase Emulator đã qua các bước bên dưới.
Chưa nghiệm thu FR-AUTH-001 trên staging/thiết bị thật: chưa có cấu hình Firebase
Android, chưa đăng nhập Google thật để đối chiếu UID giữa Android và desktop.
Các kết quả emulator không xác nhận chữ ký/consent/fingerprint của Google production.

## Kết quả tự động

| Kiểm tra | Kết quả | Phạm vi |
|---|---|---|
| Desktop Release build | Pass, 0 warning/error | Toàn solution .NET 10/Avalonia |
| .NET Release tests | 56 pass, 0 fail/skip | Core 15, Collectors 2, Sync/Auth 39; có 3 test emulator |
| Flutter analyze | Pass, không có issue | Source và test mobile |
| Flutter tests | 25 pass | Controller/router/UI và production auth repository tại SDK boundary |
| Firestore rules | 9 pass | SDK thật kết nối Firestore Emulator, không gọi cloud |
| Android compiler/linker debug | Pass trong bản sao QA | Java/Kotlin, Dart, native libraries và đóng gói APK; chưa có Firebase config |
| Android cấu hình Firebase chuẩn | Blocked | `google-services.json` chưa có; Google Services task báo thiếu file |

Ba test tích hợp .NET gọi Firebase Auth REST và Firestore REST trên emulator thật:

- Hai client dùng cùng Google subject nhận cùng Firebase UID; client mới khôi phục
  phiên từ refresh credential và giữ đúng UID.
- Owner ghi/đọc được document của mình; UID khác không đọc/ghi được; anonymous bị
  chặn. Sau sign-out, client không lấy được ID token để gửi yêu cầu ghi tiếp.
- User bị disable trên Auth Emulator không khôi phục được phiên; app xóa credential
  và trả `AUTH_INVALID`.

Google credential trong test tích hợp là fixture JSON được Auth Emulator hỗ trợ,
không phải token Google thật. Test chỉ nhận host `127.0.0.1` và project cố định
`demo-utoken`; không dùng credential của file Local hay gọi Firebase production.

Để kiểm tra compiler Android độc lập với cấu hình Firebase còn thiếu, đã tạo một
bản sao tạm của mobile ngoài repo, bỏ duy nhất dòng apply Google Services plugin
trong bản sao đó và chạy `:app:assembleDebug` thành công. Không tạo JSON Firebase
giả, không thay đổi plugin trong source chính. APK này chỉ là compile smoke test,
không được dùng làm bằng chứng Google Login đã hoạt động hoặc phân phối như bản
app đã cấu hình. Các file Dart của bản sao được đối chiếu với source chính.

## Lỗi đã tái hiện và sửa

1. **Mobile còn mở route khi cleanup phiên hết hạn bị chậm.** Test mới đã fail trên
   code cũ. Controller hiện khóa route ngay, chặn đăng nhập trong lúc cleanup và
   bỏ kết quả validation cũ khi người dùng đã chuyển phiên. Test còn kiểm tra SDK
   phát sự kiện cũ sau cleanup thất bại và double tap.
2. **Desktop có thể phát exception chưa xử lý khi Auth trả JSON `null`/array hoặc
   sai kiểu.** Chuyển thành lỗi auth có thể thử lại, không đưa payload vào thông báo.
   Google 429/5xx được phân biệt với hủy consent; callback `server_error` không còn
   bị báo là người dùng hủy. Bổ sung callback có state/code trùng, favicon và state sai.
3. **Vault không xóa được thì session vẫn còn trong RAM.** Sign-out hiện khóa bộ nhớ
   trước; lỗi xóa credential vẫn được báo, có nút thử đăng xuất lại. DPAPI ghi qua
   file tạm riêng cho mỗi lần ghi để hai instance không tranh cùng file; kiểm tra
   ghi đồng thời, hủy ghi vẫn giữ credential cũ và không để file tạm.
4. **Rule fallback của dev bỏ qua validation daily/sync_requests.** Hai test rules
   có sẵn đã fail vì dữ liệu sai được ghi thành công. Fallback hiện loại hai vùng
   đã có rule riêng; sync update giữ nguyên trigger và chỉ nhận state trong contract.
   Owner vẫn xóa được daily, UID khác không ghi/xóa được. Test xóa dữ liệu emulator
   trước mỗi case để kết quả không phụ thuộc lần chạy trước.
5. **Thiết lập test Firebase chưa chạy được theo hướng dẫn.** Sửa `node --test tests/`
   thành `node --test`, khai báo Node >=24.12 theo dependency đang khóa, thêm Auth
   Emulator vào cấu hình local. Emulator Firestore chạy với Java 21.

Giới hạn còn lại của schema: Firestore Rules không có API đo byte của document
đã serialize; `request.resource.size()` không hợp lệ và đã được bỏ. Giới hạn
900 KB trong contract vẫn phải được producer của daily summary kiểm tra trước
khi sync. Đây chưa phải nghiệm thu tính năng sync/aggregation.

## Chạy lại

Yêu cầu: .NET SDK 10, Flutter 3.29.3/Dart 3.7.2 hoặc tương thích, Node 24.12+,
Java 21 cho Firestore Emulator. Dùng JDK 17 cho Gradle 8.10.2/Android build.

Terminal 1:

```powershell
cd firebase
npm ci
npx firebase emulators:start --project demo-utoken --only auth,firestore
```

Terminal 2, từ repo root, chạy các suite tuần tự vì rules tests clear dữ liệu:

```powershell
$env:UTOKEN_TEST_AUTH_HOST = '127.0.0.1:9099'
$env:UTOKEN_TEST_FIRESTORE_HOST = '127.0.0.1:8080'
dotnet build desktop/UToken.Desktop.slnx -c Release
dotnet test desktop/UToken.Desktop.slnx -c Release --no-build

$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080'
Push-Location firebase
npm test
Pop-Location

Push-Location mobile
flutter analyze
flutter test
Pop-Location
```

Lần kiểm tra này dùng port cách ly 19099 (Auth), 18080 (Firestore), cùng project
`demo-utoken`. Khi không đặt `UTOKEN_TEST_AUTH_HOST`, 3 integration test được đánh
dấu skip rõ ràng; không được tính là đã pass emulator trong một lần chạy như vậy.

## Bước nghiệm thu thật còn lại

- Đăng ký Android `com.utoken.mobile`, SHA-1/SHA-256 debug và release, bật Google
  provider rồi tải `google-services.json` vào `mobile/android/app/`.
- Cấu hình desktop cùng Firebase project, Desktop OAuth client đúng loại và
  `UseEmulator=false`; file Local được giữ ngoài Git.
- Build APK với Google Services task được bật, thử cùng Google account trên
  Android và desktop, đối chiếu UID; hủy login, tắt mạng, restart, thu hồi phiên,
  sign-out và mở lại. Thử bản release với đúng fingerprint và thử Linux keyring.
- Rules mới ở nhánh Git và emulator; chưa deploy lên Firebase thật trong bước QA này.

## Tài liệu đối chiếu

- [Firebase: mock IDP credentials chỉ trong Auth Emulator](https://firebase.google.com/docs/emulator-suite/connect_auth)
- [Firebase Auth REST và refresh token](https://firebase.google.com/docs/reference/rest/auth)
- [Firestore: các allow chồng lấp được kết hợp bằng OR](https://firebase.google.com/docs/rules)
- [Firestore Resource: API của document trong Rules](https://firebase.google.com/docs/reference/rules/rules.firestore.Resource)
