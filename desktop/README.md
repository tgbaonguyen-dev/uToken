# Desktop (.NET 10 + Avalonia)

| Project | Trách nhiệm | Phụ thuộc |
|---|---|---|
| `UToken.Core` | Model, chuẩn hóa token, chi phí, phân loại kết quả task, thống kê, luật kết luận | (không) |
| `UToken.Collectors` | Tìm và đọc log Codex, Claude Code, Antigravity theo luồng | Core, ZstdSharp |
| `UToken.Storage` | SQLite: schema, migration, truy vấn | Core, Microsoft.Data.Sqlite, Dapper |
| `UToken.Sync` | Firebase Auth (REST), Firestore REST, hàng đợi gửi | Core, Storage |
| `UToken.Desktop.App` | Avalonia UI, tray, dịch vụ chạy nền | tất cả |

Quy tắc: `Core` không phụ thuộc gì khác; mọi công thức trong SRS §10.1 nằm ở `Core` và có unit test.

```bash
dotnet restore
dotnet test
dotnet run --project src/UToken.Desktop.App
```
