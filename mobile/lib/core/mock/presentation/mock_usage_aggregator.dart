/// Pure presentation transformations for the Figma UI preview fixtures.
///
/// This file deliberately has no Firebase, database, repository, or platform
/// dependencies. It only shapes the local JSON fixtures for UI presentation.
class MockUsageAggregator {
  const MockUsageAggregator._();

  static List<Map<String, dynamic>> rankedModels(Map periodData) {
    final rows = (periodData['models'] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList()
      ..sort((a, b) => (b['tokens'] as num).compareTo(a['tokens'] as num));
    return rows;
  }

  static List<int> activityLevels(List records) {
    final values = records.map<num>((record) {
      if (record is num) return record;
      if (record is Map) {
        final value = record['tokens'] ?? record['totalTokens'] ?? 0;
        return value is num ? value : num.tryParse(value.toString()) ?? 0;
      }
      return 0;
    }).toList(growable: false);
    final maximum = values.fold<num>(
        0, (current, value) => value > current ? value : current);
    if (maximum <= 0) return List<int>.filled(values.length, 0);
    return values
        .map((value) =>
            value <= 0 ? 0 : (value / maximum * 4).ceil().clamp(1, 4).toInt())
        .toList(growable: false);
  }

  static List<Map<String, dynamic>> sortedRows(
    List source, {
    required String key,
    required bool ascending,
  }) {
    final rows =
        source.map((row) => Map<String, dynamic>.from(row as Map)).toList();
    rows.sort((a, b) {
      final left = a[key], right = b[key];
      return left is num
          ? left.compareTo(right as num)
          : left.toString().compareTo(right.toString());
    });
    if (!ascending) return rows.reversed.toList(growable: false);
    return rows;
  }

  /// Produces sample export records from the same preview fixtures.
  /// Provider split and cost are estimates derived from the monthly fixture.
  static List<Map<String, dynamic>> exportRecords(
    List dailyRows,
    Map month,
  ) {
    return dailyRows.map((day) {
      final total = day['tokens'] as num;
      final shares = month['shares'] as List;
      final gemini = (total * (shares[0] as num) / 100).round();
      final codex = (total * (shares[1] as num) / 100).round();
      final cents = (total /
              (month['totalTokens'] as num) *
              (month['estimatedCost'] as num) *
              100)
          .round();
      return <String, dynamic>{
        'date': day['date'],
        'tokens': total,
        'chats': day['chats'],
        'estimated_cost_usd': cents / 100,
        'gemini_tokens': gemini,
        'codex_tokens': codex,
        'claude_tokens': total - gemini - codex,
      };
    }).toList(growable: false);
  }
}
