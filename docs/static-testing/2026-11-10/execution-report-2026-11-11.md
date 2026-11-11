# Thực thi test và sửa lỗi — 11/11/2026

**Cập nhật sau báo cáo:** đã chạy roundtrip Firebase thật với mobile, kiểm tra
offline/preferences và xử lý audit từ 14 xuống 0. Xem
[kết quả bổ sung](live-followup-2026-11-11.md). Phạm vi và số liệu bên dưới là
snapshot của lượt chạy trước; không dùng chúng để phủ nhận kết quả bổ sung.

## Phạm vi

Nhánh dev, HEAD `7093df8` cộng các thay đổi staged/unstaged hiện tại; chưa commit. Chỉ dùng fixture/fake HTTP/headless và Firestore Emulator `demo-utoken` cho các test tự động. Không ghi dữ liệu production, không deploy Rules, không dùng tài khoản Google thật để tự động đăng nhập.

Người dùng đã chốt: pending preferences phải tồn tại qua restart theo UID; chỉ hỗ trợ một desktop collector/account; review AI sau dùng usage kể từ review thành công gần nhất. Đã bổ sung DT17 cho yêu cầu AI này.

## Kết quả chạy

| Kiểm tra | Trước sửa | Sau sửa |
|---|---|---|
| .NET toàn solution, không loại test animation | 255 đạt, 1 lỗi timing animation; 3 production test skip | **265 đạt, 0 lỗi, 3 skip** trong 7 project |
| Flutter toàn bộ test | 182 đạt; chưa có test tái hiện null-report | **193 đạt, 0 lỗi** |
| Nullable report regression bổ sung | 2 test mới tái hiện loading không kết thúc | Đã nằm trong full suite 193 test đạt |
| Flutter analyze | Baseline trước đó sạch | **No issues found** ở lượt cuối |
| Firebase emulator | 9 đạt | **10 đạt**, gồm REST collector-claim precondition |
| Android debug APK | Không dùng thay thế cho runtime test | **Build thành công**, chưa cài/chạy trên thiết bị |
| npm audit | 5 high + 14 moderate affected entries | **0 high, 14 moderate, 0 critical**; không đồng nghĩa 14 lỗ hổng độc lập |

Các lần chạy trung gian có lỗi đã được dùng để sửa/điều chỉnh test, không cộng dồn vào số cuối. Test animation nay kiểm tra điều hướng nhanh và trạng thái cuối không kẹt mờ/cuộn; không chứng minh mọi frame animation đẹp trên thiết bị thật.

## Thay đổi đã kiểm chứng

- **F02:** counters/micro-USD âm bị từ chối, document lỗi bị cô lập. Giữ fallback field thiếu/null đang dùng để tránh phá dữ liệu legacy; chưa thay thế toàn bộ JSON-schema validation.
- **F03:** giữ invalidDocumentIds trong danh sách daily dùng chung; Analytics/Budget/Export hiển thị warning và bỏ warning khi dữ liệu được sửa.
- **F04:** desktop_name và sync state/error_code dùng parser string/enum, báo FormatException có kiểm soát thay cho cast TypeError.
- **F05/F06:** contract bổ sung started_at tùy chọn; sửa README/comment về account linking, live UI, preferences và AI review.
- **F07:** override gRPC cùng major 1 lên bản đã vá; emulator test vẫn đạt. Không ép thay major/downgrade tooling để che advisory moderate.
- **F08 / Q03:** pending preferences được lưu theo UID trước cloud write; khôi phục warning/retry sau restart; remote cũ không đè pending; latest intent được lưu dù request trước đang chờ mạng; đổi account ngay không làm mất intent A hoặc gửi sang B.
- **R01 / Q04:** upload đầu nhận collector_id bằng Firestore precondition trước khi ghi daily. Cài đặt thứ hai không upload daily/AI hoặc claim mobile sync request của account đã nhận collector; identity tồn tại qua reopen.
- **QA-REVIEW / DT17:** brief dựa trên raw events trong `[LastReviewedThrough, reviewStart)`; review đầu tối đa 30 ngày retained; subsequent review gồm usage mới cùng ngày. Chỉ kết quả ok đẩy mốc. Lỗi/insufficient giữ mốc; dữ liệu trong lúc model chạy để lần sau; restart/legacy successful state giữ mốc; retry upload không gọi AI lại. Không có usage mới là thông báo bình thường ở UI.
- **F01 phần cache:** Clear local data đặt LastSnapshot=null. Chưa đổi chính sách xóa review cũ/pending AI; người dùng đã chốt đầu vào review mới, chưa yêu cầu xóa toàn bộ kết quả cũ. Source log files không bị xóa; collector có thể nhập lại metadata của chúng, nhưng mốc review ngăn đưa lịch sử đã review vào lần phân tích mới.
- **Phát hiện thêm:** stream helper trước đây dùng hasData để phân biệt loading, khiến giá trị null hợp lệ bị xem là đang tải mãi. Đã chuyển sang connection state và thêm empty-state regression cho Suggestions/Efficiency.

## Mức bao phủ từng kịch bản

“Đạt lớp tự động” không bằng “Đạt E2E production”.

| Kịch bản | Đã có bằng chứng mới | Phần chưa xác minh |
|---|---|---|
| DT01 | Solution compile qua test; analyzer; build APK ghi riêng trong evidence | Máy sạch, publish artifact/config review, cài và mở app |
| DT02 | Restore/refresh/sign-out bằng fake Firebase + Windows DPAPI | Native Google login và reopen trên Android thật |
| DT03 | Emulator owner/anonymous isolation; test account-switch/cache | Rules production; mọi race trên thiết bị |
| DT04 | API/headless refresh UI và mobile-request state; repository/widget | Luồng Google thật → desktop → Firebase thật → Android |
| DT05 | Admin Console-style emulator listener, Dart widget cập nhật; manual reupload local summaries | Console thật trên account test; không có production write trong lượt này |
| DT06 | Wrong type/negative, mixed-day warning/recovery đa màn, null-report empty state | Chính sách mọi required/legacy field và unknown enum trong version cũ |
| DT07 | Network/revoked/permission error/retry; AI upload không gọi model lại | Lỗi giữa nhiều batch trên server thật và mọi cancellation variant |
| DT08 | Fake-clock lease expiry/restart/legacy recovery | Kill process thật giữa upload và finish |
| DT09 | Delayed API chặn manual/background/mobile overlap; busy được nhả | Stress nhiều process/máy dưới tải |
| DT10 | Per-UID restart/retry/latest write/account switching, gồm đổi ngay trước persist | Thao tác native secure storage và mất điện giữa write |
| DT11 | Clock/resume midnight main screens; incremental period/time boundary | Hai máy khác timezone, Q05 chưa chốt |
| DT12 | Optional legacy defaults, malformed/schema checks, legacy AI-state migration | Ma trận chạy APK/app phiên bản cũ và mới đầy đủ |
| DT13 | Fake competing collector + REST emulator atomic precondition; same-install reopen | Transfer collector UI, client cũ không có guard, device attestation |
| DT14 | Retention/dirty daily và clear-usage tests hiện có | Phạm vi xóa review/pending AI chưa đổi, Q01 còn cần chốt |
| DT15 | CSV/export/filter regressions hiện có | Toàn bộ nguồn log/credential và parser CSV bên thứ ba chưa được rà hết |
| DT16 | Navigation/dispose/busy regressions trong suite | Instrumentation memory/DB locks/tải lớn/queue fairness; Q06 chưa chốt |
| DT17 | Same-day delta, no-data/no-call, failure retry, insufficient accumulation, restart, model-time arrivals, legacy migration và UI no-new-data | LLM thật và dữ liệu dài hạn có retention/repricing khác nhau |

## Giới hạn còn lại

1. Không có Android emulator/thiết bị kết nối lúc chạy flutter devices; chỉ có Windows/Chrome/Edge. Build APK không phải test runtime Android. Ba .NET production tests vẫn skip do thiếu môi trường/credential xác minh.
2. Còn **14 moderate advisory trong tooling npm**. Cần upstream update/reachability review; chưa có căn cứ gán chúng cho runtime APK/.NET. Node máy hiện 24.11.0 thấp hơn engine requirement >=24.12.0 của SDK; tests chạy được nhưng cần cập nhật Node khi chuẩn hóa môi trường nhóm.
3. Collector guard thuộc client mới, không phải device attestation. Chủ account/admin vẫn sửa được profile trên Console và client cũ chưa có guard có thể không tuân theo. Collector transfer/release chưa có UI; giữ desktop-id.txt khi khôi phục cùng installation. Không triển khai sửa Rules tự động.
4. Chính sách xóa kết quả/pending AI, mọi legacy required field, timezone, SLA/tải và phân phối config chưa được nhóm chốt hết. Không tuyên bố toàn bộ 20 static group/17 dynamic scenario đã đạt nghiệm thu.
5. Không tự động cài APK, đổi Node toàn máy, publish, commit hoặc deploy Rules.

## Bằng chứng và chạy lại

[execution-evidence-2026-11-11.json](execution-evidence-2026-11-11.json) lưu tổng kết và phạm vi. Log thô được ignore: desktop/qa-baseline-tests.log, desktop/qa-final-tests.log; mobile/qa-baseline-tests.log, mobile/qa-null-before.log, mobile/qa-final-tests.log, mobile/qa-final-analyze.log, mobile/qa-android-build.log, mobile/qa-devices.log; firebase/qa-final-tests.log và qa-audit-after.json.

```powershell
dotnet test desktop/UToken.Desktop.slnx --no-restore
```

Trong mobile: `flutter analyze`, `flutter test`, `flutter build apk --debug`.
Trong firebase: `npm ci`, `npm test`, `npm audit`.

Advisory là snapshot theo ngày chạy; không suy ra “hết lỗ hổng” chỉ từ audit hoặc số test đạt.
