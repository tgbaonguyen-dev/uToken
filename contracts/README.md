# Contracts

JSON Schema cho các document Firestore. Desktop (ghi) và mobile (đọc) phải tuân theo cùng schema.

- Đổi cấu trúc → tăng `schema_version`, cập nhật cả hai phía trong cùng PR.
- `fixtures/`: log mẫu **đã làm sạch** (không có prompt, response, đường dẫn thật) cho test parser.


Pairing v2 uses camelCase `schemaVersion: 2`; usage contracts retain their existing
`schema_version`. See `firestore/pairing.schema.json`, `connection.schema.json` and
[PAIRING.md](../PAIRING.md). Firestore Timestamp values are represented as RFC3339
strings when validating JSON exports. Rules enforce the atomic state transitions.
