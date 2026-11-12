# Kế hoạch dynamic/integration — chưa thực hiện

Đọc cùng [test-design-v2.md](test-design-v2.md) để tra mã yêu cầu tạm `QA-*`, static ID và quyết định Q01–Q07. **16 kịch bản dưới đây đều Chưa chạy trong lượt thiết kế này.** Test có sẵn chỉ được mapping để tái sử dụng, không tính kết quả các lượt trước là kết quả mới.

Cập nhật 11/11: thêm DT17 theo yêu cầu review mới, tổng **17 kịch bản**. Q03/Q04 đã được người dùng chốt; xem báo cáo thực thi để biết phần nào đã được kiểm tra tự động và phần nào còn thiếu thiết bị/production. Không đổi toàn bộ kịch bản thành Đạt chỉ vì unit test thành công.

## Môi trường và dữ liệu

- Windows desktop và Android emulator/thiết bị; không có phạm vi Linux/iOS/Web.
- Mặc định dùng fixture synthetic, fake HTTP và Firebase Emulator `demo-utoken`. Native Google login và bản đóng gói cần cấu hình/tài khoản test riêng.
- Account A/B, hai data directory desktop D1/D2 khi cần. Không lưu email/UID/token thật trong fixture/báo cáo.
- Daily mẫu tại clock test: input=100, output=20, by_key tổng tương ứng 120, cost_micro=1000000; cached nằm trong miền hợp lệ. Totals/by_key/cost là các field độc lập, không kỳ vọng sửa một field tự tính field khác.
- Dữ liệu biên: 0, số nguyên dương, -1, số thập phân, string/map/list sai kiểu, null, missing field, ngày sai và schema chưa hỗ trợ. Expected cho legacy và giới hạn tối đa cần Q02/Q06.
- Chỉ ghi Firebase thật sau khi xác định tài khoản/document test và phạm vi được phép; không tự chạy các bước Console trên dữ liệu người dùng. Lượt này không thực hiện production write.

## Kịch bản chi tiết

| ID / truy vết | Tiền điều kiện / dữ liệu | Bước kiểm tra | Mong đợi / điều cần chốt | Ưu tiên / tự động hóa | Kết quả mới |
|---|---|---|---|---|---|
| DT01 — QA-BUILD; ST01/ST02/ST05/ST19 | Máy/thư mục build sạch; thiếu config và config test đúng | Restore/build theo README; kiểm tra output; chạy thiếu config rồi bổ sung và retry | Có hướng dẫn phục hồi; config đúng vào login; artifact chỉ chứa field theo Q07. Thời gian khởi động chưa có ngưỡng | Cao; build tự động + chạy tay | Chưa chạy |
| DT02 — QA-AUTH; ST14/ST21 | A đã login; session riêng | Thoát hoàn toàn và mở lại; token hết hạn rồi refresh; sign out và mở lại | Session hợp lệ được restore; refresh đúng A; sign-out không restore A; revoked yêu cầu login, không vòng lặp | Cao; fake auth + native smoke | Chưa chạy |
| DT03 — QA-AUTH; ST06/ST14 | A/B có dữ liệu riêng | Anonymous đọc/ghi A; A đọc/ghi B; đổi A→B khi response A đang chậm | Unauthorized bị từ chối; cache/UI/pending A không sang B. Emulator và Rules deploy là hai lần xác minh khác nhau | Cao; emulator/delayed API | Chưa chạy |
| DT04 — QA-SYNC/QA-UI; ST08/ST12 | Desktop chạy; mobile cùng UID; daily chưa upload | Sync desktop; đọc payload/listener; gửi refresh từ mobile; xem Sources/provider/Activity | Payload đúng fixture; request pending→running→done; hai UI cập nhật, giữ kỳ chọn. Poll 30 giây không đồng nghĩa SLA 30 giây; timeout test theo cấu hình/Q06 | Cao; fake HTTP + E2E | Chưa chạy |
| DT05 — QA-DATA/QA-SYNC; ST07/ST08/ST12 | Daily 120 đã upload; local không đổi | Console/admin sửa input=200 và by_key tương ứng; xem mobile; Sync now desktop | Mobile thành 220; desktop vẫn dùng nguồn local; manual sync khôi phục daily còn giữ local về 120. Không yêu cầu khôi phục ngày đã hết retention hoặc xóa cloud-only date | Cao; emulator admin/UI + manual được phép | Chưa chạy |
| DT06 — QA-DATA/QA-UI; ST07/ST08 | Hai ngày hợp lệ | Làm một ngày sai kiểu/counter âm/null/missing/schema lạ; mở Tokens/Analytics/Budget/Export; sửa lại | Ngày hợp lệ còn dùng được; dữ liệu sai không bị coi là số đúng; có warning và phục hồi. Required/optional/legacy theo Q02; Export khi thiếu ngày cần chính sách rõ | Cao; parser/widget/emulator | Chưa chạy |
| DT07 — QA-SYNC; ST12/ST22 | Daily/AI pending; fault injection | Mất mạng/401/403 khi upload; lỗi sau một batch; reconnect/retry; phân biệt cancellation và timeout | Không ack trước thành công; retry không mất/nhân đôi tổng; lỗi quyền/session khác offline; retry AI không gọi model lần nữa | Cao; tự động | Chưa chạy |
| DT08 — QA-SYNC; ST12/ST21 | Request pending; fake clock | Claim rồi dừng trước finish; tạo instance mới; poll trước và sau lease 30 phút; legacy running thiếu timestamp | Lease chưa hết không reclaim; hết hạn/legacy có đường nhận lại và finish. Sync dài hơn lease cần Q06/renewal, chưa mặc định an toàn | Cao; fake clock/HTTP | Chưa chạy |
| DT09 — QA-SYNC; ST12/ST21 | Delayed sync đang giữ | Bấm manual lặp; background tick/mobile poll; giải phóng bằng success/error | Cùng instance không chạy chồng đường được bảo vệ; busy được nhả; UI refresh; tác vụ kế tiếp chạy được. Không suy ra cross-device lock | Cao; delayed API/headless | Chưa chạy |
| DT10 — QA-PREFS; ST08/ST14/ST20 | A, cache riêng, budget/format/reviewed giả | Save lỗi; xem warning; retry; nhiều save nhanh; gây lỗi rồi restart LocalPrefs; đổi B | Cùng phiên có warning/retry và giữ giá trị mới; lần lưu cuối không bị cũ ghi đè; không gửi sang B. Expected độ bền/tự retry qua restart Chờ Q03 | Cao; failing store/repository + restart smoke | Chưa chạy |
| DT11 — QA-DATA/QA-UI; ST08/ST10 | Clock trước biên ngày/tháng/năm | Mở Tokens/Analytics/Budget; tiến clock; resume ngày sau; đổi kỳ | Main screens query/filter ngày mới, giữ kỳ. Khác timezone và Month=30 ngày hay tháng lịch theo Q05 | Vừa; clock/lifecycle + smoke | Chưa chạy |
| DT12 — QA-DATA; ST07/ST20 | Fixture old/new, required/optional/unknown schema | Parser/UI theo ma trận desktop cũ/mobile mới và ngược lại | Không biến thiếu dữ liệu thành số đúng trái Q02; fallback/reject/nâng cấp có quy tắc. Expected chi tiết Chờ Q02 | Cao; contract/parser | Chưa chạy |
| DT13 — QA-MULTI; ST12/ST23 | D1/D2 cùng UID/ngày; dữ liệu rời và trùng | Upload D1→D2, đảo thứ tự; đồng thời claim; retry cùng payload | Ghi actual overwrite để tái hiện R01; expected cộng/tách/một máy/dedup Chờ Q04. Claim cùng version không được cả hai xác nhận thành công | Cao; hai clients/emulator | Chưa chạy |
| DT14 — QA-DELETE; ST13 | Dirty/clean daily cũ, snapshot/pending AI | Prune qua retention; Clear local; sync/reopen | Prune giữ daily chưa ack; Clear đúng Q01. Kiểm tra usage/snapshot/AI/cloud/API key riêng, không mặc định xóa tất cả | Cao; SQLite/API; Clear Chờ Q01 | Chưa chạy |
| DT15 — QA-PRIVACY; ST16 | Fixture metadata với dấu phẩy/quote/newline và = + - @; secret marker giả | Export rồi parse CSV/JSON; rà log thành công/lỗi | File parse được, số liệu/row đúng bộ lọc; không formula injection; marker credential/prompt không xuất hiện ở luồng không được phép | Vừa; serialization/log | Chưa chạy |
| DT16 — QA-LIFECYCLE; ST21/ST22 | Tác vụ chậm, lịch sử/queue synthetic lớn | Mở/đóng tab/account lặp; thoát khi sync; reopen; thử nhiều batch/lượt queue | Không callback state đã dispose hoặc DB lock còn lại; task/lease có phục hồi; đo read/write/fairness. Ngưỡng dung lượng/latency/memory Chờ Q06 | Vừa; instrumentation/device | Chưa chạy |
| DT17 — QA-REVIEW; ST07/ST10/ST20 | Đã review thành công; có clock/model giả và usage mới cùng ngày | Review lại khi chưa có usage; thêm usage; gây lỗi; retry; restart; thêm usage trong lúc model chạy | Chỉ dữ liệu trong cửa sổ mới đi vào brief; không gọi model khi không có usage; lỗi/insufficient không đẩy mốc; mốc tồn tại qua restart; usage lúc model chạy để lần sau; UI không báo lỗi cho no_new_usage | Cao; API/core/headless | Xem báo cáo thực thi |

## Tái sử dụng và độ phủ

| Nhóm | Test hiện có để mở rộng, không phải kết quả chạy mới | Khoảng trống |
|---|---|---|
| DT02–DT04 | `desktop/tests/UToken.Desktop.Tests/FirebaseDesktopFlowTests.cs`, `mobile/test/mobile_auth_test.dart`, `firebase/tests/rules.test.js` | Native smoke, Rules deploy, account-switch race |
| DT05–DT06 | `mobile/test/live/console_edits_test.dart`, `firebase/tests/console-edit.test.js`, `desktop/tests/UToken.Desktop.Tests/RealDesktopApiTests.cs` | Negative/missing/legacy và warning đa màn; admin delivery và parser/UI là hai lớp test riêng |
| DT07–DT09 | `JudgeSyncTests.cs`, `FirebaseDesktopFlowTests.cs`, `NavigationRaceTests.cs` trong desktop tests | Partial batch, shutdown, hai clients, timeout/cancellation |
| DT10–DT11 | `mobile/test/live/live_screens_test.dart` | Restart durability theo Q03; biến thể timezone |
| DT12–DT14 | Contracts/fixtures và `desktop/tests/UToken.Storage.Tests/RetentionTests.cs` | Version matrix, multi-desktop policy, Clear/pending AI |
| DT15–DT16 | DesktopFlow/export tests, `mobile/test/ui_handoff_test.dart` | Log/CSV boundary, lifecycle instrumentation, tải theo Q06 |

Ma trận yêu cầu–test nằm trong test-design-v2.md. Không khẳng định phủ 100%: Q01–Q07 và các tổ hợp thiết bị/dữ liệu còn mở.

Mỗi lần chạy sau ghi: commit + working tree, môi trường/config không chứa secret, fixture/clock, actual result, bằng chứng, người/ngày kiểm và pass/fail/blocked. Không đánh Đạt cho nhánh đang chờ quyết định nghiệp vụ.
