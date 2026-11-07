using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using UToken.Desktop.App.Models;
namespace UToken.Desktop.App.ViewModels;

/// <summary>
/// Màn Overview chọn trạng thái theo dữ liệu thật (không có bộ chọn xem trước):
/// update (D24) khi log có định dạng lạ, offline (D09) khi không nguồn nào đang thu thập,
/// empty (D11) khi chưa có usage nào trong 30 ngày, còn lại là dashboard bình thường.
/// </summary>
public partial class MainViewModel
{
    public event Action<string>? OverviewDiagnosticsRequested;
    [ObservableProperty, NotifyPropertyChangedFor(nameof(NotFoundScenario)), NotifyPropertyChangedFor(nameof(SyncPreviewOptions))]
    private OverviewScenario[] _overviewScenarios = [];
    [ObservableProperty, NotifyPropertyChangedFor(nameof(IsOverviewDashboard)), NotifyPropertyChangedFor(nameof(IsOverviewState)),
        NotifyPropertyChangedFor(nameof(IsOfflinePreview)), NotifyPropertyChangedFor(nameof(IsEmptyPreview)),
        NotifyPropertyChangedFor(nameof(IsGenericOverviewPreview)), NotifyPropertyChangedFor(nameof(IsScanningPreview)), NotifyPropertyChangedFor(nameof(PageTitle)),
        NotifyPropertyChangedFor(nameof(Subtitle)), NotifyPropertyChangedFor(nameof(DisplayedCollector))]
    private OverviewPreview? _overviewPreview;
    public bool IsOverviewDashboard => IsOverview && (OverviewPreview is null || OverviewPreview.Scenario.Id == "normal");
    public bool IsOverviewState => IsOverview && !IsOverviewDashboard;
    public bool IsOfflinePreview => OverviewPreview?.Scenario.Id == "offline";
    public bool IsEmptyPreview => OverviewPreview?.Scenario.Id == "empty";
    public bool IsScanningPreview => OverviewPreview?.Scenario.Id == "scanning";
    public bool IsGenericOverviewPreview => !IsOfflinePreview && !IsEmptyPreview;
    public CollectorData? DisplayedCollector => Overview?.Collector;

    /// <summary>Id màn trạng thái ứng với dữ liệu hiện tại.</summary>
    public string OverviewStateId => Overview is null ? "normal"
        : Overview.Collector.State == "error" ? "update"
        : Overview.Collector.State != "running" ? "offline"
        : Overview.TotalTokens == 0 && Overview.Activity.Length == 0 ? "empty"
        : "normal";

    private void RefreshOverviewState()
    {
        if (Overview is null || OverviewScenarios.Length == 0) return;
        var scenario = OverviewScenarios.FirstOrDefault(s => s.Id == OverviewStateId)
            ?? OverviewScenarios.FirstOrDefault(s => s.Id == "normal");
        OverviewPreview = scenario is null ? null : new OverviewPreview(WithLiveDetails(scenario), Overview);
    }

    private async Task LoadOverviewScenariosCoreAsync()
    {
        OverviewScenarios = await api.GetOverviewScenariosAsync();
        RefreshOverviewState();
    }

    /// <summary>Quét lại mọi nguồn rồi tải lại Overview và Sources (dùng cho Restart/Retry/Check collector).</summary>
    private async Task RescanAllCoreAsync()
    {
        var sources = await api.RescanSourcesAsync();
        ApplySourcePermission((await api.GetSourcePermissionAsync()) with { Sources = sources });
        Overview = await api.GetOverviewAsync();
        Notice = $"Collector checked: {sources.NewEvents ?? 0} new events read.";
    }

    [RelayCommand] private Task OverviewStateActionAsync(string action) => NavigateAsync(async () =>
    {
        switch (action)
        {
            case "restart":
            case "retry":
            case "check":
                await RescanAllCoreAsync();
                break;
            case "normal":
                Overview = await api.GetOverviewAsync();
                break;
            case "sources":
                Page = "sources";
                break;
            case "setup":
                FirstRun = await api.GetFirstRunAsync(); SetupStepIndex = 0; SetupMessage = ""; Page = "first-run";
                break;
            case "settings":
                ApplySettings(await api.GetSettingsAsync()); Page = "settings";
                break;
            case "diagnostics":
                OverviewDiagnosticsRequested?.Invoke(await api.GetDiagnosticsAsync());
                break;
            case "pair":
                await LoadPairingPageCoreAsync();
                Page = "pairing";
                break;
        }
    });
}
