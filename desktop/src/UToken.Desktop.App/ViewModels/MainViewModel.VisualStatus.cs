namespace UToken.Desktop.App.ViewModels;

public partial class MainViewModel
{
    public string SidebarStatusLabel => IsPermissionRequired ? "Permission required"
        : IsSyncFailure ? "Sync needs attention" : DisplayedCollector?.SidebarLabel ?? "Collector unavailable";
    public string SidebarStatusColor => IsPermissionRequired ? PermissionAccent
        : IsSyncFailure ? ActiveSyncScenario!.Accent : DisplayedCollector?.Color ?? "#9096A1";
    public string SidebarStatusCaption => IsPermissionRequired || IsSyncFailure ? "Action may be required"
        : DisplayedCollector?.LastSyncCaption ?? "";
    private void NotifyVisualStatus()
    {
        OnPropertyChanged(nameof(SidebarStatusLabel));
        OnPropertyChanged(nameof(SidebarStatusColor));
        OnPropertyChanged(nameof(SidebarStatusCaption));
    }
    partial void OnOverviewChanged(Models.OverviewData? value) { RefreshOverviewState(); NotifyVisualStatus(); }
    partial void OnOverviewPreviewChanged(Models.OverviewPreview? value) => NotifyVisualStatus();
    partial void OnSectionScenarioChanged(Models.OverviewScenario? value) => NotifyVisualStatus();
    partial void OnSourceListChanged(Models.SourcesData? value) => NotifyVisualStatus();
    partial void OnPermissionRetryFailureChanged(string? value) => NotifyVisualStatus();
    partial void OnIsScanningSourcesChanged(bool value) => NotifyVisualStatus();
}
