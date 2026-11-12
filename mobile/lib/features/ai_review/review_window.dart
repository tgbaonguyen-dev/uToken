import 'dart:convert';

import '../../core/data/usage_aggregates.dart';
import '../../core/models/daily_doc.dart';

enum ReviewScope { sinceLastReview, last30Days }

class ReviewWindowException implements Exception {
  const ReviewWindowException(this.code);
  final String code;
}

/// Baseline of synchronized counters, not a claim about individual event times.
class ReviewCheckpoint {
  ReviewCheckpoint(this.through, Iterable<DailyDoc> documents)
      : documents = [
          for (final doc in documents)
            if (doc.date.compareTo(dayKey(through.toLocal())) <= 0)
              DailyDoc.fromMap(_dailyMap(doc))
        ];
  final DateTime through;
  final List<DailyDoc> documents;

  String encode() => jsonEncode({
        'version': 1,
        'through': through.toUtc().toIso8601String(),
        'documents': documents.map(_dailyMap).toList(),
      });

  factory ReviewCheckpoint.decode(String value) {
    final map = readMap(jsonDecode(value));
    if (map['version'] != 1) {
      throw const FormatException('Unsupported review checkpoint.');
    }
    return ReviewCheckpoint(
        DateTime.parse(readString(map['through'])!),
        readList(map['documents'])
            .map((value) => DailyDoc.fromMap(readMap(value))));
  }
}

Map<String, dynamic> _bucketMap(TokenBreakdown b) => {
      'input': b.input,
      'cached': b.cached,
      'cache_write': b.cacheWrite,
      'output': b.output,
      'thinking': b.thinking,
      'cost_micro': b.costMicro,
      'side_tokens': b.sideTokens,
      'chats': b.chats,
      'requests': b.requests,
      'error_requests': b.errorRequests,
      'side_cost_micro': b.sideCostMicro,
      'context_growth_sum': b.contextGrowthSum,
      'context_growth_count': b.contextGrowthCount,
      'duration_sum_ms': b.durationSumMs,
      'duration_count': b.durationCount,
    };

Map<String, dynamic> _dailyMap(DailyDoc d) => {
      'schema_version': 2,
      'date': d.date,
      'totals': _bucketMap(d.totals),
      'by_key': d.byKey.map((key, bucket) => MapEntry(key, _bucketMap(bucket))),
      'tasks_by_state': d.tasksByState,
      'pricing_version': d.pricingVersion,
      'updated_at': d.updatedAt,
    };

TokenBreakdown _subtract(TokenBreakdown current, TokenBreakdown? previous) {
  final values = _bucketMap(current);
  final before = previous == null ? <String, dynamic>{} : _bucketMap(previous);
  for (final field in values.keys.toList()) {
    final now = values[field] as num?;
    final old = before[field] as num?;
    if (now == null || (previous != null && old == null)) {
      values[field] = null;
      continue;
    }
    final delta = now - (old ?? 0);
    // Repricing may change historical costs; do not present it as new spend.
    if (delta < 0 &&
        const {'cost_micro', 'side_cost_micro', 'context_growth_sum'}
            .contains(field)) {
      values[field] = null;
    } else if (delta < 0) {
      throw const ReviewWindowException('review_data_changed');
    } else {
      values[field] = delta;
    }
  }
  return TokenBreakdown.fromMap(values);
}

/// Includes same-day additions and delayed uploads, without replaying the baseline.
/// Exact occurrence-time intervals require event-level data, which daily docs lack.
List<DailyDoc> newSynchronizedUsage(
    List<DailyDoc> current, ReviewCheckpoint checkpoint, DateTime through) {
  if (checkpoint.through.isAfter(through)) {
    throw const ReviewWindowException('review_data_changed');
  }
  final previous = {for (final doc in checkpoint.documents) doc.date: doc};
  final result = <DailyDoc>[];
  for (final doc in current
      .where((d) => d.date.compareTo(dayKey(through.toLocal())) <= 0)) {
    final old = previous[doc.date];
    final totals = _subtract(doc.totals, old?.totals);
    if (totals.total == 0 && totals.requests == 0) continue;
    final byKey = {
      for (final entry in doc.byKey.entries)
        entry.key: _subtract(entry.value, old?.byKey[entry.key])
    };
    if (byKey.isNotEmpty &&
        byKey.values.fold<int>(0, (sum, b) => sum + b.total) != totals.total) {
      throw const ReviewWindowException('review_data_changed');
    }
    result.add(DailyDoc(
        date: doc.date,
        totals: totals,
        byKey: byKey,
        // Outcome reclassification is not an additive event counter.
        tasksByState: const {},
        pricingVersion: doc.pricingVersion,
        updatedAt: doc.updatedAt));
  }
  return result;
}
