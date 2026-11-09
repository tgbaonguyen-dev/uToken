using System.Text.Json;
using UToken.Desktop.App.Models;

namespace UToken.Desktop.App.Services;

public sealed class LocalSettingsStore(string directory)
{
    public static string DefaultDirectory => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "uToken");
    public string DirectoryPath { get; } = Path.GetFullPath(directory);
    public string SettingsPath => Path.Combine(DirectoryPath, "settings.json");
    public string LogPath => Path.Combine(DirectoryPath, "diagnostics.log");
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true, RespectRequiredConstructorParameters = true, WriteIndented = true,
    };

    public async Task<CollectorSettings> LoadAsync(CollectorSettings defaults, int[] allowedDays, CancellationToken ct)
    {
        Directory.CreateDirectory(DirectoryPath);
        if (!File.Exists(SettingsPath)) return defaults;
        try
        {
            await using var stream = File.OpenRead(SettingsPath);
            var values = await JsonSerializer.DeserializeAsync<CollectorSettings>(stream, JsonOptions, ct)
                ?? throw new InvalidDataException("Empty local settings.");
            if (!allowedDays.Contains(values.RetentionDays)) throw new InvalidDataException("Unsupported retention period.");
            Record("Local settings loaded");
            return values;
        }
        catch (Exception ex) when (ex is IOException or JsonException or InvalidDataException or UnauthorizedAccessException)
        {
            Record("Local settings load failed: " + ex.GetType().Name);
            throw;
        }
    }

    public async Task SaveAsync(CollectorSettings values, CancellationToken ct)
    {
        Directory.CreateDirectory(DirectoryPath);
        var temporary = SettingsPath + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            await File.WriteAllTextAsync(temporary, JsonSerializer.Serialize(values, JsonOptions), ct);
            ct.ThrowIfCancellationRequested();
            File.Move(temporary, SettingsPath, overwrite: true);
            Record("Local settings saved");
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            Record("Local settings save failed: " + ex.GetType().Name);
            throw;
        }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }

    public void Record(string message)
    {
        try
        {
            Directory.CreateDirectory(DirectoryPath);
            // Keep diagnostics bounded and avoid recording exception messages or data payloads.
            if (File.Exists(LogPath) && new FileInfo(LogPath).Length > 262144)
                File.Move(LogPath, LogPath + ".previous", overwrite: true);
            File.AppendAllText(LogPath, $"{DateTimeOffset.Now:O} {message}{Environment.NewLine}");
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException) { }
    }
}
