namespace UToken.Desktop.App.Models;

public record CollectorSettings(bool LaunchAtStartup, bool BackgroundCollection, bool AutomaticUpdates,
    bool UsageNotifications, int RetentionDays, bool ShareProjectNames = true);
public record SettingsData(CollectorSettings Values, int[] RetentionOptions, string DataPath,
    string AppVersion, string UpdateMessage, string Diagnostics, bool IsPersistent = false);
