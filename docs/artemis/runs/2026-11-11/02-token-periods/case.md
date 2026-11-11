# TOK-PERIODS — Bộ lọc Tokens trong UI preview

- Yêu cầu tạm UI-FILTER: thay đổi kỳ phải cập nhật tổng token và chi phí theo mock tương ứng.
- Tiền điều kiện: cùng APK/device/model trong NAV-01; đang ở Tokens, dữ liệu mock.
- Thao tác: Day → Week → Month → Total → Month, chờ số liệu mới hiển thị sau mỗi lần bấm.
- Trace: 2d6349f4-e858-42eb-b8e3-05492e08a107; thời lượng Artemis báo 118.7 giây.
- Kết quả: PASS cho 5 lần chọn, không phải kiểm tra số liệu Firebase.

| Kỳ | Fixture totalTokens | Fixture estimatedCost | Quan sát UI |
|---|---:|---:|---|
| Day | 244000 | 1.51 | 244,000 / $1.51 — khớp |
| Week | 2000000 | 12.35 | 2,000,000 / $12.35 — khớp |
| Month | 6830736 | 42.18 | 6,830,736 / $42.18 — khớp |
| Total | 18450000 | 113.92 | 18,450,000 / $113.92 — khớp |
| Month lần nữa | 6830736 | 42.18 | 6,830,736 / $42.18 — khớp |

Nguồn kỳ vọng: mobile/lib/core/mock/data/tokens_periods.json trong commit build 9f92415. Đối chiếu độc lập sau khi agent báo số quan sát; không cung cấp các giá trị kỳ vọng trong task prompt.

Trace có 5 click và 1 report action. Ảnh before/after và action overlay được copy cùng thư mục. Agent báo lựa chọn thay đổi và nội dung đọc được; chưa phải đánh giá pixel-perfect với Figma hay đo hiệu năng.
