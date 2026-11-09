using System.Text.Json.Serialization;

namespace UToken.Core.Aggregation;

/// <summary>
/// Document users/{uid}/daily/{YYYY-MM-DD}, khớp contracts/firestore/daily.schema.json (schema_version 2).
/// Tên trường JSON đặt tường minh để không phụ thuộc naming policy.
/// </summary>
public sealed record DailyDoc(
    [property: JsonPropertyName("date")] string Date,
    [property: JsonPropertyName("totals")] UsageBucket Totals,
    [property: JsonPropertyName("by_key")] IReadOnlyDictionary<string, UsageBucket> ByKey,
    [property: JsonPropertyName("tasks_by_state")] TasksByState TasksByState,
    [property: JsonPropertyName("pricing_version")] string PricingVersion,
    [property: JsonPropertyName("updated_at")] string UpdatedAt)
{
    [JsonPropertyName("schema_version")] public int SchemaVersion => 2;

    /// <summary>Khóa by_key = provider|model|project_key; project chưa rõ dùng giá trị này.</summary>
    public const string NoProject = "none";

    public static string Key(string provider, string model, string? projectKey) =>
        $"{provider}|{model}|{projectKey ?? NoProject}";
}

/// <summary>Một breakdown (totals hoặc một phần tử by_key).</summary>
public sealed record UsageBucket(
    [property: JsonPropertyName("chats")] int Chats,
    [property: JsonPropertyName("requests")] int Requests,
    [property: JsonPropertyName("error_requests")] int ErrorRequests,
    [property: JsonPropertyName("input")] long Input,
    [property: JsonPropertyName("cached")] long Cached,
    [property: JsonPropertyName("cache_write")] long CacheWrite,
    [property: JsonPropertyName("output")] long Output,
    [property: JsonPropertyName("thinking")] long? Thinking,
    [property: JsonPropertyName("cost_micro")] long? CostMicro,
    [property: JsonPropertyName("side_requests")] int SideRequests,
    [property: JsonPropertyName("side_tokens")] long SideTokens,
    [property: JsonPropertyName("side_cost_micro")] long? SideCostMicro,
    [property: JsonPropertyName("context_growth_sum")] double ContextGrowthSum,
    [property: JsonPropertyName("context_growth_count")] int ContextGrowthCount,
    [property: JsonPropertyName("bloated_chats")] int BloatedChats,
    [property: JsonPropertyName("duration_sum_ms")] long? DurationSumMs,
    [property: JsonPropertyName("duration_count")] int? DurationCount)
{
    [JsonIgnore] public long TotalTokens => Input + Output;
}

public sealed record TasksByState(
    [property: JsonPropertyName("verified_success")] int VerifiedSuccess,
    [property: JsonPropertyName("verified_failure")] int VerifiedFailure,
    [property: JsonPropertyName("likely_success")] int LikelySuccess,
    [property: JsonPropertyName("likely_failure")] int LikelyFailure,
    [property: JsonPropertyName("undetermined")] int Undetermined);
