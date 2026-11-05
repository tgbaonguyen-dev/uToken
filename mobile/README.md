# Mobile (Flutter, Android)

Thư mục `android/` chưa có trong mẫu. Lần đầu chạy:

```bash
flutter create --platforms=android --org com.yourteam --project-name utoken_mobile .
flutter pub get
flutterfire configure   # sinh lib/firebase_options.dart (đã gitignore)
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
