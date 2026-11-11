# Thiết lập máy cho thành viên μToken

Làm theo thứ tự dưới đây. Mất khoảng 15 phút.

Có **2 file cấu hình không nằm trên git**. Bảo sẽ gửi riêng cho từng người.
Không đưa 2 file này vào nhóm chat chung và **không commit** chúng.

| File | Đặt ở đâu | Dùng cho |
|---|---|---|
| `google-services.json` | `mobile/android/app/google-services.json` | App Android (Firebase, đăng nhập Google) |
| `appsettings.Local.json` | `desktop/src/UToken.Desktop.App/appsettings.Local.json` | App desktop (đăng nhập Google, đồng bộ Firebase) |

Firebase project: `utoken-78191`.
Mọi người trong nhóm đều có quyền Editor, nên tự mở được
[Firebase Console](https://console.firebase.google.com/project/utoken-78191/overview).

---

## 1. Lấy code

```bash
git clone https://github.com/tgbaonguyen-dev/uToken.git
cd uToken
git checkout dev
```

## 2. App Android (Flutter)

### 2.1. Thêm SHA-1 của máy bạn vào Firebase (bắt buộc)

Đăng nhập Google trên Android chỉ chạy khi SHA-1 của keystore trên máy bạn đã có trong Firebase.
Thiếu SHA-1, app sẽ báo **"Google sign-in is not configured"**.

1. Lấy SHA-1 của debug keystore:
   ```bash
   # Linux / macOS
   keytool -list -v -keystore ~/.android/debug.keystore -storepass android | grep SHA1
   ```
   ```powershell
   # Windows (PowerShell)
   keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -storepass android | findstr SHA1
   ```
   Nếu chưa có file `debug.keystore`, chạy app một lần bằng `flutter run` để Android tự tạo, rồi lấy lại.
2. Vào Firebase Console → ⚙️ **Project settings** → tab **General**.
3. Kéo xuống phần **Your apps** → chọn app Android `com.utoken_mobile` → **Add fingerprint** → dán SHA-1 → **Save**.
4. **Tải lại `google-services.json`** ở chính trang đó (nút tải file), rồi đặt vào `mobile/android/app/`.
   File tải trước khi thêm SHA-1 sẽ không chạy, kể cả file Bảo gửi.

### 2.2. Chạy app

```bash
cd mobile
flutter pub get
flutter test          # kiểm tra nhanh, phải pass hết
flutter run           # chạy trên máy ảo hoặc điện thoại đã bật USB debugging
```

Muốn build bản release để cài lên điện thoại:

```bash
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## 3. App desktop (.NET 10)

1. Đặt file `appsettings.Local.json` Bảo gửi vào `desktop/src/UToken.Desktop.App/`.
   Mẫu của file nằm ở `appsettings.Local.example.json` cùng thư mục.
2. Chạy:
   ```bash
   cd desktop
   dotnet restore
   dotnet test
   dotnet run --project src/UToken.Desktop.App
   ```
3. Trong app, đăng nhập Google bằng **cùng tài khoản** bạn dùng trên điện thoại. Hai máy đồng bộ qua tài khoản này.

## 4. Firebase (rules, test, deploy)

```bash
cd firebase
npm install
npm test              # chạy test Firestore Rules trên emulator
```

Đăng nhập Firebase CLI một lần bằng lệnh `npx firebase login`.
Trước khi deploy, báo nhóm, vì deploy ảnh hưởng tới app đang chạy thật:

```bash
npx firebase deploy --only firestore:rules,firestore:indexes --project utoken-78191
```

## 5. Trang admin web

- Bản đang chạy: **https://utoken-78191.web.app**
- Chạy ở máy mình:
  ```bash
  cd admin
  npm install
  npm run dev           # mở http://localhost:5174
  npm test
  ```
- Không cần file cấu hình nào.
  Cấu hình web Firebase có sẵn trong code và được phép công khai, vì quyền truy cập do Firestore Rules kiểm soát.
- **Muốn có quyền admin:**
  1. Đăng nhập trang admin bằng Google. Trang sẽ báo chưa có quyền và cho bạn sao chép UID.
  2. Vào Firebase Console → **Firestore Database** → tab **Data**.
  3. Mở collection `admins` → **Add document**.
     - Document ID: dán UID vừa sao chép.
     - Thêm trường `email` (kiểu string) với email của bạn.
  4. Tải lại trang admin.
- Deploy trang admin:
  ```bash
  cd admin
  npm run build                  # build ra firebase/admin-dist
  cd ../firebase
  npx firebase deploy --only hosting --project utoken-78191
  ```

## 6. API key cho AI review (không bắt buộc)

Nếu muốn chạy AI review, nhập API key Gemini, Anthropic hoặc OpenAI của bạn trong phần **Settings** của app.
Key chỉ được lưu trên máy bạn, không có file `.env` nào cần chia sẻ.

---

## Lỗi hay gặp

| Triệu chứng | Cách sửa |
|---|---|
| "Google sign-in is not configured" trên Android | Thiếu SHA-1 trên Firebase, hoặc `google-services.json` được tải trước khi thêm SHA-1. Làm lại bước 2.1. |
| Đăng nhập lỗi mà bảng chọn tài khoản không hiện lại | Bản mới đã sửa lỗi này. Nếu vẫn gặp, vào Cài đặt Android → Ứng dụng → μToken → Xóa dữ liệu. |
| Trang admin báo "Firestore từ chối truy cập" | Tài khoản chưa có document `admins/<UID>`, hoặc rules mới chưa được deploy. |
| Trang admin báo "Thiếu index" | Chạy lệnh deploy `firestore:indexes` ở mục 4. Index mới cần vài phút để sẵn sàng. |
| Desktop không đăng nhập được | Kiểm tra `appsettings.Local.json` có đặt đúng chỗ ở mục 3 không. |
