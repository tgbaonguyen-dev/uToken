#!/usr/bin/env bash
# Tạo bộ label chuẩn cho repo. Cần GitHub CLI đã đăng nhập: gh auth login
set -euo pipefail
create() { gh label create "$1" --color "$2" --description "$3" --force; }
create "area:desktop"   "1d76db" "Ứng dụng desktop .NET"
create "area:mobile"    "0e8a16" "Ứng dụng Flutter"
create "area:firebase"  "fbca04" "Rules, index, cấu hình Firebase"
create "area:contracts" "5319e7" "Schema dùng chung"
create "area:docs"      "c5def5" "SRS, ADR, tài liệu"
create "type:feature"   "a2eeef" "Tính năng mới"
create "type:bug"       "d73a4a" "Lỗi"
create "type:spike"     "f9d0c4" "Thử nghiệm, PoC"
create "type:chore"     "ededed" "Bảo trì, cập nhật thư viện"
create "priority:P0"    "b60205" "Bắt buộc cho MVP"
create "priority:P1"    "d93f0b" "Nên có"
create "priority:P2"    "fef2c0" "Để sau"
create "status:triage"  "bfdadc" "Chờ phân loại"
create "status:blocked" "000000" "Bị chặn"
create "privacy"        "e99695" "Liên quan dữ liệu người dùng — cần review kỹ"
