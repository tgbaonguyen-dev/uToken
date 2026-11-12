# Artemis trên app thật — 12/11/2026

Lượt tiếp theo: [Budget bị chặn bởi quota và kết quả Firebase live](06-follow-up/case.md). Chưa hoàn tất toàn bộ bộ test.

Đã cài APK từ `mobile/lib/main.dart` lên `emulator-5554` (Android 17), dùng phiên Firebase hiện có. Không dùng preview/mock. Commit nền `094397e` có sáu file sửa thông báo chưa commit; từng case lưu danh sách file và SHA256 APK để nhận diện đúng bản đã test.

| Case | Kết quả | Bằng chứng |
|---|---|---|
| Day / Week / Month / Total, Custom rồi hủy | ĐẠT, cần phục hồi automation | [01](01-real-token-periods/case.md) |
| Tokens → Analytics → Efficiency → Analytics → Tokens | ĐẠT, agent tự sửa một locator sai | [02](02-real-analytics-navigation/case.md) |
| Custom một ngày 12/11, đối chiếu Day, trở về Month | ĐẠT chức năng; có lỗi chữ nhỏ | [03](03-real-custom-single-day/case.md) |
| Force-stop hoàn toàn rồi mở lại, không đăng nhập lại | ĐẠT với phiên hiện có | [04](04-real-session-restore/case.md) |
| Nhập số và validation Budget | BLOCKED ở thao tác nhập của Artemis | [05](05-real-budget-input/case.md) |

## Quan sát chính

- Day: **6.323.177 token / $0,93**; Week: **559.529.293 / $117,18**; Month: **701.521.151 / $144,44**; Total: **1.896.641.332 / $612,17**. Đã đối chiếu ảnh và trạng thái chọn, không chỉ dựa vào lệnh click.
- Custom 12/11–12/11 khớp Day. Hủy picker và quay lại Month giữ số liệu ban đầu.
- Phiên đăng nhập còn sau `adb shell am force-stop`; không suy rộng sang thu hồi token, đổi tài khoản hoặc cài lại app.
- Budget: Artemis báo nhập nhưng ô vẫn trống. Chẩn đoán ADB cục bộ nhập được `0` và `120.00`; đã xóa phần nhập thử về trống, không bấm Save. Không tính thao tác cục bộ này là Artemis PASS.

## Lỗi và giới hạn

1. **LOW — lỗi chữ:** chip một ngày hiện `1 days`, cần `1 day`. Ảnh [case 03](03-real-custom-single-day/step-06-before_screenshot.jpg). Chưa sửa trong lượt test để giữ nguyên APK.
2. **Automation:** Pro timeout một lần sau 180 giây, để Custom mở. Trace Pro kết thúc FAILED; trace Flash riêng phục hồi thành công. Hai case khác có locator sai được agent tự sửa. Không gọi các lượt này là chạy trơn tru hoàn toàn.
3. **Sync chưa xác nhận:** không tìm thấy tiến trình desktop; mobile báo desktop không phản hồi và hiển thị dữ liệu đã đồng bộ trước đó. Chưa xác nhận upload mới hoặc sửa trực tiếp Firebase Console trong lượt này.
4. Chưa test đăng nhập mới, Account/sign-out/đổi tài khoản, lưu ngân sách hợp lệ, AI review thật, các trạng thái thông báo admin trên thiết bị. Agent chỉ thấy các màn không có thông tin cá nhân; bước Settings để vào Budget được làm cục bộ.
5. Các đường dẫn stdout/stderr do Flash daemon trả về không tồn tại. Đã lưu tool trace, ảnh và trích log daemon có trace ID; log timeout của Pro được lưu riêng. Không coi thiếu log là không có lỗi.

Mỗi thư mục có `case.md`, `metadata.json`, trace, ảnh và bản đồ nguồn ảnh. `manifest.json` chứa SHA256 các bằng chứng. Ảnh before của bước kế tiếp chứng minh kết quả bước trước; overlay đơn thuần không chứng minh thành công. Không có khẳng định phủ toàn bộ state, chính xác 100% hoặc đo hiệu năng.
