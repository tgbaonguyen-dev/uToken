import 'local_prefs.dart';
import '../models/daily_doc.dart';
import '../i18n/tr.dart';

/// Time windows offered by the Tokens and Analytics period selector.
/// [custom] uses [customUsageRange]. Not in SRS FR-DASH-001's list
/// (day/week/month/total); added at the user's request.
enum UsagePeriod { day, week, month, total, custom }

/// Inclusive local-date range for [UsagePeriod.custom].
class UsageRange {
  UsageRange(DateTime from, DateTime to)
      : from = DateTime(from.year, from.month, from.day),
        to = DateTime(to.year, to.month, to.day);
  final DateTime from, to;

  int get days => to.difference(from).inDays + 1;

  /// "01 Nov – 11 Nov" / "01/11 – 11/11".
  String get label => from == to
      ? shortDate(dayKey(from))
      : '${shortDate(dayKey(from))} – ${shortDate(dayKey(to))}';

  /// Parses "2026-11-01".."2026-11-11"; null when missing or reversed.
  static UsageRange? tryParse(String? from, String? to) {
    final a = from == null ? null : DateTime.tryParse(from);
    final b = to == null ? null : DateTime.tryParse(to);
    if (a == null || b == null || b.isBefore(a)) return null;
    return UsageRange(a, b);
  }
}

/// Range last picked with "Custom", shared across tabs like the period.
UsageRange? customUsageRange;

/// Period name for captions: the dates themselves for a custom range.
String periodText(UsagePeriod period) =>
    period == UsagePeriod.custom && customUsageRange != null
        ? customUsageRange!.label
        : period.label;

extension UsagePeriodLabel on UsagePeriod {
  String get label => switch (this) {
        UsagePeriod.day => tr('Day'),
        UsagePeriod.week => tr('Week'),
        UsagePeriod.month => tr('Month'),
        UsagePeriod.total => tr('Total'),
        UsagePeriod.custom => tr('Custom'),
      };

  static UsagePeriod parse(String? value) => UsagePeriod.values.firstWhere(
      (p) => p.label.toLowerCase() == value?.toLowerCase(),
      orElse: () => UsagePeriod.month);
}

String dayKey(DateTime value) => DateTime(value.year, value.month, value.day)
    .toIso8601String()
    .substring(0, 10);

/// Keeps documents inside [period] ending [now]: today, the last 7 days,
/// the current calendar month (FR-DASH-001) or everything.
List<DailyDoc> filterPeriod(
    List<DailyDoc> docs, UsagePeriod period, DateTime now) =>
    switch (period) {
      UsagePeriod.day => filterLastDays(docs, 1, now),
      UsagePeriod.week => filterLastDays(docs, 7, now),
      UsagePeriod.month => filterMonth(docs, now)
          .where((d) => d.date.compareTo(dayKey(now)) <= 0)
          .toList(),
      UsagePeriod.total => docs,
      UsagePeriod.custom => filterRange(docs, customUsageRange, now),
    };

/// Documents dated inside [range] (inclusive). Without a range this falls
/// back to the current month, so a stale "Custom" link still shows data.
List<DailyDoc> filterRange(List<DailyDoc> docs, UsageRange? range, DateTime now) {
  if (range == null) return filterPeriod(docs, UsagePeriod.month, now);
  final from = dayKey(range.from), to = dayKey(range.to);
  return docs
      .where((d) => d.date.compareTo(from) >= 0 && d.date.compareTo(to) <= 0)
      .toList();
}

List<DailyDoc> filterLastDays(List<DailyDoc> docs, int days, DateTime now,
    {int offsetDays = 0}) {
  final end = DateTime(now.year, now.month, now.day - offsetDays);
  final start = DateTime(end.year, end.month, end.day - days + 1);
  final from = dayKey(start), to = dayKey(end);
  return docs
      .where((d) => d.date.compareTo(from) >= 0 && d.date.compareTo(to) <= 0)
      .toList();
}

List<DailyDoc> filterMonth(List<DailyDoc> docs, DateTime month) {
  final prefix = dayKey(month).substring(0, 7);
  return docs.where((d) => d.date.startsWith(prefix)).toList();
}

/// Human provider names for collector ids.
String providerName(String id) => switch (id) {
      'codex' => tr('Codex'),
      'claude_code' => tr('Claude'),
      'antigravity' => tr('Gemini'),
      _ => id,
    };

/// One by_key entry split into provider, model and project.
class UsageKey {
  UsageKey.parse(String key) : this._(key.split('|'));
  UsageKey._(List<String> p)
      : provider = p.isNotEmpty ? p[0] : '',
        model = p.length > 1 ? p[1] : (p.isNotEmpty ? p[0] : ''),
        project = p.length > 2 && p[2] != 'none' ? p[2] : null;
  final String provider, model;
  final String? project;
}

/// Mutable sum of token counters.
class UsageTotals {
  int input = 0, cached = 0, cacheWrite = 0, output = 0, thinking = 0;
  int chats = 0, requests = 0, errorRequests = 0;
  int cost = 0;
  bool costKnown = true;
  final Set<String> models = {};
  final Set<String> providers = {};

  String get provider => providers.isEmpty ? '' : providers.first;

  int get tokens => input + output;
  double? get costUsd => costKnown ? cost / 1e6 : null;

  void add(TokenBreakdown b) {
    input += b.input;
    cached += b.cached;
    cacheWrite += b.cacheWrite;
    output += b.output;
    thinking += b.thinking ?? 0;
    chats += b.chats;
    requests += b.requests;
    errorRequests += b.errorRequests;
    if (b.costMicro == null) {
      costKnown = false;
    } else {
      cost += b.costMicro!;
    }
  }
}

UsageTotals sumTotals(Iterable<DailyDoc> docs) {
  final t = UsageTotals();
  var any = false;
  for (final d in docs) {
    t.add(d.totals);
    any = true;
  }
  if (!any) t.costKnown = true;
  return t;
}

/// Groups by_key entries with [keyOf], sorted by tokens descending.
List<MapEntry<String, UsageTotals>> groupBy(
    Iterable<DailyDoc> docs, String? Function(UsageKey key) keyOf) {
  final groups = <String, UsageTotals>{};
  for (final d in docs) {
    for (final e in d.byKey.entries) {
      final key = UsageKey.parse(e.key);
      final group = keyOf(key);
      if (group == null) continue;
      (groups[group] ??= UsageTotals())
        ..add(e.value)
        ..models.add(key.model)
        ..providers.add(key.provider);
    }
  }
  return groups.entries.toList()
    ..sort((a, b) => b.value.tokens.compareTo(a.value.tokens));
}

List<MapEntry<String, UsageTotals>> byProvider(Iterable<DailyDoc> docs) =>
    groupBy(docs, (k) => k.provider);
List<MapEntry<String, UsageTotals>> byModel(Iterable<DailyDoc> docs) =>
    groupBy(docs, (k) => k.model);
List<MapEntry<String, UsageTotals>> byProject(Iterable<DailyDoc> docs) =>
    groupBy(docs, (k) => k.project ?? 'Unassigned');

/// Chat outcome counts from tasks_by_state (FR-ANLY-003 §C).
class Outcomes {
  /// [success] and [failure] include likely results; the verified counts do not.
  int success = 0, failure = 0, undetermined = 0;
  int verifiedSuccess = 0, verifiedFailure = 0;
  int get decided => success + failure;
  int get verified => verifiedSuccess + verifiedFailure;

  /// Main success rate: verified_success ÷ (verified_success + verified_failure).
  double? get successRate => verified == 0 ? null : verifiedSuccess / verified;

  /// Secondary rate that also counts likely results, to check a conclusion
  /// holds when the criterion is relaxed.
  double? get successRateInclLikely => decided == 0 ? null : success / decided;
}

Outcomes sumOutcomes(Iterable<DailyDoc> docs) {
  final o = Outcomes();
  for (final d in docs) {
    final s = d.tasksByState;
    o.verifiedSuccess += s['verified_success'] ?? 0;
    o.verifiedFailure += s['verified_failure'] ?? 0;
    o.success += (s['verified_success'] ?? 0) + (s['likely_success'] ?? 0);
    o.failure += (s['verified_failure'] ?? 0) + (s['likely_failure'] ?? 0);
    o.undetermined += s['undetermined'] ?? 0;
  }
  return o;
}

double share(int part, int whole) => whole == 0 ? 0 : part / whole;

String pct(double value, {int digits = 1}) =>
    '${(value * 100).toStringAsFixed(digits)}%';

/// US dollars with thousands separators: \$5,000.00, -\$1,234.5678.
String usd(double? value, {int digits = 2}) {
  if (value == null) return '—';
  final fixed = value.abs().toStringAsFixed(digits);
  final dot = fixed.indexOf('.');
  final whole = dot < 0 ? fixed : fixed.substring(0, dot);
  final rest = dot < 0 ? '' : fixed.substring(dot);
  final grouped =
      whole.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '${value < 0 ? '-' : ''}\$$grouped$rest';
}

/// Cost with 4 decimals below \$1 and 2 decimals above.
String usdSmart(double? value) =>
    usd(value, digits: value != null && value.abs() < 1 ? 4 : 2);

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String monthName(int month) =>
    LocalPrefs.instance.vietnamese ? 'Tháng $month' : _months[month - 1];

/// "Nov 2026" / "Tháng 11, 2026".
String monthYear(DateTime d) => LocalPrefs.instance.vietnamese
    ? 'Tháng ${d.month}, ${d.year}'
    : '${_months[d.month - 1]} ${d.year}';

/// "01 Nov" from "2026-11-01".
String shortDate(String key) {
  final d = DateTime.tryParse(key);
  if (d == null) return key;
  final day = d.day.toString().padLeft(2, '0');
  return LocalPrefs.instance.vietnamese
      ? '$day/${d.month.toString().padLeft(2, '0')}'
      : '$day ${_months[d.month - 1]}';
}

String relativeTime(DateTime value, DateTime now) {
  final minutes = now.difference(value).inMinutes;
  if (minutes < 1) return tr('just now');
  if (minutes < 60) return tr('{n}m ago', {'n': minutes});
  final hours = minutes ~/ 60;
  if (hours < 24) return tr('{n}h ago', {'n': hours});
  return tr('{n}d ago', {'n': hours ~/ 24});
}
