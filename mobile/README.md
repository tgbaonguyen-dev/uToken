# Mobile (Flutter, Android)

Thư mục `android/` đã được tạo cho package `com.utoken.mobile`, Android 9+.
Đăng ký package và SHA-1/SHA-256 trong Firebase, bật Google provider rồi đặt
`google-services.json` vào `android/app/` (không commit). Xem [thiết lập auth](../docs/auth.md).

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Cấu trúc (feature-first)

```
lib/
├── main.dart
├── app/            router (go_router), theme, shell bottom navigation
├── core/
│   ├── models/     model đọc từ Firestore, khớp contracts/firestore/*.schema.json
│   ├── format/     định dạng số token, tiền (FR-SETT-001)
│   └── firebase/   provider Firestore, Auth
└── features/
    ├── auth/         M01  (FR-AUTH-001, FR-DEMO-001)
    ├── pairing/      M02, M03, M10 (FR-CONN-001/002)
    ├── tokens/       M04, M04B, M06 (FR-DASH-001, FR-ANLY-001)
    ├── analytics/    M05 (FR-ANLY-002, FR-ANLY-004)
    ├── efficiency/   M05B, M05C (FR-ANLY-003)
    ├── insights/     M07, M08, M15 (FR-RECO-001, FR-AIKEY-001)
    ├── budget/       M11, O02 (FR-BUDG-001, FR-NOTI-001)
    └── settings/     M09, M12, M13, M14, O01
```

Mỗi feature chia `data/` (đọc Firestore), `domain/` (model, logic thuần), `presentation/` (màn hình, widget).
State management: Riverpod. Mobile **không tự tính** P50/P90 hay khoảng tin cậy — chỉ hiển thị `efficiency/current` do desktop tính.

`authRepositoryProvider` cung cấp Google Sign-In/Firebase Auth; `authControllerProvider`
theo dõi phiên. Router chặn màn hình riêng tư khi chưa đăng nhập hoặc hết phiên.
Các data repository mới nên đọc `userDocumentProvider` để scope vào UID hiện tại.
Firebase SDK giữ phiên; ứng dụng không tự ghi ID/refresh token vào preferences hay Firestore.
