using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace UToken.Desktop.App.ViewModels;

public partial class MainViewModel(Services.IDesktopApi api, bool showSetupOnStart = false, Services.DesktopUiStateStore? uiStateStore = null, TimeProvider? timeProvider = null) : ObservableObject
{
    [ObservableProperty, NotifyPropertyChangedFor(nameof(IsActivityEmpty)), NotifyPropertyChangedFor(nameof(DisplayedCollector))] private Models.OverviewData? _overview;
    [ObservableProperty, NotifyPropertyChangedFor(nameof(IsSourceListEmpty)), NotifyPropertyChangedFor(nameof(HasPermissionIssue)), NotifyPropertyChangedFor(nameof(IsPermissionRequired)), NotifyPropertyChangedFor(nameof(IsSourcesNormal)), NotifyPropertyChangedFor(nameof(PermissionSource)), NotifyPropertyChangedFor(nameof(PermissionProviders)), NotifyPropertyChangedFor(nameof(Subtitle)), NotifyPropertyChangedFor(nameof(HasNoSupportedSources)), NotifyPropertyChangedFor(nameof(IsSourceNotFound)), NotifyPropertyChangedFor(nameof(DiscoveryProviders)), NotifyPropertyChangedFor(nameof(PageTitle))] private Models.SourcesData? _sourceList;
    [ObservableProperty, NotifyPropertyChangedFor(nameof(DiscoveryProviders))] private Models.SupportedSourceData[] _supportedSources = [];
    [ObservableProperty, NotifyPropertyChangedFor(nameof(PageTitle))] private Models.SourceData? _selectedSource;
    [ObservableProperty] private string _page = "overview";
    [ObservableProperty, NotifyPropertyChangedFor(nameof(ShowProgress))] private bool _isBusy;
    /// <summary>Trang đang tải dữ liệu nền; khác IsBusy, không khóa điều hướng hay nút.</summary>
    [ObservableProperty, NotifyPropertyChangedFor(nameof(ShowProgress))] private bool _isLoading;
    public bool ShowProgress => IsBusy || IsLoading;
    private int _pageVersion;
    [ObservableProperty] private string? _error;
    [ObservableProperty] private string _notice = "Local data · usage metadata only";
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
        "settings" => "Settings", "pricing" => "Model pricing", "sync" => IsSyncStatePreview ? ActiveSyncScenario!.Title : "Sync", "pairing" => ActivePairingScenario?.Title ?? (HasDevice ? "Google account" : "Sign in with Google"), _ => SelectedSource?.Name ?? "Source",
    };
    public string Subtitle => Page switch
    {
        "first-run" => FirstRun?.Subtitle ?? "Three steps to connect your AI usage securely.",
        "overview" => IsOverviewState ? OverviewPreview!.Scenario.Subtitle : "Live ingestion from this device",
        "sources" => IsSourcesStatePreview ? SectionScenario!.Subtitle : IsScanningSources ? "Checking supported provider sources on this device." : IsSourceNotFound ? NotFoundScenario?.Description ?? "Install or use a supported AI tool, then rescan." : IsPermissionRequired ? "Collector access and provider availability." : "Providers detected on this computer and their collection health.",
        "activity" => "A live, searchable stream of collected usage events.",
        "settings" => "Collector behavior, privacy, retention, and maintenance.",
        "pricing" => "Current models.dev API rates used for estimated costs.",
        "sync" => IsSyncStatePreview ? ActiveSyncScenario!.Subtitle : "Google account, encrypted upload to Firebase, and synchronization history.",
        "pairing" => ActivePairingScenario?.Subtitle ?? (HasDevice ? "Signed-in account, privacy, and supported sources." : "Use the same Google account as uToken mobile."),
        _ => "Provider usage, models, and collector health.",
    };
    partial void OnErrorChanged(string? value) => OnPropertyChanged(nameof(HasError));
    partial void OnPageChanged(string value)
    {
        foreach (var name in new[] { nameof(IsOverview), nameof(IsSources), nameof(IsDetail), nameof(IsSourceSection), nameof(PageTitle), nameof(Subtitle), nameof(IsActivityPage), nameof(IsPricingPage), nameof(IsSyncPage), nameof(IsPairingPage), nameof(IsOverviewSection), nameof(IsSyncSection), nameof(IsSettingsPage), nameof(IsFirstRunPage), nameof(CanNavigate), nameof(CanSkipSetup), nameof(IsOverviewDashboard), nameof(IsOverviewState), nameof(DisplayedCollector), nameof(IsPermissionRequired), nameof(IsSourcesNormal), nameof(IsSourceNotFound), nameof(IsSourcesStatePreview), nameof(IsSyncStatePreview), nameof(IsSectionStatePreview), nameof(IsSyncNormal), nameof(ActiveSyncScenario), nameof(IsSyncDetailState), nameof(IsSyncFailure), nameof(IsSyncProgress), nameof(SyncStateDetails), nameof(ActivePairingScenario), nameof(IsPairingStateVisible), nameof(IsPairingFormVisible), nameof(IsPairingVerifying), nameof(OverviewStateId) }) OnPropertyChanged(name);
        NotifyVisualStatus();
        SkipSetupCommand.NotifyCanExecuteChanged();
    }
    private static bool IsDataError(Exception ex) => ex is System.IO.IOException or System.IO.InvalidDataException or System.Text.Json.JsonException or UnauthorizedAccessException;
    private string DataErrorMessage => IsSettingsPage ? "Could not read or save settings. Check folder permissions. For invalid settings JSON, Restore defaults resets your preferences." : "Could not read local usage data. Check Settings → Open diagnostics.";
    private async Task RunAsync(Func<Task> action)
    {
        if (IsBusy) return;
        IsBusy = true; Error = null;
        try { await action(); }
        catch (Exception ex) when (IsDataError(ex)) { Error = DataErrorMessage; }
        finally { IsBusy = false; }
    }
    /// <summary>
    /// Chuyển trang ngay (caller đổi Page trước), rồi tải dữ liệu nền. Không đặt IsBusy nên các nút
    /// vẫn bấm được; bấm trang khác giữa chừng thì kết quả cũ bị bỏ qua (xem <see cref="IsCurrentLoad"/>).
    /// </summary>
    private async Task LoadPageAsync(Func<int, Task> load)
    {
        var version = ++_pageVersion;
        IsLoading = true; Error = null;
        try { await load(version); }
        catch (Exception ex) when (IsDataError(ex)) { if (IsCurrentLoad(version)) Error = DataErrorMessage; }
        finally { if (IsCurrentLoad(version)) IsLoading = false; }
    }
    private bool IsCurrentLoad(int version) => version == _pageVersion;
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
        Sync = await api.GetSyncAsync();
        ApplySettings(await api.GetSettingsAsync());
        if (showSetupOnStart && !_startupLoaded)
        {
            if (!await api.IsSetupCompleteAsync())
            {
                FirstRun = await api.GetFirstRunAsync();
                SetupStepIndex = 0; Page = "first-run";
            }
            _startupLoaded = true;
        }
        if (IsSettingsPage) ApplySettings(await api.GetSettingsAsync());
        if (IsActivityPage) await LoadActivityCoreAsync();
        if (IsPricingPage) Pricing = await api.GetPricingAsync(CancellationToken.None);
        if (IsSyncPage) Sync = await api.GetSyncAsync();
        if (IsPairingPage) await LoadPairingPageCoreAsync();
        if (IsDetail && SelectedSource is not null)
        {
            SelectedSource = await api.GetSourceAsync(SelectedSource.Id, SelectedPeriod);
            _loadedPeriod = SelectedPeriod;
        }
    });
    [RelayCommand] private void ShowOverview() { if (CanNavigate) { _pageVersion++; IsLoading = false; Page = "overview"; } }
    [RelayCommand] private void ShowSources() { if (CanNavigate) { _pageVersion++; IsLoading = false; ResetSectionPreview(); if (SourcePermission is not null) ApplySourcePermission(SourcePermission); Page = "sources"; } }
    [RelayCommand]
    private Task OpenSourceAsync(Models.SourceData source)
    {
        if (!CanNavigate) return Task.CompletedTask;
        RestoreUiPreferences();
        // Hiện ngay số liệu 30 ngày đã có trong danh sách, rồi tải kỳ đang chọn ở nền.
        SelectedSource = source;
        Page = "detail";
        return LoadPageAsync(async version =>
        {
            var period = SelectedPeriod;
            var detail = await api.GetSourceAsync(source.Id, period);
            if (!IsCurrentLoad(version)) return;
            SelectedSource = detail; _loadedPeriod = period;
        });
    }
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
