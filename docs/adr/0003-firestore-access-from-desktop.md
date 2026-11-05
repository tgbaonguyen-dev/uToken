# ADR-0003: Desktop truy cập Firebase qua REST

- Trạng thái: Đề xuất — cần spike
- Liên quan: FR-AUTH-001, FR-SYNC-001, FR-SYNC-002

## Đăng nhập
1. Mở trình duyệt hệ thống với Google OAuth (loopback redirect `http://127.0.0.1:<port>`, PKCE).
2. Đổi Google ID token lấy Firebase ID token: `accounts:signInWithIdp` (Identity Toolkit REST).
3. Làm mới token bằng `securetoken.googleapis.com/v1/token`. Refresh token lưu bằng DPAPI (Windows) / libsecret (Linux).

## Đọc/ghi Firestore
- REST `https://firestore.googleapis.com/v1/projects/{id}/databases/(default)/documents/...` với header `Authorization: Bearer <Firebase ID token>`; Security Rules được áp dụng.
- Ghi nhiều document một lần bằng `:commit` (vẫn tính mỗi document là một lượt ghi).

## Vấn đề mở: nhận `sync_requests` gần thời gian thực
REST không có listener. Lựa chọn:
- (a) Poll mỗi 60 giây: ~1.440 lượt đọc/ngày/người → gói Spark (50.000 đọc/ngày) chỉ ~30 người.
- (b) Dùng `Listen` gRPC của Firestore với Firebase ID token — cần spike để xác nhận.
- (c) Poll thưa (theo chu kỳ sync) và chấp nhận "Sync now" chậm tối đa 1 chu kỳ — phải sửa tiêu chí 30 giây trong SRS.

Spike: thử (b) trong 1 ngày; nếu không được thì chọn (a) với chu kỳ 60–120 giây.
