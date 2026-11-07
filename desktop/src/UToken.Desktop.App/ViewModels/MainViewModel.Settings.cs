using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using UToken.Desktop.App.Models;
namespace UToken.Desktop.App.ViewModels;

public partial class MainViewModel
{
    [ObservableProperty] private SettingsData? _settings;
    [ObservableProperty] private bool _launchAtStartup;
    [ObservableProperty] private bool _backgroundCollection;
    [ObservableProperty] private bool _automaticUpdates;
    [ObservableProperty] private bool _usageNotifications;
    [ObservableProperty, NotifyPropertyChangedFor(nameof(SelectedRetention))] private int _retentionDays;
    public object SelectedRetention
    {
        get => RetentionDays;
        // ComboBox clears selection temporarily when its items are replaced.
        set { if (value is int days) RetentionDays = days; }
    }
    [ObservableProperty, NotifyPropertyChangedFor(nameof(HasSettingsMessage))] private string? _settingsMessage;
    public bool HasSettingsMessage => !string.IsNullOrEmpty(SettingsMessage);
    [ObservableProperty] private bool _confirmClearData;
    [ObservableProperty, NotifyPropertyChangedFor(nameof(HasDiagnosticsReport))] private string? _diagnosticsReport;
    public bool HasDiagnosticsReport => DiagnosticsReport is not null;
    public bool IsSettingsPage => Page == "settings";

    private void ApplySettings(SettingsData data)
    {
        Settings = data;
        LaunchAtStartup = data.Values.LaunchAtStartup;
        BackgroundCollection = data.Values.BackgroundCollection;
        AutomaticUpdates = data.Values.AutomaticUpdates;
        UsageNotifications = data.Values.UsageNotifications;
        RetentionDays = data.Values.RetentionDays;
        OnPropertyChanged(nameof(SelectedRetention));
    }

    [RelayCommand] private Task ShowSettingsAsync() => NavigateAsync(async () =>
    {
        Page = "settings"; SettingsMessage = null; ConfirmClearData = false;
        ApplySettings(await api.GetSettingsAsync());
    });
    [RelayCommand] private Task SaveSettingsAsync() => RunAsync(async () =>
    {
        ApplySettings(await api.SaveSettingsAsync(new(LaunchAtStartup, BackgroundCollection,
            AutomaticUpdates, UsageNotifications, RetentionDays)));
        SettingsMessage = Settings!.IsPersistent ? "Settings saved on this computer. Collector behavior is still simulated." : "Settings saved for this test session.";
    });
    [RelayCommand] private Task ResetSettingsAsync() => RunAsync(async () =>
    {
        ApplySettings(await api.ResetSettingsAsync());
        SettingsMessage = "Default settings restored.";
    });
    [RelayCommand] private void SettingsAction(string action)
    {
        if (IsBusy || Settings is null) return;
        SettingsMessage = action switch
        {
            "updates" => Settings.UpdateMessage,
            "clear" => "Clearing local data is not available yet. Records are retained.",
            _ => null,
        };
        ConfirmClearData = false;
    }
    [RelayCommand] private Task OpenDiagnosticsAsync() => RunAsync(async () =>
        DiagnosticsReport = await api.GetDiagnosticsAsync());
    [RelayCommand] private void CloseDiagnostics() => DiagnosticsReport = null;
    public void ReportFolderResult(bool success) =>
        SettingsMessage = success ? "Data folder opened." : "Could not open the data folder.";
    public async Task<string?> ExportSettingsCsvAsync()
    {
        string? csv = null;
        await RunAsync(async () =>
        {
            var collected = await api.ExportActivityAsync(new ActivityQuery(Period: "All time"));
            var warnings = await api.ExportActivityAsync(new ActivityQuery(Period: "All time", WarningsOnly: true));
            csv = collected + warnings[(warnings.IndexOf('\n') + 1)..];
        });
        return csv;
    }
    [RelayCommand] private void RequestClearData() { if (!IsBusy) ConfirmClearData = true; }
    [RelayCommand] private void CancelClearData() => ConfirmClearData = false;
}
