using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using UToken.Desktop.App.Models;

namespace UToken.Desktop.App.ViewModels;

/// <summary>
/// Màn trạng thái của Sources và Sync, bật theo kết quả thật:
/// D22 "up-to-date" sau khi quét lại không có event mới; D12/D13/D23/D25 theo kết quả Sync now.
/// </summary>
public partial class MainViewModel
{
    [ObservableProperty, NotifyPropertyChangedFor(nameof(IsSourcesStatePreview)),
        NotifyPropertyChangedFor(nameof(IsSyncStatePreview)), NotifyPropertyChangedFor(nameof(IsSectionStatePreview)),
        NotifyPropertyChangedFor(nameof(IsPermissionRequired)), NotifyPropertyChangedFor(nameof(IsSourceNotFound)),
        NotifyPropertyChangedFor(nameof(IsSourcesNormal)), NotifyPropertyChangedFor(nameof(IsSyncNormal)),
        NotifyPropertyChangedFor(nameof(PageTitle)), NotifyPropertyChangedFor(nameof(Subtitle)),
        NotifyPropertyChangedFor(nameof(ActiveSyncScenario)), NotifyPropertyChangedFor(nameof(IsSyncDetailState)),
        NotifyPropertyChangedFor(nameof(IsSyncFailure)), NotifyPropertyChangedFor(nameof(IsSyncProgress)), NotifyPropertyChangedFor(nameof(SyncStateDetails))]
    private OverviewScenario? _sectionScenario;
    /// <summary>Nội dung các màn trạng thái Sync (tra theo id, không hiển thị như bộ chọn).</summary>
    public OverviewScenario[] SyncPreviewOptions => [.. SyncStateConfig?.Scenarios ?? [], .. OverviewScenarios.Where(s => s.Id is "revoked" or "network")];
    public bool IsSourcesStatePreview => IsSources && SectionScenario?.Id == "up-to-date";
    public bool IsSyncStatePreview => IsSyncPage && ActiveSyncScenario is not null;
    public bool IsSectionStatePreview => IsSourcesStatePreview || (IsSyncStatePreview && !IsSyncDetailState);
    public bool IsSyncNormal => IsSyncPage && !IsSyncStatePreview;

    private void ResetSectionPreview() => SectionScenario = null;

    [RelayCommand] private async Task SectionStateActionAsync(string action)
    {
        if (IsBusy || !CanNavigate) return;
        if (action == "settings") { await ShowSettingsCommand.ExecuteAsync(null); return; }
        if (IsSourcesStatePreview)
        {
            ResetSectionPreview();
            if (action == "normal") ShowOverviewCommand.Execute(null);
            return;
        }
        if (!IsSyncStatePreview) return;
        switch (action)
        {
            case "sync":
                ResetSectionPreview();
                break;
            case "pair":
                ResetSectionPreview();
                await ShowPairingCommand.ExecuteAsync(null);
                break;
            case "retry":
                ResetSectionPreview();
                await SyncNowCommand.ExecuteAsync(null);
                break;
        }
    }
}
