# LLM Judge trên desktop

Desktop gửi cho Claude duy nhất bản tóm tắt 30 ngày: tổng token/chi phí theo provider và model, tỉ lệ cache, thinking, requests/chats, process metrics và setup reports. Không gửi project key, prompt, code, nội dung hội thoại hay tên file; các giá trị trong evidence được desktop lấy lại từ catalog.

## Nhà cung cấp

| Provider | Model mặc định | Key |
|---|---|---|
| Gemini · Antigravity (`google`) | `gemini-2.5-flash` | Google AI Studio; gói miễn phí có thể dùng dữ liệu để cải thiện dịch vụ |
| Claude (`anthropic`) | `claude-sonnet-5-5` | Anthropic API |
| OpenAI · Codex (`openai`) | `gpt-4.1-mini` | OpenAI API |

Người dùng chọn provider/model trong Settings. Key được lưu riêng trong thư mục dữ liệu ứng dụng (600 trên Linux/macOS, DPAPI CurrentUser trên Windows), hoặc đọc biến môi trường tương ứng khi phát triển.

Đặt `Judge:ApiKey` trong `appsettings.Local.json` hoặc biến môi trường `ANTHROPIC_API_KEY`. Không ghi key vào log hoặc repository. Mỗi lần chạy dùng model `claude-sonnet-5-5`, output có cấu trúc và giới hạn 16.000 token; chi phí phụ thuộc token input/output theo bảng giá Anthropic.

So với SRS, FR-RECO-001 và FR-AIKEY-001 đã chuyển judge sang desktop. Màn M15 trên điện thoại không còn nhập API key; mobile chỉ đọc `users/{uid}/insights/current`.
