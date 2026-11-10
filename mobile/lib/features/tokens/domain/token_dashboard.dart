import '../../../core/models/daily_doc.dart';

enum TokenPeriod { day, week, month, total }

class TokenMetric {
  const TokenMetric({required this.label, required this.tokens});
  final String label;
  final int tokens;
  double shareOf(int total) => total <= 0 ? 0 : tokens / total;
}

class DailyTokenPoint {
  const DailyTokenPoint({required this.date, required this.tokens});
  final String date;
  final int tokens;
}

class TokenDashboard {
  const TokenDashboard({
    required this.totalTokens,
    required this.cachedTokens,
    required this.costMicro,
    required this.providers,
    required this.models,
    required this.daily,
  });

  final int totalTokens;
  final int cachedTokens;
  final int? costMicro;
  final List<TokenMetric> providers;
  final List<TokenMetric> models;
  final List<DailyTokenPoint> daily;

  factory TokenDashboard.fromDailyDocs(List<DailyDoc> docs) {
    var total = 0;
    var cached = 0;
    var cost = 0;
    var hasAllCosts = true;
    final providers = <String, int>{};
    final models = <String, int>{};
    final daily = <DailyTokenPoint>[];

    for (final doc in docs) {
      total += doc.totals.total;
      cached += doc.totals.cached;
      final dayCost = doc.totals.costMicro;
      if (dayCost == null) {
        hasAllCosts = false;
      } else {
        cost += dayCost;
      }
      daily.add(DailyTokenPoint(date: doc.date, tokens: doc.totals.total));

      for (final entry in doc.byKey.entries) {
        final parts = entry.key.split('|');
        final provider = parts.first;
        final model = parts.length > 1 ? parts[1] : entry.key;
        providers.update(provider, (value) => value + entry.value.total,
            ifAbsent: () => entry.value.total);
        models.update(model, (value) => value + entry.value.total,
            ifAbsent: () => entry.value.total);
      }
    }

    List<TokenMetric> ranked(Map<String, int> values) {
      final result = values.entries
          .map((entry) => TokenMetric(label: entry.key, tokens: entry.value))
          .toList()
        ..sort((a, b) => b.tokens.compareTo(a.tokens));
      return result;
    }

    return TokenDashboard(
      totalTokens: total,
      cachedTokens: cached,
      costMicro: hasAllCosts ? cost : null,
      providers: ranked(providers),
      models: ranked(models),
      daily: daily,
    );
  }

  static List<DailyDoc> filterPeriod(
    List<DailyDoc> docs,
    TokenPeriod period,
    DateTime now,
  ) {
    final days = switch (period) {
      TokenPeriod.day => 1,
      TokenPeriod.week => 7,
      TokenPeriod.month => 30,
      TokenPeriod.total => 36500,
    };
    final cutoff = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1))
        .toIso8601String()
        .substring(0, 10);
    final filtered = docs
        .where((doc) => doc.date.compareTo(cutoff) >= 0)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return filtered;
  }
}
