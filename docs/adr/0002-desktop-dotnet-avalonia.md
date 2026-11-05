# ADR-0002: Desktop dùng .NET 10 + Avalonia UI

- Trạng thái: Chấp nhận (2026-11-05)
- Liên quan: SRS §3.4, OQ-09

## Bối cảnh
Desktop phải chạy trên Windows và Linux (máy demo chạy Ubuntu), chạy nền, đọc file lớn theo luồng, dùng SQLite.

## Quyết định
- .NET 10 (LTS), C#.
- UI: **Avalonia UI** vì chạy được cả Windows và Linux. (WPF, WinUI chỉ Windows; .NET MAUI không hỗ trợ Linux.)
- MVVM: CommunityToolkit.Mvvm. SQLite: Microsoft.Data.Sqlite + Dapper. Zstd: ZstdSharp.Port.

## Hệ quả
- Không có SDK Firestore chính thức cho người dùng cuối trên .NET (Google.Cloud.Firestore là SDK server, bỏ qua Security Rules). Desktop dùng **REST API** với Firebase ID token — xem ADR-0003.
- Hàng đợi offline tự làm bằng SQLite (`sync_queue`), không dựa vào offline persistence của Firestore.
