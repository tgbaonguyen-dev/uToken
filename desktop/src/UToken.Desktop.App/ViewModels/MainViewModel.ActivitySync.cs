using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using System.Collections.ObjectModel;
using UToken.Desktop.App.Models;

namespace UToken.Desktop.App.ViewModels;

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
    partial void OnIsSyncingChanged(bool value) { NotifySyncState(); NotifyTopbar(); }
    partial void OnSyncChanged(SyncData? value)
    {
        if (Overview is { } overview)
            Overview = overview with { Collector = overview.Collector with
            { LastSyncAt = value?.Device?.LastSyncAt, ReferenceTime = value?.ReferenceTime ?? overview.Collector.ReferenceTime } };
        NotifySyncState(); NotifyPairingState(); OnPropertyChanged(nameof(CloudSyncLabel)); NotifyTopbar();
    }
    [ObservableProperty, NotifyPropertyChangedFor(nameof(HasSyncMessage))] private string _syncMessage = "";
    [ObservableProperty] private string _syncMessageColor = "#2EC790";
    [ObservableProperty] private PairingData? _pairing;
    [ObservableProperty, NotifyPropertyChangedFor(nameof(PairingMessageColor)), NotifyPropertyChangedFor(nameof(IsPaired)), NotifyPropertyChangedFor(nameof(CanEnterPairing))] private string _pairingState = "waiting";
    partial void OnPairingStateChanged(string value) => NotifyPairingState();
    [ObservableProperty] private string _pairingMessage = "";
    public ObservableCollection<string> ActivityProviders { get; } = ["All sources"];
    public ObservableCollection<string> ActivityModels { get; } = ["All models"];
    public ObservableCollection<string> ActivityPeriods { get; } = ["Last 24h"];
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
    public string PairingActionLabel => HasDevice ? "Google account" : "Sign in with Google";
    public bool CanEnterPairing => !IsPaired;
    public string PairingMessageColor => IsPaired ? "#2EC790" : "#F26039";

    public ActivityQuery CurrentActivityQuery => new(ActivityProvider, ActivityModel, ActivityPeriod, ActivitySearch, WarningsOnly);
    private int _activityLoadVersion;
    private async Task LoadActivityCoreAsync(int? pageVersion = null)
    {
        RestoreUiPreferences();
        var request = ++_activityLoadVersion;
        var version = pageVersion ?? _pageVersion;
        var query = CurrentActivityQuery;
        bool Current() => request == _activityLoadVersion && IsCurrentLoad(version) && CurrentActivityQuery == query;
        var result = await api.GetActivityAsync(query);
        if (!Current()) return;
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
            query = CurrentActivityQuery;
            result = await api.GetActivityAsync(query);
            if (!Current()) return;
        }
        ActivityPage = result;
        SelectedActivity = result.Events.FirstOrDefault(e => e.Id == SelectedActivity?.Id) ?? result.Events.FirstOrDefault();
        SaveUiPreferences();
    }
    [RelayCommand]
    private Task ShowActivityAsync()
    {
        if (!CanNavigate) return Task.CompletedTask;
        Page = "activity";
        return LoadPageAsync(version => LoadActivityCoreAsync(version));
    }
    [RelayCommand] private Task RefreshActivityAsync() => LoadPageAsync(version => LoadActivityCoreAsync(version));
    [RelayCommand]
    private Task ShowCollectedAsync() { WarningsOnly = false; return LoadPageAsync(version => LoadActivityCoreAsync(version)); }
    [RelayCommand]
    private Task ShowWarningsAsync() { WarningsOnly = true; return LoadPageAsync(version => LoadActivityCoreAsync(version)); }
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
    private Task ShowSyncAsync()
    {
        if (!CanNavigate) return Task.CompletedTask;
        ResetSectionPreview(); Page = "sync"; ConfirmDisconnect = false;
        return LoadPageAsync(async version =>
        {
            var sync = await api.GetSyncAsync();
            if (IsCurrentLoad(version)) Sync = sync;
        });
    }
    [RelayCommand]
    private Task SyncNowAsync() => RunAsync(async () =>
    {
        IsSyncing = true; SyncMessage = HasDevice ? "Analyzing local usage and uploading summaries..." : "Analyzing local usage...";
        try
        {
            var result = await api.SyncNowAsync(resendAll: true);
            ApplySyncResult(result);
            Notice = result.Message;
            await RefreshUsageAfterSyncAsync();
        }
        catch { SetSyncResultState("failed"); SyncMessage = "Sync did not complete. Please try again."; SyncMessageColor = "#F26039"; throw; }
        finally { IsSyncing = false; }
    });
    private void ApplySyncResult(SyncResult result)
    {
        Sync = result.Data; SyncMessage = result.Message;
        SetSyncResultState(result.State);
        SyncMessageColor = result.State is "success" or "no_new_usage" ? "#2EC790" : "#F26039";
    }
    private async Task RefreshUsageAfterSyncAsync()
    {
        Overview = await api.GetOverviewAsync();
        ApplySourcePermission(await api.GetSourcePermissionAsync());
        if (IsDetail && SelectedSource is { } source)
        {
            var period = SelectedPeriod;
            var detail = await api.GetSourceAsync(source.Id, period);
            if (IsDetail && SelectedSource?.Id == source.Id && SelectedPeriod == period)
            {
                SelectedSource = detail;
                _loadedPeriod = period;
            }
        }
        if (IsActivityPage) await LoadActivityCoreAsync();
    }
    [RelayCommand] private void RequestDisconnect() { if (!IsBusy) ConfirmDisconnect = true; }
    [RelayCommand] private void CancelDisconnect() => ConfirmDisconnect = false;
    [RelayCommand]
    private Task DisconnectAsync() => RunAsync(async () =>
    {
        try
        {
            CancelPageLoad();
            Sync = await api.DisconnectAsync(); ConfirmDisconnect = false; PairingState = "waiting";
            SyncMessage = "Signed out. Local usage collection continues; sign in again to resume cloud sync."; SyncMessageColor = "#9096A1";
        }
        catch (Exception ex) when (ex is System.IO.IOException or UnauthorizedAccessException)
        {
            Error = "Could not remove the saved sign-in session. Close applications using the session file, then retry Sign out before restarting the app.";
            SyncMessage = "Sign-out could not be saved."; SyncMessageColor = "#F26039";
        }
    });
    private async Task LoadPairingPageCoreAsync(int? pageVersion = null)
    {
        var version = pageVersion ?? _pageVersion;
        var scenarios = await api.GetPairingScenariosAsync();
        var supported = await api.GetSupportedSourcesAsync();
        var pairing = await api.GetPairingInfoAsync();
        var sync = await api.GetSyncAsync();
        if (!IsCurrentLoad(version)) return;
        PairingScenarios = scenarios; SupportedSources = supported; Pairing = pairing; Sync = sync;
        PairingState = HasDevice ? "connected" : "waiting";
        PairingMessage = HasDevice ? $"Signed in as {Sync.Device!.Name}." : "";
    }
    [RelayCommand]
    private Task ShowPairingAsync()
    {
        if (!CanNavigate) return Task.CompletedTask;
        Page = "pairing";
        return LoadPageAsync(version => LoadPairingPageCoreAsync(version));
    }
    [RelayCommand]
    private Task RestartPairingAsync() => RunAsync(async () => { if (!HasDevice) await LoadPairingPageCoreAsync(); });
    /// <summary>Mở trình duyệt đăng nhập Google; chờ tối đa 3 phút.</summary>
    [RelayCommand]
    private Task SignInAsync() => RunAsync(SignInCoreAsync);
    private async Task<bool> SignInCoreAsync()
    {
        if (HasDevice) return true;
        CancelPageLoad();
        PairingState = "verifying"; PairingMessage = "Finish signing in with Google in your browser...";
        try
        {
            var result = await api.SignInAsync();
            PairingState = result.State == "unavailable" ? "waiting" : result.State;
            PairingMessage = result.Message;
            if (result.Data is not null) { Sync = result.Data; SyncMessage = ""; SectionScenario = null; }
            return result.State == "success";
        }
        catch { PairingState = "rejected"; PairingMessage = "Sign-in did not complete. Please try again."; throw; }
    }
}
