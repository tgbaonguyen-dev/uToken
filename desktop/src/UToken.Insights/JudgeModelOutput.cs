using System.Text.Json.Serialization;

namespace UToken.Insights;

/// <summary>Structured fields returned by an LLM; transport metadata is added by the service.</summary>
public sealed record JudgeModelOutput(
    [property: JsonPropertyName("score")] int? Score,
    [property: JsonPropertyName("grade")] string? Grade,
    [property: JsonPropertyName("headline")] string Headline,
    [property: JsonPropertyName("dimensions")] IReadOnlyList<JudgeDimensionOutput> Dimensions,
    [property: JsonPropertyName("insights")] IReadOnlyList<JudgeInsightOutput> Insights);

public sealed record JudgeDimensionOutput([property: JsonPropertyName("id")] string Id, [property: JsonPropertyName("score")] int? Score, [property: JsonPropertyName("comment")] string Comment);
public sealed record JudgeEvidenceOutput([property: JsonPropertyName("metric")] string Metric);
public sealed record JudgeInsightOutput([property: JsonPropertyName("id")] string Id, [property: JsonPropertyName("title")] string Title, [property: JsonPropertyName("severity")] string Severity, [property: JsonPropertyName("category")] string Category, [property: JsonPropertyName("provider")] string? Provider, [property: JsonPropertyName("evidence")] IReadOnlyList<JudgeEvidenceOutput> Evidence, [property: JsonPropertyName("recommendation")] string Recommendation, [property: JsonPropertyName("estimated_impact")] string? EstimatedImpact, [property: JsonPropertyName("estimated_saving_usd_per_month")] double? EstimatedSavingUsdPerMonth, [property: JsonPropertyName("confidence")] string Confidence);

public static class JudgeOutputMapper
{
    public static InsightDoc Map(JudgeModelOutput output, JudgeBrief brief, string provider, string model, DateTimeOffset now)
    {
        var dimensions = output.Dimensions.Select(d => new InsightDimension(d.Id, d.Score, d.Comment)).ToArray();
        var insights = output.Insights.Select(i => new InsightItem(i.Id, i.Title, i.Severity, i.Category, i.Provider, i.Evidence.Select(e => new InsightEvidence(e.Metric, "", "")).ToArray(), i.Recommendation, i.EstimatedImpact, i.EstimatedSavingUsdPerMonth is null ? null : (long)Math.Round(i.EstimatedSavingUsdPerMonth.Value * 1_000_000d), i.Confidence)).ToArray();
        var raw = new InsightDoc("ok", now.UtcDateTime.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'"), brief.PeriodStart, brief.PeriodEnd, provider, model, brief.PricingVersion, output.Score, output.Grade, output.Headline, dimensions, insights, null);
        return InsightValidator.Validate(raw, brief, now, model, brief.MonthlyCostMicro);
    }
}
