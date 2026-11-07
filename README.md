# μToken — AI Usage Tracker & Optimizer

μToken đo **hiệu suất sử dụng token** của Codex CLI, Claude Code và Antigravity từ log trên máy tính,
rồi gửi số liệu tổng hợp về điện thoại.

- **Desktop** (`desktop/`): .NET 10 + Avalonia UI, chạy trên Windows và Linux. Đọc log, tính chỉ số, đẩy dữ liệu tổng hợp lên Firestore.
- **Mobile** (`mobile/`): Flutter, chỉ Android. Hiển thị dashboard, gọi LLM để gợi ý.
- **Firebase** (`firebase/`): Firestore Security Rules, index, test rules bằng emulator.
- **Contracts** (`contracts/`): JSON Schema của các document Firestore, dùng chung cho desktop và mobile.
- **Tài liệu** (`docs/`): SRS, kiến trúc, quyết định kiến trúc (ADR), báo cáo nghiên cứu.

> Nguyên tắc bất di bất dịch: prompt, response, lệnh terminal, source code và credential **không bao giờ** rời khỏi máy người dùng.

## Cấu trúc thư mục

```
utoken/
├── .github/                 CI, template issue/PR, CODEOWNERS, dependabot
├── contracts/               JSON Schema + dữ liệu mẫu (fixtures) dùng chung
│   ├── firestore/           schema các document trên Firestore
│   └── fixtures/            log mẫu đã làm sạch cho test parser
├── desktop/                 .NET 10 solution
│   ├── src/
│   │   ├── UToken.Desktop.App/   Avalonia UI, tray, khởi động nền
│   │   ├── UToken.Core/          model, công thức, thống kê, luật kết luận
│   │   ├── UToken.Collectors/    parser Codex, Claude Code, Antigravity
│   │   ├── UToken.Storage/       SQLite, migration
│   │   └── UToken.Sync/          Firebase Auth, Firestore REST, hàng đợi
│   └── tests/
├── mobile/                  Flutter app (Android)
│   ├── lib/
│   │   ├── app/             router, theme
│   │   ├── core/            firebase, model từ contracts, format số
│   │   └── features/        auth, pairing, tokens, analytics, efficiency, insights, budget, settings
│   └── test/
├── firebase/                firestore.rules, indexes, test rules
├── docs/                    srs/, adr/, architecture.md, research/
└── scripts/                 tiện ích (tạo label GitHub…)
```

## Bắt đầu nhanh

| Phần | Yêu cầu | Lệnh |
|---|---|---|
| Desktop | .NET SDK 10 | `cd desktop && dotnet restore && dotnet test` rồi `dotnet run --project src/UToken.Desktop.App` |
| Mobile | Flutter 3.29.3+, JDK 17, Android SDK | `cd mobile && flutter pub get && flutter test` |
| Firebase | Node 20+, Firebase CLI | `cd firebase && npm ci && npm test` (chạy emulator) |

File cấu hình Firebase thật (`google-services.json`, `appsettings.Local.json`) **không commit**. Xem `docs/setup.md` và `docs/auth.md`.

## Làm việc nhóm

Xem [CONTRIBUTING.md](CONTRIBUTING.md): quy tắc nhánh, commit, PR, review và Definition of Done.
# uToken
