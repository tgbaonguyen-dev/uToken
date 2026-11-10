namespace UToken.Core.Models;

public enum Provider { Codex, ClaudeCode, Antigravity }

public static class ProviderNames
{
    /// <summary>Tên dùng trong Firestore và SQLite: codex, claude_code, antigravity.</summary>
    public static string ToWire(this Provider p) => p switch
    {
        Provider.Codex => "codex",
        Provider.ClaudeCode => "claude_code",
        Provider.Antigravity => "antigravity",
        _ => throw new ArgumentOutOfRangeException(nameof(p)),
    };

    public static Provider FromWire(string s) => s switch
    {
        "codex" => Provider.Codex,
        "claude_code" => Provider.ClaudeCode,
        "antigravity" => Provider.Antigravity,
        _ => throw new ArgumentOutOfRangeException(nameof(s), s, "invalid provider"),
    };
}

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
    /// <summary>Request lỗi (ví dụ Claude Code isApiErrorMessage). Dùng cho error_requests và retry rate.</summary>
    public bool IsError { get; init; }

    public long TotalTokens => Input + Output;

    /// <summary>Kiểm tra ràng buộc FR-DATA-001; sai → METRIC_INVALID.</summary>
    public bool IsValid =>
        Input >= 0 && Cached >= 0 && CacheWrite >= 0 && Output >= 0 &&
        Cached + CacheWrite <= Input &&
        (Thinking is null || (Thinking >= 0 && Thinking <= Output));
}
