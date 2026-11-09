using UToken.Desktop.App.Models;
namespace UToken.Desktop.App.Services;

/// <summary>Dịch vụ dữ liệu của giao diện desktop. Bản cài đặt duy nhất: <see cref="RealDesktopApi"/> (log thật, SQLite, Firestore).</summary>
public interface IDesktopApi
{
    // First run
    Task<FirstRunData> GetFirstRunAsync(CancellationToken ct = default);
    Task<bool> IsSetupCompleteAsync(CancellationToken ct = default);
    Task CompleteSetupAsync(CancellationToken ct = default);

    // Settings và bảo trì
    Task<string> GetDiagnosticsAsync(CancellationToken ct = default);
    Task<SettingsData> GetSettingsAsync(CancellationToken ct = default);
    Task<SettingsData> SaveSettingsAsync(CollectorSettings values, CancellationToken ct = default);
    Task<SettingsData> ResetSettingsAsync(CancellationToken ct = default);
    /// <summary>Xóa toàn bộ usage đã lưu trên máy; trả về số event đã xóa.</summary>
    Task<long> ClearLocalDataAsync(CancellationToken ct = default);

    // Pricing catalog
    Task<PricingData> GetPricingAsync(CancellationToken ct);

    // Overview: nội dung các màn trạng thái (chữ hiển thị) và số liệu thật
    Task<OverviewScenario[]> GetOverviewScenariosAsync(CancellationToken ct = default);
    Task<OverviewData> GetOverviewAsync(CancellationToken ct = default);

    // Nguồn log
    Task<SourcePermissionData> GetSourcePermissionAsync(CancellationToken ct = default);
    Task<SourcePermissionData> RetrySourcePermissionAsync(string sourceId, CancellationToken ct = default);
    /// <summary>Đường dẫn đầy đủ tới thư mục log của nguồn (để mở bằng trình quản lý file).</summary>
    string GetSourceFolder(string sourceId);
    Task<SourcesData> GetSourcesAsync(CancellationToken ct = default);
    Task<SupportedSourceData[]> GetSupportedSourcesAsync(CancellationToken ct = default);
    Task<SourceData> GetSourceAsync(string id, string period = "30 days", CancellationToken ct = default);
    Task<SourcesData> RescanSourcesAsync(CancellationToken ct = default, IProgress<SourceScanProgress>? progress = null);

    // Activity
    Task<ActivityPageData> GetActivityAsync(ActivityQuery query, CancellationToken ct = default);
    Task<string> ExportActivityAsync(ActivityQuery query, CancellationToken ct = default);

    // Sync với Firestore và tài khoản Google
    Task<SyncStateConfig> GetSyncStateConfigAsync(CancellationToken ct = default);
    Task<SyncData> GetSyncAsync(CancellationToken ct = default);
    Task<SyncResult> SyncNowAsync(CancellationToken ct = default);
    /// <summary>Đăng xuất Google trên máy này. Dữ liệu trên máy và trên cloud giữ nguyên.</summary>
    Task<SyncData> DisconnectAsync(CancellationToken ct = default);
    Task<OverviewScenario[]> GetPairingScenariosAsync(CancellationToken ct = default);
    Task<PairingData> GetPairingInfoAsync(CancellationToken ct = default);
    /// <summary>Mở trình duyệt đăng nhập Google. State: success, rejected (lỗi/hủy), expired (hết giờ), unavailable (chưa cấu hình).</summary>
    Task<PairingResult> SignInAsync(CancellationToken ct = default);

    // AI review (LLM judge)
    /// <summary>
    /// Chạy AI review; <paramref name="force"/> bỏ qua giới hạn giờ và công tắc bật/tắt.
    /// </summary>
    Task<JudgeRunResult> RunJudgeAsync(bool force, CancellationToken ct = default);
    Task<JudgeRunResult> TestJudgeConnectionAsync(
        string provider, string model, string? key, CancellationToken ct = default);
}
