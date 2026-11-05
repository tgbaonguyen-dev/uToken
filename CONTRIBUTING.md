# Quy trình làm việc

## 1. Nhánh

- `main`: luôn build được, được bảo vệ. Không push trực tiếp.
- Nhánh làm việc tách từ `main`, đặt tên theo loại và số issue:
  - `feat/123-codex-parser`
  - `fix/140-claude-dedupe`
  - `docs/150-srs-v0-10`
  - `spike/160-firestore-listen`
- Nhánh sống ngắn (≤ 3 ngày). Rebase lên `main` trước khi mở PR.

## 2. Commit — Conventional Commits

```
<type>(<scope>): <mô tả ngắn>

[thân: vì sao thay đổi]
Refs: #123, FR-DATA-001
```

- `type`: feat, fix, docs, test, refactor, perf, chore, ci
- `scope`: desktop, mobile, firebase, contracts, docs
- Ví dụ: `feat(desktop): đọc rollout-*.jsonl.zst theo luồng`

## 3. Issue

- Mỗi việc là một issue, dùng template (Feature, Bug, Spike).
- Feature phải ghi **mã yêu cầu SRS** (ví dụ FR-ANLY-003) và tiêu chí nghiệm thu.
- Gắn label `area:*`, `type:*`, `priority:*` và milestone của sprint.

## 4. Pull request

- Một PR = một issue, nhỏ (lý tưởng < 400 dòng thay đổi).
- Tiêu đề theo Conventional Commits; mô tả theo template, có `Closes #<số>`.
- Cần **1 approval** từ CODEOWNERS của phần bị sửa và CI xanh.
- Merge bằng **Squash and merge**; xóa nhánh sau khi merge.

## 5. Definition of Done

- [ ] Đáp ứng tiêu chí nghiệm thu Given/When/Then của FR liên quan
- [ ] Có test (unit test cho công thức và parser là bắt buộc)
- [ ] CI xanh trên cả Windows và Ubuntu (desktop)
- [ ] Không log, không lưu, không gửi prompt/response/lệnh/source code/credential
- [ ] Cập nhật `contracts/` nếu đổi cấu trúc document Firestore (và tăng `schema_version`)
- [ ] Cập nhật SRS nếu thay đổi yêu cầu (ghi CR, không tạo bản song song)

## 6. Quản lý công việc

- **GitHub Projects** (board): Backlog → Ready → In progress → In review → Done.
- **Milestone** = sprint 1 tuần. Họp review cuối sprint xem board và burndown.
- **Release**: tag `desktop-vX.Y.Z` và `mobile-vX.Y.Z`; GitHub Release đính kèm file build.
