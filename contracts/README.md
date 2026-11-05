# Contracts

JSON Schema cho các document Firestore. Desktop (ghi) và mobile (đọc) phải tuân theo cùng schema.

- Đổi cấu trúc → tăng `schema_version`, cập nhật cả hai phía trong cùng PR.
- `fixtures/`: log mẫu **đã làm sạch** (không có prompt, response, đường dẫn thật) cho test parser.
