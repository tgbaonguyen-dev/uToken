using System.Text.Json;
using UToken.Desktop.App.Models;

namespace UToken.Desktop.App.Services;

public sealed record WindowPlacement(double Width = 1180, double Height = 760, int? X = null, int? Y = null, bool Maximized = false);
public sealed record DesktopUiState(WindowPlacement Window, ActivityQuery Activity, string SourcePeriod)
{
    public static DesktopUiState Default => new(new(), new(), "30 days");
}

public sealed class DesktopUiStateStore
{
    private readonly LocalSettingsStore _settings;
    public string FilePath => Path.Combine(_settings.DirectoryPath, "ui-state.json");
    public DesktopUiState State { get; private set; }
    private static readonly JsonSerializerOptions Options = new() { WriteIndented = true, RespectRequiredConstructorParameters = true };
    public DesktopUiStateStore(LocalSettingsStore settings)
    {
        _settings = settings;
        State = DesktopUiState.Default;
        try
        {
            if (File.Exists(FilePath))
            {
                var value = JsonSerializer.Deserialize<DesktopUiState>(File.ReadAllText(FilePath), Options);
                if (value?.Window is null || value.Activity is null || value.SourcePeriod is null ||
                    !double.IsFinite(value.Window.Width) || !double.IsFinite(value.Window.Height) ||
                    value.Window.Width is < 100 or > 10000 || value.Window.Height is < 100 or > 10000 ||
                    value.Activity.Provider is null || value.Activity.Model is null || value.Activity.Search is null ||
                    value.Activity.Search.Length > 2048 ||
                    value.Activity.Period is not ("Last 24h" or "Last 7 days" or "All time") ||
                    value.SourcePeriod is not ("1 day" or "Week" or "30 days" or "Total"))
                    throw new InvalidDataException("Invalid UI preferences.");
                State = value;
            }
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or JsonException or InvalidDataException)
        { _settings.Record("UI preferences load failed: " + ex.GetType().Name); }
    }
    public bool SaveFilters(ActivityQuery query, string period)
    {
        State = State with { Activity = query with { Search = query.Search[..Math.Min(query.Search.Length, 2048)] }, SourcePeriod = period };
        return Save();
    }
    public bool SaveWindow(WindowPlacement placement)
    {
        State = State with { Window = placement };
        return Save();
    }
    private bool Save()
    {
        var temporary = FilePath + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            Directory.CreateDirectory(_settings.DirectoryPath);
            File.WriteAllText(temporary, JsonSerializer.Serialize(State, Options));
            File.Move(temporary, FilePath, overwrite: true);
            return true;
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        { _settings.Record("UI preferences save failed: " + ex.GetType().Name); return false; }
        finally
        {
            try { if (File.Exists(temporary)) File.Delete(temporary); }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException) { }
        }
    }
}
