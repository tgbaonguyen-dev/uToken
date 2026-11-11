# BUDGET-DIALOG — Validation và Cancel (UI mock)

- Trace: 657063c2-a9c9-4535-961d-0f3d792df6c4; runner completed sau 257.7 giây.
- Cùng APK/device/model như NAV-01. Giá trị đầu: $50.00.
- Yêu cầu tạm UI-BUDGET: dialog từ chối ngoài 1–100000 USD, tối đa 2 số lẻ; Cancel giữ nguyên hạn mức.
- Nguồn kỳ vọng: mobile/lib/core/widgets/budget_limit_dialog.dart và FigmaPixelScreen xử lý Edit monthly limit/Save budget.
- Kế hoạch: thử 0, thử 120.00, Cancel, kiểm tra Budget/Settings giữ $50.00; không Apply hoặc Save budget.

## Kết quả đối chiếu

| Checkpoint | Kết quả | Bằng chứng |
|---|---|---|
| Mở Settings → Budget → dialog | PASS | steps 1–4 |
| Thông báo validation và Apply bị vô hiệu với input không hợp lệ/rỗng | PASS | step-05-before_screenshot.jpg: lỗi Enter 1–100000 USD, up to 2 decimals.; Apply mờ |
| Chính xác input số 0 | CHƯA XÁC NHẬN | tool báo Typed 0, nhưng ảnh chỉ thấy ký hiệu $ và ô rỗng; không đủ căn cứ kết luận giá trị 0 đã vào field |
| Input hợp lệ 120.00 làm Apply bật | BLOCKED bởi automation | input_text và thao tác bàn phím không tạo được giá trị quan sát; agent thử lại nhiều lần, đã được yêu cầu dừng |
| Cancel không thay đổi ngân sách | PASS | steps 13–15: Budget và Settings vẫn $50.00 |
| Trở về Tokens | PASS | step 16 quan sát Tokens |

**Kết luận toàn case: PARTIAL / BLOCKED, không phải PASS đầy đủ**, dù runner báo completed. Chưa kiểm tra Save/Apply hoặc persistence qua restart. Không quan sát ANR trong lượt này. Không sửa mã ứng dụng hay dữ liệu lưu.

Trace đầy đủ có 16 bước; ảnh chọn lọc before/after và overlay trong cùng thư mục. Agent tự báo test 0 đạt nhưng nhận định này đã được hạ xuống chưa xác nhận sau khi đọc ảnh độc lập.

Lượt thử riêng input hợp lệ tiếp theo bị quota HTTP 429 trước khi có bước UI được ghi nhận: [chi tiết và thời điểm reset](valid-input-retry.md).
