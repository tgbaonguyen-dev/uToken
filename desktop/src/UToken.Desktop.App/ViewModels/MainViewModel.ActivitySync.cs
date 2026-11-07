using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using System.Collections.ObjectModel;
using UToken.Desktop.App.Models;

namespace UToken.Desktop.App.ViewModels;

public sealed partial class PairingDigit : ObservableObject
{
    [ObservableProperty] private string _text = "";
}

public partial class MainViewModel
{
    [ObservableProperty, NotifyPropertyChangedFor(nameof(IsActivityListEmpty))] private ActivityPageData? _activityPage;
    [ObservableProperty] private UsageActivity? _selectedActivity;
    [ObservableProperty] private string _activityProvider = "All sources";
    [ObservableProperty] private string _activityModel = "All models";
    [ObservableProperty] private string _activityPeriod = "Last 24h";
    [ObservableProperty] private string _activitySearch = "";
    [ObservableProperty, NotifyPropertyChangedFor(nameof(IsCollectedTab))] private bool _warningsOnly;
    [ObservableProperty, NotifyPropertyChangedFor(nameof(HasDevice)), NotifyPropertyChangedFor(nameof(HasNoDevice)), NotifyPropertyChangedFor(nameof(IsSyncHistoryEmpty)), NotifyPropertyChangedFor(nameof(IsPaired)), NotifyPropertyChangedFor(nameof(CanEnterPairing)), NotifyPropertyChangedFor(nameof(PairingActionLabel)), NotifyPropertyChangedFor(nameof(PairingMessageColor)), NotifyPropertyChangedFor(nameof(PageTitle)), NotifyPropertyChangedFor(nameof(Subtitle))] private SyncData? _sync;
    [ObservableProperty] private bool _confirmDisconnect;
    [ObservableProperty] private bool _isSyncing;
    partial void OnIsSyncingChanged(bool value) => NotifySyncState();
    partial void OnSyncChanged(SyncData? value) { NotifySyncState(); NotifyPairingState(); }
    [ObservableProperty, NotifyPropertyChangedFor(nameof(HasSyncMessage))] private string _syncMessage = "";
    [ObservableProperty] private string _syncMessageColor = "#2EC790";
    [ObservableProperty] private PairingData? _pairing;
    [ObservableProperty, NotifyPropertyChangedFor(nameof(PairingMessageColor)), NotifyPropertyChangedFor(nameof(IsPaired)), NotifyPropertyChangedFor(nameof(CanEnterPairing))] private string _pairingState = "waiting";
    partial void OnPairingStateChanged(string value) => SyncPairingSelection();
    [ObservableProperty] private string _pairingMessage = "";
    public ObservableCollection<string> ActivityProviders { get; } = ["All sources"];
    public ObservableCollection<string> ActivityModels { get; } = ["All models"];
    public ObservableCollection<string> ActivityPeriods { get; } = ["Last 24h"];
    public PairingDigit[] PairingDigits { get; } = Enumerable.Range(0, 6).Select(_ => new PairingDigit()).ToArray();
    public bool IsActivityPage => Page == "activity";
    public bool IsSyncPage => Page == "sync";
    public bool IsPairingPage => Page == "pairing";
    public bool IsOverviewSection => IsOverview || IsActivityPage || IsFirstRunPage;
    public bool IsSyncSection => IsSyncPage || IsPairingPage;
    public bool IsActivityListEmpty => ActivityPage?.Events.Length == 0;
    public bool IsCollectedTab => !WarningsOnly;
    public bool HasDevice => Sync?.Device is not null;
    public bool HasNoDevice => Sync is not null && Sync.Device is null;
    public bool IsSyncHistoryEmpty => Sync?.History.Length == 0;
    public bool HasSyncMessage => !string.IsNullOrEmpty(SyncMessage);
    public bool IsPaired => HasDevice;
    public string PairingActionLabel => HasDevice ? "Device information" : "Pair new device";
    public bool CanEnterPairing => !IsPaired;
    public string PairingMessageColor => IsPaired ? "#2EC790" : "#F26039";

    public ActivityQuery CurrentActivityQuery => new(ActivityProvider, ActivityModel, ActivityPeriod, ActivitySearch, WarningsOnly);
    private async Task LoadActivityCoreAsync()
    {
        RestoreUiPreferences();
        var result = await api.GetActivityAsync(CurrentActivityQuery);
        // Keep selector collections stable when replacing the response, preserving the selected filters.
        foreach (var value in result.Providers) if (!ActivityProviders.Contains(value)) ActivityProviders.Add(value);
        foreach (var value in result.Models) if (!ActivityModels.Contains(value)) ActivityModels.Add(value);
        foreach (var value in result.Periods) if (!ActivityPeriods.Contains(value)) ActivityPeriods.Add(value);
        var invalidProvider = !result.Providers.Contains(ActivityProvider) && ActivityProvider != "All sources";
        var invalidModel = !result.Models.Contains(ActivityModel) && ActivityModel != "All models";
        if (invalidProvider || invalidModel)
        {
            if (invalidProvider) ActivityProvider = "All sources";
            if (invalidModel) ActivityModel = "All models";
            result = await api.GetActivityAsync(CurrentActivityQuery);
        }
        ActivityPage = result;
        SelectedActivity = result.Events.FirstOrDefault(e => e.Id == SelectedActivity?.Id) ?? result.Events.FirstOrDefault();
        SaveUiPreferences();
    }
    [RelayCommand]
    private Task ShowActivityAsync() => NavigateAsync(async () => { Page = "activity"; await LoadActivityCoreAsync(); });
    [RelayCommand] private Task RefreshActivityAsync() => RunAsync(LoadActivityCoreAsync);
    [RelayCommand]
    private Task ShowCollectedAsync() => RunAsync(async () => { WarningsOnly = false; await LoadActivityCoreAsync(); });
    [RelayCommand]
    private Task ShowWarningsAsync() => RunAsync(async () => { WarningsOnly = true; await LoadActivityCoreAsync(); });
    public async Task<string?> ExportActivityCsvAsync()
    {
        string? csv = null;
        await RunAsync(async () =>
        {
            await LoadActivityCoreAsync();
            csv = await api.ExportActivityAsync(CurrentActivityQuery);
        });
        return csv;
    }
    public void ReportExportResult(bool success) => Notice = success ? "Activity exported successfully." : "Could not save the export. Choose another location and try again.";

    [RelayCommand]
    private Task ShowSyncAsync() => NavigateAsync(async () => { ResetSectionPreview(); Page = "sync"; ConfirmDisconnect = false; Sync = await api.GetSyncAsync(); });
    [RelayCommand]
    private Task SyncNowAsync() => RunAsync(async () =>
    {
        IsSyncing = true; SyncMessage = "Synchronizing demo usage metadata...";
        try
        {
            var result = await api.SyncNowAsync();
            Sync = result.Data; SyncMessage = result.Message;
            SetSyncResultState(result.State);
            if (result.State == "success" && Overview is not null)
                Overview = Overview with { Collector = Overview.Collector with { LastSyncAt = Sync.Device?.LastSyncAt, ReferenceTime = Sync.ReferenceTime } };
            SyncMessageColor = result.State is "success" or "no_new_usage" ? "#2EC790" : "#F26039";
        }
        catch { SetSyncResultState("failed"); SyncMessage = "Sync did not complete. Please try again."; SyncMessageColor = "#F26039"; throw; }
        finally { IsSyncing = false; }
    });
    [RelayCommand] private void RequestDisconnect() { if (!IsBusy) ConfirmDisconnect = true; }
    [RelayCommand] private void CancelDisconnect() => ConfirmDisconnect = false;
    [RelayCommand]
    private Task DisconnectAsync() => RunAsync(async () =>
    {
        Sync = await api.DisconnectAsync(); ConfirmDisconnect = false;
        SyncMessage = "Demo device disconnected. Pair a device to resume sync."; SyncMessageColor = "#9096A1";
    });
    private async Task StartPairingCoreAsync()
    {
        Pairing = await api.StartPairingAsync();
        foreach (var digit in PairingDigits) digit.Text = "";
        ResetPairingPreview();
        PairingState = "waiting"; PairingMessage = "";
    }
    private async Task LoadPairingPageCoreAsync()
    {
        PairingScenarios = await api.GetPairingScenariosAsync();
        ResetPairingPreview();
        SupportedSources = await api.GetSupportedSourcesAsync();
        Sync = await api.GetSyncAsync();
        if (HasDevice)
        {
            Pairing = await api.GetPairingInfoAsync();
            PairingState = "connected";
            PairingMessage = "Your mobile device is paired. Review its connection details below.";
        }
        else await StartPairingCoreAsync();
    }
    [RelayCommand]
    private Task ShowPairingAsync() => NavigateAsync(async () => { Page = "pairing"; await LoadPairingPageCoreAsync(); });
    [RelayCommand]
    private Task RestartPairingAsync() => RunAsync(async () => { if (!HasDevice) await StartPairingCoreAsync(); });
    [RelayCommand]
    private Task PairDeviceAsync() => RunAsync(async () =>
    {
        if (HasDevice) return;
        PairingState = "verifying"; PairingMessage = "Verifying code...";
        try
        {
            var result = await api.PairDeviceAsync(string.Concat(PairingDigits.Select(d => d.Text)));
            PairingState = result.State; PairingMessage = result.Message;
            if (result.Data is not null) { Sync = result.Data; SyncMessage = ""; }
        }
        catch { PairingState = "error"; PairingMessage = "Pairing did not complete. Please try again."; throw; }
    });
}
