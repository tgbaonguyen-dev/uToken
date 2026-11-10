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
    public string CloudSyncLabel => Sync?.Device is { } account ? $"Signed in · {account.Name}" : "Not signed in";

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

    [RelayCommand] private Task ShowSettingsAsync()
    {
        if (!CanNavigate) return Task.CompletedTask;
        Page = "settings"; SettingsMessage = null; ConfirmClearData = false; JudgeMessage = null;
        return LoadPageAsync(async version =>
        {
            var settings = await api.GetSettingsAsync();
            var judge = await api.GetJudgeSettingsAsync();
            if (!IsCurrentLoad(version)) return;
            ApplySettings(settings); ApplyJudge(judge);
        });
    }
    [RelayCommand] private Task SaveSettingsAsync() => RunAsync(async () =>
    {
        ApplySettings(await api.SaveSettingsAsync(new(LaunchAtStartup, BackgroundCollection,
            AutomaticUpdates, UsageNotifications, RetentionDays)));
        SettingsMessage = "Settings saved." + (LaunchAtStartup ? " uToken starts when you sign in to this computer." : "")
            + (BackgroundCollection ? " Usage is collected and synced in the background." : "");
    });
    [RelayCommand] private Task ResetSettingsAsync() => RunAsync(async () =>
    {
        ApplySettings(await api.ResetSettingsAsync());
        SettingsMessage = "Default settings restored.";
    });
    /// <summary>"clear": xóa thật toàn bộ usage trên máy (log cũ không bị đọc lại; dữ liệu trên cloud giữ nguyên).</summary>
    [RelayCommand] private Task SettingsActionAsync(string action) => RunAsync(async () =>
    {
        if (Settings is null || action != "clear") return;
        var removed = await api.ClearLocalDataAsync();
        ConfirmClearData = false;
        Overview = await api.GetOverviewAsync();
        ApplySourcePermission(await api.GetSourcePermissionAsync());
        SettingsMessage = $"Cleared {removed:N0} usage events from this computer. New usage will be collected from now on.";
    });
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
