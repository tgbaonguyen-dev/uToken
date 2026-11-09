namespace UToken.Insights;

public static class InsightValidator
{
    private static readonly HashSet<string> Categories = ["cache", "context", "reasoning", "reliability", "outcomes", "hidden_cost"];
    public static InsightDoc Validate(InsightDoc candidate, JudgeBrief brief, DateTimeOffset now, string model, long monthlyCostMicro)
    {
        if (candidate is null) throw new ArgumentNullException(nameof(candidate));
        if (brief is null) throw new ArgumentNullException(nameof(brief));
        var dimensions = candidate.Dimensions.Where(d => Categories.Contains(d.Id)).Select(d => d with { Score = Clamp(d.Score) }).ToArray();
        var insights = candidate.Insights.Select(i =>
        {
            var evidence = i.Evidence.Where(e => brief.Catalog.TryGetValue(e.Metric, out _)).Select(e => { var m = brief.Catalog[e.Metric]; return e with { Label = m.Label, Value = m.Value }; }).ToArray();
            long? saving = i.EstimatedSavingMicroPerMonth is null ? null : Math.Clamp(i.EstimatedSavingMicroPerMonth.Value, 0, monthlyCostMicro);
            return i with { Evidence = evidence, EstimatedSavingMicroPerMonth = saving };
        }).Where(i => i.Evidence.Count > 0 && Categories.Contains(i.Category)).Take(5).ToArray();
        return candidate with { GeneratedAt = now.UtcDateTime.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'"), Model = model, Score = Clamp(candidate.Score), Dimensions = dimensions, Insights = insights };
    }
    private static int? Clamp(int? value) => value is null ? null : Math.Clamp(value.Value, 0, 100);
}
