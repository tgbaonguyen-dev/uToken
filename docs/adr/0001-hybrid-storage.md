# ADR-0001: Lưu trữ lai SQLite + Firestore

- Trạng thái: Chấp nhận (2026-11-05)
- Liên quan: SRS FR-DATA-001, FR-DATA-002, FR-SYNC-002, §6

## Bối cảnh
Firebase gói Spark có hạn mức đọc/ghi/lưu trữ tính cho cả project. Một người dùng nặng sinh ~1.000 usage event/ngày.
Đưa từng event lên Firestore chỉ đủ cho khoảng 18 người dùng và mỗi lần mở dashboard tháng đọc ~30.000 document.

## Quyết định
- Event và task chỉ lưu trong SQLite trên desktop.
- Firestore lưu **một document mỗi ngày** (`users/{uid}/daily/{YYYY-MM-DD}`) chứa map breakdown theo nguồn/model/project, và `efficiency/current`.
- Desktop chỉ ghi document có thay đổi; ~2 lượt ghi mỗi lần sync.

## Hệ quả
- Mobile không tự tính được P50/P90 hay khoảng tin cậy; desktop tính sẵn trong `efficiency/current`.
- Document ngày phải < 1 MiB (thực tế vài chục KB).
