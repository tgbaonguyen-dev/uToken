using System.Text.Json;
using UToken.Desktop.App.Models;
namespace UToken.Desktop.App.Services;
// shortcut: JSON simulates API responses; replace this service when real data services are ready.
public sealed partial class MockDesktopApi(string? dataDirectory = null, TimeProvider? timeProvider = null, LocalSettingsStore? localSettings = null) : IDesktopApi
{
    private readonly string _directory = dataDirectory ?? Path.Combine(AppContext.BaseDirectory, "MockData");
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNameCaseInsensitive = true,
        RespectRequiredConstructorParameters = true,
    };
    private async Task<T> ReadAsync<T>(string file, CancellationToken ct)
    {
        await Task.Delay(300, ct);
        try
        {
            await using var stream = File.OpenRead(Path.Combine(_directory, file));
            return await JsonSerializer.DeserializeAsync<T>(stream, Options, ct) ?? throw new InvalidDataException($"Empty mock data: {file}");
        }
        catch (Exception ex) when (ex is IOException or JsonException or InvalidDataException or UnauthorizedAccessException)
        {
            localSettings?.Record($"Mock JSON read failed ({Path.GetFileName(file)}): {ex.GetType().Name}");
            throw;
        }
    }
    public async Task<OverviewData> GetOverviewAsync(CancellationToken ct = default)
    {
        var config = await ReadAsync<OverviewConfig>("overview.json", ct);
        var sources = await GetSourcesAsync(ct);
        var activity = await ReadAsync<ActivityPageData>("activity.json", ct);
        var recent = activity.Events.Where(e => e.Status == "OK" && e.OccurredAt <= activity.ReferenceTime)
            .OrderByDescending(e => e.OccurredAt).Take(5)
            .Select(e => new ActivityData(e.OccurredAt, e.Provider, e.TotalTokens, e.Color, "Success")).ToArray();
        var collector = _lastSuccessfulSync is { } synced
            ? config.Collector with { LastSyncAt = synced, ReferenceTime = _clock.GetUtcNow() } : config.Collector;
        return new(sources.Sources.Sum(s => s.Tokens), sources.Sources.Sum(s => s.EstimatedCost),
            sources.Sources.Sum(s => s.CachedTokens), collector, recent, config.Health);
    }
    public async Task<SourcesData> GetSourcesAsync(CancellationToken ct = default)
    {
        var data = await ReadAsync<SourcesData>("sources.json", ct);
        var total = data.Sources.Sum(s => s.Tokens);
        foreach (var source in data.Sources) ValidateUsage(source.Tokens, source.EstimatedCost, source.Models, source.Trend);
        return data with { Sources = data.Sources.Select(s => s with
        {
            ReferenceTime = data.ReferenceTime,
            Health = s.Health with { HasLogAccess = _sourceLogAccess.GetValueOrDefault(s.Id, s.Health.HasLogAccess) },
            CollectorState = _sourceDiscoveryOverride == false ? "not_found"
                : _sourceDiscoveryOverride == true && s.CollectorState == "not_found" ? "running"
                : _sourceLogAccess.GetValueOrDefault(s.Id) && s.CollectorState == "permission_required" ? "running" : s.CollectorState,
            Share = total == 0 ? 0 : 100d * s.Tokens / total,
            Models = NormalizeModels(s.Models),
        }).ToArray() };
    }
    public Task<SupportedSourceData[]> GetSupportedSourcesAsync(CancellationToken ct = default) =>
        ReadAsync<SupportedSourceData[]>("supported-sources.json", ct);

    private static ModelData[] NormalizeModels(ModelData[] models)
    {
        var total = models.Sum(m => m.Tokens);
        return models.Select(m => m with { Share = total == 0 ? 0 : 100d * m.Tokens / total }).ToArray();
    }
    private static void ValidateUsage(long tokens, decimal cost, ModelData[] models, TrendData[] trend)
    {
        if (tokens < 0 || cost < 0 || models.Any(m => m.Tokens < 0) ||
            trend.Any(p => p.Tokens < 0 || p.Cached < 0 || p.Cached > p.Tokens))
            throw new InvalidDataException("Usage values must be non-negative and cached tokens cannot exceed total tokens.");
    }
    public async Task<SourceData> GetSourceAsync(string id, string period = "30 days", CancellationToken ct = default)
    {
        var source = (await GetSourcesAsync(ct)).Sources.FirstOrDefault(s => s.Id == id)
            ?? throw new InvalidDataException($"Source not found: {id}");
        if (period == "30 days") return source;
        var periods = await ReadAsync<Dictionary<string, Dictionary<string, SourceUsageData>>>("source-periods.json", ct);
        if (!periods.TryGetValue(id, out var ranges) || !ranges.TryGetValue(period, out var usage))
            throw new InvalidDataException($"Period not found: {id}/{period}");
        ValidateUsage(usage.Tokens, usage.EstimatedCost, usage.Models, usage.Trend);
        return source with
        {
            Tokens = usage.Tokens, Share = usage.Share, EstimatedCost = usage.EstimatedCost,
            DailyCost = usage.DailyCost, CacheRate = usage.CacheRate, CacheChange = usage.CacheChange,
            CacheChangePeriod = usage.CacheChangePeriod,
            Models = NormalizeModels(usage.Models), Trend = usage.Trend, PeriodStart = usage.PeriodStart, PeriodEnd = usage.PeriodEnd,
            Granularity = usage.Granularity,
        };
    }

}
