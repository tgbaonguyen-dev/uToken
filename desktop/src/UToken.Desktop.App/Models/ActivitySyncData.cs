using System.Globalization;

namespace UToken.Desktop.App.Models;

public sealed record UsageActivity(string Id, DateTimeOffset OccurredAt, string Provider, string Model,
    long Input, long Cached, long Output, long? DurationMs, decimal Cost, string Status, string Color)
{
    public string Latency => DurationMs is null ? "No data" : (DurationMs.Value / 1000d).ToString("0.0", CultureInfo.InvariantCulture) + " s";
    // Input includes cached tokens, matching Core's normalized usage model.
    public long TotalTokens => Input + Output;
    public string TimeLabel => OccurredAt.ToOffset(DisplayFormat.DisplayOffset).ToString("HH:mm:ss", CultureInfo.InvariantCulture);
    public string TimestampLabel => OccurredAt.ToOffset(DisplayFormat.DisplayOffset).ToString("yyyy-MM-dd HH:mm:ss zzz", CultureInfo.InvariantCulture);
    public string TokenLabel => FormatTokens(TotalTokens);
    public string InputLabel => FormatTokens(Input);
    public string CachedLabel => FormatTokens(Cached);
    public string OutputLabel => FormatTokens(Output);
    public string CostLabel => Cost.ToString("$0.00", CultureInfo.InvariantCulture);
    public string StatusColor => Status == "OK" ? "#2EC790" : "#F26039";
    private static string FormatTokens(long value) => value >= 1_000
        ? (value / 1000d).ToString("0.0", CultureInfo.InvariantCulture) + "K"
        : value.ToString(CultureInfo.InvariantCulture);
}

public sealed record ActivityQuery(string Provider = "All sources", string Model = "All models",
    string Period = "Last 24h", string Search = "", bool WarningsOnly = false);
public sealed record ActivityPageData(DateTimeOffset ReferenceTime, string[] Providers, string[] Models,
    string[] Periods, UsageActivity[] Events);
public sealed record MobileDevice(string Name, string Platform, string Version, string Initial,
    bool IsOnline, DateTimeOffset? LastSyncAt, long TransferredBytes, DateTimeOffset ReferenceTime = default)
{
    public string LastSync => LastSyncAt is null ? "Not synchronized yet" : DisplayFormat.Relative(LastSyncAt, ReferenceTime);
    public string Transferred => DisplayFormat.Bytes(TransferredBytes);
    public string ConnectionLabel => IsOnline ? "Online" : "Offline";
    public string ConnectionColor => IsOnline ? "#2EC790" : "#9096A1";
}
public sealed record SyncHistoryData(DateTimeOffset OccurredAt, string Device, int Events, long Bytes, string Result)
{
    public string Time => OccurredAt.ToOffset(DisplayFormat.DisplayOffset).ToString("HH:mm", CultureInfo.InvariantCulture);
    public string Size => DisplayFormat.Bytes(Bytes);
    public string Color => Result == "Success" ? "#2EC790" : "#F26039";
}
public sealed record SyncScenario(string State, string Message, int Events, long Bytes);
public sealed record SyncData(MobileDevice? Device, string EncryptionTitle, string EncryptionDescription,
    HealthData[] Privacy, SyncHistoryData[] History, SyncScenario NextSync, DateTimeOffset ReferenceTime);
public sealed record SyncResult(string State, string Message, SyncData Data);
public sealed record PairingConfig(string ValidCode, string ExpiredCode, int ExpiryMinutes,
    string SignInHint, string RejectedMessage, string ExpiredMessage, string SuccessMessage,
    string[] SecurityItems, MobileDevice Device);
public sealed record PairingData(DateTimeOffset ExpiresAt, int ExpiryMinutes, string SignInHint, string[] SecurityItems);
public sealed record PairingResult(string State, string Message, SyncData? Data = null);

public sealed record SyncQueueItem(string Id, string Name, int Events, long Bytes)
{
    public string Logo => $"/Assets/{Id}.svg";
    public string EventLabel => $"{Events} events";
    public string SizeLabel => DisplayFormat.Bytes(Bytes);
}
public sealed record SyncStateConfig(OverviewScenario[] Scenarios, SyncQueueItem[] Queue);
