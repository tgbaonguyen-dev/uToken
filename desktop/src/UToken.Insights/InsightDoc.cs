using System.Text.Json.Serialization;

namespace UToken.Insights;

/// <summary>A scored dimension in the generated insight document.</summary>
public sealed record InsightDimension(
    [property: JsonPropertyName("id")] string Id,
    [property: JsonPropertyName("score")] int? Score,
    [property: JsonPropertyName("comment")] string Comment);

/// <summary>Evidence supporting an insight.</summary>
public sealed record InsightEvidence(
    [property: JsonPropertyName("metric")] string Metric,
    [property: JsonPropertyName("label")] string Label,
    [property: JsonPropertyName("value")] string Value);

/// <summary>An actionable insight in the generated document.</summary>
public sealed record InsightItem(
    [property: JsonPropertyName("id")] string Id,
    [property: JsonPropertyName("title")] string Title,
    [property: JsonPropertyName("severity")] string Severity,
    [property: JsonPropertyName("category")] string Category,
    [property: JsonPropertyName("provider")] string? Provider,
    [property: JsonPropertyName("evidence")] IReadOnlyList<InsightEvidence> Evidence,
    [property: JsonPropertyName("recommendation")] string Recommendation,
    [property: JsonPropertyName("estimated_impact")] string? EstimatedImpact,
    [property: JsonPropertyName("estimated_saving_micro_per_month")]
    long? EstimatedSavingMicroPerMonth,
    [property: JsonPropertyName("confidence")] string Confidence,
    /// <summary>Why this pattern costs tokens, in one or two sentences.</summary>
    [property: JsonPropertyName("why")] string Why = "",
    /// <summary>Concrete actions, in order (at most 4).</summary>
    [property: JsonPropertyName("steps")] IReadOnlyList<string>? Steps = null);

/// <summary>The validated output document returned by a judge.</summary>
public sealed record InsightDoc(
    [property: JsonPropertyName("status")] string Status,
    [property: JsonPropertyName("generated_at")] string GeneratedAt,
    [property: JsonPropertyName("period_start")] string PeriodStart,
    [property: JsonPropertyName("period_end")] string PeriodEnd,
    [property: JsonPropertyName("provider")] string Provider,
    [property: JsonPropertyName("model")] string Model,
    [property: JsonPropertyName("pricing_version")] string PricingVersion,
    [property: JsonPropertyName("score")] int? Score,
    [property: JsonPropertyName("grade")] string? Grade,
    [property: JsonPropertyName("headline")] string Headline,
    [property: JsonPropertyName("dimensions")] IReadOnlyList<InsightDimension> Dimensions,
    [property: JsonPropertyName("insights")] IReadOnlyList<InsightItem> Insights,
    [property: JsonPropertyName("error_code")] string? ErrorCode)
{
    [JsonPropertyName("schema_version")] public int SchemaVersion => 1;
}
