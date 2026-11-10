namespace UToken.Desktop.App.ViewModels;

/// <summary>
/// Thu thập nền (Settings → Background collection): App gọi <see cref="BackgroundSyncAsync"/> theo chu kỳ
/// Sync:IntervalMinutes. Có bật Usage notifications thì báo khi có usage mới được đẩy lên hoặc khi sync gặp lỗi.
/// </summary>
public partial class MainViewModel
{
    /// <summary>(tiêu đề, nội dung, là lỗi?) — MainWindow hiển thị thành thông báo.</summary>
    public event Action<string, string, bool>? NotificationRequested;

    public async Task BackgroundSyncAsync()
    {
        if (IsBusy || IsFirstRunPage || IsScanningSources || Settings?.Values.BackgroundCollection != true) return;
        Models.SyncResult? result = null;
        await RunAsync(async () =>
        {
            result = await api.SyncNowAsync();
            ApplySyncResult(result);
            Overview = await api.GetOverviewAsync();
            ApplySourcePermission(await api.GetSourcePermissionAsync());
            if (IsActivityPage) await LoadActivityCoreAsync();
        });
        if (result is null || Settings?.Values.UsageNotifications != true) return;
        switch (result.State)
        {
            case "success":
                NotificationRequested?.Invoke("Usage synced", result.Message, false);
                break;
            case "revoked" or "network" or "failed":
                NotificationRequested?.Invoke("Sync needs attention", result.Message, true);
                break;
        }
        if (HasPermissionIssue)
            NotificationRequested?.Invoke("Log access required", $"uToken cannot read {PermissionSource?.Name} logs. Open Sources to fix it.", true);
    }

    /// <summary>
    /// Phục vụ nút Sync/Refresh trên điện thoại: App gọi định kỳ; có yêu cầu thì quét log và đẩy lên ngay,
    /// kể cả khi Background collection tắt (người dùng chủ động yêu cầu).
    /// </summary>
    private bool _servingMobile;

    public async Task ServeMobileSyncRequestsAsync()
    {
        // Sync + AI review có thể lâu hơn chu kỳ timer: không chạy chồng.
        if (_servingMobile || IsBusy || IsFirstRunPage || IsScanningSources) return;
        _servingMobile = true;
        Models.SyncResult? result = null;
        try { result = await api.ServeMobileSyncRequestsAsync(); }
        catch (Exception ex) when (ex is HttpRequestException or IOException or InvalidOperationException) { return; }
        finally { _servingMobile = false; }
        if (result is null) return;
        await RunAsync(async () =>
        {
            ApplySyncResult(result);
            Overview = await api.GetOverviewAsync();
            if (IsActivityPage) await LoadActivityCoreAsync();
        });
    }
}
