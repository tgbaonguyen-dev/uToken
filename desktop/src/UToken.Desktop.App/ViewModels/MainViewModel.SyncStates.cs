using CommunityToolkit.Mvvm.ComponentModel;
using UToken.Desktop.App.Models;

namespace UToken.Desktop.App.ViewModels;

public partial class MainViewModel
{
    [ObservableProperty, NotifyPropertyChangedFor(nameof(SyncPreviewOptions)), NotifyPropertyChangedFor(nameof(SyncQueuedLabel))]
    private SyncStateConfig? _syncStateConfig;
    partial void OnSyncStateConfigChanged(SyncStateConfig? value) => NotifySyncState();
    public OverviewScenario? ActiveSyncScenario => !IsSyncPage ? null
        : IsSyncing ? SyncStateConfig?.Scenarios.FirstOrDefault(s => s.Id == "syncing")
        : SectionScenario?.Id is "sync-failed" or "not-paired" or "syncing" or "revoked" or "network" ? SectionScenario
        : HasNoDevice ? SyncStateConfig?.Scenarios.FirstOrDefault(s => s.Id == "not-paired") : null;
    public bool IsSyncDetailState => ActiveSyncScenario?.Id is "sync-failed" or "not-paired" or "syncing";
    public bool IsSyncFailure => ActiveSyncScenario?.Id == "sync-failed";
    public bool IsSyncProgress => ActiveSyncScenario?.Id == "syncing";
    public string SyncQueuedLabel => $"{SyncStateConfig?.Queue.Sum(q => q.Events) ?? 0} events queued";
    public HealthData[] SyncStateDetails => IsSyncFailure
        ? [new("Device", Sync?.Device?.Name ?? "No mobile device", "#F3F4F7"),
           new("Last successful sync", Sync?.Device?.LastSync ?? "Not synchronized yet", "#9096A1"),
           new("Encryption", Sync?.EncryptionTitle ?? "Not configured", "#2EC790"),
           new("Collector", DisplayedCollector?.Label ?? "Unknown", DisplayedCollector?.Color ?? "#9096A1")]
        : ActiveSyncScenario?.Details ?? [];

    private void NotifySyncState()
    {
        foreach (var name in new[] { nameof(ActiveSyncScenario), nameof(IsSyncDetailState), nameof(IsSyncFailure),
            nameof(IsSyncProgress), nameof(IsSyncStatePreview), nameof(IsSectionStatePreview), nameof(IsSyncNormal),
            nameof(SyncStateDetails), nameof(PageTitle), nameof(Subtitle) }) OnPropertyChanged(name);
        NotifyVisualStatus();
    }

    private void SetSyncResultState(string result)
    {
        var id = result switch { "failed" or "offline" => "sync-failed", "not_paired" => "not-paired", _ => "normal" };
        _restoringSyncSelection = true;
        SelectedSyncScenario = SyncPreviewOptions.FirstOrDefault(s => s.Id == id);
        SectionScenario = id == "normal" ? null : SelectedSyncScenario;
        _restoringSyncSelection = false;
    }
}
