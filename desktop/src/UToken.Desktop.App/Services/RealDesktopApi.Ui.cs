using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using UToken.Core.Pricing;
using UToken.Desktop.App.Models;

namespace UToken.Desktop.App.Services;

/// <summary>Cài đặt, chẩn đoán, first-run và nội dung các màn trạng thái giao diện.</summary>
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

    /// <summary>Đăng ký khởi động cùng hệ điều hành; null thì "Launch at startup" chỉ được lưu, không áp dụng (dùng trong test).</summary>
    public StartupRegistration? Startup { get; init; }

    private SettingsData WithLocalMetadata(SettingsData data) => data with
    {
        // Phản ánh trạng thái thật trên máy; chưa có server phát hành nên không có tự cập nhật.
        Values = data.Values with
        {
            LaunchAtStartup = Startup is { IsSupported: true } st ? st.IsEnabled() : data.Values.LaunchAtStartup,
            AutomaticUpdates = false,
        },
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
        values = values with { AutomaticUpdates = false };
        Startup?.Apply(values.LaunchAtStartup);
        if (_localSettings is not null) await _localSettings.SaveAsync(values, ct);
        _localSettings?.Record($"Settings saved: startup={values.LaunchAtStartup}, background={values.BackgroundCollection}, notifications={values.UsageNotifications}, retention={values.RetentionDays}d");
        return _settings = settings with { Values = values };
    }

    public async Task<SettingsData> ResetSettingsAsync(CancellationToken ct = default)
    {
        var defaults = await ReadContentAsync<SettingsData>("settings.json", ct);
        Startup?.Apply(defaults.Values.LaunchAtStartup);
        if (_localSettings is not null) await _localSettings.SaveAsync(defaults.Values with { AutomaticUpdates = false }, ct);
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

        AppendJudgeDiagnostics(report);
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

    // ───────────────────────── Nội dung các màn trạng thái ─────────────────────────

    public Task<OverviewScenario[]> GetOverviewScenariosAsync(CancellationToken ct = default) =>
        ReadContentAsync<OverviewScenario[]>("overview-states.json", ct);

    // ───────────────────────── Quyền đọc thư mục log ─────────────────────────

    public async Task<SourcePermissionData> GetSourcePermissionAsync(CancellationToken ct = default)
    {
        var config = await ReadContentAsync<SourcePermissionConfig>("source-permission.json", ct);
        var sources = await GetSourcesAsync(ct);
        var blocked = sources.Sources.FirstOrDefault(s => s.CollectorState == "permission_required");
        if (blocked is not null) config = config with { SourceId = blocked.Id };
        // Trạng thái thật: có nguồn không đọc được thư mục thì "permission-required", ngược lại "normal".
        var scenario = config.Scenarios.FirstOrDefault(s => s.Id == (blocked is null ? "normal" : "permission-required"))
            ?? config.Scenarios.First();
        return new(config, scenario, sources);
    }

    /// <summary>Kiểm tra lại quyền đọc thư mục; đọc được thì quét luôn nguồn đó.</summary>
    public async Task<SourcePermissionData> RetrySourcePermissionAsync(string sourceId, CancellationToken ct = default)
    {
        var location = _locations.FirstOrDefault(l => l.Id == sourceId) ?? throw new InvalidDataException("Unknown permission source.");
        if (CheckFolder(location) == FolderState.Running)
            await WithStoreAsync(() => _engine.Scan([location.Provider], ct), ct);
            DataChanged();
        return await GetSourcePermissionAsync(ct);
    }
}
