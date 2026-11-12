# μToken — Nội dung slide bảo vệ đồ án

Theo khung "Software Project Presentation Guideline V11": 4 phần, khoảng 18–20 phút.

| Phần | Slide | Thời lượng |
|---|---|---|
| P1 Problem | 01–06 | ≈ 3,5′ |
| P2 Design | 07–16, có thêm **10b** | ≈ 6,5′ |
| P3 Demo | 17–20 | ≈ 6,5′ |
| P4 Proof | 21–24 | ≈ 2,5′ |
| Phụ lục | A1–A6 | 0′, chỉ mở khi hội đồng hỏi |

**Slide thêm:** **10b · Cách tính độ hiệu quả**, đặt ngay sau Technology Stack. Bản công thức đầy đủ nằm ở phụ lục **A2**.

Quy ước trong file:
- `[ẢNH: …]`: chỗ cần chèn ảnh chụp màn hình thật.
- `[ĐIỀN: …]`: số liệu nhóm phải tự đo hoặc kiểm tra lại trước khi bảo vệ.
- Mọi số liệu còn lại lấy từ code và tài liệu trong repo (ngày 11/11/2026).

---

# P1 · PROBLEM

## Slide 01 — Overview

**Tiêu đề:** μToken: biết mình dùng AI coding tốn bao nhiêu và dùng có hiệu quả không

**Một câu:** μToken đọc log của Codex CLI, Claude Code và Antigravity ngay trên máy tính, tính chi phí và độ hiệu quả, rồi đưa kết quả lên điện thoại. Prompt và code không rời máy.

| USERS | VALUE | PLATFORM |
|---|---|---|
| Lập trình viên dùng AI coding agent (sinh viên, freelancer, team nhỏ) | Thấy rõ token và tiền đã dùng; biết thói quen nào gây lãng phí; nhận gợi ý cụ thể | Desktop (.NET 10 + Avalonia), Android (Flutter), Web admin (React), Firebase |

- `[ẢNH: điện thoại mở tab Tokens, cạnh màn hình Overview của desktop]`
- Nhóm: `[ĐIỀN: tên thành viên]` · Môn PRM393 · GVHD: `[ĐIỀN]`

> **Tránh:** mở đầu bằng danh sách công nghệ.

---

## Slide 02 — Context

**Tiêu đề:** AI coding agent đã thành công cụ hằng ngày, nhưng chi phí thì vô hình

| MÔI TRƯỜNG | NGƯỜI LIÊN QUAN | CÔNG CỤ HIỆN TẠI |
|---|---|---|
| Lập trình hằng ngày với Codex CLI, Claude Code, Antigravity | Lập trình viên; người trả tiền (cá nhân, team lead) | Trang billing của nhà cung cấp; file log JSONL trên máy (hàng trăm MB) |

**Quy trình hiện tại:** dùng agent → hết hạn mức hoặc nhận hóa đơn → mở trang billing → chỉ thấy tổng tiền, không biết vì sao.

**Hiện trạng:**
- Máy nhóm trưởng có 290 file log, khoảng 68 MB.
- Có file Codex trên 500 MB, nén `.jsonl.zst`.
- Người dùng gói subscription không thấy token theo từng phiên.

> **Tránh:** kể lể; vấn đề để dành cho slide 03.

---

## Slide 03 — Problem

**Tiêu đề:** Không đo được thì không tối ưu được

| PAIN POINT | NGUYÊN NHÂN | IMPACT |
|---|---|---|
| Không biết tiền đi đâu | Billing chỉ có tổng; log nằm rải rác ở 3 công cụ, mỗi công cụ một định dạng | Không biết model, dự án hay ngày nào tốn nhất |
| Lãng phí mà không hay | Cache thấp, chat kéo quá dài, suy luận thừa, agent chạy lại lệnh lỗi | Cùng một việc có thể tốn gấp nhiều lần (P90/P50 > 3) |
| Không dám chia sẻ dữ liệu để phân tích | Log chứa prompt, code, đường dẫn | Các công cụ phân tích "upload log" không dùng được |

**Minh chứng:**
- Kiểm tra log thật ngày 05/11/2026 (SRS v0.10 §10.4).
- Báo cáo nghiên cứu hiệu suất token (`docs/research/`).
- `[ĐIỀN: 1 số liệu ấn tượng từ máy nhóm, ví dụ "phiên phụ chiếm X% chi phí" hoặc "cache hit chỉ Y%"]`

> **Tránh:** nói giải pháp ở slide này.

---

## Slide 04 — Proposed Solution

**Tiêu đề:** Đo tại máy, chỉ gửi số tổng hợp, chấm điểm bằng công thức có kiểm chứng

| PAIN POINT | SOLUTION | EXPECTED VALUE |
|---|---|---|
| Không biết tiền đi đâu | Desktop đọc log của 3 công cụ, tính giá theo bảng giá models.dev | Token và chi phí theo ngày, model, dự án |
| Lãng phí mà không hay | 8 chỉ số quy trình (cache, context, thinking, lỗi, retry…), so sánh setup có thống kê, AI review có trích dẫn số | Biết chính xác thói quen nào cần sửa và tiết kiệm được bao nhiêu |
| Không dám chia sẻ | Chỉ gửi số đếm lên Firestore; tên dự án là mã băm (tên thư mục là tùy chọn) | Riêng tư theo thiết kế |

**IN-SCOPE (MVP):**
- Đọc log Codex CLI và Claude Code.
- Đồng bộ desktop ↔ điện thoại.
- Dashboard trên điện thoại.
- Độ hiệu quả và AI review.
- Ngân sách tháng.
- Web admin.

**OUT-OF-SCOPE:**
- Cursor, Copilot, chat trên web: chưa có nguồn log chính thức.
- Tự đổi model: μToken chỉ tư vấn.
- So sánh với người dùng khác: cần server tổng hợp và sự đồng ý chia sẻ dữ liệu.

> **Tránh:** nói "dùng AI" mà không nói lợi ích.

---

## Slide 05 — Main Actors

| Actor | Mô tả | Quyền hạn chính |
|---|---|---|
| **Developer** (người dùng) | Người dùng AI coding agent trên máy tính, xem kết quả trên điện thoại | Đăng nhập Google; xem usage và gợi ý; yêu cầu đồng bộ; chạy AI review; đặt ngân sách |
| **Admin** | Người vận hành hệ thống | Xem toàn bộ người dùng, crash, tình trạng sync và AI review; khóa hoặc mở khóa tài khoản; đóng crash. Không sửa được usage |
| **Desktop companion** (hệ thống) | Chạy nền trên máy người dùng | Đọc log, tính chỉ số, đẩy dữ liệu, nhận yêu cầu sync |
| **Firebase** (hệ thống ngoài) | Auth, Firestore, Hosting, Crashlytics | Xác thực; lưu số liệu tổng hợp; kiểm tra quyền bằng Security Rules |
| **LLM provider** (hệ thống ngoài) | Gemini, Claude hoặc OpenAI, theo API key của người dùng | Chấm điểm và viết gợi ý từ bản tóm tắt số liệu |

`[ẢNH nhỏ: avatar hoặc icon cho từng actor]`

---

## Slide 06 — Main Features

**Tiêu đề:** 4 nhóm tính năng, 3 workflow sẽ demo

| WF-01 · Đồng bộ usage | WF-02 · AI review | WF-03 · Quản trị hệ thống |
|---|---|---|
| **Actor:** Developer (điện thoại) + Desktop | **Actor:** Developer | **Actor:** Admin |
| **Trigger:** mở app khi dữ liệu cũ hơn 15 phút, hoặc kéo để làm mới | **Trigger:** bấm "Run new review" | **Trigger:** có crash mới hoặc sync bị kẹt |
| **Kết quả:** `sync_request` từ pending → running → done; dashboard tự cập nhật | **Kết quả:** điểm 0–100, hạng A–D, tối đa 5 gợi ý kèm bằng chứng | **Kết quả:** crash được đóng, tài khoản bị khóa, mọi thao tác ghi vào nhật ký |
| **Tính năng:** đọc log, tính giá, đẩy daily, banner S03/S04, offline | **Tính năng:** catalog chỉ số, rubric, kiểm tra lại số, why + steps | **Tính năng:** tổng quan, danh sách người dùng, crash, sync health, nhật ký |

**Ngoài workflow lõi:**
- Ngân sách tháng có cảnh báo 70/90/100%.
- So sánh model.
- Bảng giá model.
- Xuất CSV/JSON.
- Tiếng Việt và tiếng Anh.

---

# P2 · DESIGN

## Slide 07 — Business Flow

Sơ đồ swimlane, 5 làn:

```
DEVELOPER (máy tính)   Dùng Codex / Claude Code ──► (log JSONL ghi ra đĩa)
DESKTOP                Quét log ─► Tính giá ─► Gom task ─► Tính chỉ số ─► [BR-SYNC] có thay đổi? ─► Đẩy Firestore
                                                                              │không → "No new usage"
DEVELOPER (điện thoại) Mở app ─► [BR-STALE] dữ liệu > 15′? ─có─► Gửi sync_request ─► Đợi ─► Xem dashboard / Insights
                                                     │ [BR-TIMEOUT] 30s không phản hồi ─► S04 "Desktop không phản hồi"
LLM                    ◄── Brief số liệu (không có prompt/code) ── Desktop hoặc điện thoại ──► Điểm + gợi ý ─► [BR-VERIFY] kiểm lại số
ADMIN                  Xem Overview ─► Crash/Sync bất thường? ─► Đóng crash / Khóa tài khoản ─► Ghi admin_audit
```

**Mã business rule:**
- **BR-STALE:** tự đồng bộ khi dữ liệu cũ hơn 15 phút.
- **BR-TIMEOUT:** desktop phải nhận yêu cầu trong 30 giây.
- **BR-VERIFY:** evidence phải là chỉ số có trong catalog.
- **BR-PRIV:** không gửi prompt hay code.

`[ẢNH: vẽ lại bằng draw.io hoặc Figma]`

---

## Slide 08 — State Machine

**Entity: `sync_request`**, nối điện thoại với desktop:

```
● ─create(trigger)─► PENDING ─desktop claim / started_at─► RUNNING ─upload ok─► DONE
                        │                                     │
                        │ 30s không ai nhận                    └─ lỗi mạng/hết phiên ─► FAILED(error_code)
                        └──────────────────────────────────────────────────────────► FAILED(companion_offline)
```

- **Guard:** `trigger ∈ {screen_open, manual_refresh, ai_review}` và tạo mới phải ở `state = pending`. Firestore Rules chặn mọi giá trị khác.
- **Cấm:** tạo thẳng ở `DONE`; một request bị hai desktop cùng nhận (lease bằng `started_at`).
- **Phụ (nếu còn thời gian):** trạng thái task gồm Undetermined, Likely success / failure, Verified success / failure.
  - Thứ tự ưu tiên: thất bại có bằng chứng → thành công có bằng chứng → có thể thất bại → có thể thành công.

---

## Slide 09 — System Architecture

```
┌──────── MÁY NGƯỜI DÙNG ────────┐        HTTPS (REST + ID token)        ┌──── FIREBASE ────┐
│ ~/.codex, ~/.claude (log)      │ ─────────────────────────────────────►│ Auth (Google)     │
│   ▼ Collectors (chỉ giữ số)    │                                       │ Firestore         │
│ SQLite (events, turns, tasks)  │◄──── sync_requests (poll) ────────────│ Hosting (admin)   │
│   ▼ Core: giá, task, chỉ số    │                                       │ Crashlytics       │
│ Desktop .NET 10 / Avalonia     │                                       └────────┬──────────┘
└────────────────────────────────┘                                                │ SDK realtime
        │ brief số liệu                                         ┌─────────────────┴─────────┐
        ▼                                                       │ Android Flutter  · Web admin│
   LLM (Gemini / Claude / OpenAI) ◄──── brief số liệu ──────────└───────────────────────────┘
```

- **DEPLOYMENT:**
  - Desktop: chạy trên máy người dùng (Windows, Linux).
  - Firebase gói Spark ($0): web admin trên https://utoken-78191.web.app.
  - Android: file APK.
- **QUYẾT ĐỊNH 1, lưu trữ lai (ADR-0001):**
  - Chi tiết ở lại SQLite trên máy; Firestore chỉ có một document mỗi ngày, khoảng 2 lượt ghi mỗi lần sync.
  - Riêng tư và vừa hạn mức miễn phí.
  - Đánh đổi: không xem được chi tiết từng request trên điện thoại.
- **QUYẾT ĐỊNH 2, không có backend riêng:**
  - Quyền truy cập do Firestore Rules quyết định, kể cả quyền admin.
  - Đánh đổi: logic phía server bị giới hạn.

---

## Slide 10 — Technology Stack

| Nhóm | Công nghệ | Dùng để làm gì |
|---|---|---|
| Desktop | .NET 10, Avalonia UI 11, SQLite (Dapper) | Đọc log, tính toán, giao diện Windows/Linux |
| Mobile | Flutter (Dart), Riverpod, go_router | App Android |
| Web | React 18, TypeScript, Vite | Trang admin |
| Backend | Firebase Auth, Firestore, Hosting, Crashlytics | Đăng nhập, dữ liệu, phân quyền, báo crash |
| AI | Gemini / Claude / OpenAI API (structured output) | AI review, người dùng tự chọn nhà cung cấp |
| Dữ liệu ngoài | models.dev API | Bảng giá model, tự cập nhật mỗi ngày |
| Test | xUnit, flutter_test, Vitest, @firebase/rules-unit-testing | Unit, widget, rules test |
| Dev | Git/GitHub, Figma, Firebase Emulator | Phát triển và kiểm thử |

---

## Slide 10b — Cách tính độ hiệu quả ⭐ (slide thêm)

**Tiêu đề:** Điểm hiệu quả = 8 chỉ số đo được → 6 chiều → điểm có trọng số

**Câu hỏi hội đồng:** "Điểm 76 / hạng B lấy từ đâu ra, có phải AI tự bịa không?"
**Thời lượng:** 60 giây.
**Minh chứng:** công thức trong code (`EfficiencyCalculator.cs`, `contracts/judge/rubric.md`) và test.

### Bố cục 3 tầng (trái → phải)

**① ĐO, trên desktop, từ log (tầng xác định, không dùng AI)**

| Chỉ số | Công thức | Ngưỡng Review |
|---|---|---|
| Cache hit rate | cached ÷ input | < 50% |
| Context growth | input lượt cuối ÷ input lượt đầu của mỗi chat (lấy trung vị) | > 5× |
| Thinking share | thinking ÷ output | 7 ngày gần nhất > 2× trung vị theo ngày |
| Error rate | lệnh lỗi ÷ tổng lệnh | > 10% hoặc ≥ 3 lỗi liên tiếp |
| Retry rate | request gửi lại ≤ 2 phút sau request lỗi ÷ tổng request | > 10% |
| Token/turn | token/turn 7 ngày ÷ trung vị theo ngày − 1 | > +50% |
| Cost tail | P90 ÷ P50 chi phí mỗi task | > 3 |
| Hidden cost | chi phí phiên phụ (sub-agent, review) ÷ tổng chi phí | > 30% |

**② XẾP MỨC VÀ CHẤM ĐIỂM TỪNG CHIỀU**

- **Mỗi chỉ số được xếp một mức:**
  - Good: đạt ngưỡng tốt.
  - Watch: nằm giữa hai ngưỡng.
  - Review: vượt ngưỡng.
- **Điểm mỗi chiều:**
  - Tất cả Good → **90**
  - Có Watch → **70**
  - 1 Review → **50**
  - ≥ 2 Review, hoặc vượt gấp đôi ngưỡng → **30**
- **6 chiều và trọng số:**
  - Outcomes **30**
  - Reliability **20**
  - Cache **15**
  - Context **15**
  - Reasoning **10**
  - Hidden cost **10**

**③ TỔNG HỢP**

```
Điểm = round( Σ (trọng số × điểm chiều) ÷ Σ trọng số của các chiều có dữ liệu )
Hạng:  A ≥ 85 · B 70–84 · C 50–69 · D < 50
```

### Ví dụ tính (đặt ở góc phải slide)

| Chiều | Điểm | × Trọng số |
|---|---|---|
| Outcomes | 70 | 2100 |
| Reliability | 90 | 1800 |
| Cache | 90 | 1350 |
| Context | 50 | 750 |
| Reasoning | 70 | 700 |
| Hidden cost | 90 | 900 |
| **Tổng** | | **7600 ÷ 100 = 76 → hạng B** |

### Dòng chốt ở chân slide

- **Số do code tính:** AI chỉ xếp mức, giải thích và khuyên.
- **AI không bịa được số:** desktop kiểm lại mọi trích dẫn. Chỉ số nào không có trong catalog thì bị loại.
- **Tính được tiền tiết kiệm:** `tiết kiệm/tháng ≤ chi phí tháng thật`, tính theo giá models.dev.
- **So sánh 2 model hoặc setup:** dùng thống kê (Success rate và Cost per successful task, khoảng tin cậy 95%, cần ≥ 20 task). Chi tiết ở phụ lục A2.

> **Mẹo trình bày:** chỉ chỉ tay vào ví dụ "76 → B" và nói một câu cho mỗi tầng. Đừng đọc cả bảng 8 chỉ số.

---

## Slide 11 — UI/UX Design

- **Sitemap điện thoại:**
  - Onboarding (M01–M03) → Đăng nhập.
  - 4 tab: **Tokens · Analytics · Insights · Settings**.
  - Màn chi tiết: Daily usage, Model detail, Insight detail, Budget, Desktop connection.
- **Desktop:** Overview · Activity · Sources · Pricing · Sync · Settings.
- **Web admin:** Tổng quan · Người dùng · Crash · Đồng bộ · AI review · Nhật ký.
- **Ngôn ngữ thiết kế chung:**
  - Nền tối, màu nhấn xanh `#2EC790`.
  - Thẻ bo góc 17px.
  - Có tiếng Việt và tiếng Anh.
- **Trạng thái UI:**
  - Empty: chưa có usage.
  - Loading: skeleton.
  - Error: S04, offline.
  - Success: S03 → dữ liệu mới.
- **Sau góp ý:**
  - Chữ nhỏ 10px → 11px.
  - Tab Project hiện tên thư mục thay cho mã băm.
  - Chi tiết gợi ý có thêm "Vì sao", các bước làm và "Đến từ đâu".
- `[ẢNH: Figma (wireframe → final) + 3 màn hình thật]`

---

## Slide 12 — Sequence Diagram (tùy chọn)

**Tương tác: kéo để làm mới trên điện thoại → desktop sync**

```
Điện thoại:UI   SyncCenter     Firestore      Desktop:SyncLoop    UsageEngine
  │ pull ─────►│ add(sync_requests, pending) ─►│                    │
  │            │◄──── watch(id) ───────────────│◄── poll pending ────│
  │ S03 banner │                               │── claim: running ──►│ Run(): đọc log, tính
  │            │◄── state=running ─────────────│                     │
  │            │                               │◄── commit daily/efficiency ──│
  │            │◄── state=done ────────────────│                     │
  │ UI cập nhật│
alt [30s không ai nhận]  → SyncCenter._fail('companion_offline') → banner S04
```

---

## Slide 13 — Class Design

```
TokensScreen ──► SyncCenter (single-flight, timeout 30s) ──► UsageRepository (interface)
                                                               ├─ FirestoreUsageRepository
                                                               └─ CachedUsageRepository (ReplayStream, đổi tab không spinner)
Desktop: RealDesktopApi ──► UsageEngine ──► Collectors (Codex, ClaudeCode)
                                       ├─► TaskBuilder ─► OutcomeClassifier
                                       ├─► EfficiencyCalculator ─► Stats, VerdictRules
                                       └─► SqliteStore
         ──► FirebaseCloudSync (ICloudSync) ──► FirestoreRestClient
         ──► JudgeService ─► Gemini/Anthropic/OpenAiJudgeModel ─► InsightValidator
```

- **Business rule đặt trong Core**, gồm các hàm thuần, không I/O:
  - `OutcomeClassifier`
  - `VerdictRules`
  - `InsightValidator`
- UI chỉ hiển thị kết quả.

---

## Slide 14 — Database Conceptual (gộp vào 15 nếu thiếu giờ)

```
USER 1 ── 0..* DAILY (một document mỗi ngày)
USER 1 ── 0..1 EFFICIENCY · 0..1 INSIGHTS · 0..1 PROJECT_NAMES
USER 1 ── 0..* SYNC_REQUEST · 0..* CRASH_REPORT
ADMIN 1 ── 0..* ADMIN_AUDIT ;  ADMIN ── 0..* SUSPENDED(user)
```

**Business rules:**
- **BR-01:** chỉ chủ tài khoản đọc và ghi dữ liệu của mình; admin chỉ đọc.
- **BR-02:** `daily` phải có `schema_version = 2` và ID dạng `YYYY-MM-DD`.
- **BR-03:** tài khoản trong `suspended/{uid}` mất mọi quyền với dữ liệu của chính mình.
- **BR-04:** `admin_audit` chỉ thêm được, không sửa hay xóa.

---

## Slide 15 — Database Logical / Physical

**Hai tầng lưu trữ:**

| Nơi | Bảng / Collection | Khóa và ràng buộc chính |
|---|---|---|
| SQLite (desktop) | `usage_events`, `turns`, `tasks`, `projects`, `source_files`, `daily_local`, `pricing`, `pricing_tier` | Khóa nguồn chống trùng; `source_files.offset` để đọc tiếp; cờ `dirty` để sync lại khi mất mạng |
| Firestore | `users/{uid}/daily/{date}`, `efficiency/current`, `insights/current`, `sync_requests/{id}`, `crash_reports/{id}`, `meta/projects`; `admins`, `suspended`, `admin_audit` | Ràng buộc bằng **Security Rules** + JSON Schema trong `contracts/firestore/` |

- **Ví dụ `daily`:**
  - `totals { input, cached, output, thinking, cost_micro, chats, requests… }`
  - `by_key { "codex|gpt-5|3f2a9c1b04de": {…} }`
- **Index:** collection group trên `daily.date`, `sync_requests.created_at`, `crash_reports.created_at` (`firebase/firestore.indexes.json`).
- **Tiền lưu bằng số nguyên micro-USD** để không sai số dấu phẩy động.

---

## Slide 16 — Traceability

| Feature | Screen | Class / Service | Entity | Tests |
|---|---|---|---|---|
| F1 Đồng bộ usage | Tokens, banner S03/S04, Desktop Sync | `SyncCenter`, `UsageEngine`, `FirebaseCloudSync` | `daily`, `sync_requests` | `sync_states_test`, `CloudSyncTests`, `LiveSyncRoundTripTests` |
| F2 Độ hiệu quả | Analytics, Efficiency | `EfficiencyCalculator`, `Stats`, `VerdictRules` | `efficiency` | `UToken.Core.Tests` (74) |
| F3 AI review | Insights, Insight detail | `JudgeService`, `InsightValidator`, `phone_judge` | `insights` | `UToken.Insights.Tests` (37), `phone_judge_test` |
| F4 Quản trị | Web admin (7 trang) | `data.ts`, Firestore Rules | `admins`, `suspended`, `admin_audit`, `crash_reports` | `admin-rules.test.js` (7), `stats.test.ts` |

**Truy vết:** Feature → Screen → Class → Firestore/SQLite → Test.

---

# P3 · DEMO

## Slide 17 — Demo Plan

| 01 · Đồng bộ usage | 02 · AI review | 03 · Quản trị |
|---|---|---|
| Developer | Developer | Admin |
| **Kết quả:** usage hôm nay hiện trên điện thoại, `sync_request` ở trạng thái done | **Kết quả:** điểm `[ĐIỀN]`/100, hạng `[ĐIỀN]`, gợi ý có các bước làm | **Kết quả:** crash của bước 1 được đóng; nhật ký có dòng mới |

**Chuẩn bị:**
- 1 tài khoản Google đã có ≥ 5 chat trong 30 ngày.
- Desktop đã đăng nhập.
- Điện thoại cắm USB, chiếu màn hình bằng scrcpy.
- Tài khoản admin.
- API key Gemini.
- Video dự phòng.
- Người thao tác ≠ người thuyết minh.

---

## Slide 18 — Demo WF-01 · Đồng bộ usage

`Trigger: kéo để làm mới` → `Gửi sync_request` → `Desktop nhận (running)` → `Đọc log, tính giá, đẩy daily` → `Kết quả: dashboard cập nhật`

- **TRẠNG THÁI:** PENDING → RUNNING → DONE.
- **EXCEPTION:**
  - Tắt desktop rồi kéo làm mới → sau 30 giây hiện banner S04 "Desktop không phản hồi" và dữ liệu cũ vẫn còn.
  - Tắt mạng → dải "Offline · đang hiện dữ liệu đã lưu".
- **EVIDENCE:**
  - Document `sync_requests/<id>` có `state = done`.
  - Số token hôm nay khớp màn Overview trên desktop.
  - Test `sync_states_test`.

---

## Slide 19 — Demo WF-02 · AI review

`Trigger: Insights → Run new review` → `Chọn "Từ lần review trước" hoặc "30 ngày"` → `Gửi brief số liệu (không có prompt)` → `Kiểm lại evidence` → `Kết quả: điểm + 5 gợi ý`

- **Mở 1 gợi ý** để cho thấy:
  - "Vì sao".
  - Các bước làm.
  - "Đến từ đâu", tức model và dự án đóng góp nhiều nhất.
  - Liên hệ lại slide **10b**.
- **EXCEPTION:**
  - API key sai → `failed / invalid_api_key`, gợi ý cũ vẫn giữ.
  - Dưới 5 chat → `insufficient_data`, không gọi AI.
- **EVIDENCE:** document `insights/current` có `score`, `grade`, mỗi gợi ý có `evidence[].metric` nằm trong catalog.

---

## Slide 20 — Demo WF-03 · Quản trị hệ thống

`Trigger: Settings → Test crash trên điện thoại` → `Admin mở web → Crash` → `Xem chi tiết + stack` → `Đánh dấu đã xử lý (có ghi chú)` → `Kết quả: audit log`

- **Phụ:** khóa một tài khoản test → điện thoại đó báo "Firebase từ chối truy cập" → mở khóa → dùng lại bình thường.
- **EXCEPTION:**
  - Tài khoản không phải admin mở web → màn "Chưa có quyền admin".
  - Admin thử sửa usage → Firestore Rules chặn.
- **EVIDENCE:**
  - `crash_reports/<id>.status = resolved`.
  - Có dòng `admin_audit` mới.
  - Rules test 21/21 pass.

---

# P4 · PROOF

## Slide 21 — Testing

| 500+ | 100% | `[ĐIỀN]` |
|---|---|---|
| test tự động | pass (11/11/2026) | bug còn mở |

| Level | Evidence | Result |
|---|---|---|
| Unit (Core, Insights, Storage, Collectors) | xUnit: 74 + 37 + 13 + 14 test | Pass |
| Integration (desktop ↔ Firestore) | `CloudSyncTests`, `LiveSyncRoundTripTests`, Firestore emulator | Pass (3 test cần emulator bị skip khi chạy CI) |
| Widget / UI (mobile) | flutter_test: 226 test | Pass |
| Security Rules | @firebase/rules-unit-testing: 21 test | Pass |
| Web admin | Vitest (4) + chạy thử 7 trang trên emulator | Pass |
| Thiết bị thật | Samsung S22 (Android) + Waydroid | `[ĐIỀN: checklist UAT]` |

**Kiểm thử tĩnh:** `docs/static-testing/2026-11-10/` (thiết kế case, báo cáo).

---

## Slide 22 — Achievements

| OBJECTIVE | IMPLEMENTED | VALIDATED |
|---|---|---|
| Đo token và chi phí của 2 công cụ (Codex, Claude Code) | Desktop đọc log, giá từ models.dev; 290 file / 68 MB quét trong 1,7 giây | Test Collectors và Core |
| Đánh giá hiệu quả có cơ sở | 8 chỉ số + so sánh setup có thống kê + AI review được kiểm lại số | Test Core, Insights |
| Riêng tư | Chỉ gửi số tổng hợp; key AI lưu trên máy | Rules test + `--judge --dry-run` cho xem chính xác dữ liệu gửi đi |
| Vận hành | Web admin, Crashlytics, khóa tài khoản | https://utoken-78191.web.app |

**CHƯA ĐẠT:** Antigravity chưa có token trong log → slide 23.

---

## Slide 23 — Limitations

| Giới hạn | Tác động | Ưu tiên | Next step |
|---|---|---|---|
| Antigravity không ghi token ra log | Mới đo được 2/3 công cụ | Cao | Theo dõi định dạng log mới; thêm connector |
| Retry rate của Codex luôn = 0 (log không ghi request lỗi) | Chiều Reliability thiếu dữ liệu cho Codex | TB | Suy ra từ thời gian giữa các request |
| Ngưỡng chấm là giả định (SRS OQ-03) | Điểm có thể chưa hợp mọi kiểu làm việc | TB | Thu thập dữ liệu và hiệu chỉnh ngưỡng |
| Chưa so sánh giữa các công cụ khác nhau | Chỉ so được model trong cùng công cụ | Thấp | Chuẩn hóa task giữa các công cụ |

---

## Slide 24 — Conclusion

1. **PROBLEM SOLVED:** chi phí AI coding hết "vô hình". Người dùng biết tiền đi đâu, thói quen nào lãng phí, và tiết kiệm được bao nhiêu.
2. **WORKING PRODUCT:** desktop + Android + web admin chạy trên Firebase; đã demo WF-01..03.
3. **VERIFIED RESULT:** hơn 500 test tự động pass; điểm hiệu quả tính bằng công thức minh bạch, AI không bịa được số.

[Demo: utoken-78191.web.app] · [Repo: github.com/tgbaonguyen-dev/uToken] · [Figma: `[ĐIỀN]`]

> Để slide này trên màn hình suốt phần hỏi đáp.

---

# PHỤ LỤC (không chiếu, chỉ mở khi được hỏi)

## A1 — Màn hình phụ

`[ẢNH: Efficiency, Model compare, Budget, Desktop Sources, Pricing, 7 trang web admin]`

## A2 — Chi tiết công thức hiệu quả (mở rộng slide 10b)

**Chuẩn hóa token (SRS §10.4):**
- `input` đã gồm `cached` và `cache_write`; `output` đã gồm `thinking`. Tổng = input + output.
- Chi phí = Σ (token theo loại × giá theo bậc context) theo models.dev tại thời điểm event. Ví dụ gpt-5.6-sol: $4/$20 mỗi 1 triệu token, lên $8/$30 khi context > 272K.

**Task và kết quả (FR-ANLY-003):**
- Task là các turn cách nhau ≤ 2 phút trong cùng phiên chính.
- Nhóm việc theo số request: Small ≤ 10, Medium ≤ 40, Large > 40.
- Trạng thái task:
  - **Verified failure:** lượt lỗi, bị ngắt, hoặc lần test cuối fail.
  - **Verified success:** lần test cuối pass.
  - **Likely failure:** ≥ 3 lỗi liên tiếp, hoặc hỏi lại trong 2 phút.
  - **Likely success:** có sửa file.
  - Còn lại là **Undetermined**.

**So sánh 2 setup (provider + model + effort, trong cùng nhóm việc):**
- **SR** (success rate) = verified success ÷ (verified success + verified failure), kèm khoảng Wilson 95%.
- **CPST** (cost per successful task) = tổng chi phí ÷ số task thành công. Khoảng tin cậy dùng bootstrap theo phiên, 1.000 lần, seed cố định.
- **Sai số SR tính theo cụm phiên**, vì các task cùng phiên không độc lập. Khi SR = 0% hoặc 100% thì dùng Agresti–Coull.
- **MDE** = (1,96 + 0,84) × √(SE_A² + SE_B²), tức 95% tin cậy và 80% power.
- **Kết luận:**
  - Thiếu dữ liệu khi n < 20 task hoặc MDE > 20 điểm.
  - Tốt hơn khi khoảng SR_A − SR_B > 0.
  - Rẻ hơn mà không tệ hơn khi CI chi phí của A < CI của B.
  - Đánh đổi khi vừa tốt hơn vừa tệ hơn ở hai trục.
  - Tệ hơn.
  - Chưa thấy khác biệt.
- **Độ tin cậy:** cao khi MDE ≤ 10 điểm.
- **Bất ổn:** SR theo tuần dao động > 10 điểm, hoặc P90/P50 > 3.

**AI review:**
- **Brief gửi đi:** catalog chỉ số (id, nhãn, giá trị), không có prompt, code hay đường dẫn.
- **Kết quả AI trả về:**
  - Điểm theo rubric (`contracts/judge/rubric.md`).
  - Tối đa 5 gợi ý.
  - Mỗi gợi ý có 1–3 evidence, "why" và 2–4 bước làm.
- **`InsightValidator` kiểm tra lại:**
  - Evidence không có trong catalog thì bỏ.
  - Tiền tiết kiệm bị chặn ở mức chi phí tháng thật.
  - Category, severity và confidence phải hợp lệ.

## A3 — Test case & report

`flutter test` (226), `dotnet test` (266 pass / 4 skip), `npm test` trong `firebase/` (21) và `admin/` (4). Kèm `docs/static-testing/`.

## A4 — Physical schema

`contracts/firestore/*.schema.json`, `firebase/firestore.rules`, `firebase/firestore.indexes.json`.

## A5 — Application design

ADR-0001 (lưu trữ lai), ADR-0002 (.NET + Avalonia), ADR-0003 (Firestore REST từ desktop).

## A6 — Video demo dự phòng

`[ĐIỀN: link video 3 workflow]`

---

## Checklist trước khi bảo vệ

- [ ] Thay mọi `[ĐIỀN]` và `[ẢNH]`.
- [ ] Chạy lại các bộ test và cập nhật số trên slide 21.
- [ ] Deploy Firestore Rules và index mới; tạo tài khoản admin để demo.
- [ ] Cài bản app mới nhất lên điện thoại demo; kiểm tra đăng nhập Google.
- [ ] Desktop có đủ ≥ 5 chat trong 30 ngày để AI review có kết quả.
- [ ] Quay video dự phòng cho WF-01..03.
