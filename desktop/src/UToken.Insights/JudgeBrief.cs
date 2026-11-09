using System.Globalization;
using UToken.Core.Aggregation;
using UToken.Core.Efficiency;

namespace UToken.Insights;

/// <summary>A metric included in the judge brief.</summary>
public sealed record MetricEntry(string Label, string Value, double? Raw);

/// <summary>The aggregated data supplied to a judge model.</summary>
public sealed record JudgeBrief(
    string PeriodStart,
    string PeriodEnd,
    string PricingVersion,
    IReadOnlyDictionary<string, MetricEntry> Catalog,
    int Chats,
    bool HasEvents,
    long MonthlyCostMicro = 0);

/// <summary>Builds a judge brief from usage and efficiency documents.</summary>
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
            var totals = d.Totals;
            input += totals.Input;
            cached += totals.Cached;
            output += totals.Output;
            cost += totals.CostMicro ?? 0;
            chats += totals.Chats;
            requests += totals.Requests;
            errors += totals.ErrorRequests;
        }
        Add(entries, "usage.chats", "Chats", chats, chats.ToString(CultureInfo.InvariantCulture));
        Add(entries, "usage.requests", "Requests", requests,
            requests.ToString(CultureInfo.InvariantCulture));
        Add(entries, "usage.input_tokens", "Input tokens", input,
            input.ToString("N0", CultureInfo.InvariantCulture));
        Add(entries, "usage.cached_tokens", "Cached tokens", cached,
            cached.ToString("N0", CultureInfo.InvariantCulture));
        Add(entries, "usage.output_tokens", "Output tokens", output,
            output.ToString("N0", CultureInfo.InvariantCulture));
        Add(entries, "usage.cost_micro", "Monthly cost", cost,
            (cost / 1_000_000d).ToString("0.00", CultureInfo.InvariantCulture) + " USD");
        Add(entries, "usage.cache_hit_rate", "Cache hit rate",
            input == 0 ? null : (double)cached / input,
            input == 0 ? "N/A" : ((double)cached / input)
                .ToString("P1", CultureInfo.InvariantCulture));
        Add(entries, "usage.error_rate", "Error request rate",
            requests == 0 ? null : (double)errors / requests,
            requests == 0 ? "N/A" : ((double)errors / requests)
                .ToString("P1", CultureInfo.InvariantCulture));
        foreach (var p in efficiency.ProcessMetrics)
        {
            var id = "process." + p.Metric + (p.Provider is null ? "" : "." + p.Provider);
            Add(entries, id, MetricLabel(p.Metric), p.Value,
                p.Value?.ToString("0.###", CultureInfo.InvariantCulture) ?? "N/A");
        }
        foreach (var s in efficiency.Setups)
        {
            var prefix = $"setup.{s.Provider}.{s.Model}";
            Add(entries, prefix + ".sr", "Success rate", s.Sr,
                s.Sr?.ToString("P1", CultureInfo.InvariantCulture) ?? "N/A");
            Add(entries, prefix + ".cpst_micro", "Cost per successful task", s.CpstMicro,
                s.CpstMicro?.ToString(CultureInfo.InvariantCulture) ?? "N/A");
            Add(entries, prefix + ".n_tasks", "Tasks", s.NTasks,
                s.NTasks.ToString(CultureInfo.InvariantCulture));
            Add(entries, prefix + ".verdict", "Verdict", (string?)null, s.Verdict);
        }
        var byModel = daily
            .SelectMany(d => d.ByKey)
            .GroupBy(x =>
            {
                var parts = x.Key.Split('|');
                return (Provider: parts[0], Model: parts[1]);
            });
        foreach (var group in byModel)
        {
            var bucket = group.Select(x => x.Value).ToArray();
            var modelPrefix = $"usage.{group.Key.Provider}.{group.Key.Model}";
            var modelInput = bucket.Sum(x => x.Input);
            var modelCached = bucket.Sum(x => x.Cached);
            var totalTokens = bucket.Sum(x => x.TotalTokens);
            Add(entries, modelPrefix + ".tokens", "Tokens", totalTokens,
                totalTokens.ToString("N0", CultureInfo.InvariantCulture));
            var modelCost = bucket.Sum(x => x.CostMicro ?? 0);
            Add(entries, modelPrefix + ".cost_micro", "Cost", modelCost,
                (modelCost / 1_000_000d).ToString("0.00", CultureInfo.InvariantCulture) + " USD");
            Add(entries, modelPrefix + ".cache_rate", "Cache hit rate",
                modelInput == 0 ? null : (double)modelCached / modelInput,
                modelInput == 0 ? "N/A" : ((double)modelCached / modelInput)
                    .ToString("P1", CultureInfo.InvariantCulture));
            var thinking = bucket.Sum(x => x.Thinking ?? 0);
            var outputTokens = bucket.Sum(x => x.Output);
            Add(entries, modelPrefix + ".thinking_share", "Thinking share",
                outputTokens == 0 ? null : (double)thinking / outputTokens,
                outputTokens == 0 ? "N/A" : ((double)thinking / outputTokens)
                    .ToString("P1", CultureInfo.InvariantCulture));
        }
        return new(
            efficiency.PeriodStart,
            efficiency.PeriodEnd,
            efficiency.PricingVersion,
            entries,
            chats,
            requests > 0,
            cost);
    }

    private static void Add(
        IDictionary<string, MetricEntry> map,
        string id,
        string label,
        double? raw,
        string value) => map[id] = new(label, value, raw);

    private static void Add(
        IDictionary<string, MetricEntry> map,
        string id,
        string label,
        long raw,
        string value) => map[id] = new(label, value, raw);

    private static void Add(
        IDictionary<string, MetricEntry> map,
        string id,
        string label,
        int raw,
        string value) => map[id] = new(label, value, raw);

    private static void Add(
        IDictionary<string, MetricEntry> map,
        string id,
        string label,
        string? raw,
        string value) => map[id] = new(label, value, null);
    private static string MetricLabel(string metric) => metric switch
    {
        "cache_hit_rate" => "Cache hit rate",
        "context_growth" => "Context growth",
        "tokens_per_turn_vs_median" => "Tokens per turn vs median",
        "cost_tail" => "Cost tail",
        "error_rate" => "Error rate",
        _ => metric.Replace('_', ' '),
    };
}
