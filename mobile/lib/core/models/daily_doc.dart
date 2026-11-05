/// users/{uid}/daily/{YYYY-MM-DD} — khớp contracts/firestore/daily.schema.json (schema_version 2).
class TokenBreakdown {
  const TokenBreakdown({
    required this.input,
    required this.cached,
    required this.cacheWrite,
    required this.output,
    this.thinking,
    this.costMicro,
    this.sideTokens = 0,
  });

  final int input; // đã gồm cached
  final int cached;
  final int cacheWrite;
  final int output; // đã gồm thinking
  final int? thinking; // null = nguồn không cung cấp → hiển thị "—"
  final int? costMicro; // null = thiếu giá
  final int sideTokens;

  /// SRS §10.1: total = input + output, không cộng thêm cached hay thinking.
  int get total => input + output;

  double? get cacheHitRate => input == 0 ? null : cached / input;

  factory TokenBreakdown.fromMap(Map<String, dynamic> m) => TokenBreakdown(
        input: (m['input'] ?? 0) as int,
        cached: (m['cached'] ?? 0) as int,
        cacheWrite: (m['cache_write'] ?? 0) as int,
        output: (m['output'] ?? 0) as int,
        thinking: m['thinking'] as int?,
        costMicro: m['cost_micro'] as int?,
        sideTokens: (m['side_tokens'] ?? 0) as int,
      );
}

class DailyDoc {
  const DailyDoc({required this.date, required this.totals, required this.byKey});

  final String date;
  final TokenBreakdown totals;
  final Map<String, TokenBreakdown> byKey; // khóa: provider|model|project_key

  factory DailyDoc.fromMap(Map<String, dynamic> m) {
    if (m['schema_version'] != 2) {
      throw FormatException('daily schema_version không hỗ trợ: ${m['schema_version']}');
    }
    final byKey = (m['by_key'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k, TokenBreakdown.fromMap(v as Map<String, dynamic>)));
    return DailyDoc(
      date: m['date'] as String,
      totals: TokenBreakdown.fromMap(m['totals'] as Map<String, dynamic>),
      byKey: byKey,
    );
  }
}
