namespace UToken.Core.Models;

public enum Provider { Codex, ClaudeCode, Antigravity }

/// <summary>Một lần gọi model, đã chuẩn hóa theo SRS §10.4: Input gồm cache, Output gồm thinking.</summary>
public sealed record UsageEvent(
    Provider Provider,
    string SourceEventId,
    string SessionId,
    string? TurnId,
    string Model,
    string? Effort,
    DateTimeOffset OccurredAt,
    long Input,
    long Cached,
    long CacheWrite,
    long Output,
    long? Thinking,
    long? DurationMs,
    bool IsSideSession,
    string? ProjectKey)
{
    public long TotalTokens => Input + Output;

    /// <summary>Kiểm tra ràng buộc FR-DATA-001; sai → METRIC_INVALID.</summary>
    public bool IsValid =>
        Input >= 0 && Cached >= 0 && CacheWrite >= 0 && Output >= 0 &&
        Cached + CacheWrite <= Input &&
        (Thinking is null || (Thinking >= 0 && Thinking <= Output));
}
