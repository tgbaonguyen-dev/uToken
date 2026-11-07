using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using UToken.Desktop.App.Models;
namespace UToken.Desktop.App.ViewModels;

public partial class MainViewModel
{
    public event Action<string>? OverviewDiagnosticsRequested;
    [ObservableProperty, NotifyPropertyChangedFor(nameof(NotFoundScenario)), NotifyPropertyChangedFor(nameof(OverviewPreviewOptions)), NotifyPropertyChangedFor(nameof(SourcePreviewOptions)), NotifyPropertyChangedFor(nameof(SyncPreviewOptions))] private OverviewScenario[] _overviewScenarios = [];
    private static bool IsOverviewScenario(string id) => id is "normal" or "offline" or "empty" or "update";
    public OverviewScenario[] OverviewPreviewOptions => OverviewScenarios.Where(s => IsOverviewScenario(s.Id)).ToArray();
    [ObservableProperty] private OverviewScenario? _selectedOverviewScenario;
    [ObservableProperty, NotifyPropertyChangedFor(nameof(IsOverviewDashboard)), NotifyPropertyChangedFor(nameof(IsOverviewState)),
        NotifyPropertyChangedFor(nameof(IsOfflinePreview)), NotifyPropertyChangedFor(nameof(IsEmptyPreview)),
        NotifyPropertyChangedFor(nameof(IsGenericOverviewPreview)), NotifyPropertyChangedFor(nameof(IsScanningPreview)), NotifyPropertyChangedFor(nameof(PageTitle)),
        NotifyPropertyChangedFor(nameof(Subtitle)), NotifyPropertyChangedFor(nameof(DisplayedCollector))]
    private OverviewPreview? _overviewPreview;
    private bool _restoringOverviewSelection;
    public bool IsOverviewDashboard => IsOverview && (OverviewPreview is null || OverviewPreview.Scenario.Id == "normal");
    public bool IsOverviewState => IsOverview && !IsOverviewDashboard;
    public bool IsOfflinePreview => OverviewPreview?.Scenario.Id == "offline";
    public bool IsEmptyPreview => OverviewPreview?.Scenario.Id == "empty";
    public bool IsScanningPreview => OverviewPreview?.Scenario.Id == "scanning";
    public bool IsGenericOverviewPreview => !IsOfflinePreview && !IsEmptyPreview;
    public CollectorData? DisplayedCollector => IsOverviewState ? OverviewPreview?.Data.Collector : Overview?.Collector;

    partial void OnSelectedOverviewScenarioChanged(OverviewScenario? value)
    {
        if (!_restoringOverviewSelection && value is not null && IsOverview && !IsBusy)
            _ = ChangeOverviewScenarioCommand.ExecuteAsync(null);
    }
    private async Task LoadOverviewScenariosCoreAsync()
    {
        var id = OverviewPreview?.Scenario.Id ?? "normal";
        if (!IsOverviewScenario(id)) id = "normal";
        var scenarios = await api.GetOverviewScenariosAsync();
        var selection = scenarios.FirstOrDefault(s => s.Id == id)
            ?? throw new InvalidDataException("Overview scenario missing.");
        var preview = id == "normal" ? new OverviewPreview(selection, Overview!) : await api.GetOverviewPreviewAsync(id);
        OverviewScenarios = scenarios; OverviewPreview = preview;
        RestoreOverviewSelection(id);
    }
    private void RestoreOverviewSelection(string id)
    {
        _restoringOverviewSelection = true;
        SelectedOverviewScenario = OverviewPreviewOptions.FirstOrDefault(s => s.Id == id);
        _restoringOverviewSelection = false;
    }
    [RelayCommand] private async Task ChangeOverviewScenarioAsync()
    {
        if (!IsOverview || !CanNavigate) return;
        if (SelectedOverviewScenario is { } selected && !IsOverviewScenario(selected.Id))
        {
            RestoreOverviewSelection(OverviewPreview?.Scenario.Id ?? "normal");
            return;
        }
        await RunAsync(async () =>
        {
            var preview = await api.GetOverviewPreviewAsync(SelectedOverviewScenario?.Id ?? "normal");
            OverviewPreview = preview;
            Notice = "State preview - usage data is unchanged.";
        });
        RestoreOverviewSelection(OverviewPreview?.Scenario.Id ?? "normal");
    }
    [RelayCommand] private Task OverviewStateActionAsync(string action) => NavigateAsync(async () =>
    {
        switch (action)
        {
            case "restart":
            case "retry":
            case "normal":
                OverviewPreview = await api.GetOverviewPreviewAsync("normal");
                RestoreOverviewSelection("normal");
                Notice = action == "restart" ? "Preview: collector restarted. Usage history retained."
                    : action == "retry" ? "Preview: retry completed. No network request was made." : "Normal overview restored.";
                break;
            case "check":
                Notice = "Preview: collector check complete. Usage data is unchanged.";
                break;
            case "sources":
                Page = "sources";
                break;
            case "setup":
                FirstRun = await api.GetFirstRunAsync(); SetupStepIndex = 0; Page = "first-run";
                break;
            case "settings":
                ApplySettings(await api.GetSettingsAsync()); Page = "settings";
                break;
            case "diagnostics":
                OverviewDiagnosticsRequested?.Invoke(await api.GetDiagnosticsAsync());
                break;
            case "pair":
                Sync = await api.DisconnectAsync();
                await LoadPairingPageCoreAsync();
                Page = "pairing";
                break;
        }
    });
}
