# Phạm vi AI review sau điều chỉnh ngày 2026-11-11

Tài liệu này thay thế mô tả incremental desktop trong báo cáo merge trước đó. Các báo cáo cũ giữ nguyên như bằng chứng lịch sử.

## Hành vi

- Desktop bỏ checkpoint incremental; mỗi lần review dùng dữ liệu 30 ngày gần nhất. Checkpoint cũ trong file state không chặn review. Giữ cơ chế retry upload.
- Mobile cho chọn review phần usage mới kể từ lần review thành công hoặc tổng quan 30 ngày. Mở Insights không tự gọi AI trả phí.
- Lần đầu cần review 30 ngày thành công để tạo mốc. Cả hai chế độ thành công đều cập nhật chung mốc của tài khoản trên điện thoại này; mốc lưu theo UID trong secure storage, không dùng chung giữa các điện thoại.
- Không có usage mới, lỗi provider, lỗi upload hoặc thiếu dữ liệu không làm tiến mốc. Lỗi lưu checkpoint được thông báo.
- Cloud hiện cung cấp tổng hợp theo ngày. Chế độ usage mới lấy chênh lệch giữa các snapshot đã đồng bộ, bao gồm phần tăng trong cùng ngày và upload muộn; không thể cam kết lọc chính xác theo thời điểm phát sinh từng sự kiện. Usage chưa đồng bộ chưa được review.

## Kiểm chứng

- .NET: 266 đạt, 4 test production chủ động bỏ qua.
- Flutter: 218 đạt; analyzer không có lỗi/cảnh báo.
- Firebase Emulator: 14 đạt.
- Chạy bổ sung JudgeSyncTests sau khi thêm trường checkpoint legacy vào fixture: 13 đạt.
- Android debug APK build thành công: mobile/build/app/outputs/flutter-apk/app-debug.apk.
- Không gọi AI trả phí thật, không deploy Security Rules và không xác nhận E2E trên Firebase production trong lượt này.
