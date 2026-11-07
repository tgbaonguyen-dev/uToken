using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using UToken.Desktop.App.Models;

namespace UToken.Desktop.App.ViewModels;

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
    [ObservableProperty] private OverviewScenario? _selectedSyncScenario;
    public OverviewScenario[] SyncPreviewOptions => [.. OverviewScenarios.Where(s => s.Id == "normal"), .. SyncStateConfig?.Scenarios ?? [], .. OverviewScenarios.Where(s => s.Id is "revoked" or "network")];
    public bool IsSourcesStatePreview => IsSources && SectionScenario?.Id == "up-to-date";
    public bool IsSyncStatePreview => IsSyncPage && ActiveSyncScenario is not null;
    public bool IsSectionStatePreview => IsSourcesStatePreview || (IsSyncStatePreview && !IsSyncDetailState);
    public bool IsSyncNormal => IsSyncPage && !IsSyncStatePreview;
    private bool _restoringSyncSelection;

    partial void OnSelectedSyncScenarioChanged(OverviewScenario? value)
    {
        if (_restoringSyncSelection || IsBusy || !IsSyncPage || value is null) return;
        if (!SyncPreviewOptions.Any(s => s.Id == value.Id)) return;
        SectionScenario = value.Id == "normal" ? null : value;
    }

    private void ResetSectionPreview()
    {
        SectionScenario = null;
        _restoringSyncSelection = true;
        SelectedSyncScenario = SyncPreviewOptions.FirstOrDefault(s => s.Id == "normal");
        _restoringSyncSelection = false;
    }

    [RelayCommand] private async Task SectionStateActionAsync(string action)
    {
        if (IsBusy || !CanNavigate) return;
        if (action == "settings") { await ShowSettingsCommand.ExecuteAsync(null); return; }
        if (IsSourcesStatePreview)
        {
            ResetSectionPreview();
            ApplySourcePermission(SourcePermission!);
            if (action == "normal") ShowOverviewCommand.Execute(null);
            return;
        }
        if (!IsSyncStatePreview) return;
        if (action == "sync") { ResetSectionPreview(); return; }
        if (action == "pair")
        {
            await NavigateAsync(async () =>
            {
                Sync = await api.DisconnectAsync();
                await LoadPairingPageCoreAsync();
                ResetSectionPreview();
                Page = "pairing";
            });
        }
        else if (action == "retry")
        {
            ResetSectionPreview();
            await SyncNowCommand.ExecuteAsync(null);
        }
    }
}
