using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.Json;
using UToken.Desktop.App.Models;
namespace UToken.Desktop.App.Services;

public sealed partial class MockDesktopApi
{
    private SettingsData? _settings;
    private static string BuildVersion => typeof(MockDesktopApi).Assembly
        .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion
        ?? typeof(MockDesktopApi).Assembly.GetName().Version?.ToString() ?? "Unknown";

    private SettingsData WithLocalMetadata(SettingsData data) => data with
    {
        DataPath = localSettings?.DirectoryPath ?? Path.GetFullPath(_directory),
        AppVersion = BuildVersion,
        IsPersistent = localSettings is not null,
    };

    public async Task<SettingsData> GetSettingsAsync(CancellationToken ct = default)
    {
        if (_settings is not null) return _settings;
        var defaults = await ReadAsync<SettingsData>("settings.json", ct);
        var values = localSettings is null ? defaults.Values :
            await localSettings.LoadAsync(defaults.Values, defaults.RetentionOptions, ct);
        return _settings = WithLocalMetadata(defaults with { Values = values });
    }

    public async Task<SettingsData> SaveSettingsAsync(CollectorSettings values, CancellationToken ct = default)
    {
        var settings = await GetSettingsAsync(ct);
        if (!settings.RetentionOptions.Contains(values.RetentionDays))
            throw new InvalidDataException("Unsupported retention period.");
        if (localSettings is not null) await localSettings.SaveAsync(values, ct);
        return _settings = settings with { Values = values };
    }

    public async Task<SettingsData> ResetSettingsAsync(CancellationToken ct = default)
    {
        var defaults = await ReadAsync<SettingsData>("settings.json", ct);
        if (localSettings is not null) await localSettings.SaveAsync(defaults.Values, ct);
        return _settings = WithLocalMetadata(defaults);
    }

    public async Task<string> GetDiagnosticsAsync(CancellationToken ct = default)
    {
        var report = new StringBuilder()
            .AppendLine($"App version: {BuildVersion}")
            .AppendLine($"OS: {RuntimeInformation.OSDescription}")
            .AppendLine($"Runtime: {RuntimeInformation.FrameworkDescription}")
            .AppendLine($"Architecture: {RuntimeInformation.ProcessArchitecture}")
            .AppendLine("Collector: Mock usage service; provider logs are not accessed.")
            .AppendLine($"Settings storage: {localSettings?.DirectoryPath ?? "In-memory test/demo session"}")
            .AppendLine("Mock JSON syntax checks (not collector health):");
        foreach (var name in new[] { "overview.json", "sources.json", "source-periods.json", "activity.json", "sync.json", "pairing.json", "supported-sources.json", "settings.json", "first-run.json", "overview-states.json", "source-permission.json", "source-scan.json", "sync-states.json", "pairing-states.json" })
        {
            try
            {
                await using var stream = File.OpenRead(Path.Combine(_directory, name));
                using var document = await JsonDocument.ParseAsync(stream, cancellationToken: ct);
                report.AppendLine($"  {name}: OK");
            }
            catch (Exception ex) when (ex is IOException or JsonException or UnauthorizedAccessException)
            {
                report.AppendLine($"  {name}: {ex.GetType().Name}");
                localSettings?.Record($"Diagnostics JSON check failed ({name}): {ex.GetType().Name}");
            }
        }
        if (localSettings is not null)
        {
            localSettings.Record("Diagnostics opened");
            report.AppendLine("Recent application log:");
            try
            {
                if (File.Exists(localSettings.LogPath))
                    foreach (var line in (await File.ReadAllLinesAsync(localSettings.LogPath, ct)).TakeLast(30))
                        report.AppendLine(line);
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            { report.AppendLine("Log unavailable: " + ex.GetType().Name); }
        }
        return report.ToString();
    }
}
