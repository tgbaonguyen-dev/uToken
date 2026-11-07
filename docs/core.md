# Core tính toán (desktop)

Tài liệu bàn giao phần core: đọc log → SQLite → task → `daily` và `efficiency/current`.
Người dùng chính: thành viên 4 (sync Firestore), bạn desktop (màn hình), 2 bạn mobile (đọc schema).

## 1. Luồng xử lý

```
~/.codex/sessions/**/rollout-*.jsonl(.zst)   ─┐
~/.claude/projects/**/*.jsonl                ─┤ Collectors (đọc phần mới từ offset, chỉ giữ số)
                                              ▼
SQLite: usage_events, turns, projects, source_files (offset + ngữ cảnh parser)
                                              ▼
TaskBuilder: gom turn cách nhau ≤ 2 phút thành task → outcome_state
                                              ▼
DailyAggregator  → DailyDoc       (users/{uid}/daily/{YYYY-MM-DD}, schema_version 2)
EfficiencyCalculator → EfficiencyDoc (users/{uid}/efficiency/current, schema_version 1)
```

| Project | Nội dung |
|---|---|
| `UToken.Core` | Hàm thuần, không I/O: `TaskBuilder`, `DailyAggregator`, `EfficiencyCalculator`, `Stats`, `VerdictRules`, `StaticPriceBook`, `TestCommandDetector`, `ProjectKey` |
| `UToken.Collectors` | Parser Codex và Claude Code: event + tín hiệu turn. Antigravity vẫn để trống (OQ-10) |
| `UToken.Storage` | `SqliteStore`: ghi theo transaction, đọc theo khoảng thời gian, `daily_local` có cờ dirty |
| `UToken.Engine` | `UsageEngine`: điểm vào duy nhất cho app và lớp sync |

## 2. Cách dùng cho lớp sync (thành viên 4)

```csharp
var (engine, store) = EngineFactory.Create(
    settings.DatabasePath,
    settings.Collectors.Enabled,
    AppSettings.ExpandHome(settings.Collectors.CodexHome),
    AppSettings.ExpandHome(settings.Collectors.ClaudeHome));

// Mỗi lần "Sync now" hoặc mỗi 15 phút (gọi tuần tự, không chạy song song):
AnalysisSnapshot snap = engine.Run();
foreach (DailyDoc d in snap.ChangedDaily)          // chỉ document có nội dung đổi so với lần trước
    write($"users/{uid}/daily/{d.Date}", UsageEngine.ToJson(d));
write($"users/{uid}/efficiency/current", UsageEngine.ToJson(snap.Efficiency));
// Ghi xong thì gọi store.MarkDailySynced(d.Date) cho từng ngày.
```

- `UsageEngine.ToJson(doc)` trả JSON đúng tên trường của schema. Lớp sync chỉ cần đổi JSON thường sang định dạng `fields` của Firestore REST.
- `engine.BuildDaily(date)` và `engine.BuildEfficiency()` tính lại bất kỳ lúc nào; cùng dữ liệu thì cho cùng nội dung (trừ `updated_at`).
- `store.GetDirtyDaily()` liệt kê các ngày đã tính nhưng chưa đẩy, dùng khi mất mạng.
- **Chú ý `by_key`:** khóa có dạng `codex|gpt-5.6-sol|3f2a9c1b04de`, nên có dấu `|` và dấu `.`. Ghi cả document (không dùng `updateMask`) thì không sao. Nếu dùng `updateMask` hoặc field path thì phải bọc khóa trong backtick.

Chạy thử không cần giao diện:

```bash
cd desktop
dotnet run --project src/UToken.Desktop.App -- --scan                 # dùng DB thật trong ~/.local/share/uToken
dotnet run --project src/UToken.Desktop.App -- --scan --db /tmp/t.db --out /tmp/out   # DB tạm, ghi JSON ra thư mục
```

## 3. Đọc số liệu (cho mobile)

- Token: `input` đã gồm `cached` và `cache_write`; `output` đã gồm `thinking`. Tổng = `input + output`. Không cộng thêm cached hay thinking.
- Chi phí: số nguyên micro-USD (`cost_micro / 1e6` ra USD).
  - `cost_micro = null` nghĩa là không event nào có giá. Hiển thị "thiếu giá", không hiển thị 0.
  - Nếu một vài model không có giá, tổng chỉ cộng các model có giá.
- Giá trị `null` nghĩa là nguồn không cung cấp, hiển thị "—" hoặc "Không có dữ liệu". Ví dụ: `thinking` của nguồn không có thinking, `duration_*` của Claude Code.
- `chats` chỉ đếm phiên chính. Phiên phụ (Codex `guardian_review`/sub-agent, Claude Code `isSidechain`) vẫn được cộng vào token và chi phí, và được tách riêng ở `side_requests`, `side_tokens`, `side_cost_micro`.
- Context growth trung bình = `context_growth_sum / context_growth_count`.
- Độ trễ trung bình = `duration_sum_ms / duration_count`. Hiện chỉ Codex có dữ liệu này.
- `process_metrics[].value`:
  - Các tỉ lệ là phân số 0..1, gồm `cache_hit_rate`, `thinking_share`, `error_rate`, `retry_rate`, `hidden_cost_share`.
  - `context_growth` và `cost_tail` là bội số (4.7 = 4,7×).
  - `tokens_per_turn_vs_median` là mức thay đổi (0.49 = +49%).
  - `provider = null` là gộp mọi nguồn.
  - `label = no_data` khi kỳ có ít hơn 5 chat.
- `setups[]`:
  - `verdict = insufficient` thì hiển thị "Chưa đủ dữ liệu · n_tasks/20".
  - `compared_to = null` nghĩa là trong nhóm không có setup nào khác để so.
  - `mde` là phân số (0.19 = 19 điểm phần trăm).
  - `weekly_sr` có 5 phần tử, mỗi phần tử ứng với 7 ngày tính từ `period_start`; phần tử `null` là tuần có ít hơn 5 task đã xác minh.

Các trường thêm so với schema ban đầu (đã ghi vào `contracts/firestore/`, đều là optional):
- `daily`: `side_requests`, `bloated_chats`.
- `efficiency`: `pricing_version`, `setups[].n_verified`, `setups[].cpst_ci_low_micro`, `setups[].cpst_ci_high_micro`.

## 4. Giả định cần nhóm duyệt (OQ-03)

| # | Giả định | Ở đâu |
|---|---|---|
| 1 | Task = các turn liên tiếp cách nhau ≤ 2 phút trong cùng phiên chính. Có turn gộp vào thì coi là "hỏi lại trong 2 phút", nên task chỉ còn verified hoặc likely_failure | `TaskBuilder` |
| 2 | Nhóm việc theo số lần gọi model: Small ≤ 10, Medium ≤ 40, Large > 40 | `TaskBuilderOptions` |
| 3 | Danh sách lệnh test/build: pytest, npm/pnpm/yarn test\|build, flutter test, dotnet test\|build, cargo, go test, make… Lệnh chỉ được đọc trong bộ nhớ, không lưu | `TestCommandDetector` |
| 4 | Bảng giá để cứng `static-2026-11-06`; `codex-auto-review` tạm tính bằng giá gpt-5; cache write Claude tính theo mức 5 phút | `StaticPriceBook` |
| 5 | Mỗi setup được so với setup có nhiều task nhất trong cùng công cụ và nhóm việc; setup đứng đầu so với setup thứ hai | `EfficiencyCalculator.Setups` |
| 6 | Nhãn chỉ chuyển "review" khi vượt ngưỡng Review của SRS (cache < 50%, context > 5×, thinking 7 ngày > 2× trung vị ngày, lỗi lệnh > 10% hoặc ≥ 3 lỗi liên tiếp, retry > 10%, token/turn > +50%, P90/P50 > 3, chi phí ngầm > 30%) | `ProcessMetrics` |
| 7 | Sai số SR tính theo cụm phiên. Khi SR = 0% hoặc 100% thì dùng sai số Agresti–Coull. Khoảng tin cậy CPST dùng bootstrap theo phiên, 1.000 lần, seed cố định | `Stats` |

## 5. Chưa làm hoặc chưa kiểm chứng

- **Antigravity:** chưa có token (OQ-10). Collector trả rỗng.
- **Chi phí phiên phụ chưa cộng vào setup tạo ra nó** (SRS: "phiên phụ được cộng vào chi phí của setup tạo ra nó"). Hiện chỉ có trong `side_*` và `hidden_cost_share`.
- **So sánh khác công cụ:** chưa làm, `cross_tool` luôn là `false`.
- **Retry rate:** chỉ đếm được khi log ghi request lỗi (Claude Code `isApiErrorMessage`). Codex không ghi nên luôn bằng 0.
- **Turn bị người dùng ngắt giữa chừng trong Claude Code:** chưa nhận ra, vì phải đọc nội dung tin nhắn mới biết.
- **Đổi phiên bản schema SQLite:** xóa toàn bộ bảng rồi quét lại từ log, vì dữ liệu đều suy ra được từ log.
- **Hiệu năng:** đã chạy trên log thật (290 file, khoảng 68 MB) mất 1,7 giây lần đầu và 0,3 giây các lần sau. Chưa thử với file 500 MB.
- **Claude Code CLI:** đã kiểm tra trên log Claude Code (VS Code và SDK) của máy nhóm trưởng.
