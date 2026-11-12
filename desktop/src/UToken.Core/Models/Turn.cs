namespace UToken.Core.Models;

/// <summary>
/// Tín hiệu của một turn (một lần người dùng gửi prompt) sau khi parser đọc log.
/// Chỉ gồm số đếm, cờ và thời điểm; không có prompt, lệnh hay kết quả lệnh (FR-PRIV-001).
/// </summary>
public sealed record TurnRecord(
    Provider Provider,
    string SessionId,
    string TurnId,
    DateTimeOffset StartedAt,
    DateTimeOffset LastSeenAt,
    DateTimeOffset? EndedAt,
    int CommandsTotal,
    int CommandsFailed,
    int MaxConsecutiveFailures,
    int TestRuns,
    bool? LastTestPassed,
    bool FilesChanged,
    bool TurnError,
    bool Aborted,
    long? DurationMs,
    bool IsSideSession,
    string? ProjectKey)
{
    /// <summary>Thời điểm hoạt động cuối của turn, dùng để gom turn thành task.</summary>
    public DateTimeOffset LastActivityAt => EndedAt ?? LastSeenAt;
}

/// <summary>
/// Bộ đếm tín hiệu của turn đang đọc. Lưu được ra JSON để đọc tiếp file log từ offset cũ.
/// </summary>
public sealed class TurnAccumulator
{
    public string TurnId { get; set; } = "";
    public DateTimeOffset StartedAt { get; set; }
    public DateTimeOffset LastSeenAt { get; set; }
    public DateTimeOffset? EndedAt { get; set; }
    public int CommandsTotal { get; set; }
    public int CommandsFailed { get; set; }
    public int ConsecutiveFailures { get; set; }
    public int MaxConsecutiveFailures { get; set; }
    public int TestRuns { get; set; }
    public bool? LastTestPassed { get; set; }
    public bool FilesChanged { get; set; }
    public bool TurnError { get; set; }
    public bool Aborted { get; set; }
    public long? DurationMs { get; set; }
    public bool Closed { get; set; }

    public static TurnAccumulator Start(string turnId, DateTimeOffset at) =>
        new() { TurnId = turnId, StartedAt = at, LastSeenAt = at };

    public void Seen(DateTimeOffset at)
    {
        if (at > LastSeenAt) LastSeenAt = at;
    }

    /// <summary>Một lệnh terminal hoặc tool call đã có kết quả.</summary>
    public void Command(bool failed, bool isTestOrBuild)
    {
        CommandsTotal++;
        if (failed)
        {
            CommandsFailed++;
            ConsecutiveFailures++;
            MaxConsecutiveFailures = Math.Max(MaxConsecutiveFailures, ConsecutiveFailures);
        }
        else ConsecutiveFailures = 0;

        if (isTestOrBuild)
        {
            TestRuns++;
            LastTestPassed = !failed;
        }
    }

    /// <summary>Sửa file sau lần test cuối thì kết quả test cũ không còn đại diện (FR-ANLY-003 mục B).</summary>
    public void FileChanged()
    {
        FilesChanged = true;
        LastTestPassed = null;
    }

    public void Close(DateTimeOffset at)
    {
        Closed = true;
        EndedAt ??= at;
        Seen(at);
    }

    public TurnRecord ToRecord(Provider provider, string sessionId, bool isSide, string? projectKey) => new(
        provider, sessionId, TurnId, StartedAt, LastSeenAt, EndedAt,
        CommandsTotal, CommandsFailed, MaxConsecutiveFailures, TestRuns, LastTestPassed,
        FilesChanged, TurnError, Aborted, DurationMs, isSide, projectKey);
}
