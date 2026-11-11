# NAV-DETAIL — Điều hướng trang chi tiết và các tab

- Yêu cầu tạm UI-NAV: mở Analytics/Efficiency, quay lại, vào Insights/Settings rồi trở về Tokens.
- Tiền điều kiện: cùng APK preview, thiết bị và model miễn phí trong NAV-01; đang ở Tokens với mock.
- Mong đợi: mỗi màn đích có tiêu đề/nội dung; Back từ Efficiency trở về Analytics; cuối cùng ở Tokens.
- Trace: c551443c-54eb-49e5-ad43-3d4e39871496; thời lượng báo 134.2 giây.
- Kết quả: PASS các checkpoint điều hướng, có một lỗi định vị của agent đã phục hồi.

| Checkpoint | Quan sát |
|---|---|
| Analytics | Analytics / Token mix, models, and cost. |
| Efficiency detail | Efficiency / Results per token · last 30 days; ảnh step-03-before_screenshot.jpg được kiểm tra trực tiếp |
| Back | Trở về Analytics |
| Insights | Suggestions / Small changes based on your usage.; 2 gợi ý mock |
| Settings | Settings / Account, display, and sync preferences. |
| Kết thúc | Tokens / 6,830,736 / $42.18 |

## Sự cố công cụ

Ở step 5, agent dùng index cũ 43 trong khi hierarchy mới chỉ có 25 phần tử. Click bị từ chối, không phải app crash hay lỗi điều hướng. Step 6 đọc hierarchy mới và dùng index 24 thành công. Đã chạy mobile_diagnose, môi trường ready.

Trace có 7 action attempts (6 thành công, 1 bị từ chối) và 1 report action. Báo cáo tự động nói 6 UI actions; con số đó chỉ đếm action thành công, không được hiểu là không có lỗi automation.

Không sửa cài đặt, không kiểm tra persistence, không gọi AI review hay sync thật. Tài khoản example.com trong ảnh là dữ liệu mock. Không phải kết luận Figma pixel-perfect hoặc phủ mọi state.
