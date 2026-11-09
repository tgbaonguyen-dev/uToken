# Kiến trúc

```mermaid
flowchart LR
  subgraph PC[Máy tính người dùng]
    L1[~/.codex/sessions] --> C
    L2[~/.claude/projects] --> C
    L3[~/.gemini/antigravity] --> C
    C[Collectors\nđọc theo luồng, chỉ giữ số] --> DB[(SQLite\nusage_events\ntask_outcomes)]
    DB --> M[Core\nchỉ số, thống kê, luật kết luận]
    M --> Q[(sync_queue)]
  end
  Q -- HTTPS + Firebase ID token --> FS[(Firestore\nusers/uid/daily, efficiency…)]
  FS --> MB[Mobile Flutter\ndashboard]
  MB -- API key của người dùng --> LLM[LLM gợi ý]
```

## Phân chia lưu trữ (ADR-0001)

| Nơi lưu | Dữ liệu | Lý do |
|---|---|---|
| SQLite trên desktop | `source_files`, `sessions`, `usage_events`, `task_outcomes`, `daily_local`, `sync_queue`, `pricing` | Dữ liệu chi tiết, nhiều dòng; cần SQL để tính P50/P90, khoảng tin cậy; không rời máy |
| Firestore | `users/{uid}`: `connections`, `pairing`, `sync_requests`, `daily/{date}`, `efficiency/current`, `recommendations`, `budget`, `budget_alerts`; `pricing/` | Chỉ số liệu tổng hợp; ~2 lượt ghi mỗi lần sync, vừa hạn mức gói Spark |
| Android Keystore | API key LLM | Không bao giờ rời điện thoại |

## Luồng xử lý trên desktop

1. `Collectors` theo dõi thư mục log, đọc phần mới từ `read_offset`, giải nén `.zst`.
2. Chuẩn hóa token (SRS §10.4), gộp trùng theo khóa nguồn, ghi `usage_events`.
3. Gom turn thành task, suy ra `outcome_state`, ghi `task_outcomes`.
4. Tính lại document ngày hôm nay và `efficiency/current`, đánh dấu `dirty`.
5. Theo chu kỳ sync (hoặc khi có `sync_requests`), đẩy các document `dirty` qua `sync_queue`.


## Login / pairing implementation

[PAIRING.md](../PAIRING.md) records the live implementation and SRS clarifications.
Current request: `users/{uid}/pairing/current`; durable records:
`users/{uid}/connections/{connectionId}`. Confirmation/revocation are atomic;
server-created timestamps enforce expiry. Revoked history is retained. Desktop
polls connection status every four seconds while signed in on Sync/Pairing; this is not usage sync.
The architecture diagram describes the target usage pipeline; current usage UI
still reads fixtures. Desktop OAuth/pairing adapters live in App/Services today.
