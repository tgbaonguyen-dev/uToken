# Báo cáo static testing uToken — 10/11/2026

> **Bản v1 — lưu lịch sử audit.** Thiết kế hiện hành là [test-design-v2.md](test-design-v2.md): 20 nhóm static và [dynamic-plan.md](dynamic-plan.md): 16 kịch bản chưa chạy. Phân loại và mức độ findings v1 đã được điều chỉnh ở v2; không dùng tỷ lệ v1 làm release gate. `cases.csv` hiện phản ánh v2. `evidence.json` giữ snapshot công cụ của audit gốc, không phải kết quả chạy mới.

## Phạm vi và kết luận

Nhánh `dev`, HEAD `7093df8`, bao gồm thay đổi staged/unstaged hiện tại. Đây là kiểm tra working tree, không chỉ commit HEAD. Không sửa source, package hoặc lockfile; chỉ thêm báo cáo và log công cụ được ignore.

**18 mục: 4 đạt, 8 một phần, 6 không đạt.** Có 8 phát hiện cần xử lý/đánh giá. Chưa đủ cơ sở kết luận toàn bộ static testing đạt. “Một phần” không có nghĩa là không tồn tại lỗi.

Build/analyzer/format không chạy ứng dụng. Không chạy unit/widget/emulator test trong lượt này, không sửa Firebase production, không deploy Rules. Không đưa kết quả test các lượt trước vào số lần kiểm tra động của báo cáo này.

- [Checklist CSV](cases.csv).
- [Snapshot kết quả công cụ và advisory](evidence.json).
- Các vị trí `file:dòng` bên dưới tính từ gốc repository.

## Kết quả công cụ

| Kiểm tra | Kết quả và giới hạn |
|---|---|
| .NET build solution, `--no-restore` | Thành công, 0 lỗi, 0 cảnh báo; chưa xác nhận restore sạch trên máy mới |
| Flutter analyze | No issues found |
| Dart format không ghi file | 11 file được chọn, 0 file thay đổi; không phải quét toàn repo |
| Git diff check / unmerged | Không lỗi whitespace, không unmerged entry; không thấy conflict marker trong phạm vi quét |
| Quét secret theo chữ ký | Không thấy secret thật trong text tracked/index đã quét; 3 match là placeholder/test. Chưa quét lịch sử Git/binary hoặc mọi định dạng secret |
| NuGet advisory, gồm transitive | 0 affected package entries theo nguồn trả về; không phải bảo chứng an toàn |
| npm audit | 19 affected package entries: 5 high, 14 moderate, 0 critical. Có thể trùng nguyên nhân advisory, không phải 19 lỗi độc lập |
| Advisory Flutter plugin/native | Chưa xác minh đầy đủ; analyzer không phải vulnerability scanner |

## Checklist 18 mục

| ID | Nội dung | Kết luận | Bằng chứng và nhận xét |
|---|---|---|---|
| ST01 | Build/phân tích C# | ĐẠT | `desktop/static-build.log`: build solution thành công, 0 warning/error |
| ST02 | Flutter analyzer | ĐẠT | `mobile/static-analyze.log`: No issues found |
| ST03 | Format/Git/conflict | ĐẠT | `mobile/static-format.log`: 11 file không đổi; diff check và unmerged sạch |
| ST04 | Secrets | MỘT PHẦN | `.gitignore:41`; config local được ignore, match đã chọn chỉ là placeholder/fixture; chưa quét history/binary |
| ST05 | Cấu hình Firebase | MỘT PHẦN | `desktop/src/UToken.Desktop.App/AppSettings.cs:40`; `mobile/lib/main.dart:41`. Có precedence/validation; chưa xác nhận cấu hình Console và bản cài |
| ST06 | Security Rules | MỘT PHẦN | `firebase/firestore.rules:6`, `:18`, `:35`: owner guard và pricing public; daily validation còn hạn chế, Rules production chưa xác minh |
| ST07 | Hợp đồng dữ liệu | KHÔNG ĐẠT | Field cơ bản thống nhất nhưng parser chưa thực thi đầy đủ required/minimum; schema sync request thiếu started_at. F02, F05 |
| ST08 | BE đến UI | ĐẠT | `mobile/lib/app/router.dart:176` map live M04–M15/overlays; preview/demo giữ mock có chủ đích. Chỉ kết luận wiring tĩnh các luồng đã đọc, không phải E2E |
| ST09 | Dữ liệu sai kiểu | KHÔNG ĐẠT | `mobile/lib/core/models/daily_doc.dart:4`, `usage_repository.dart:137`, `features/live/live_common.dart:33`. F02–F04 |
| ST10 | Tính toán | MỘT PHẦN | `desktop/src/UToken.Core/Aggregation/DailyDoc.cs:46`, `mobile/lib/core/data/usage_aggregates.dart:79`: input+output và micro-USD thống nhất; chưa chứng minh mọi công thức Efficiency/AI/giá hoặc consistency totals/by_key |
| ST11 | Ngày giờ | MỘT PHẦN | `desktop/src/UToken.Engine/UsageEngine.cs:41`, `mobile/lib/features/live/live_common.dart:239`: main Tokens/Analytics/Budget có rollover; khác múi giờ giữa máy và các trang chi tiết chưa được xác nhận đầy đủ |
| ST12 | Sync/retry/concurrency | MỘT PHẦN | `MainViewModel.Background.cs:43`, `FirebaseCloudSync.cs:196`: busy guard chung, ack sau upload, lease/precondition; chưa stress multi-desktop, lease chưa có renewal |
| ST13 | Retention/xóa | KHÔNG ĐẠT | `desktop/src/UToken.Storage/SqliteStore.cs:249` giữ dirty daily; `RealDesktopApi.cs:458` chưa xóa/reset pending AI và snapshot. F01 |
| ST14 | Phân tách tài khoản | MỘT PHẦN | `RealDesktopApi.Sync.cs:24`, `mobile/lib/core/data/local_prefs.dart:67`: khóa UID/project/environment và guard callback; chưa xác nhận mọi race/E2E |
| ST15 | Lỗi và thông báo | KHÔNG ĐẠT | Sync request/save/retry/missing Insight đã có xử lý; warning daily chưa đồng đều và preferences pending chưa bền vững qua restart. F03, F08 |
| ST16 | Log/export | MỘT PHẦN | `RealDesktopApi.cs:398` chống CSV formula injection; `mobile/lib/features/live/settings_screens.dart:967` xuất date/counters. Không thấy upload prompt trong đường summary đã đọc; chưa rà mọi log/fixture/binary |
| ST17 | Dependency | KHÔNG ĐẠT | NuGet không báo affected entry; npm tooling có 19 affected package entries; Dart/native chưa kiểm tra đầy đủ. F07 |
| ST18 | Tài liệu/test coverage | KHÔNG ĐẠT | Có test cho sync/retry/Console/rollover nhưng README/schema lệch code. Chưa đo coverage %. F05, F06 |

Tên file rút gọn trong bảng: `RealDesktopApi*.cs` nằm trong `desktop/src/UToken.Desktop.App/Services/`; `MainViewModel.Background.cs` nằm trong `desktop/src/UToken.Desktop.App/ViewModels/`; `FirebaseCloudSync.cs` nằm trong `desktop/src/UToken.Sync/`. Log thô được ignore; `evidence.json` giữ bản kết quả bàn giao.

## Phát hiện và hướng xử lý

### F01 — Clear local data còn giữ dữ liệu AI cũ — Cao

**Bằng chứng:** `desktop/src/UToken.Desktop.App/Services/RealDesktopApi.cs:458` gọi `_store.ClearUsage()` và `_history.Clear()`, không reset `LastSnapshot` hoặc judge state. `RealDesktopApi.Judge.cs:241` vẫn retry `PendingUploads`.

**Ảnh hưởng suy ra:** sau khi xóa usage local, Insight cũ đang chờ vẫn có thể được upload; snapshot cũ vẫn tồn tại trong instance. Chưa tái hiện xóa rồi upload trong lượt này.

**Đề xuất:** chốt phạm vi xóa rồi reset snapshot/kết quả/pending AI tương ứng; giữ API key/preferences theo phạm vi đã chốt. Thêm test xóa → sync không gửi lại review cũ.

### F02 — Validation daily chưa khớp schema — Vừa

**Bằng chứng:** `mobile/lib/core/models/daily_doc.dart:4` chỉ kiểm tra số nguyên hữu hạn, không chặn số âm; `:75` mặc định field thiếu thành 0; `:120` cho totals null thành map rỗng. `contracts/firestore/daily.schema.json:21` yêu cầu counters; `:32` trở đi có minimum 0. Rules tại `firebase/firestore.rules:20` chỉ kiểm tra ID ngày và schema_version.

**Ảnh hưởng:** Console/chủ tài khoản có thể tạo daily âm hoặc thiếu counters, mobile hiển thị số sai/zero thay vì cảnh báo. Đây là vấn đề tính hợp lệ dữ liệu, không phải bypass quyền UID.

**Đề xuất:** phân biệt required/optional, chặn counters âm, thống nhất nơi enforce schema. Thêm test thiếu totals, missing required counter, negative input/cached/cost.

### F03 — Cảnh báo invalid daily chỉ hiện ở Tokens — Vừa

**Bằng chứng:** `mobile/lib/core/data/usage_repository.dart:45` giữ `invalidDocumentIds`; `mobile/lib/features/live/live_common.dart:33` chuyển sang `.documents`, bỏ metadata cảnh báo; Tokens đọc snapshot trực tiếp và hiện warning tại `tokens_screens.dart:109`.

**Ảnh hưởng:** Analytics/Budget/Export có thể hiển thị tổng thiếu ngày mà không giải thích document bị loại.

**Đề xuất:** giữ metadata đến UI dùng chung; Export cần báo số ngày bị loại trước khi sử dụng kết quả.

### F04 — Profile/sync request còn cast trực tiếp — Vừa

**Bằng chứng:** `mobile/lib/core/data/usage_repository.dart:137` cast desktop_name; `:156`, `:157` cast state/error_code trực tiếp, không validate state enum.

**Ảnh hưởng:** sai kiểu do Console/client làm stream báo TypeError và thông báo chung. Không khẳng định crash toàn app vì widget có xử lý stream error.

**Đề xuất:** dùng helper string/enum, thông báo có thể phục hồi; test số/list/enum không được hỗ trợ.

### F05 — Schema sync request chưa mô tả started_at — Thấp

**Bằng chứng:** `desktop/src/UToken.Sync/FirebaseCloudSync.cs:243` ghi started_at cho lease; `contracts/firestore/sync_request.schema.json:10` chưa khai báo.

**Ảnh hưởng:** thiếu field quan trọng trong tài liệu contract. Schema không chặn additionalProperties nên chưa phải lỗi reject document hiện tại.

**Đề xuất:** bổ sung field tùy chọn, kiểu/quy ước timestamp và hành vi legacy request không có timestamp. Không tự tăng schema_version nếu chỉ bổ sung tương thích.

### F06 — Tài liệu mobile còn mô tả pairing/kiến trúc cũ — Thấp

**Bằng chứng:** `mobile/README.md:13`, `:29` còn hướng dẫn login/pairing và feature pairing; router mới tại `mobile/lib/app/router.dart:176` dùng features/live. `mobile/lib/core/data/usage_repository.dart:73` vẫn có comment “never writes” dù `:141`, `:169` ghi sync request/preferences.

**Ảnh hưởng:** người nhận bàn giao hiểu sai account linking và phạm vi read/write.

**Đề xuất:** cập nhật login cùng UID, thư mục live, refresh/request sync và account preferences; đánh dấu tài liệu pairing là lịch sử/demo nếu còn giữ.

### F07 — npm Firebase tooling có advisory — Cao trong phạm vi tooling

**Bằng chứng:** `firebase/package.json:8` khai báo devDependencies; `evidence.json` lưu audit trả về 5 high, 14 moderate. Chuỗi high có `@grpc/grpc-js` và các package Firebase phụ thuộc nó. NuGet không báo affected entries trong lượt này.

**Ảnh hưởng:** cần đánh giá CLI/emulator/test/CI cài các dependency này. Không có bằng chứng từ audit này rằng .NET app/APK sử dụng chính dependency npm đó hoặc đã bị khai thác. Số affected package không bằng số lỗ hổng độc lập.

**Đề xuất:** rà advisory trực tiếp/transitive, chọn nâng cấp tương thích, chạy lại emulator/rules tests. Không dùng `npm audit fix --force` theo gợi ý downgrade tự động. Chưa sửa package.

### F08 — Preferences chờ lưu chưa bền vững qua restart — Vừa

**Bằng chứng:** `mobile/lib/core/data/local_prefs.dart:44` pending/saveError nằm trong RAM; `:135` lưu cache nhưng không có pending marker; `:185` load không khôi phục pending; `:75` chỉ bảo vệ snapshot cũ khi pending đang true.

**Ảnh hưởng suy ra:** lưu cloud thất bại rồi đóng hẳn app có thể khiến lần mở lại nhận snapshot cloud cũ và ghi đè cache mới; cảnh báo/nút retry không được khôi phục. Retry trong cùng phiên đã có xử lý. Chưa tái hiện restart ở lượt này.

**Đề xuất:** lưu pending theo UID và giá trị cần ghi, khôi phục cảnh báo/retry đúng tài khoản; test tạo LocalPrefs mới trên cùng store sau remote write thất bại.

## Giới hạn và cách chạy lại

Chưa xác nhận Rules production, Firebase Console/IAM/SHA, mạng thật, Windows/Android UI trực quan hoặc Figma. Chưa đo coverage %, chứng minh mọi công thức, async race/multi-desktop hay trường hợp hai máy khác múi giờ. Test animation flaky là ghi nhận từ lượt trước, không phải kết quả chạy trong lượt này.

Lease có giới hạn 30 phút, chưa heartbeat. Hàng chờ giới hạn 20 document/lượt; fairness và tải lớn chưa stress test. Tính khai thác thực tế của npm advisory chưa được kết luận.

Tại gốc repo:

```powershell
dotnet build desktop/UToken.Desktop.slnx --no-restore
git diff --check
git ls-files -u
dotnet list desktop/UToken.Desktop.slnx package --vulnerable --include-transitive --format json
```

Trong thư mục mobile:

```powershell
flutter analyze
dart format --output=none --set-exit-if-changed lib/core/data/local_prefs.dart lib/core/data/stream_status.dart lib/core/ui/ut_kit.dart lib/features/live test/live
```

Trong thư mục firebase:

```powershell
npm audit --json
```

Advisory thay đổi theo thời điểm tra. Exit code 1 của npm audit khi có vulnerability là kết quả kiểm tra, không tự nghĩa là lỗi công cụ. Các log được ignore: `desktop/static-build.log`, `mobile/static-analyze.log`, `mobile/static-format.log`, `desktop/static-dependency-audit.json`, `firebase/static-npm-audit.json`. `evidence.json` lưu kết quả có thể bàn giao, không chứa credential.
