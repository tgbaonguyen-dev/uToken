using System.Globalization;
using System.Text;
using System.Text.Json;
using UToken.Core.Aggregation;
using UToken.Core.Models;
using UToken.Core.Pricing;
using UToken.Desktop.App.Models;
using UToken.Engine;
using UToken.Storage;
using UToken.Sync;

namespace UToken.Desktop.App.Services;

/// <summary>Thư mục log của từng nguồn, dùng để hiển thị và kiểm tra quyền đọc.</summary>
public sealed record SourceLocation(Provider Provider, string Id, string Name, string DisplayPath, string Directory, bool Enabled);

/// <summary>
/// IDesktopApi chạy bằng dữ liệu thật: số liệu lấy từ UsageEngine (log cục bộ → SQLite).
/// Chữ hiển thị (hướng dẫn, kịch bản xem trước trạng thái) đọc từ UiContent/*.json.
/// Mọi thao tác với engine/SQLite đi qua một khóa vì engine không thread-safe.
/// </summary>
public sealed partial class RealDesktopApi : IDesktopApi, IDisposable
{
    private readonly UsageEngine _engine;
    private readonly ICloudSync? _cloud;
    private readonly SqliteStore _store;
    private readonly IReadOnlyList<SourceLocation> _locations;
    private readonly LocalSettingsStore? _localSettings;
    private readonly string _contentDirectory;
    private readonly string _databasePath;
    private readonly TimeProvider _clock;
    private readonly SemaphoreSlim _gate = new(1, 1);
    private ScanReport? _lastScan;
    private DateTimeOffset? _lastScanAt;

    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNameCaseInsensitive = true,
        RespectRequiredConstructorParameters = true,
    };

    public RealDesktopApi(UsageEngine engine, SqliteStore store, IReadOnlyList<SourceLocation> locations, string databasePath,
        LocalSettingsStore? localSettings = null, string? contentDirectory = null, TimeProvider? clock = null, ICloudSync? cloud = null)
    {
        _engine = engine;
        _cloud = cloud;
        _store = store;
        _locations = locations;
        _databasePath = databasePath;
        _localSettings = localSettings;
        _contentDirectory = contentDirectory ?? Path.Combine(AppContext.BaseDirectory, "UiContent");
        _clock = clock ?? TimeProvider.System;
    }

    /// <summary>Vị trí log mặc định theo cấu hình appsettings.</summary>
    public static IReadOnlyList<SourceLocation> DefaultLocations(string codexHome, string claudeHome, string homeDirectory, IReadOnlyCollection<string> enabled)
    {
        bool On(string wire) => enabled.Count == 0 || enabled.Contains(wire, StringComparer.OrdinalIgnoreCase);
        return
        [
            new(Provider.Codex, "codex", "Codex", "~/.codex/sessions", Path.Combine(codexHome, "sessions"), On("codex")),
            new(Provider.ClaudeCode, "claude", "Claude", "~/.claude/projects", Path.Combine(claudeHome, "projects"), On("claude_code")),
            AntigravityLocation(homeDirectory, On("antigravity")),
        ];
    }

    /// <summary>Thư mục hội thoại Antigravity đầu tiên có thật (CLI trước, rồi IDE); không có thì hiển thị đường dẫn CLI.</summary>
    private static SourceLocation AntigravityLocation(string home, bool enabled)
    {
        var app = UToken.Collectors.Antigravity.AntigravityCollector.AppDirectories
            .FirstOrDefault(a => System.IO.Directory.Exists(Path.Combine(home, ".gemini", a, "conversations")))
            ?? UToken.Collectors.Antigravity.AntigravityCollector.AppDirectories[0];
        return new(Provider.Antigravity, "antigravity", "Antigravity", $"~/.gemini/{app}/conversations",
            Path.Combine(home, ".gemini", app, "conversations"), enabled);
    }

    private DateTimeOffset Now => _clock.GetUtcNow();
    private IPriceBook Prices => _engine.Prices;

    private static string ColorOf(string id) => id switch { "antigravity" => "#F26039", "codex" => "#4089EF", "claude" => "#E64C9D", _ => "#9096A1" };
    private SourceLocation LocationOf(Provider p) => _locations.First(l => l.Provider == p);
    private string NameOf(Provider p) => LocationOf(p).Name;

    /// <summary>Chạy một thao tác engine/SQLite trên thread nền, tuần tự.</summary>
    private async Task<T> WithStoreAsync<T>(Func<T> work, CancellationToken ct)
    {
        await _gate.WaitAsync(ct);
        try { return await Task.Run(work, ct); }
        finally { _gate.Release(); }
    }

    /// <summary>Lần đầu mở màn hình thì quét log một lần để có số liệu.</summary>
    private void EnsureScanned()
    {
        if (_lastScanAt is not null) return;
        _lastScan = _engine.Scan();
        _lastScanAt = Now;
        _localSettings?.Record($"Initial scan: {_lastScan.FilesRead} files read, {_lastScan.NewEvents} new events, {_lastScan.Errors.Count} errors");
    }

    private async Task<T> ReadContentAsync<T>(string file, CancellationToken ct)
    {
        try
        {
            await using var stream = File.OpenRead(Path.Combine(_contentDirectory, file));
            return await JsonSerializer.DeserializeAsync<T>(stream, Options, ct) ?? throw new InvalidDataException($"Empty UI content: {file}");
        }
        catch (Exception ex) when (ex is IOException or JsonException or InvalidDataException or UnauthorizedAccessException)
        {
            _localSettings?.Record($"UI content read failed ({Path.GetFileName(file)}): {ex.GetType().Name}");
            throw;
        }
    }

    // ───────────────────────── Nguồn và quyền đọc thư mục ─────────────────────────

    private enum FolderState { Running, NotFound, PermissionRequired, Paused }

    private static FolderState CheckFolder(SourceLocation l)
    {
        if (!l.Enabled) return FolderState.Paused;
        if (!System.IO.Directory.Exists(l.Directory)) return FolderState.NotFound;
        try
        {
            using var e = System.IO.Directory.EnumerateFileSystemEntries(l.Directory).GetEnumerator();
            e.MoveNext();
            return FolderState.Running;
        }
        catch (Exception ex) when (ex is UnauthorizedAccessException or IOException)
        {
            return FolderState.PermissionRequired;
        }
    }

    private sealed record PeriodWindow(DateTimeOffset Start, DateTimeOffset End, string Granularity, TimeSpan Step, string ChangeLabel);

    private PeriodWindow WindowFor(string period, DateTimeOffset? firstEvent)
    {
        var now = Now;
        switch (period)
        {
            case "1 day":
                var localNow = TimeZoneInfo.ConvertTime(now, _engine.TimeZone);
                var midnight = new DateTimeOffset(localNow.Date, localNow.Offset);
                return new(midnight, now, "hour", TimeSpan.FromHours(1), "vs yesterday");
            case "Week":
                return new(now.AddDays(-7), now, "day", TimeSpan.FromDays(1), "vs previous week");
            case "Total":
                var start = firstEvent is { } f && f < now.AddDays(-7) ? f : now.AddDays(-7);
                return new(start, now, "week", TimeSpan.FromDays(7), "all time");
            default: // "30 days"
                return new(now.AddDays(-30), now, "day", TimeSpan.FromDays(1), "vs previous 30 days");
        }
    }

    private static double CacheRate(IReadOnlyCollection<UsageEvent> events)
    {
        long input = events.Sum(e => e.Input);
        return input == 0 ? 0 : 100d * events.Sum(e => e.Cached) / input;
    }

    private decimal CostUsd(IEnumerable<UsageEvent> events) =>
        events.Sum(e => Prices.CostMicro(e) ?? 0) / 1_000_000m;

    private SourcesData BuildSources(string period)
    {
        EnsureScanned();
        var window = WindowFor(period, _store.GetFirstEventAt());
        var length = window.End - window.Start;
        var events = _store.GetEvents(window.Start, window.End.AddSeconds(1)).Where(e => e.IsValid).ToList();
        var previous = period == "Total" ? new List<UsageEvent>() : _store.GetEvents(window.Start - length, window.Start).Where(e => e.IsValid).ToList();
        long allTokens = events.Sum(e => e.TotalTokens);
        double days = Math.Max(1, length.TotalDays);

        var sources = _locations.Select(l =>
        {
            var mine = events.Where(e => e.Provider == l.Provider).ToList();
            var before = previous.Where(e => e.Provider == l.Provider).ToList();
            long tokens = mine.Sum(e => e.TotalTokens);
            decimal cost = CostUsd(mine);
            var folder = CheckFolder(l);

            var models = mine.GroupBy(e => e.Model)
                .Select(g => new ModelData(g.Key, g.Sum(e => e.TotalTokens), 0))
                .OrderByDescending(m => m.Tokens).ToArray();
            long modelTotal = models.Sum(m => m.Tokens);
            models = models.Select(m => m with { Share = modelTotal == 0 ? 0 : 100d * m.Tokens / modelTotal }).ToArray();

            var trend = new List<TrendData>();
            for (var t = window.Start; t < window.End; t += window.Step)
            {
                var end = t + window.Step;
                var bucket = mine.Where(e => e.OccurredAt >= t && e.OccurredAt < end).ToList();
                trend.Add(new TrendData(t, bucket.Sum(e => e.TotalTokens), bucket.Sum(e => e.Cached)));
            }

            double rate = CacheRate(mine);
            double change = before.Count == 0 || mine.Count == 0 ? 0 : rate - CacheRate(before);
            string parser = "healthy";

            return new SourceData(
                Id: l.Id,
                Name: l.Name,
                Status: tokens > 0 ? "Connected" : "No usage",
                Color: ColorOf(l.Id),
                Tokens: tokens,
                Share: allTokens == 0 ? 0 : 100d * tokens / allTokens,
                Path: l.DisplayPath,
                LastEventAt: _store.GetLastEventAt(l.Provider),
                EstimatedCost: Math.Round(cost, 4),
                DailyCost: Math.Round(cost / (decimal)days, 4),
                CacheRate: Math.Round(rate, 1),
                CacheChange: Math.Round(change, 1),
                CacheChangePeriod: window.ChangeLabel,
                Models: models,
                Trend: trend.ToArray(),
                Health: new SourceHealthData(folder != FolderState.PermissionRequired, parser, _store.GetLastReadAt(l.Provider), false),
                CollectorState: folder switch
                {
                    FolderState.NotFound => "not_found",
                    FolderState.PermissionRequired => "permission_required",
                    FolderState.Paused => "paused",
                    _ => "running",
                },
                PeriodStart: window.Start,
                PeriodEnd: window.End,
                Granularity: window.Granularity,
                ReferenceTime: Now);
        }).ToArray();

        int withUsage = sources.Count(s => s.Tokens > 0);
        int total = sources.Length;
        CoverageData[] coverage =
        [
            new("Token usage", "Input, output, cached", withUsage, total),
            new("Model identity", "Provider and model", withUsage, total),
            new("Timing", "Timestamp; latency for Codex", withUsage, total),
            new("Prompt content", "Never collected", 0, total),
            new("AI responses", "Never collected", 0, total),
        ];
        return new SourcesData(Now, sources, coverage);
    }

    public async Task<SourcesData> GetSourcesAsync(CancellationToken ct = default) =>
        await WithStoreAsync(() => BuildSources("30 days"), ct);

    public async Task<SourceData> GetSourceAsync(string id, string period = "30 days", CancellationToken ct = default)
    {
        var data = await WithStoreAsync(() => BuildSources(period), ct);
        return data.Sources.FirstOrDefault(s => s.Id == id) ?? throw new InvalidDataException($"Source not found: {id}");
    }

    public async Task<SupportedSourceData[]> GetSupportedSourcesAsync(CancellationToken ct = default)
    {
        var listed = await ReadContentAsync<SupportedSourceData[]>("supported-sources.json", ct);
        return listed.Select(s =>
        {
            var location = _locations.FirstOrDefault(l => l.Id == s.Id);
            var state = location is null ? "Not supported" : CheckFolder(location) switch
            {
                FolderState.Running => "Found",
                FolderState.NotFound => "Not installed",
                FolderState.PermissionRequired => "Permission required",
                _ => "Disabled in settings",
            };
            return s with { Availability = state };
        }).ToArray();
    }

    // ───────────────────────── Overview ─────────────────────────

    public async Task<OverviewData> GetOverviewAsync(CancellationToken ct = default)
    {
        var sources = await GetSourcesAsync(ct);
        var (recent, counts) = await WithStoreAsync(() =>
        {
            var last = _store.GetEvents(Now.AddDays(-30), Now.AddSeconds(1))
                .Where(e => e.IsValid && !e.IsError)
                .OrderByDescending(e => e.OccurredAt).Take(5)
                .Select(e => new ActivityData(e.OccurredAt, NameOf(e.Provider), e.TotalTokens, ColorOf(LocationOf(e.Provider).Id), "Success"))
                .ToArray();
            return (last, _store.Counts());
        }, ct);

        var settings = await GetSettingsAsync(ct);
        // Log có dòng không đọc được (định dạng lạ) → collector cần cập nhật (SOURCE_FORMAT_UNSUPPORTED, màn D24).
        string state = _lastScan is { MalformedLines: > 0 } ? "error"
            : sources.Sources.Any(s => s.CollectorState == "running") ? "running" : "stopped";
        HealthData[] health =
        [
            new("Prompt content", "Not collected", "#2EC790"),
            new("Local database", $"{counts.Events:N0} events", "#9096A1"),
            new("Logs retained", $"{settings.Values.RetentionDays} days", "#9096A1"),
            new("App version", BuildVersion, "#9096A1"),
        ];
        return new OverviewData(
            sources.Sources.Sum(s => s.Tokens),
            sources.Sources.Sum(s => s.EstimatedCost),
            sources.Sources.Sum(s => s.CachedTokens),
            new CollectorData(state, _lastUploadAt, Now), // "Synced …" = lần upload thành công gần nhất
            recent,
            health);
    }

    // ───────────────────────── Activity ─────────────────────────

    private const int MaxActivityRows = 1000;

    public async Task<ActivityPageData> GetActivityAsync(ActivityQuery query, CancellationToken ct = default)
    {
        var now = Now;
        var cutoff = query.Period switch
        {
            "Last 24h" => now.AddDays(-1),
            "Last 7 days" => now.AddDays(-7),
            "All time" => DateTimeOffset.UnixEpoch,
            _ => throw new InvalidDataException("Unknown activity period."),
        };
        var events = await WithStoreAsync(() =>
        {
            EnsureScanned();
            return _store.GetEvents(cutoff, now.AddSeconds(1)).Where(e => e.IsValid).ToList();
        }, ct);

        var search = query.Search.Trim();
        var rows = events
            .Select(e => new UsageActivity(e.SourceEventId, e.OccurredAt, NameOf(e.Provider), e.Model,
                e.Input, e.Cached, e.Output, e.DurationMs, (Prices.CostMicro(e) ?? 0) / 1_000_000m,
                e.IsError ? "Warning" : "OK", ColorOf(LocationOf(e.Provider).Id)))
            .Where(e =>
                (query.Provider == "All sources" || e.Provider == query.Provider) &&
                (query.Model == "All models" || e.Model == query.Model) &&
                (query.WarningsOnly ? e.Status != "OK" : e.Status == "OK") &&
                (search.Length == 0 || $"{e.Id} {e.Provider} {e.Model}".Contains(search, StringComparison.OrdinalIgnoreCase)))
            .OrderByDescending(e => e.OccurredAt)
            .Take(MaxActivityRows)
            .ToArray();

        return new ActivityPageData(
            now,
            ["All sources", .. _locations.Select(l => l.Name)],
            ["All models", .. events.Select(e => e.Model).Distinct().Order(StringComparer.Ordinal)],
            ["Last 24h", "Last 7 days", "All time"],
            rows);
    }

    public async Task<string> ExportActivityAsync(ActivityQuery query, CancellationToken ct = default)
    {
        var page = await GetActivityAsync(query, ct);
        var csv = new StringBuilder("Event ID,Timestamp,Source,Model,Input,Cached,Output,Total,Cost USD,Status\r\n");
        foreach (var e in page.Events)
        {
            string[] cells = [e.Id, e.OccurredAt.ToString("O"), e.Provider, e.Model,
                e.Input.ToString(CultureInfo.InvariantCulture), e.Cached.ToString(CultureInfo.InvariantCulture),
                e.Output.ToString(CultureInfo.InvariantCulture), e.TotalTokens.ToString(CultureInfo.InvariantCulture),
                e.Cost.ToString(CultureInfo.InvariantCulture), e.Status];
            csv.Append(string.Join(",", cells.Select(CsvCell))).Append("\r\n");
        }
        return csv.ToString();
    }

    /// <summary>Chặn CSV injection: ô bắt đầu bằng = + - @ được thêm dấu nháy.</summary>
    private static string CsvCell(string value)
    {
        var t = value.TrimStart();
        if (t.StartsWith('=') || t.StartsWith('+') || t.StartsWith('-') || t.StartsWith('@')) value = "'" + value;
        return "\"" + value.Replace("\"", "\"\"") + "\"";
    }

    // ───────────────────────── Quét lại ─────────────────────────

    public async Task<SourcesData> RescanSourcesAsync(CancellationToken ct = default, IProgress<SourceScanProgress>? progress = null)
    {
        var config = await ReadContentAsync<SourceScanConfig>("source-scan.json", ct);
        var retention = (await GetSettingsAsync(ct)).Values.RetentionDays;
        int newEvents = 0, malformed = 0;
        var items = _locations.Select(l => new SourceScanItem(l.Name, $"/Assets/{l.Id}.svg", "waiting")).ToArray();
        progress?.Report(new(config, 0, items.Length, items.Length == 0 ? "None" : items[0].Name, items.ToArray()));

        for (int i = 0; i < _locations.Count; i++)
        {
            ct.ThrowIfCancellationRequested();
            var l = _locations[i];
            items[i] = items[i] with { State = "scanning" };
            progress?.Report(new(config, i, items.Length, l.Name, items.ToArray()));

            var folder = CheckFolder(l);
            if (folder == FolderState.Running)
            {
                var report = await WithStoreAsync(() => _engine.Scan([l.Provider], ct), ct);
                _localSettings?.Record($"Rescan {l.Id}: {report.FilesRead} files read, {report.NewEvents} new events, {report.Errors.Count} errors");
                newEvents += report.NewEvents;
                malformed += report.MalformedLines;
            }
            if (config.StepDelayMs > 0) await Task.Delay(config.StepDelayMs, ct);

            items[i] = items[i] with
            {
                State = folder switch
                {
                    FolderState.PermissionRequired => "permission",
                    FolderState.NotFound => "not-found",
                    _ => "complete",
                },
            };
            progress?.Report(new(config, i + 1, items.Length, l.Name, items.ToArray()));
        }
        await WithStoreAsync(() => _store.PruneBefore(Now.AddDays(-retention)), ct);
        _lastScan = new ScanReport(_locations.Count, 0, newEvents, 0, malformed, [], []);
        _lastScanAt = Now;
        return (await GetSourcesAsync(ct)) with { NewEvents = newEvents };
    }

    public string GetSourceFolder(string sourceId) =>
        _locations.FirstOrDefault(l => l.Id == sourceId)?.Directory ?? throw new InvalidDataException($"Unknown source: {sourceId}");

    public async Task<long> ClearLocalDataAsync(CancellationToken ct = default)
    {
        var removed = await WithStoreAsync(() =>
        {
            var n = _store.Counts().Events;
            _store.ClearUsage();
            return n;
        }, ct);
        _history.Clear();
        _localSettings?.Record($"Local data cleared: {removed} events");
        return removed;
    }

    public void Dispose()
    {
        _priceUpdateGate.Dispose();
        _gate.Dispose();
        _store.Dispose();
    }
}
