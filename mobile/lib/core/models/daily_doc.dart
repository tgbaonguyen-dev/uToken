typedef JsonMap = Map<String, dynamic>;

int? readInt(Object? value) => value is num ? value.toInt() : null;
double? readDouble(Object? value) => value is num ? value.toDouble() : null;

class TokenBreakdown {
  const TokenBreakdown({required this.input, required this.cached, required this.cacheWrite, required this.output, this.thinking, this.costMicro, this.sideTokens = 0, this.chats = 0, this.requests = 0, this.errorRequests = 0, this.sideCostMicro, this.contextGrowthSum, this.contextGrowthCount, this.durationSumMs, this.durationCount});
  final int input, cached, cacheWrite, output, sideTokens, chats, requests, errorRequests;
  final int? thinking, costMicro, sideCostMicro, durationSumMs, durationCount;
  final double? contextGrowthSum;
  final int? contextGrowthCount;
  int get total => input + output;
  double? get cacheHitRate => input == 0 ? null : cached / input;
  factory TokenBreakdown.fromMap(JsonMap m) => TokenBreakdown(input: readInt(m['input']) ?? 0, cached: readInt(m['cached']) ?? 0, cacheWrite: readInt(m['cache_write']) ?? 0, output: readInt(m['output']) ?? 0, thinking: readInt(m['thinking']), costMicro: readInt(m['cost_micro']), sideTokens: readInt(m['side_tokens']) ?? 0, chats: readInt(m['chats']) ?? 0, requests: readInt(m['requests']) ?? 0, errorRequests: readInt(m['error_requests']) ?? 0, sideCostMicro: readInt(m['side_cost_micro']), contextGrowthSum: readDouble(m['context_growth_sum']), contextGrowthCount: readInt(m['context_growth_count']), durationSumMs: readInt(m['duration_sum_ms']), durationCount: readInt(m['duration_count']));
}

class DailyDoc {
  const DailyDoc({required this.date, required this.totals, required this.byKey, required this.tasksByState, this.pricingVersion, this.updatedAt});
  final String date;
  final TokenBreakdown totals;
  final Map<String, TokenBreakdown> byKey;
  final Map<String, int> tasksByState;
  final String? pricingVersion, updatedAt;
  factory DailyDoc.fromMap(JsonMap m) { if (m['schema_version'] != 2) throw FormatException('Unsupported daily schema_version: ${m['schema_version']}'); final raw = m['by_key'] is Map ? (m['by_key'] as Map).cast<String, dynamic>() : <String, dynamic>{}; final states = m['tasks_by_state'] is Map ? (m['tasks_by_state'] as Map).cast<String, dynamic>() : <String, dynamic>{}; return DailyDoc(date: m['date'] as String? ?? '', totals: TokenBreakdown.fromMap((m['totals'] is Map ? (m['totals'] as Map).cast<String, dynamic>() : <String, dynamic>{})), byKey: raw.map((k, v) => MapEntry(k, TokenBreakdown.fromMap((v as Map).cast<String, dynamic>()))), tasksByState: states.map((k, v) => MapEntry(k, readInt(v) ?? 0)), pricingVersion: m['pricing_version'] as String?, updatedAt: m['updated_at'] as String?); }
}
