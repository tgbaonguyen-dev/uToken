# Mobile (Flutter, Android)

Android is already configured for `com.utoken_mobile`; do not run `flutter create`
over this project. Place the correct ignored `android/app/google-services.json`,
register the signing SHA and enable Google Authentication in Firebase.

```powershell
flutter pub get
flutter run -d emulator-5554 -t lib/main.dart
```

See [FIREBASE_LOGIN.md](FIREBASE_LOGIN.md) and [PAIRING.md](../PAIRING.md) for real
login/pairing, new Rules and the distinction between live and demo modes.
`main.dart` uses native Android Firebase resources; `firebase_options.dart` is not
required for this Android setup. `main_ui_preview.dart` keeps the UI fixtures.

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
