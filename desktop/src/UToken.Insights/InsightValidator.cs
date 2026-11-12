namespace UToken.Insights;

/// <summary>Normalizes and validates judge output.</summary>
public static class InsightValidator
{
    private static readonly HashSet<string> Categories =
    ["cache", "context", "reasoning", "reliability", "outcomes", "hidden_cost"];

    public static InsightDoc Validate(
        InsightDoc candidate,
        JudgeBrief brief,
        DateTimeOffset now,
        string model,
        long monthlyCostMicro)
    {
        if (candidate is null) throw new ArgumentNullException(nameof(candidate));
        if (brief is null) throw new ArgumentNullException(nameof(brief));
        var dimensions = candidate.Dimensions
            .Where(d => Categories.Contains(d.Id))
            .GroupBy(d => d.Id)
            .Select(g => g.First() with { Score = Clamp(g.First().Score) })
            .ToArray();
        var insights = candidate.Insights.Select(i =>
        {
            var evidence = i.Evidence
                .Where(e => brief.Catalog.TryGetValue(e.Metric, out _))
                .Select(e =>
                {
                    var metric = brief.Catalog[e.Metric];
                    return e with { Label = metric.Label, Value = metric.Value };
                })
                .ToArray();
            long? saving = i.EstimatedSavingMicroPerMonth is null
                ? null
                : Math.Clamp(i.EstimatedSavingMicroPerMonth.Value, 0, monthlyCostMicro);
            var provider = i.Provider is null
                or "codex"
                or "claude_code"
                or "antigravity"
                ? i.Provider
                : null;
            return i with
            {
                Provider = provider,
                Evidence = evidence,
                EstimatedSavingMicroPerMonth = saving,
                Why = (i.Why ?? "").Trim(),
                Steps = (i.Steps ?? []).Select(s => s.Trim()).Where(s => s.Length > 0).Take(4).ToArray(),
            };
        })
        .Where(i => i.Evidence.Count > 0)
        .Where(i => Categories.Contains(i.Category))
        .Where(i => Severities.Contains(i.Severity))
        .Where(i => Confidences.Contains(i.Confidence))
        .GroupBy(i => i.Id)
        .Select(g => g.First())
        .Take(5)
        .ToArray();
        var grade = candidate.Grade is "A" or "B" or "C" or "D" ? candidate.Grade : null;
        return candidate with
        {
            GeneratedAt = now.UtcDateTime.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'"),
            Model = model,
            Score = Clamp(candidate.Score),
            Grade = grade,
            Dimensions = dimensions,
            Insights = insights,
        };
    }
    private static readonly HashSet<string> Severities = ["high", "medium", "low"];
    private static readonly HashSet<string> Confidences = ["high", "medium", "low"];
    private static int? Clamp(int? value) => value is null ? null : Math.Clamp(value.Value, 0, 100);
}
