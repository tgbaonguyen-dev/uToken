# Artemis: kết quả và bằng chứng kiểm thử

**Lượt app thật mới nhất — 12/11/2026:** [Báo cáo và bằng chứng](runs/2026-11-12/README.md): 4 case đạt trong phạm vi quan sát, 1 case Budget BLOCKED bởi nhập liệu automation. Có ghi riêng timeout Pro, locator sai, lỗi chữ `1 days` và các phần chưa kiểm thử.

Thư mục này lưu bằng chứng trong repository uToken, không phụ thuộc đường dẫn cài Artemis trên máy người chạy.

## Kết quả mới

**Current scope:** Artemis tests the real Android app via `mobile/lib/main.dart`, Google sign-in and Firebase, using a real Google test account. Preview launchers and the state gallery are removed. Results below are historical MOCK APK results (`9f92415`), not production E2E passes.

## Run the real app

```powershell
cd D:\IntelliJProjects\uToken\mobile
flutter run -d emulator-5554 -t lib/main.dart
```

Rebuild/install from main.dart before dispatching Artemis; an old installed APK may still be preview. Sign in with the same test account on desktop to test sync. Never put passwords, tokens or API keys in tasks or evidence. Record entrypoint, commit, device and before/after values in each run. Unit/widget fixtures are separate from device E2E.

No real-account Artemis run has been performed as part of this removal. The previously configured free endpoint had quota/data restrictions; select an appropriate provider before sending real-account screenshots. Do not silently switch to paid models.


| Case | Phạm vi | Kết quả | Bằng chứng |
|---|---|---|---|
| NAV-01 | Welcome → View demo → Analytics → Tokens | PASS | [Trace](runs/2026-11-11/01-preview-navigation/trace-summary.md), [steps](runs/2026-11-11/01-preview-navigation/steps.json) và ảnh trong cùng thư mục |
| TOK-PERIODS | Day / Week / Month / Total / Month; đối chiếu tổng token và chi phí mock | PASS | [Case và kết quả](runs/2026-11-11/02-token-periods/case.md), trace JSON/Markdown và ảnh trong cùng thư mục |
| NAV-DETAIL | Analytics → Efficiency → Back; Insights, Settings và trở về Tokens | PASS, agent phục hồi 1 lỗi locator | [Case và kết quả](runs/2026-11-11/03-navigation-details/case.md), trace và ảnh trong cùng thư mục |
| BUDGET-DIALOG | Validation dialog và Cancel giữ nguyên ngân sách | PARTIAL / BLOCKED phần nhập số | [Case và đối chiếu ảnh](runs/2026-11-11/04-budget-dialog/case.md), trace và ảnh cùng thư mục |

Thông tin cấu hình và giới hạn của lượt chạy: [báo cáo OpenRouter](run-2026-11-11-openrouter-smoke.md).

NAV-01 trong thư mục `01-preview-navigation` hiện là lượt PASS mới nhất (trace `30f96a78-69ac-4c2c-9c90-4eeafe7f7a91`, 83.1 giây). Các thư mục chạy lại trùng đã được bỏ theo yêu cầu; xem [lịch sử sự cố](run-history.md) để không làm mất ghi nhận ANR.

Các lượt Gemini bị 503/504 và lượt khởi tạo client thất bại là BLOCKED bởi công cụ/provider, không được cộng vào PASS ứng dụng: [nhật ký](run-2026-11-11-initial-smoke.md).

## Quy ước bằng chứng

- `runs/<ngày>/<case>/`: mô tả case, metadata, trace thực, ảnh và kết quả đối chiếu.
- `steps.json` mới là kết quả export chi tiết qua Artemis MCP; không dùng file `[]` từ trình compile trace làm bằng chứng đã chạy.
- PASS chỉ áp dụng những điều đã quan sát/đối chiếu. UI preview dùng mock không xác nhận Firebase, persistence sau restart hay AI review thật.
- Không lưu API key, token, cấu hình `.env` hoặc dữ liệu tài khoản thật.
- Log `.log` có thể bị Git ignore; trace JSON/Markdown và ảnh mới là bằng chứng chính để bàn giao.
- Các kịch bản được dispatch qua Artemis MCP. Chưa có runner deterministic độc lập; không coi task prompt là test tự động không cần LLM.

## Tài liệu cũ

[Báo cáo ban đầu](artemis_android_test_report.md) là tài liệu lịch sử. Ảnh và trace cũ hiện đang được xóa khỏi working tree; có thể tra lại trong lịch sử Git. Kết luận phủ toàn bộ 74 state, 100% và phản hồi dưới 400 ms trong báo cáo cũ chưa có đủ bằng chứng để xác nhận. Không gộp chúng vào kết quả mới.

## Phạm vi tiếp theo chưa chạy trong bộ mới

- Dialog ngân sách: cần xử lý định vị/nhập liệu của automation để xác nhận chính xác số 0, input hợp lệ, Apply và Save; validation ô rỗng và Cancel đã quan sát.
- Restart preview: xác nhận rõ cài đặt nào được lưu và cài đặt nào chỉ trong phiên.
- Các state auth/network/data: chạy từng case với kỳ vọng riêng, không suy ra coverage từ enum.
- App thật: đăng nhập/giữ phiên/đổi tài khoản, manual sync và offline; cần bộ riêng, dữ liệu test và provider phù hợp chính sách dữ liệu. Endpoint miễn phí hiện tại chỉ dùng mock.
