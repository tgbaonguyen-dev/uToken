namespace UToken.Desktop.App.Models;

public sealed record ActivityData(DateTimeOffset OccurredAt, string Provider, long Tokens, string Color, string Result)
{
    public string TimeLabel => OccurredAt.ToOffset(DisplayFormat.DisplayOffset).ToString("HH:mm");
    public string TokenLabel => DisplayFormat.Tokens(Tokens);
}
public sealed record HealthData(string Label, string Value, string Color = "#9096A1");
public sealed record CoverageData(string Label, string Description, int Available, int Total)
{
    public string Count => $"{Available} / {Total}";
    public string Color => Available == 0 ? "#9096A1" : Available == Total ? "#2EC790" : "#F26039";
}
public sealed record ModelData(string Name, long Tokens, double Share)
{
    public string TokenLabel => DisplayFormat.Tokens(Tokens);
}
public sealed record TrendData(DateTimeOffset Timestamp, long Tokens, long Cached);
public sealed record TrendBar(double Height, double CachedHeight, string Tooltip);
public sealed record CollectorData(string State, DateTimeOffset? LastSyncAt, DateTimeOffset ReferenceTime)
{
    public string Label => State switch { "running" => "Running", "stopped" => "Stopped", "offline" => "Offline", "error" => "Error", _ => "Unavailable" };
    public string SidebarLabel => "Collector " + Label.ToLowerInvariant();
    public string Color => State == "running" ? "#2EC790" : State == "offline" ? "#F04D57" : State == "error" ? "#F26039" : "#9096A1";
    public string LastSyncLabel => DisplayFormat.Age(LastSyncAt, ReferenceTime);
    public string LastSyncCaption => LastSyncAt is null ? "Not synchronized yet" : "Synced " + DisplayFormat.Relative(LastSyncAt, ReferenceTime);
}
public sealed record OverviewData(long TotalTokens, decimal EstimatedCost, long Cached, CollectorData Collector,
    ActivityData[] Activity, HealthData[] Health)
{
    public string TotalTokensLabel => DisplayFormat.Tokens(TotalTokens);
    public string EstimatedCostLabel => DisplayFormat.Money(EstimatedCost);
    public string CachedLabel => DisplayFormat.Tokens(Cached);
}
public sealed record OverviewConfig(CollectorData Collector, HealthData[] Health);
public sealed record SourceHealthData(bool HasLogAccess, string ParserState, DateTimeOffset? LastReadAt, bool CollectsPrompt);
public sealed record SourceData(string Id, string Name, string Status, string Color, long Tokens, double Share,
    string Path, DateTimeOffset? LastEventAt, decimal EstimatedCost, decimal DailyCost, double CacheRate,
    double CacheChange, string CacheChangePeriod, ModelData[] Models, TrendData[] Trend, SourceHealthData Health,
    string CollectorState, DateTimeOffset PeriodStart, DateTimeOffset PeriodEnd, string Granularity,
    DateTimeOffset ReferenceTime = default)
{
    public string TokenLabel => DisplayFormat.Tokens(Tokens);
    public string ShareLabel => DisplayFormat.Percent(Share);
    public string EstimatedCostLabel => DisplayFormat.Money(EstimatedCost);
    public string DailyCostLabel => DisplayFormat.Money(DailyCost) + " daily average";
    public string CacheRateLabel => DisplayFormat.Percent(CacheRate);
    public string CacheChangeLabel => (CacheChange > 0 ? "+" : "") + DisplayFormat.Percent(CacheChange) + " " + CacheChangePeriod;
    public string LastEventLabel => DisplayFormat.Age(LastEventAt, ReferenceTime);
    public string LastEventCaption => "Last event: " + DisplayFormat.Relative(LastEventAt, ReferenceTime);
    public int ModelCount => Models.Length;
    public long CachedTokens => Trend.Sum(p => p.Cached);
    public string Logo => $"/Assets/{Id}.svg";
    public string StatusLabel => !Health.HasLogAccess ? "Permission required" : CollectorState switch
    {
        "running" => Status, "paused" => "Paused", "not_found" => "Not found", "permission_required" => "Permission required", _ => "Error",
    };
    public string StatusColor => !Health.HasLogAccess ? "#F26039" : CollectorState == "running"
        ? (Status == "Connected" ? "#2EC790" : "#9096A1") : CollectorState == "paused" ? "#9096A1" : "#F26039";
    public string CollectorHealthLabel => !Health.HasLogAccess ? "Permission required" : CollectorState switch
    {
        "running" => "Collector healthy", "permission_required" => "Permission required",
        "not_found" => "Source not found", "paused" => "Collector paused", _ => "Collector error",
    };
    public string CollectorHealthColor => Health.HasLogAccess && CollectorState == "running" ? "#2EC790" : "#F26039";
    public string TrendStart => PeriodStart.ToOffset(DisplayFormat.DisplayOffset).ToString(Granularity == "hour" ? "HH:mm" : "dd MMM", System.Globalization.CultureInfo.InvariantCulture);
    public string TrendEnd => PeriodEnd.ToOffset(DisplayFormat.DisplayOffset).ToString(Granularity == "hour" ? "HH:mm" : "dd MMM", System.Globalization.CultureInfo.InvariantCulture);
    public string TrendCaption => "Tokens by " + Granularity;
    public TrendBar[] ChartBars
    {
        get
        {
            var max = Trend.Length == 0 ? 0 : Trend.Max(p => p.Tokens);
            return Trend.Select(p => new TrendBar(max <= 0 ? 0 : 144d * p.Tokens / max,
                max <= 0 ? 0 : 144d * p.Cached / max,
                $"{p.Timestamp.ToOffset(DisplayFormat.DisplayOffset):yyyy-MM-dd HH:mm}: {p.Tokens:N0} tokens, {p.Cached:N0} cached")).ToArray();
        }
    }
    public HealthData[] HealthRows => [
        new("Log access", Health.HasLogAccess ? "Allowed" : "Permission required", Health.HasLogAccess ? "#2EC790" : "#F26039"),
        new("Metadata parsing", Health.ParserState == "healthy" ? "Healthy" : Health.ParserState, Health.ParserState == "healthy" ? "#2EC790" : "#F26039"),
        new("Last successful read", DisplayFormat.Relative(Health.LastReadAt, ReferenceTime), "#F3F4F7"),
        new("Prompt content", Health.CollectsPrompt ? "Collected" : "Not collected", Health.CollectsPrompt ? "#F26039" : "#2EC790")];
}
/// <param name="NewEvents">Số event mới đọc được ở lần quét vừa chạy (null khi chỉ đọc lại số liệu).</param>
public sealed record SourcesData(DateTimeOffset ReferenceTime, SourceData[] Sources, CoverageData[] Coverage, int? NewEvents = null);
public sealed record SupportedSourceData(string Id, string Name, string Availability)
{
    public string Color => Id switch { "antigravity" => "#F26039", "codex" => "#4089EF", "claude" => "#E64C9D", _ => "#9096A1" };
    public string Logo => $"/Assets/{Id}.svg";
}
public sealed record SourceUsageData(long Tokens, double Share, decimal EstimatedCost, decimal DailyCost,
    double CacheRate, double CacheChange, string CacheChangePeriod, ModelData[] Models, TrendData[] Trend,
    DateTimeOffset PeriodStart, DateTimeOffset PeriodEnd, string Granularity);
