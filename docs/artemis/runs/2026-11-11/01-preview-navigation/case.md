# NAV-01 chạy lại — PASS

- Trace: 30f96a78-69ac-4c2c-9c90-4eeafe7f7a91.
- Device: Pixel_10 / emulator-5554; APK UI preview/mock đã cài từ build commit 9f92415, không build lại trong lượt này.
- Provider/model: OpenRouter / nvidia/nemotron-3.5-super-vl:free.
- Thời lượng runner: 83.1 giây.
- Kỳ vọng: Welcome → View demo → Tokens → Analytics → Tokens, xác nhận màn đích sau từng click.
- Thực tế: đủ 3 click thành công và 1 report action; Tokens hiển thị 6,830,736 và $42.18; Analytics có tiêu đề và subtitle Token mix, models, and cost.; cuối cùng trở về Tokens.
- Không thấy ANR trong lượt này. Hộp thoại cũ không xuất hiện lúc bắt đầu nên agent không phải đóng hộp thoại hay relaunch trong task.
- Không đăng nhập, sync, sửa cài đặt, đổi bộ lọc hay gọi AI review.
- Lượt PASS này được chọn làm bộ bằng chứng NAV-01 chính. Thư mục lặp và ảnh cũ đã được bỏ theo yêu cầu; [lịch sử sự cố](../../../run-history.md) vẫn ghi nhận ANR. Một lượt PASS không chứng minh nguyên nhân treo đã được sửa.

## Lượt liền trước

Trace 43f0dd82-c744-4cf6-b4a4-8dba9a02c47e kết thúc failed sau 39.4 giây, report rằng hộp thoại ANR đã có lúc bắt đầu. Không hoàn thành luồng điều hướng. Lượt đó không được tính PASS.
