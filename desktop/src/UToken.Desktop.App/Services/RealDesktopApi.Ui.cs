using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using UToken.Core.Pricing;
using UToken.Desktop.App.Models;

namespace UToken.Desktop.App.Services;

/// <summary>Cài đặt, chẩn đoán, first-run và các kịch bản xem trước trạng thái giao diện.</summary>
public sealed partial class RealDesktopApi
{
    private SettingsData? _settings;
    private bool _setupComplete;

    internal static string BuildVersion => typeof(RealDesktopApi).Assembly
        .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion?.Split('+')[0]
        ?? typeof(RealDesktopApi).Assembly.GetName().Version?.ToString() ?? "Unknown";

    // ───────────────────────── First run ─────────────────────────

    public async Task<FirstRunData> GetFirstRunAsync(CancellationToken ct = default)
    {
        var data = await ReadContentAsync<FirstRunData>("first-run.json", ct);
        if (data.Steps.Length != 3) throw new InvalidDataException("Setup requires three steps.");
        return data;
    }

    public Task<bool> IsSetupCompleteAsync(CancellationToken ct = default)
    {
        ct.ThrowIfCancellationRequested();
        return Task.FromResult(_setupComplete || (_localSettings is not null &&
            File.Exists(Path.Combine(_localSettings.DirectoryPath, "setup-complete"))));
    }

    public async Task CompleteSetupAsync(CancellationToken ct = default)
    {
        if (_localSettings is not null)
        {
            Directory.CreateDirectory(_localSettings.DirectoryPath);
            await File.WriteAllTextAsync(Path.Combine(_localSettings.DirectoryPath, "setup-complete"), "setup completed", ct);
            _localSettings.Record("Setup completed");
        }
        _setupComplete = true;
    }

    // ───────────────────────── Settings ─────────────────────────

    private SettingsData WithLocalMetadata(SettingsData data) => data with
    {
        DataPath = Path.GetDirectoryName(Path.GetFullPath(_databasePath)) ?? _databasePath,
        AppVersion = BuildVersion,
        Diagnostics = "Collector reads local logs of enabled sources. Only token counts and metadata are stored.",
        IsPersistent = _localSettings is not null,
    };

    public async Task<SettingsData> GetSettingsAsync(CancellationToken ct = default)
    {
        if (_settings is not null) return _settings;
        var defaults = await ReadContentAsync<SettingsData>("settings.json", ct);
        var values = _localSettings is null ? defaults.Values :
            await _localSettings.LoadAsync(defaults.Values, defaults.RetentionOptions, ct);
        return _settings = WithLocalMetadata(defaults with { Values = values });
    }

    public async Task<SettingsData> SaveSettingsAsync(CollectorSettings values, CancellationToken ct = default)
    {
        var settings = await GetSettingsAsync(ct);
        if (!settings.RetentionOptions.Contains(values.RetentionDays))
            throw new InvalidDataException("Unsupported retention period.");
        if (_localSettings is not null) await _localSettings.SaveAsync(values, ct);
        return _settings = settings with { Values = values };
    }

    public async Task<SettingsData> ResetSettingsAsync(CancellationToken ct = default)
    {
        var defaults = await ReadContentAsync<SettingsData>("settings.json", ct);
        if (_localSettings is not null) await _localSettings.SaveAsync(defaults.Values, ct);
        return _settings = WithLocalMetadata(defaults);
    }

    public async Task<string> GetDiagnosticsAsync(CancellationToken ct = default)
    {
        var report = new StringBuilder()
            .AppendLine($"App version: {BuildVersion}")
            .AppendLine($"OS: {RuntimeInformation.OSDescription}")
            .AppendLine($"Runtime: {RuntimeInformation.FrameworkDescription}")
            .AppendLine($"Architecture: {RuntimeInformation.ProcessArchitecture}")
            .AppendLine($"Database: {_databasePath}")
            .AppendLine($"Pricing: {Prices.Version} (estimated API prices)");

        var (counts, lastEvent, unpriced) = await WithStoreAsync(() => (_store.Counts(), _store.GetLastEventAt(), ModelsWithoutCatalogPrice()), ct);
        if (Prices is TieredPriceBook book)
            report.AppendLine($"Price catalog: {book.ModelCount} models from models.dev" +
                              (book.LastFetchedAt is { } f ? $", fetched {f:u}" : ", not fetched yet (using built-in prices)"));
        foreach (var m in unpriced) report.AppendLine($"  not on models.dev: {m}");
        report.AppendLine($"Stored: {counts.Events:N0} usage events, {counts.Turns:N0} turns, {counts.Files:N0} log files tracked")
              .AppendLine($"Last event: {(lastEvent is { } le ? le.ToString("u") : "none")}");

        if (_lastScan is { } s)
            report.AppendLine($"Last scan: {_lastScanAt:u} · {s.FilesRead} files read, {s.FilesUnchanged} unchanged, " +
                              $"{s.NewEvents} new events, {s.MalformedLines} malformed lines");
        if (_lastScan?.Errors is { Count: > 0 } errors)
            foreach (var e in errors.Take(10)) report.AppendLine($"  scan error: {e}");

        report.AppendLine("Sources:");
        foreach (var l in _locations)
            report.AppendLine($"  {l.Name}: {l.DisplayPath} → {CheckFolder(l)}");

        if (_localSettings is not null)
        {
            _localSettings.Record("Diagnostics opened");
            report.AppendLine("Recent application log:");
            try
            {
                if (File.Exists(_localSettings.LogPath))
                    foreach (var line in (await File.ReadAllLinesAsync(_localSettings.LogPath, ct)).TakeLast(30))
                        report.AppendLine(line);
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            { report.AppendLine("Log unavailable: " + ex.GetType().Name); }
        }
        return report.ToString();
    }

    // ───────────────────────── Xem trước trạng thái Overview ─────────────────────────

    public Task<OverviewScenario[]> GetOverviewScenariosAsync(CancellationToken ct = default) =>
        ReadContentAsync<OverviewScenario[]>("overview-states.json", ct);

    public async Task<OverviewPreview> GetOverviewPreviewAsync(string id, CancellationToken ct = default)
    {
        var scenario = (await GetOverviewScenariosAsync(ct)).FirstOrDefault(s => s.Id == id)
            ?? throw new InvalidDataException("Unknown overview scenario.");
        var data = await GetOverviewAsync(ct);
        if (scenario.EmptyUsage) data = data with { TotalTokens = 0, EstimatedCost = 0, Cached = 0, Activity = [] };
        data = data with { Collector = data.Collector with { State = scenario.CollectorState } };
        return new(scenario, data);
    }

    // ───────────────────────── Quyền đọc log ─────────────────────────
    // Trạng thái thật lấy từ việc thử đọc thư mục. Các kịch bản trong source-permission.json chỉ là
    // xem trước giao diện: chúng phủ lên kết quả thật cho tới lần quét lại tiếp theo.

    private string _permissionScenarioId = "normal";
    private readonly Dictionary<string, bool> _previewLogAccess = [];
    private bool? _previewDiscovery;

    private void ClearPreview()
    {
        _permissionScenarioId = "normal";
        _previewLogAccess.Clear();
        _previewDiscovery = null;
    }

    private SourcesData ApplyPreview(SourcesData data) => data with
    {
        Sources = data.Sources.Select(s =>
        {
            if (_previewDiscovery == false) s = s with { CollectorState = "not_found" };
            if (_previewLogAccess.TryGetValue(s.Id, out var allowed))
                s = s with
                {
                    Health = s.Health with { HasLogAccess = allowed },
                    CollectorState = allowed ? s.CollectorState : "permission_required",
                };
            return s;
        }).ToArray(),
    };

    public async Task<SourcePermissionData> GetSourcePermissionAsync(CancellationToken ct = default)
    {
        var config = await ReadContentAsync<SourcePermissionConfig>("source-permission.json", ct);
        var sources = await GetSourcesAsync(ct);
        // Có nguồn thật sự bị chặn quyền → chỉ hướng dẫn tới nguồn đó.
        var blocked = sources.Sources.FirstOrDefault(s => s.CollectorState == "permission_required");
        if (blocked is not null) config = config with { SourceId = blocked.Id };
        var scenario = config.Scenarios.FirstOrDefault(s => s.Id == _permissionScenarioId)
            ?? config.Scenarios.First(s => s.Id == "normal");
        return new(config, scenario, sources);
    }

    public async Task<SourcePermissionData> SetSourcePermissionScenarioAsync(string id, CancellationToken ct = default)
    {
        var config = await ReadContentAsync<SourcePermissionConfig>("source-permission.json", ct);
        var scenario = config.Scenarios.FirstOrDefault(s => s.Id == id)
            ?? throw new InvalidDataException("Unknown permission scenario.");
        ClearPreview();
        _permissionScenarioId = id;
        if (scenario.MissingAccess) _previewLogAccess[config.SourceId] = false;
        if (scenario.SourcesNotFound) _previewDiscovery = false;
        return new(config, scenario, await GetSourcesAsync(ct));
    }

    public async Task<SourcePermissionData> RetrySourcePermissionAsync(string sourceId, CancellationToken ct = default)
    {
        var current = await GetSourcePermissionAsync(ct);
        if (!current.Sources.Sources.Any(s => s.Id == sourceId))
            throw new InvalidDataException("Unknown permission source.");
        // Kịch bản xem trước "vẫn bị từ chối" giữ nguyên; còn lại kiểm tra lại thư mục thật.
        if (current.Scenario.RetryResult != "denied") ClearPreview();
        var refreshed = await GetSourcePermissionAsync(ct);
        return refreshed with { Scenario = current.Scenario.RetryResult == "denied" ? current.Scenario : refreshed.Scenario };
    }
}
