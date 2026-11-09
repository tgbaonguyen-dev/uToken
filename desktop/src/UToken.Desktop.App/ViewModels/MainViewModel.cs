using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace UToken.Desktop.App.ViewModels;

public partial class MainViewModel(Services.IDesktopApi api, bool showSetupOnStart = false, Services.DesktopUiStateStore? uiStateStore = null, TimeProvider? timeProvider = null, Services.DesktopGoogleAuth? googleAuth = null) : ObservableObject
{
    [ObservableProperty, NotifyPropertyChangedFor(nameof(IsActivityEmpty)), NotifyPropertyChangedFor(nameof(DisplayedCollector))] private Models.OverviewData? _overview;
    [ObservableProperty, NotifyPropertyChangedFor(nameof(IsSourceListEmpty)), NotifyPropertyChangedFor(nameof(HasPermissionIssue)), NotifyPropertyChangedFor(nameof(IsPermissionRequired)), NotifyPropertyChangedFor(nameof(IsSourcesNormal)), NotifyPropertyChangedFor(nameof(PermissionSource)), NotifyPropertyChangedFor(nameof(PermissionProviders)), NotifyPropertyChangedFor(nameof(Subtitle)), NotifyPropertyChangedFor(nameof(HasNoSupportedSources)), NotifyPropertyChangedFor(nameof(IsSourceNotFound)), NotifyPropertyChangedFor(nameof(DiscoveryProviders)), NotifyPropertyChangedFor(nameof(PageTitle))] private Models.SourcesData? _sourceList;
    [ObservableProperty, NotifyPropertyChangedFor(nameof(DiscoveryProviders))] private Models.SupportedSourceData[] _supportedSources = [];
    [ObservableProperty, NotifyPropertyChangedFor(nameof(PageTitle))] private Models.SourceData? _selectedSource;
    [ObservableProperty] private string _page = "overview";
    [ObservableProperty] private bool _isBusy;
    [ObservableProperty] private string? _error;
    [ObservableProperty] private string _notice = "Demo mode · Sample data";
    [ObservableProperty] private string _selectedPeriod = "30 days";
    private bool _startupLoaded;
    private string _loadedPeriod = "30 days";
    private bool _restoringPeriod;
    public string[] Periods { get; } = ["1 day", "Week", "30 days", "Total"];
    partial void OnSelectedPeriodChanged(string value)
    {
        if (IsDetail && !IsBusy && !_restoringPeriod) _ = ChangePeriodCommand.ExecuteAsync(null);
    }
    public bool IsOverview => Page == "overview";
    public bool IsSources => Page == "sources";
    public bool IsDetail => Page == "detail";
    public bool IsSourceSection => IsSources || IsDetail;
    public bool HasError => Error is not null;
    public bool IsActivityEmpty => Overview?.Activity.Length == 0;
    public bool IsSourceListEmpty => SourceList?.Sources.Length == 0;
    public string PageTitle => Page switch
    {
        "first-run" => FirstRun?.Title ?? "Set up automatic tracking", "overview" => IsOverviewState ? OverviewPreview!.Scenario.Title : "Collector", "sources" => IsSourcesStatePreview ? SectionScenario!.Title : IsScanningSources ? "Scanning local usage" : IsSourceNotFound ? NotFoundScenario?.Title ?? "No supported source found" : "Sources", "activity" => "Activity",
        "settings" => "Settings", "sync" => IsSyncStatePreview ? ActiveSyncScenario!.Title : "Sync", "pairing" => ActivePairingScenario?.Title ?? (HasDevice ? "Device information" : "Pair mobile device"), _ => SelectedSource?.Name ?? "Source",
    };
    public string Subtitle => Page switch
    {
        "first-run" => FirstRun?.Subtitle ?? "Three steps to connect your AI usage securely.",
        "overview" => IsOverviewState ? OverviewPreview!.Scenario.Subtitle : "Live ingestion from this device",
        "sources" => IsSourcesStatePreview ? SectionScenario!.Subtitle : IsScanningSources ? "Checking supported provider sources on this device." : IsSourceNotFound ? NotFoundScenario?.Description ?? "Install or use a supported AI tool, then rescan." : IsPermissionRequired ? "Collector access and provider availability." : "Providers detected on this computer and their collection health.",
        "activity" => "A live, searchable stream of collected usage events.",
        "settings" => "Collector behavior, privacy, retention, and maintenance.",
        "sync" => IsSyncStatePreview ? ActiveSyncScenario!.Subtitle : "Mobile connection, encrypted transfer, and synchronization history.",
        "pairing" => ActivePairingScenario?.Subtitle ?? (HasDevice ? "Connected mobile device, privacy, and supported sources." : "Enter the one-time code shown in the mobile app."),
        _ => "Provider usage, models, and collector health.",
    };
    partial void OnErrorChanged(string? value) => OnPropertyChanged(nameof(HasError));
    partial void OnPageChanged(string value)
    {
        OnPropertyChanged(nameof(IsDemoSync)); OnPropertyChanged(nameof(IsDemoPairing));
        foreach (var name in new[] { nameof(IsOverview), nameof(IsSources), nameof(IsDetail), nameof(IsSourceSection), nameof(PageTitle), nameof(Subtitle), nameof(IsActivityPage), nameof(IsSyncPage), nameof(IsPairingPage), nameof(IsOverviewSection), nameof(IsSyncSection), nameof(IsSettingsPage), nameof(IsFirstRunPage), nameof(CanNavigate), nameof(CanSkipSetup), nameof(IsOverviewDashboard), nameof(IsOverviewState), nameof(DisplayedCollector), nameof(IsPermissionRequired), nameof(IsSourcesNormal), nameof(IsSourceNotFound), nameof(IsSourcesStatePreview), nameof(IsSyncStatePreview), nameof(IsSectionStatePreview), nameof(IsSyncNormal), nameof(ActiveSyncScenario), nameof(IsSyncDetailState), nameof(IsSyncFailure), nameof(IsSyncProgress), nameof(SyncStateDetails), nameof(ActivePairingScenario), nameof(IsPairingStateVisible), nameof(IsPairingFormVisible), nameof(IsPairingVerifying) }) OnPropertyChanged(name);
        NotifyVisualStatus();
        SkipSetupCommand.NotifyCanExecuteChanged();
    }
    private async Task RunAsync(Func<Task> action)
    {
        if (IsBusy) return;
        IsBusy = true; Error = null;
        try { await action(); }
        catch (Services.FirebaseSessionExpiredException ex) { Sync = null; GoogleAccount = ex.Message; Error = ex.Message; }
        catch (Exception ex) when (ex is HttpRequestException or OperationCanceledException or System.Net.HttpListenerException or InvalidOperationException or System.Security.Cryptography.CryptographicException or System.ComponentModel.Win32Exception)
        { Error = ex is InvalidOperationException ? ex.Message : "Could not complete the Firebase request. Check your connection, sign-in and Firebase configuration, then retry."; }
        catch (Exception ex) when (ex is System.IO.IOException or System.IO.InvalidDataException or System.Text.Json.JsonException or UnauthorizedAccessException)
        { Error = IsSettingsPage ? "Could not read or save settings. Check folder permissions. For invalid settings JSON, Restore defaults resets your preferences." : "Could not load demo data. Please try again."; }
        finally { IsBusy = false; }
    }
    [RelayCommand]
    private Task LoadAsync() => RunAsync(async () =>
    {
        RestoreUiPreferences();
        var overview = await api.GetOverviewAsync();
        var sources = await api.GetSourcesAsync();
        var supported = await api.GetSupportedSourcesAsync();
        Overview = overview; SourceList = sources; SupportedSources = supported;
        await LoadOverviewScenariosCoreAsync();
        SyncStateConfig = await api.GetSyncStateConfigAsync();
        ApplySourcePermission(await api.GetSourcePermissionAsync());
        if (showSetupOnStart && !_startupLoaded)
        {
            ApplySettings(await api.GetSettingsAsync());
            if (!await api.IsSetupCompleteAsync())
            {
                FirstRun = await api.GetFirstRunAsync();
                SetupStepIndex = 0; Page = "first-run";
            }
            _startupLoaded = true;
        }
        if (IsSettingsPage) ApplySettings(await api.GetSettingsAsync());
        if (IsActivityPage) await LoadActivityCoreAsync();
        if (IsSyncPage) Sync = await api.GetSyncAsync();
        if (IsPairingPage) await LoadPairingPageCoreAsync();
        if (IsDetail && SelectedSource is not null)
        {
            SelectedSource = await api.GetSourceAsync(SelectedSource.Id, SelectedPeriod);
            _loadedPeriod = SelectedPeriod;
        }
    });
    [RelayCommand] private void ShowOverview() { if (!IsBusy && CanNavigate) Page = "overview"; }
    [RelayCommand] private void ShowSources() { if (!IsBusy && CanNavigate) { ResetSectionPreview(); if (SourcePermission is not null) ApplySourcePermission(SourcePermission); Page = "sources"; } }
    [RelayCommand]
    private Task OpenSourceAsync(Models.SourceData source) => NavigateAsync(async () =>
    {
        RestoreUiPreferences();
        SelectedSource = await api.GetSourceAsync(source.Id, SelectedPeriod);
        _loadedPeriod = SelectedPeriod;
        Page = "detail";
    });
    [RelayCommand]
    private async Task ChangePeriodAsync()
    {
        await RunAsync(async () =>
        {
            if (SelectedSource is null) return;
            SelectedSource = await api.GetSourceAsync(SelectedSource.Id, SelectedPeriod);
            _loadedPeriod = SelectedPeriod;
            SaveUiPreferences();
        });
        if (HasError)
        {
            _restoringPeriod = true;
            SelectedPeriod = _loadedPeriod;
            _restoringPeriod = false;
        }
    }

}
