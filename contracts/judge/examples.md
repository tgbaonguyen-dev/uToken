<!-- Ví dụ few-shot cho model chấm; gửi kèm sau rubric.md. Số liệu là minh họa. -->

# Ví dụ

## Catalog đầu vào

```json
{
  "period": {"start": "2026-10-11", "end": "2026-11-09"},
  "metrics": [
    {"id": "chats_30d", "label": "Số chat", "value": "42"},
    {"id": "cost_30d", "label": "Chi phí 30 ngày", "value": "$18.40"},
    {"id": "cache_hit_rate.codex", "label": "Cache hit Codex", "value": "32%"},
    {"id": "cache_hit_rate.claude_code", "label": "Cache hit Claude Code", "value": "80%"},
    {"id": "context_growth_median", "label": "Context phình (trung vị)", "value": "2.4×"},
    {"id": "thinking_share_ratio", "label": "Thinking so với thường", "value": "1.5×"},
    {"id": "retry_rate", "label": "Tỷ lệ retry", "value": "12%"},
    {"id": "hidden_cost_share.codex", "label": "Chi phí ngầm Codex", "value": "41%"},
    {"id": "input_uncached_cost.codex", "label": "Input không cache Codex", "value": "$6.10"},
    {"id": "sr_primary", "label": "SR chính", "value": "—"}
  ],
  "comparisons": [
    {"setup_a": "codex/gpt-5.6-sol", "setup_b": "codex/gpt-6-luna", "verdict": "Chưa đủ dữ liệu", "progress": "12/20"}
  ]
}
```

Cách chấm: cache 1 Review → 50, còn xa ngưỡng → 45; context, reasoning Good → 90; reliability
1 Review → 50; outcomes không có chỉ số → `null`; hidden_cost 1 Review → 50.
Điểm = (20·50 + 15·45 + 15·90 + 10·90 + 10·50) ÷ 70 = 63 → C.
Tiết kiệm: chi phí ngầm (41% − 30%) × $18.40 = $2.02; cache $6.10 × (50% − 32%) = $1.10.
So sánh "Chưa đủ dữ liệu" → không insight nào nói về hai model.

## Output đúng

```json
{
  "score": 63, "grade": "C",
  "headline": "Chi phí ngầm và cache thấp ở Codex là hai chỗ tốn tiền nhất tháng này.",
  "dimensions": [
    {"id": "cache", "score": 45, "comment": "Codex 32% (cache_hit_rate.codex) dưới 50%; Claude Code ổn 80%."},
    {"id": "context", "score": 90, "comment": "Trung vị 2.4× (context_growth_median) ≤ 3×."},
    {"id": "reasoning", "score": 90, "comment": "Thinking 1.5× mức thường (thinking_share_ratio)."},
    {"id": "reliability", "score": 50, "comment": "Retry 12% (retry_rate) trên 10%."},
    {"id": "outcomes", "score": null, "comment": "Chưa có nhãn thành công (sr_primary)."},
    {"id": "hidden_cost", "score": 50, "comment": "Phiên phụ Codex 41% (hidden_cost_share.codex) trên 30%."}
  ],
  "insights": [
    {
      "id": "hidden-codex", "title": "Chi phí ngầm Codex cao", "severity": "medium",
      "category": "hidden_cost", "provider": "codex",
      "evidence": [{"metric": "hidden_cost_share.codex", "label": "Chi phí ngầm Codex", "value": "41%"}],
      "recommendation": "Tắt auto-review cho task nhỏ hoặc dùng model rẻ hơn cho phiên duyệt.",
      "estimated_impact": "≈ $2.0/tháng", "estimated_saving_micro_per_month": 2024000, "confidence": "medium"
    },
    {
      "id": "cache-codex", "title": "Cache Codex thấp", "severity": "medium",
      "category": "cache", "provider": "codex",
      "evidence": [
        {"metric": "cache_hit_rate.codex", "label": "Cache hit Codex", "value": "32%"},
        {"metric": "input_uncached_cost.codex", "label": "Input không cache", "value": "$6.10"}
      ],
      "recommendation": "Giữ cố định phần đầu prompt và danh sách tool; đặt nội dung hay đổi ở cuối.",
      "estimated_impact": "≈ $1.1/tháng", "estimated_saving_micro_per_month": 1098000, "confidence": "medium"
    },
    {
      "id": "retry", "title": "Retry vượt ngưỡng", "severity": "low",
      "category": "reliability", "provider": null,
      "evidence": [{"metric": "retry_rate", "label": "Tỷ lệ retry", "value": "12%"}],
      "recommendation": "Khi agent lỗi 2 lần liên tiếp, dừng lại và bổ sung thông tin môi trường.",
      "estimated_impact": "Giảm lượt lỗi lặp", "estimated_saving_micro_per_month": null, "confidence": "low"
    }
  ]
}
```

## Output sai (không được làm)

| Output | Vì sao sai |
|---|---|
| `"recommendation": "**Lưu ý:** bạn nên...\n- Giữ prompt..."` | Markdown và xuống dòng |
| `"title": "Tỷ lệ cache hit của Codex đang thấp hơn nhiều so với ngưỡng khuyến nghị"` | Quá 48 ký tự |
| `"recommendation": "Dùng gpt-6-luna vì hiệu quả hơn gpt-5.6-sol."` | Trái kết luận "Chưa đủ dữ liệu" |
| `"value": "~30%"` cho `cache_hit_rate.codex` | Không chép nguyên văn (catalog ghi 32%) |
| `"metric": "avg_session_length"` | `id` không có trong catalog |
| `"title": "Project demo-app tốn nhiều token"` | Nhắc tên project |
| `"comment": "Bạn đã nhờ agent sửa test pytest nhiều lần"` | Đoán nội dung chat và lệnh |
| `"outcomes"` có `"score": 0` | Thiếu dữ liệu phải là `null` |
| Insight về `context` trong khi context là Good | Insight chỉ dành cho chỉ số Review |
| `"headline": "Điểm 63/100, hạng C."` | Nhắc lại điểm, không nêu điều gì mới |
