using System.Text.Json.Serialization;

namespace UToken.Core.Efficiency;

/// <summary>Document users/{uid}/efficiency/current, khớp contracts/firestore/efficiency.schema.json (schema_version 1).</summary>
public sealed record EfficiencyDoc(
    [property: JsonPropertyName("period_start")] string PeriodStart,
    [property: JsonPropertyName("period_end")] string PeriodEnd,
    [property: JsonPropertyName("generated_at")] string GeneratedAt,
    [property: JsonPropertyName("undetermined_tasks")] int UndeterminedTasks,
    [property: JsonPropertyName("process_metrics")] IReadOnlyList<ProcessMetric> ProcessMetrics,
    [property: JsonPropertyName("setups")] IReadOnlyList<SetupReport> Setups,
    [property: JsonPropertyName("pricing_version")] string PricingVersion)
{
    [JsonPropertyName("schema_version")] public int SchemaVersion => 1;
}

/// <summary>
/// Chỉ số quá trình (FR-ANLY-003 mục A). Tỉ lệ lưu dạng phân số 0..1; context_growth và cost_tail là bội số;
/// tokens_per_turn_vs_median là mức thay đổi (0.2 = +20%). provider null = mọi nguồn.
/// </summary>
public sealed record ProcessMetric(
    [property: JsonPropertyName("metric")] string Metric,
    [property: JsonPropertyName("provider")] string? Provider,
    [property: JsonPropertyName("value")] double? Value,
    [property: JsonPropertyName("label")] string Label);

public sealed record SetupReport(
    [property: JsonPropertyName("provider")] string Provider,
    [property: JsonPropertyName("model")] string Model,
    [property: JsonPropertyName("effort")] string? Effort,
    [property: JsonPropertyName("task_group")] string TaskGroup,
    [property: JsonPropertyName("n_tasks")] int NTasks,
    [property: JsonPropertyName("n_sessions")] int NSessions,
    [property: JsonPropertyName("n_verified")] int NVerified,
    [property: JsonPropertyName("sr")] double? Sr,
    [property: JsonPropertyName("sr_ci_low")] double? SrCiLow,
    [property: JsonPropertyName("sr_ci_high")] double? SrCiHigh,
    [property: JsonPropertyName("sr_alt")] double? SrAlt,
    [property: JsonPropertyName("cpst_micro")] long? CpstMicro,
    [property: JsonPropertyName("cpst_ci_low_micro")] long? CpstCiLowMicro,
    [property: JsonPropertyName("cpst_ci_high_micro")] long? CpstCiHighMicro,
    [property: JsonPropertyName("cost_p50_micro")] long? CostP50Micro,
    [property: JsonPropertyName("cost_p90_micro")] long? CostP90Micro,
    [property: JsonPropertyName("weekly_sr")] IReadOnlyList<double?> WeeklySr,
    [property: JsonPropertyName("redo_rate")] double? RedoRate,
    [property: JsonPropertyName("mde")] double? Mde,
    [property: JsonPropertyName("stability_flag")] bool StabilityFlag,
    [property: JsonPropertyName("verdict")] string Verdict,
    [property: JsonPropertyName("confidence")] string? Confidence,
    [property: JsonPropertyName("compared_to")] string? ComparedTo,
    [property: JsonPropertyName("cross_tool")] bool CrossTool);

public static class Labels
{
    public const string Good = "good", Review = "review", NoData = "no_data";
}

public static class WireNames
{
    public static string ToWire(this Verdict v) => v switch
    {
        Verdict.Better => "better",
        Verdict.CheaperNotWorse => "cheaper_not_worse",
        Verdict.Tradeoff => "tradeoff",
        Verdict.Worse => "worse",
        Verdict.NoClearDifference => "no_clear_difference",
        _ => "insufficient",
    };

    public static string ToWire(this Confidence c) => c == Confidence.High ? "high" : "medium";

    public static string ToWire(this Models.TaskGroup g) => g switch
    {
        Models.TaskGroup.Small => "small",
        Models.TaskGroup.Medium => "medium",
        _ => "large",
    };

    public static string ToWire(this Models.OutcomeState s) => s switch
    {
        Models.OutcomeState.VerifiedSuccess => "verified_success",
        Models.OutcomeState.VerifiedFailure => "verified_failure",
        Models.OutcomeState.LikelySuccess => "likely_success",
        Models.OutcomeState.LikelyFailure => "likely_failure",
        _ => "undetermined",
    };
}
