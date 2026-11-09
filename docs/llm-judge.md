# AI review (LLM judge) trên desktop

Desktop gửi bản tóm tắt 30 ngày gần nhất cho một model AI do người dùng chọn. Model chấm điểm
cách dùng token (0–100, hạng A–D) theo 6 chiều `cache`, `context`, `reasoning`, `reliability`,
`outcomes`, `hidden_cost` và đưa tối đa 5 gợi ý. Kết quả được đẩy lên
`users/{uid}/insights/current`; mobile chỉ đọc document này.

## Cấu hình (Settings → AI review)

| Nhà cung cấp | Mã | Model mặc định | Lấy key ở đâu |
|---|---|---|---|
| Gemini · Antigravity (mặc định) | `google` | `gemini-flash-latest` | Google AI Studio, có gói miễn phí (gói miễn phí có thể dùng dữ liệu để cải thiện dịch vụ) |
| Claude | `anthropic` | `claude-sonnet-5-5` | Anthropic Console |
| OpenAI · Codex | `openai` | `gpt-6-luna` | OpenAI platform |

- **Model**: gõ mã model bất kỳ, hoặc chọn trong danh sách lấy từ bảng giá models.dev đã tải về
  (lọc theo nhà cung cấp, kèm chi phí ước tính mỗi lần chấm).
- **API key**: ô dạng mật khẩu. Key lưu trong `judge-keys.bin` ở thư mục dữ liệu app
  (`%LOCALAPPDATA%\uToken` trên Windows, `~/.local/share/uToken` trên Linux): Windows mã hóa bằng
  DPAPI CurrentUser, Linux/macOS ghi file quyền 600. Để trống ô key khi lưu thì giữ key cũ.
  Key không bao giờ được ghi vào `judge-state.json`, log, Diagnostics hay Firestore.
- **Test connection** gửi một brief mẫu nhỏ (không chứa dữ liệu thật) để kiểm tra key và model.
- **Run AI review now** chạy ngay, bỏ qua công tắc bật/tắt và giới hạn thời gian.
- Công tắc bật/tắt; card hiện điểm, headline và thời điểm chạy gần nhất.

Cấu hình, bản insights tốt gần nhất và lần chạy cuối nằm trong `judge-state.json` cùng thư mục.
Không còn cấu hình `Judge` trong `appsettings*.json` và không đọc key từ biến môi trường.

## Khi nào chạy

Sau mỗi lần Sync đẩy dữ liệu lên Firestore thành công, nếu AI review đang bật, đã có key cho nhà
cung cấp đang chọn và lần chạy trước đã cũ hơn `MinHoursBetweenRuns` (24 giờ). Khi chưa đủ 5 chat
hoặc chưa có request nào trong 30 ngày, desktop không gọi model mà ghi `status: insufficient_data`.

Lỗi của judge **không** làm Sync thất bại. Desktop ghi log, giữ insights cũ và đẩy lại chúng với
`status: failed` và `error_code` (`invalid_api_key`, `rate_limited`, `provider_error`, `refused`,
`truncated`) để mobile vẫn hiển thị kết quả trước kèm cảnh báo. Diagnostics có dòng `AI review`
(nhà cung cấp, model, có key hay không, lần chạy cuối và kết quả).

## Dữ liệu gửi đi

Chỉ gửi rubric cố định (`JudgePrompt.System`) và brief gồm catalog chỉ số có id, nhãn đọc được và
giá trị: tổng chat/request/token/chi phí, tỉ lệ cache, tỉ lệ request lỗi, process metrics (theo
từng nguồn), setup report theo provider/model và token/chi phí/cache/thinking theo từng model.
**Không** gửi prompt, câu trả lời, code, tên file, đường dẫn hay project key. Evidence trong kết
quả được desktop đối chiếu lại với catalog, model không thể bịa số.

Xem chính xác những gì sẽ gửi, không gọi AI:

```sh
cd desktop
dotnet run --project src/UToken.Desktop.App -- --judge --dry-run
```

`--judge` (không có `--dry-run`) in catalog rồi gọi thật bằng key và model đã lưu, in InsightDoc.

## Chi phí

Mỗi lần chấm ước tính khoảng 6.000 token vào và 2.000 token ra; card Settings nhân với giá
models.dev của model đang chọn (ví dụ `claude-sonnet-5-5` ở $3/$15 mỗi triệu token ≈ $0.048 mỗi
lần). Mặc định chạy tối đa một lần mỗi ngày, nên khoảng 30 lần một tháng. Claude giới hạn output
16.000 token; khi bị cắt, kết quả là `failed` với `truncated`. Gemini có gói miễn phí.

## Thay đổi so với SRS

- **FR-RECO-001** (gợi ý tối ưu): SRS đặt việc sinh gợi ý ở mobile. Nay desktop sinh bằng LLM judge
  trên dữ liệu tổng hợp, ghi `users/{uid}/insights/current` theo
  `contracts/firestore/insights.schema.json`; mobile chỉ hiển thị.
- **FR-AIKEY-001** (API key AI): SRS cho nhập key trên mobile (M15). Nay key nhập và lưu trên
  desktop; không có key nào đi qua Firestore. Người dùng chọn được 3 nhà cung cấp thay vì một.
- Firestore Rules: chỉ chủ tài khoản đọc/ghi `users/{uid}/insights/*`
  (test trong `firebase/tests/rules.test.js`).
