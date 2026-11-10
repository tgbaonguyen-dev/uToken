# Định dạng log Antigravity (giải OQ-10)

Khảo sát ngày 10/11/2026 trên một máy Linux có Antigravity CLI và IDE. Định dạng không có tài liệu
chính thức; bản đồ trường dưới đây suy ra từ dữ liệu thật và có thể đổi khi Antigravity cập nhật.
Đổi parser thì tăng `ParserVersion` trong `AntigravityCollector` để quét lại từ đầu.

## Vị trí

| Thư mục | Nội dung |
|---|---|
| `~/.gemini/antigravity-cli/conversations/<id>.db` | Mỗi hội thoại CLI một file SQLite |
| `~/.gemini/antigravity-ide/conversations/<id>.db` | Hội thoại IDE (có thêm `-wal`, `-shm`) |
| `~/.gemini/antigravity/` | Chỉ có chỉ mục `conversation_summaries.db` (`app_data_dir = antigravity-cli`); `conversations/` rỗng |

Đây không phải log Gemini CLI.

## Dữ liệu dùng

Mỗi dòng `gen_metadata` là một lần gọi model; cột `data` là protobuf.

| Trường | Nghĩa | Ghi chú |
|---|---|---|
| `1.19` | tên model | ví dụ `gemini-3.8-flash-n`, `gemini-pro-default`, `claude-opus-4-6-thinking` |
| `1.4.2` | input không cache | |
| `1.4.5` | cache read | lượt sau ≈ toàn bộ context lượt trước |
| `1.4.3` | output | = `1.4.9` + `1.4.10` |
| `1.4.9` | thinking | |
| `1.4.10` | output văn bản | không dùng |
| `1.4.6` | chưa rõ | luôn 24, không dùng |
| `1.4.11` | response id | duy nhất, làm `SourceEventId` |
| `1.9.4.1` | thời điểm (giây Unix) | chỉ bản IDE |

Bản CLI không ghi thời điểm trong `gen_metadata`. Lượt trả lời của model là các dòng `steps` có
`step_type = 15`, theo đúng thứ tự `gen_metadata`; thời điểm ở `steps.metadata` trường `1.1`.

Collector chỉ đọc các trường trên và cột `steps.metadata` (dấu thời gian). Không đọc
`steps.step_payload` hay chuỗi nào khác, nên không chạm vào nội dung hội thoại.

Dòng có 0 token (lượt bị hủy) bị bỏ qua. Dòng thiếu khối `1.4` hoặc thiếu thời điểm tính là dòng lỗi.

## Kết quả trên máy khảo sát

17 file, 1167 lần gọi, 0 dòng lỗi, id không trùng. Từ 25/09 đến 06/11/2026; khoảng 89% input là
cache read. Chi phí ước tính theo bảng giá models.dev.

## Giới hạn

- Engine chỉ đọc lại file khi kích thước hoặc thời gian sửa của `.db` đổi. Bản IDE ghi vào `-wal`
  trước; dữ liệu mới hiện ra sau khi SQLite checkpoint (thường khi file WAL đầy hoặc khi app đóng).
- Chưa có tín hiệu kết quả task (test/build) và chưa phân biệt phiên phụ cho Antigravity.
- Chưa đối chiếu với con số token mà Antigravity tự hiển thị.
