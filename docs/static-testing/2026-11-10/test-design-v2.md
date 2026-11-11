# Thiết kế kiểm tra v2 — uToken Windows/Android

Ngày chỉnh thiết kế: **11/11/2026**. Giữ thư mục ngày 10/11 để liên kết với audit gốc; không đổi ngày của bằng chứng công cụ cũ.

## Phạm vi và cách sử dụng

Đây là bản chỉnh thiết kế trước khi sửa code. Giữ `evidence.json` của lượt kiểm tra trước; không chạy lại build, analyzer, advisory hoặc kiểm thử động trong lượt chỉnh tài liệu này. Không sửa source/package/Rules.

Có **20 nhóm static review** và **16 kịch bản dynamic/integration dự kiến**. Đây là số nhóm/kịch bản, không phải số test tự động đã chạy hay tỷ lệ coverage. Các tổ hợp dữ liệu trong một kịch bản có thể cần tách thành nhiều test khi triển khai.

**Cập nhật sau yêu cầu chạy/sửa ngày 11/11:** thêm DT17 cho review AI theo dữ liệu mới, tổng kế hoạch thành **17 kịch bản**. Q03 đã chốt giữ pending preferences theo UID qua restart; Q04 đã chốt một collector/tài khoản. Các bảng “Chưa chạy” bên dưới ghi trạng thái lúc thiết kế; kết quả mới nằm ở [execution-report-2026-11-11.md](execution-report-2026-11-11.md), không phải tất cả đã chạy E2E.

Bản bảng để bàn giao: [cases.csv](cases.csv), [dynamic-cases.csv](dynamic-cases.csv); [design-manifest.json](design-manifest.json) lưu phiên bản và mapping ID. Ban đầu CSV dynamic để trống actual result/bằng chứng/người kiểm/ngày chạy; sau lượt thực thi 11/11 các cột này ghi bằng chứng tự động và phần chưa xác minh, không đánh Đạt E2E cho toàn kịch bản.

Nguồn yêu cầu: các yêu cầu người dùng trong phiên về Windows desktop, Android mobile, login cùng Google UID, sync và phục hồi dữ liệu. Mã `QA-*` bên dưới là **mã truy vết tạm**, không thay thế FR/SRS đã được nhóm phê duyệt. Đặc tả chưa rõ được ghi `[cần nhóm xác nhận]`; không suy ra kết quả đúng chỉ từ hành vi code hiện tại.

## Phân loại trạng thái

| Cột | Giá trị | Ý nghĩa |
|---|---|---|
| Phạm vi kiểm tra | Đã kiểm tra trong phạm vi | Có đọc code/kết quả công cụ được nêu; không xác nhận phần ngoài phạm vi |
| Phạm vi kiểm tra | Chưa xác minh | Đã thiết kế nhưng chưa kiểm tra đủ để kết luận |
| Kết luận | Đạt trong phạm vi | Đáp ứng tiêu chí được giới hạn rõ trong hàng đó |
| Kết luận | Có phát hiện | Có bằng chứng về chênh lệch/rủi ro cần xử lý; xem finding |
| Kết luận | Cần chốt yêu cầu | Thiếu chính sách nghiệp vụ; chưa được kết luận hành vi hiện tại là lỗi |
| Kết luận | Chưa kết luận | Chưa có đủ bằng chứng |
| Kết quả chạy dynamic | Chưa chạy | Không có kết quả mới của lượt thiết kế này |

Không dùng “một phần” như một kết luận chung. Kết quả static và dynamic tách riêng. Advisory scan là phân tích dependency, không phải SAST code hoặc bằng chứng đã khai thác được.

## Truy vết và quyết định còn mở

| Mã tạm | Yêu cầu/phạm vi | Static | Dynamic |
|---|---|---|---|
| QA-BUILD | Cấu hình Windows/Android và bàn giao không lẫn môi trường/secret | ST01–ST05, ST19 | DT01 |
| QA-DATA | Hợp đồng dữ liệu, số liệu đúng, parser tương thích | ST07, ST10, ST20 | DT05, DT06, DT11, DT12 |
| QA-UI | Dữ liệu live và trạng thái lỗi nối đến UI | ST08 | DT04–DT06, DT10, DT11 |
| QA-AUTH | Login/restore/sign-out, dữ liệu phân tách theo tài khoản | ST06, ST14 | DT02, DT03 |
| QA-SYNC | Upload, request từ mobile, retry, chống chạy chồng | ST12, ST22 | DT04, DT07–DT09, DT13 |
| QA-DELETE | Retention và phạm vi Clear local data | ST13 | DT14 |
| QA-PREFS | Lưu preferences, báo lỗi và retry | ST08, ST14, ST20 | DT10 |
| QA-PRIVACY | Log/export/credential và phạm vi dependency | ST04, ST16, ST17 | DT15 |
| QA-LIFECYCLE | Hủy stream/timer/tác vụ và giải phóng tài nguyên | ST21 | DT16 |
| QA-MULTI | Nhiều desktop cùng tài khoản | ST23 | DT13 |
| QA-DOC | Tài liệu/contract và test traceability khớp code | ST18 | Đối chiếu bằng chứng, không cần app cho chính mục này |
| QA-REVIEW | Review sau chỉ dùng usage kể từ review thành công trước; lỗi/thiếu dữ liệu không tiêu thụ cửa sổ | ST07/ST10/ST20 | DT17 |

Các quyết định cần chốt trước khi viết expected result cuối cùng:

1. **Q01 — Xóa local:** xóa usage thôi hay cả snapshot/review/pending AI? Có giữ API key, preferences, log nguồn và dữ liệu cloud không? Không mặc định xóa cloud.
2. **Q02 — Dữ liệu cũ:** field nào bắt buộc ở schema hiện hành, field nào được thiếu ở legacy? Thiếu field tùy chọn không tự bị coi là lỗi. Số âm vi phạm minimum của counters là phát hiện riêng.
3. **Q03 — Preferences:** thay đổi chưa lưu cloud có phải tồn tại và tiếp tục retry sau khi app tắt hẳn không? Trong cùng phiên phải báo lỗi và có retry; độ bền qua restart cần xác nhận.
4. **Q04 — Nhiều desktop:** tổng account cộng nhiều máy, tách từng máy hay chỉ cho phép một máy? Dữ liệu cùng log trên hai máy có cần chống đếm trùng không?
5. **Q05 — Ngày giờ:** ngày được chốt theo timezone desktop, điện thoại hay tài khoản khi hai máy khác múi giờ? “Month” là 30 ngày gần nhất hay tháng lịch ở từng màn?
6. **Q06 — Tải/độ trễ:** lịch sử tối đa, số máy, kích thước daily và mục tiêu thời gian cập nhật/đóng app là bao nhiêu? Chưa đặt ngưỡng hiệu năng tùy ý để đánh fail.
7. **Q07 — Đóng gói:** có phân phối cấu hình OAuth desktop chung không, field nào được phép có trong bản phát hành? File cần cho build local không đồng nghĩa được phép bàn giao nguyên trạng.

## Checklist static đã điều chỉnh

Mỗi hàng có phương pháp, tiêu chí và giới hạn. Kết quả công cụ được kế thừa từ audit trước, không phải lần chạy mới.

| ID | Nội dung / phương pháp | Tiêu chí kiểm tra | Phạm vi và kết luận hiện tại |
|---|---|---|---|
| ST01 | Build C# solution không chạy app | Biên dịch thành công; warning được phân loại | Đã kiểm tra trong phạm vi — Đạt: build --no-restore 0 lỗi/0 warning; máy sạch thuộc DT01 |
| ST02 | Flutter analyzer | Không có analyzer issue trong mobile | Đã kiểm tra trong phạm vi — Đạt theo log đã lưu |
| ST03 | Git/conflict và format chỉ đọc | Không có unmerged/marker/whitespace lỗi; file Dart được chọn đúng format | Đã kiểm tra trong phạm vi — Đạt cho phạm vi đã quét, không phải toàn repo |
| ST04 | Quét secret, ignore và tham chiếu cấu hình | Không đưa credential thật vào tracked source/tài liệu/artifact ngoài chính sách | Đã kiểm tra trong phạm vi — Chưa kết luận toàn bộ: chữ ký đã chọn không có secret thật; history/binary/artifact chưa quét đầy đủ |
| ST05 | Đọc precedence, emulator và production config | Project/mode/endpoint được xác định rõ; thiếu cấu hình có thông báo phục hồi | Đã kiểm tra trong phạm vi — Có precedence và validation; cấu hình Console/bản cài Chưa xác minh |
| ST06 | Đọc Rules, đường dẫn và nhánh match chồng nhau | Owner isolation ở nguồn local; không vô tình mở nhánh ghi chéo UID | Đã kiểm tra trong phạm vi — Guard local có bằng chứng; không kết luận Rules deploy hoặc bảo mật production |
| ST07 | Contract + validation, gộp ST09 cũ | Tên field/đơn vị/schema khớp; required/optional theo Q02; counters đúng miền; unknown schema không bị diễn giải thành số hợp lệ | Đã kiểm tra trong phạm vi — Có phát hiện F02/F04/F05; phần legacy cần chốt Q02 |
| ST08 | Nối BE–UI + trạng thái, gộp ST15 cũ | Route live dùng repository/API; loading/empty/error/retry rõ; dữ liệu bị loại không bị che giấu | Đã kiểm tra trong phạm vi — Có phát hiện F03; F08 là rủi ro cần chốt Q03, không kết luận toàn UI lỗi |
| ST10 | Tính toán + ngày giờ, gộp ST11 cũ | Công thức/đơn vị/filter và timezone đúng đặc tả đã chốt | Đã kiểm tra trong phạm vi — Input+output và micro-USD thống nhất; cần chốt Q05, chưa kết luận mọi công thức/giá |
| ST12 | Rà call graph sync, retry, ack và lease | Không ack trước upload; không nuốt lỗi làm báo thành công; task đang chạy được bảo vệ, có đường phục hồi | Đã kiểm tra trong phạm vi — Có guard/lease/precondition; không chứng minh mọi interleaving bằng static review |
| ST13 | Rà retention và mọi nơi giữ usage/review | Retention giữ dữ liệu chưa gửi theo quy tắc; Clear đúng phạm vi Q01 | Đã kiểm tra trong phạm vi — Cần chốt yêu cầu Q01; F01 là bằng chứng dữ liệu AI/snapshot còn lại, không mặc định yêu cầu xóa tất cả |
| ST14 | Rà khóa account/cache và async callback | Không gửi dữ liệu A sang B; kết quả cũ không khôi phục UI của account cũ | Đã kiểm tra trong phạm vi — Có UID/project/environment guard; chưa chứng minh mọi race trên thiết bị |
| ST16 | Rà log/export và luồng metadata | Không xuất credential/prompt ngoài phạm vi; escape định dạng và CSV formula phù hợp | Đã kiểm tra trong phạm vi — Desktop có CSV protection; luồng đã đọc không thấy upload prompt; chưa rà mọi binary/log |
| ST17 | Phân tích dependency theo thành phần | Tách runtime .NET, Flutter/native và tooling npm; advisory được đánh giá reachability/khả năng khai thác trước quyết định release | Đã kiểm tra trong phạm vi — F07 có advisory npm tooling; NuGet không báo affected entry; Flutter/native chưa xác minh đầy đủ |
| ST18 | Rà tài liệu và mapping test–yêu cầu | Hướng dẫn và schema khớp code; không tuyên bố coverage % khi chưa đo | Đã kiểm tra trong phạm vi — Có phát hiện F05/F06; test hiện có không đồng nghĩa đã chạy lại hoặc phủ mọi biến thể |
| ST19 | **Mới:** build config và bàn giao | Đọc csproj/Gradle/manifest/ignore/copy/publish để biết artifact chứa gì, nguồn cấu hình và bước máy mới; theo Q07 | Chưa xác minh đầy đủ — đọc sơ bộ thấy csproj copy appsettings.Local.json vào output; cần rà publish/artifact thực tế, chưa kết luận lộ secret |
| ST20 | **Mới:** tương thích version/dữ liệu cũ | Lập ma trận old/new desktop/mobile; xác định field/schema được fallback, reject hoặc yêu cầu nâng cấp; theo Q02/Q03 | Chưa xác minh — cần thiết kế fixture sau khi chốt legacy policy |
| ST21 | **Mới:** vòng đời tài nguyên | Theo dõi tạo–hủy listener/timer/CTS/HTTP/SQLite, thứ tự shutdown và task chưa hoàn tất | Chưa xác minh đầy đủ — App có handler stop timer/dispose API; chưa rà hết await/cancellation/race khi thoát |
| ST22 | **Mới:** giới hạn query/write/document | Rà full-history reads, pagination, batch/chunk, queue fairness và document growth; đối chiếu quota và Q06 | Chưa xác minh đầy đủ — có batch 400, queue limit 20 và mobile đọc toàn lịch sử; chưa kết luận hiệu năng từ code |
| ST23 | **Mới:** phạm vi ghi đè nhiều desktop | Xác định document key, nguồn tổng hợp, device identity, merge/idempotency theo Q04 | Chưa xác minh theo yêu cầu — writer dùng users/{uid}/daily/{date}; cần chốt Q04, có rủi ro R01 bên dưới |

## Mapping từ bản cũ

Giữ ID để truy vết, không đánh lại tất cả số:

- ST09 cũ nhập vào ST07: hợp đồng và dữ liệu sai kiểu.
- ST15 cũ nhập vào ST08: wiring và trạng thái UI.
- ST11 cũ nhập vào ST10: tính toán và ngày giờ.
- ST01–ST08, ST10, ST12–ST14, ST16–ST18 giữ ID; bổ sung ST19–ST23.
- Tổng active: 18 − 3 + 5 = **20 nhóm**. Mã bị gộp không phải test bị bỏ.

## Phân loại lại findings trước khi sửa

| Mã | Phân loại mới | Quyết định |
|---|---|---|
| F01 | Hành vi giữ AI/snapshot đã thấy trong code; mức ảnh hưởng phụ thuộc Q01 | Chưa kết luận toàn bộ là lỗi; chốt phạm vi xóa trước |
| F02 | Counters âm: chênh lệch rõ với minimum schema. Field thiếu: phụ thuộc Q02 | Tách nhánh expected result, không reject mọi field thiếu |
| F03 | Metadata warning bị bỏ trên helper đã xác nhận trong code | Cần phương án hiển thị thống nhất và DT06 |
| F04 | Cast trực tiếp/enum chưa validate đã xác nhận | Cải thiện lỗi/validation; không gọi đây là crash toàn app khi chưa tái hiện |
| F05 | Schema thiếu mô tả started_at | Lỗi tài liệu; additionalProperties hiện không chặn nên không gọi là runtime failure |
| F06 | README/comment chưa khớp luồng mới | Lỗi tài liệu, không phải test login thất bại |
| F07 | Advisory snapshot của npm dev tooling | Đánh giá riêng tooling/CI; không gán mức độ cho APK/.NET khi chưa có bằng chứng |
| F08 | Pending preferences không tồn tại qua restart là rủi ro có bằng chứng tĩnh | Chốt Q03 rồi dùng DT10 để kiểm chứng trước khi quyết định sửa |

**R01 — Nhiều desktop có thể ghi đè cùng ngày:** `desktop/src/UToken.Sync/FirebaseCloudSync.cs:132` ghi `users/{uid}/daily/{d.Date}` bằng document chứa tổng hợp local; device name nằm ở user profile tại `:138`, không nằm trong daily key. Nếu hai máy có dữ liệu khác nhau, đường ghi hiện tại có thể thay thế daily của máy kia. Điều này chưa chứng minh sai yêu cầu nếu sản phẩm chỉ hỗ trợ một collector/account. Chốt Q04 trước khi thiết kế giải pháp hoặc kết luận lỗi nghiệp vụ. Không tự đổi schema/merge ở lượt này.

## Điều kiện trước khi bắt đầu sửa

1. Phân biệt lỗi rõ (ví dụ counter âm, tài liệu sai) với quyết định sản phẩm (xóa, legacy, multi-desktop).
2. Dùng [dynamic-plan.md](dynamic-plan.md) để chọn regression test cho từng thay đổi. Tất cả kết quả mới của kế hoạch đó đang **Chưa chạy**.
3. Không dùng tỷ lệ 4/18 hay “6 không đạt” của báo cáo v1 làm release gate mới. Giữ v1 làm lịch sử bằng chứng; bảng v2 là thiết kế hiện hành.
4. Không sửa source/Rules/package trong lượt chỉnh thiết kế. Không thực hiện test production ghi dữ liệu cho đến khi xác định rõ tài khoản/document test và phạm vi được phép.
