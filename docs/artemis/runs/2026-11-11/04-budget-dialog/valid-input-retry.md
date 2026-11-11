# Thử riêng input hợp lệ — BLOCKED bởi quota

- Trace: adc44380-fc20-4d27-82ff-13db58244b55.
- Mục tiêu: focus ô USD, chờ bàn phím số mở, lấy hierarchy mới, nhập 120.00 tối đa hai lần; xác nhận Apply bật rồi Cancel, không lưu.
- Provider/model: OpenRouter / nvidia/nemotron-3.5-super-vl:free.
- Kết quả: BLOCKED trước khi có bước UI được ghi nhận. Tác vụ được hủy sau khi provider trả quota error; không tính PASS hoặc lỗi ứng dụng.
- Lỗi đã rút gọn, bỏ định danh tài khoản: HTTP 429; Rate limit exceeded: free-models-per-day; X-RateLimit-Limit=50; X-RateLimit-Remaining=0; X-RateLimit-Reset=1794441600000.
- Reset do provider thông báo: 07:00 ngày 12/11/2026, UTC+07:00. Quota model/provider vẫn có thể áp dụng thêm sau reset.
- MCP trace summary: No action steps have been recorded yet. Không xuất steps.json giả/rỗng để làm bằng chứng đã chạy.

## Nhận định kỹ thuật (chưa xác nhận nguyên nhân)

Model không có tùy chọn bắt buộc bật riêng để nhập bàn phím số. Layout dialog thay đổi khi IME mở có thể làm index/tọa độ cũ sai. Ngoài ra artemis/drivers/android/adb_driver.py ưu tiên clipboard + KEYCODE_PASTE và trả True sau khi gửi lệnh, không đối chiếu text thực tế trong field. Vì vậy tool báo Typed không chứng minh input thành công. Chưa sửa Artemis hay mã uToken trong lượt thử này; cần chạy tiếp khi có quota để phân biệt các khả năng.
