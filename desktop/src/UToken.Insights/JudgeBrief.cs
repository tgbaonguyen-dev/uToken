using System.Globalization;
using UToken.Core.Aggregation;
using UToken.Core.Efficiency;

namespace UToken.Insights;

public sealed record MetricEntry(string Label, string Value, double? Raw);
public sealed record JudgeBrief(string PeriodStart, string PeriodEnd, string PricingVersion, IReadOnlyDictionary<string, MetricEntry> Catalog, int Chats, bool HasEvents);

public static class JudgeBriefBuilder
{
    public static JudgeBrief Build(EfficiencyDoc efficiency, IReadOnlyList<DailyDoc> daily)
    {
        if (efficiency is null) throw new ArgumentNullException(nameof(efficiency));
        if (daily is null) throw new ArgumentNullException(nameof(daily));
        var entries = new Dictionary<string, MetricEntry>(StringComparer.Ordinal);
        long input = 0, cached = 0, output = 0, cost = 0; int chats = 0, requests = 0, errors = 0;
        foreach (var d in daily)
        {
            var t = d.Totals; input += t.Input; cached += t.Cached; output += t.Output; cost += t.CostMicro ?? 0;
            chats += t.Chats; requests += t.Requests; errors += t.ErrorRequests;
        }
        Add(entries, "usage.chats", "Chats", chats, chats.ToString(CultureInfo.InvariantCulture));
        Add(entries, "usage.requests", "Requests", requests, requests.ToString(CultureInfo.InvariantCulture));
        Add(entries, "usage.input_tokens", "Input tokens", input, input.ToString("N0", CultureInfo.InvariantCulture));
        Add(entries, "usage.cached_tokens", "Cached tokens", cached, cached.ToString("N0", CultureInfo.InvariantCulture));
        Add(entries, "usage.output_tokens", "Output tokens", output, output.ToString("N0", CultureInfo.InvariantCulture));
        Add(entries, "usage.cost_micro", "Monthly cost", cost, (cost / 1_000_000d).ToString("0.00", CultureInfo.InvariantCulture) + " USD");
        Add(entries, "usage.cache_hit_rate", "Cache hit rate", input == 0 ? null : (double)cached / input, input == 0 ? "N/A" : ((double)cached / input).ToString("P1", CultureInfo.InvariantCulture));
        Add(entries, "usage.error_rate", "Error request rate", requests == 0 ? null : (double)errors / requests, requests == 0 ? "N/A" : ((double)errors / requests).ToString("P1", CultureInfo.InvariantCulture));
        foreach (var p in efficiency.ProcessMetrics) Add(entries, "process." + p.Metric + (p.Provider is null ? "" : "." + p.Provider), p.Label, p.Value, p.Value?.ToString("0.###", CultureInfo.InvariantCulture) ?? "N/A");
        foreach (var s in efficiency.Setups) Add(entries, $"setup.{s.Provider}.{s.Model}.sr", "Success rate", s.Sr, s.Sr?.ToString("P1", CultureInfo.InvariantCulture) ?? "N/A");
        return new(efficiency.PeriodStart, efficiency.PeriodEnd, efficiency.PricingVersion, entries, chats, requests > 0);
    }

    private static void Add(IDictionary<string, MetricEntry> map, string id, string label, double? raw, string value) => map[id] = new(label, value, raw);
    private static void Add(IDictionary<string, MetricEntry> map, string id, string label, long raw, string value) => map[id] = new(label, value, raw);
}
