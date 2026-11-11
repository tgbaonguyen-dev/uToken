# Lịch sử chạy lại và sự cố

Chỉ giữ một thư mục bằng chứng chính cho mỗi case. Các thư mục NAV-01 chạy lại trùng đã được xóa theo yêu cầu; không diễn giải việc dọn thư mục là lỗi cũ đã được sửa.

| Trace | Kết quả / ghi nhận |
|---|---|
| 034ece09-4064-48c7-96d6-8bb08fc5439d | NAV-01 PASS ban đầu, 92.9 giây; đã thay bằng bằng chứng PASS mới nhất |
| 3906077c-fc56-4888-8999-7889494bcb66 | Không hoàn tất điều hướng; quan sát Android μToken isn't responding; tác vụ hủy; nguyên nhân chưa xác định, thu logcat bị từ chối |
| 43f0dd82-c744-4cf6-b4a4-8dba9a02c47e | Failed do hộp thoại ANR đã có lúc bắt đầu; không tính PASS |
| 30f96a78-69ac-4c2c-9c90-4eeafe7f7a91 | NAV-01 PASS mới nhất, 83.1 giây, 3 click và 1 report; không thấy ANR trong lượt này; được giữ ở 01-preview-navigation |

Raw trace vẫn nằm trong thư mục cài Artemis ngoài repo nếu chưa bị dọn. Không cần chúng để xem ảnh/trace của bộ kết quả chính đã export.
