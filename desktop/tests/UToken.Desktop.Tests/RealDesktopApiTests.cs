using UToken.Desktop.App.Models;
using Xunit;

namespace UToken.Desktop.Tests;

/// <summary>RealDesktopApi trên thư mục home giả dựng từ fixture (không đụng log thật, không gọi mạng).</summary>
public sealed class RealDesktopApiTests : IDisposable
{
    private readonly RealHome _home = new();

    [Fact]
    public async Task Sources_and_overview_come_from_scanned_logs()
    {
        using var api = _home.Api();
        var sources = await api.GetSourcesAsync();
        var codex = sources.Sources.Single(s => s.Id == "codex");
        var claude = sources.Sources.Single(s => s.Id == "claude");
        var gemini = sources.Sources.Single(s => s.Id == "gemini");

        Assert.Equal(20_500 + 30_300 + 40_100 + 50_200, codex.Tokens); // 3 lượt gọi phiên chính + 1 guardian
        Assert.Equal("running", codex.CollectorState);
        Assert.Contains(codex.Models, m => m.Name == "codex-auto-review");
        Assert.True(claude.Tokens > 0);
        Assert.Equal("paused", gemini.CollectorState); // không bật trong cấu hình
        Assert.Equal(100, sources.Sources.Sum(s => s.Share), 1);

        var overview = await api.GetOverviewAsync();
        Assert.Equal(codex.Tokens + claude.Tokens, overview.TotalTokens);
        Assert.Equal(5, overview.Activity.Length);
        Assert.Equal("running", overview.Collector.State);
    }

    [Theory]
    [InlineData("1 day", "hour")]
    [InlineData("Week", "day")]
    [InlineData("30 days", "day")]
    [InlineData("Total", "week")]
    public async Task Every_period_builds_a_trend(string period, string granularity)
    {
        using var api = _home.Api();
        var codex = await api.GetSourceAsync("codex", period);
        Assert.Equal(granularity, codex.Granularity);
        Assert.NotEmpty(codex.Trend);
        Assert.All(codex.Trend, p => Assert.InRange(p.Cached, 0, p.Tokens));
        await Assert.ThrowsAsync<InvalidDataException>(() => api.GetSourceAsync("missing"));
    }

    [Fact]
    public async Task Activity_filters_and_exports_real_events()
    {
        using var api = _home.Api();
        Assert.Equal(9, (await api.GetActivityAsync(new ActivityQuery(Period: "Last 7 days"))).Events.Length);
        Assert.Equal(4, (await api.GetActivityAsync(new ActivityQuery(Provider: "Codex", Period: "Last 7 days"))).Events.Length);
        Assert.Single((await api.GetActivityAsync(new ActivityQuery(Period: "All time", Search: "msg_b"))).Events);
        var csv = await api.ExportActivityAsync(new ActivityQuery(Period: "Last 7 days"));
        Assert.Equal(10, csv.Split("\r\n", StringSplitOptions.RemoveEmptyEntries).Length);
    }

    [Fact]
    public async Task Rescan_reports_progress_and_new_event_count()
    {
        using var api = _home.Api();
        var reports = new List<SourceScanProgress>();
        var first = await api.RescanSourcesAsync(progress: new SyncProgress<SourceScanProgress>(reports.Add));
        Assert.Equal(9, first.NewEvents);
        Assert.Equal(3, reports[^1].Completed);
        Assert.Equal("complete", reports[^1].Providers.Single(p => p.Name == "Codex").State);
        Assert.Equal(0, (await api.RescanSourcesAsync()).NewEvents); // không có log mới
    }

    [Fact]
    public async Task Sync_without_sign_in_analyzes_locally_and_queues_summaries()
    {
        using var api = _home.Api();
        var result = await api.SyncNowAsync();
        Assert.Equal("not_paired", result.State);
        Assert.Null(result.Data.Device);
        Assert.True(result.Data.NextSync.Events > 0);
        Assert.Contains((await api.GetSyncStateConfigAsync()).Queue, q => q.Id == "codex" && q.Events > 0);
        Assert.Empty(_home.Cloud.Uploads);
    }

    [Fact]
    public async Task Sign_in_then_sync_uploads_all_pending_days_once()
    {
        using var api = _home.Api();
        await api.SyncNowAsync(); // phân tích trước khi đăng nhập

        var signIn = await api.SignInAsync();
        Assert.Equal("success", signIn.State);
        Assert.Equal("ana@example.com", signIn.Data!.Device!.Name);

        var first = await api.SyncNowAsync();
        Assert.Equal("success", first.State);
        var upload = Assert.Single(_home.Cloud.Uploads);
        Assert.Equal(["2026-11-05", "2026-11-06"], upload.Daily.Select(d => d.Date).Order());
        Assert.Equal(0, first.Data.NextSync.Events);
        Assert.Equal("Success", first.Data.History[0].Result);
        Assert.NotNull(first.Data.Device!.LastSyncAt);

        var second = await api.SyncNowAsync();
        Assert.Equal("no_new_usage", second.State);
        Assert.Empty(_home.Cloud.Uploads[^1].Daily); // chỉ efficiency + last_sync_at
    }

    [Fact]
    public async Task Revoked_and_network_failures_keep_summaries_queued()
    {
        using var api = _home.Api();
        await api.SignInAsync();
        _home.Cloud.NextUpload = FakeCloud.Failure.Revoked;
        var revoked = await api.SyncNowAsync();
        Assert.Equal("revoked", revoked.State);
        Assert.True(revoked.Data.NextSync.Events > 0);

        _home.Cloud.NextUpload = FakeCloud.Failure.Network;
        Assert.Equal("network", (await api.SyncNowAsync()).State);
        _home.Cloud.NextUpload = FakeCloud.Failure.Server;
        Assert.Equal("failed", (await api.SyncNowAsync()).State);

        Assert.Equal("success", (await api.SyncNowAsync()).State);
        Assert.Equal(2, _home.Cloud.Uploads[^1].Daily.Count);
    }

    [Fact]
    public async Task Sign_out_and_sign_in_failures()
    {
        using var api = _home.Api();
        await api.SignInAsync();
        Assert.Null((await api.DisconnectAsync()).Device);
        _home.Cloud.SignInFails = true;
        Assert.Equal("rejected", (await api.SignInAsync()).State);

        using var unconfigured = _home.Api(cloud: false);
        Assert.Equal("unavailable", (await unconfigured.SignInAsync()).State);
        Assert.Contains("not configured", (await unconfigured.GetPairingInfoAsync()).SignInHint);
    }

    [Fact]
    public async Task Clear_local_data_removes_usage_and_does_not_reread_old_logs()
    {
        using var api = _home.Api();
        Assert.True((await api.GetOverviewAsync()).TotalTokens > 0);
        Assert.Equal(9, await api.ClearLocalDataAsync());
        Assert.Equal(0, (await api.GetOverviewAsync()).TotalTokens);
        Assert.Equal(0, (await api.RescanSourcesAsync()).NewEvents); // log cũ không bị đọc lại
    }

    [Fact]
    public async Task Retention_prunes_usage_older_than_the_setting()
    {
        using var api = _home.Api();
        await api.GetSourcesAsync();
        var settings = await api.GetSettingsAsync();
        await api.SaveSettingsAsync(settings.Values with { RetentionDays = 7 });
        _home.Clock.Now = _home.Clock.Now.AddDays(10); // event của fixture giờ cũ hơn 7 ngày
        await api.SyncNowAsync();
        Assert.Empty((await api.GetActivityAsync(new ActivityQuery(Period: "All time"))).Events);
    }

    [Fact]
    public async Task Launch_at_startup_writes_and_removes_the_autostart_entry()
    {
        using var api = _home.Api();
        var settings = await api.GetSettingsAsync();
        Assert.False(settings.Values.LaunchAtStartup);
        Assert.False(settings.Values.AutomaticUpdates);

        var saved = await api.SaveSettingsAsync(settings.Values with { LaunchAtStartup = true, AutomaticUpdates = true });
        var entry = Path.Combine(_home.AutostartDirectory, "utoken.desktop");
        Assert.True(File.Exists(entry));
        Assert.Contains("Exec=\"/opt/utoken/UToken.Desktop.App\" --background", File.ReadAllText(entry));
        Assert.False(saved.Values.AutomaticUpdates); // không có server phát hành
        Assert.True((await _home.Api().GetSettingsAsync()).Values.LaunchAtStartup);

        await api.SaveSettingsAsync(saved.Values with { LaunchAtStartup = false });
        Assert.False(File.Exists(entry));
    }

    [Fact]
    public async Task Missing_log_folders_are_reported_as_not_found()
    {
        using var empty = new RealHome(withLogs: false);
        using var api = empty.Api();
        var sources = await api.GetSourcesAsync();
        Assert.All(sources.Sources.Where(s => s.Id != "gemini"), s => Assert.Equal("not_found", s.CollectorState));
        Assert.Equal("stopped", (await api.GetOverviewAsync()).Collector.State);
        Assert.EndsWith(Path.Combine(".codex", "sessions"), api.GetSourceFolder("codex"));
    }

    [Fact]
    public async Task Unreadable_log_folder_requires_permission_until_fixed()
    {
        if (OperatingSystem.IsWindows() || Environment.UserName == "root") return; // chmod không có tác dụng
        using var api = _home.Api();
        var sessions = Path.Combine(_home.Home, ".codex", "sessions");
        File.SetUnixFileMode(sessions, UnixFileMode.None);
        try
        {
            var blocked = await api.GetSourcePermissionAsync();
            Assert.Equal("permission-required", blocked.Scenario.Id);
            Assert.Equal("codex", blocked.Config.SourceId);
            Assert.False(blocked.Sources.Sources.Single(s => s.Id == "codex").Health.HasLogAccess);
        }
        finally { File.SetUnixFileMode(sessions, UnixFileMode.UserRead | UnixFileMode.UserWrite | UnixFileMode.UserExecute); }
        Assert.Equal("normal", (await api.RetrySourcePermissionAsync("codex")).Scenario.Id);
    }

    [Fact]
    public async Task Diagnostics_describe_real_storage_and_cloud()
    {
        using var api = _home.Api();
        await api.GetSourcesAsync();
        var report = await api.GetDiagnosticsAsync();
        Assert.Contains("9 usage events", report);
        Assert.Contains("Codex: ~/.codex/sessions → Running", report);
        Assert.Contains("codex-auto-review (fallback price)", report);
    }

    public void Dispose() => _home.Dispose();

    private sealed class SyncProgress<T>(Action<T> report) : IProgress<T>
    {
        public void Report(T value) => report(value);
    }
}
