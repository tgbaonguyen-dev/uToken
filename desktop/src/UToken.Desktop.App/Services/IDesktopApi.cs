using UToken.Desktop.App.Models;
namespace UToken.Desktop.App.Services;
public interface IDesktopApi
{
    Task<FirstRunData> GetFirstRunAsync(CancellationToken ct = default);
    Task<bool> IsSetupCompleteAsync(CancellationToken ct = default);
    Task CompleteSetupAsync(CancellationToken ct = default);
    Task<string> GetDiagnosticsAsync(CancellationToken ct = default);
    Task<SettingsData> GetSettingsAsync(CancellationToken ct = default);
    Task<SettingsData> SaveSettingsAsync(CollectorSettings values, CancellationToken ct = default);
    Task<SettingsData> ResetSettingsAsync(CancellationToken ct = default);
    Task<OverviewScenario[]> GetOverviewScenariosAsync(CancellationToken ct = default);
    Task<OverviewPreview> GetOverviewPreviewAsync(string id, CancellationToken ct = default);
    Task<OverviewData> GetOverviewAsync(CancellationToken ct = default);
    Task<SourcePermissionData> GetSourcePermissionAsync(CancellationToken ct = default);
    Task<SourcePermissionData> SetSourcePermissionScenarioAsync(string id, CancellationToken ct = default);
    Task<SourcePermissionData> RetrySourcePermissionAsync(string sourceId, CancellationToken ct = default);
    Task<SourcesData> GetSourcesAsync(CancellationToken ct = default);
    Task<SupportedSourceData[]> GetSupportedSourcesAsync(CancellationToken ct = default);
    Task<SourceData> GetSourceAsync(string id, string period = "30 days", CancellationToken ct = default);
    Task<SourcesData> RescanSourcesAsync(CancellationToken ct = default, IProgress<SourceScanProgress>? progress = null);
    Task<ActivityPageData> GetActivityAsync(ActivityQuery query, CancellationToken ct = default);
    Task<string> ExportActivityAsync(ActivityQuery query, CancellationToken ct = default);
    Task<SyncStateConfig> GetSyncStateConfigAsync(CancellationToken ct = default);
    Task<SyncData> GetSyncAsync(CancellationToken ct = default);
    Task<SyncResult> SyncNowAsync(CancellationToken ct = default);
    Task<SyncData> DisconnectAsync(CancellationToken ct = default);
    Task<OverviewScenario[]> GetPairingScenariosAsync(CancellationToken ct = default);
    Task<PairingData> StartPairingAsync(CancellationToken ct = default);
    Task<PairingData> GetPairingInfoAsync(CancellationToken ct = default);
    Task<PairingResult> PairDeviceAsync(string code, CancellationToken ct = default);
}
