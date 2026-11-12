typedef JsonMap = Map<String, dynamic>;

/// Reads Firestore integer values, including values decoded as doubles.
int? readInt(Object? value) {
  if (value == null) return null;
  if (value is num && value.isFinite && value == value.truncateToDouble()) {
    return value.toInt();
  }
  throw const FormatException('Expected a finite integer field.');
}

/// Counters and micro-USD amounts cannot be negative.
int? readCounter(Object? value) {
  final result = readInt(value);
  if (result != null && result < 0) {
    throw const FormatException('Expected a non-negative counter.');
  }
  return result;
}

/// Reads Firestore numeric values without coercing null to zero.
double? readDouble(Object? value) {
  if (value == null) return null;
  if (value is num && value.isFinite) return value.toDouble();
  throw const FormatException('Expected a finite numeric field.');
}

JsonMap readMap(Object? value) {
  if (value == null) return {};
  if (value is Map && value.keys.every((key) => key is String)) {
    return Map<String, dynamic>.from(value);
  }
  throw const FormatException('Expected a map field.');
}

List<dynamic> readList(Object? value) {
  if (value == null) return [];
  if (value is List) return value;
  throw const FormatException('Expected a list field.');
}

String? readString(Object? value) {
  if (value == null || value is String) return value as String?;
  throw const FormatException('Expected a string field.');
}

bool? readBool(Object? value) {
  if (value == null || value is bool) return value as bool?;
  throw const FormatException('Expected a boolean field.');
}

/// Aggregated token counters for one daily document section.
class TokenBreakdown {
  const TokenBreakdown(
      {required this.input,
      required this.cached,
      required this.cacheWrite,
      required this.output,
      this.thinking,
      this.costMicro,
      this.sideTokens = 0,
      this.chats = 0,
      this.requests = 0,
      this.errorRequests = 0,
      this.sideCostMicro,
      this.contextGrowthSum,
      this.contextGrowthCount,
      this.durationSumMs,
      this.durationCount});
  final int input,
      cached,
      cacheWrite,
      output,
      sideTokens,
      chats,
      requests,
      errorRequests;
  final int? thinking, costMicro, sideCostMicro, durationSumMs, durationCount;
  final double? contextGrowthSum;
  final int? contextGrowthCount;
  int get total => input + output;
  double? get cacheHitRate => input == 0 ? null : cached / input;
  factory TokenBreakdown.fromMap(JsonMap m) => TokenBreakdown(
      input: readCounter(m['input']) ?? 0,
      cached: readCounter(m['cached']) ?? 0,
      cacheWrite: readCounter(m['cache_write']) ?? 0,
      output: readCounter(m['output']) ?? 0,
      thinking: readCounter(m['thinking']),
      costMicro: readCounter(m['cost_micro']),
      sideTokens: readCounter(m['side_tokens']) ?? 0,
      chats: readCounter(m['chats']) ?? 0,
      requests: readCounter(m['requests']) ?? 0,
      errorRequests: readCounter(m['error_requests']) ?? 0,
      sideCostMicro: readCounter(m['side_cost_micro']),
      contextGrowthSum: readDouble(m['context_growth_sum']),
      contextGrowthCount: readCounter(m['context_growth_count']),
      durationSumMs: readCounter(m['duration_sum_ms']),
      durationCount: readCounter(m['duration_count']));
}

/// Usage totals and provider/model breakdown for one calendar day.
class DailyDoc {
  const DailyDoc(
      {required this.date,
      required this.totals,
      required this.byKey,
      required this.tasksByState,
      this.pricingVersion,
      this.updatedAt});
  final String date;
  final TokenBreakdown totals;
  final Map<String, TokenBreakdown> byKey;
  final Map<String, int> tasksByState;
  final String? pricingVersion, updatedAt;
  factory DailyDoc.fromMap(JsonMap m) {
    if (m['schema_version'] != 2) {
      throw FormatException(
          'Unsupported daily schema_version: ${m['schema_version']}');
    }
    final raw = readMap(m['by_key']);
    final states = readMap(m['tasks_by_state']);
    final date = readString(m['date']) ?? '';
    if (date.isNotEmpty &&
        (DateTime.tryParse(date)?.toIso8601String().substring(0, 10) != date)) {
      throw const FormatException('Expected a valid calendar date.');
    }
    return DailyDoc(
        date: date,
        totals: TokenBreakdown.fromMap(readMap(m['totals'])),
        byKey:
            raw.map((k, v) => MapEntry(k, TokenBreakdown.fromMap(readMap(v)))),
        tasksByState: states.map((k, v) => MapEntry(k, readCounter(v) ?? 0)),
        pricingVersion: readString(m['pricing_version']),
        updatedAt: readString(m['updated_at']));
  }
}
