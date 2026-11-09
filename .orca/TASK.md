# Checklist nhánh feat/mobile-firestore (app Flutter trong mobile/, Flutter: /home/camellya/Tools/Flutter/bin)
Quy tắc: làm lần lượt; xong mỗi mục thì chạy kiểm tra của mục, commit (KHÔNG Co-Authored-By/chữ ký AI), đổi [ ] thành [x] trong file này. Không push. Không đọc file credential. Không gọi Firebase thật trong test. Chỉ dart format file mình sửa. Không sửa màn Figma mock (lib/features/figma, lib/core/mock). Dòng code ≤ 100 ký tự. Báo cáo cuối bằng tiếng Việt.

- [x] 1. Commit các bản sửa đang nằm chưa commit ở lib/features/{tokens,analytics,efficiency,insights,settings}/presentation (spinner chỉ khi connectionState == waiting; câu lỗi qua lib/core/data/stream_status.dart). Kiểm tra: flutter analyze 0 issue.
- [x] 2. mobile/test/live/: UsageRepository giả (StreamController). Widget test Tokens (tổng token/chi phí; đổi Day/Week/Month/Total), Efficiency ('Chưa đủ dữ liệu · n/20'), M10 (thời điểm sync), stream lỗi → câu thân thiện, null → '—'.
- [ ] 3. Widget test Insights: không document / insufficient_data / failed còn insights cũ + câu lỗi thân thiện / ok; bấm thẻ mở chi tiết M08 (evidence, recommendation, saving USD/tháng).
- [ ] 4. Router test: đăng nhập thật → màn live; demo hoặc chưa đăng nhập → FigmaPixelScreen.
- [ ] 5. Kiểm tra cuối: dart format --set-exit-if-changed (file đã sửa/thêm); flutter analyze 0 issue; flutter test (đợi kết quả cuối, timeout ≥ 900s; tổng > 159, 0 fail); flutter build apk --debug (copy tạm /home/camellya/Repositories/Class/PRM393/uToken/mobile/android/app/google-services.json, không commit). Ghi kết quả vào cuối file này.
