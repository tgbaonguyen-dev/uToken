using System.Text.Json;
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
        var antigravity = sources.Sources.Single(s => s.Id == "antigravity");

        Assert.Equal(20_500 + 30_300 + 40_100 + 50_200, codex.Tokens); // 3 lượt gọi phiên chính + 1 guardian
        Assert.Equal("running", codex.CollectorState);
        Assert.Contains(codex.Models, m => m.Name == "codex-auto-review");
        Assert.True(claude.Tokens > 0);
        Assert.Equal("paused", antigravity.CollectorState); // home giả chỉ bật codex + claude_code
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
    public async Task Export_includes_all_matching_rows_beyond_the_activity_limit()
    {
        _home.AddClaudeUsage(1105);
        _home.AddClaudeUsage(1105, warning: true);
        using var api = _home.Api();
        foreach (var warnings in new[] { false, true })
        {
            var query = new ActivityQuery(Provider: "Claude", Model: "claude-export-check",
                Period: "All time", Search: "bulk-", WarningsOnly: warnings);
            Assert.Equal(1000, (await api.GetActivityAsync(query)).Events.Length);
            var csv = await api.ExportActivityAsync(query);
            var rows = csv.Split("\r\n", StringSplitOptions.RemoveEmptyEntries);
            Assert.Equal(1106, rows.Length);
            Assert.All(rows.Skip(1), row =>
            {
                Assert.Contains(warnings ? "bulk-warning-" : "bulk-collected-", row);
                Assert.Contains("claude-export-check", row);
            });
            var one = await api.ExportActivityAsync(query with { Search = "bulk-collected-1104" });
            Assert.Equal(warnings ? 1 : 2, one.Split("\r\n", StringSplitOptions.RemoveEmptyEntries).Length);
        }
    }

    [Fact]
    public async Task Old_usage_scanned_before_retention_stays_queued_until_upload()
    {
        _home.Clock.Now += TimeSpan.FromDays(40);
        using var api = _home.Api();
        await api.RescanSourcesAsync();
        await api.SignInAsync();
        _home.Cloud.NextUpload = FakeCloud.Failure.Network;
        Assert.Equal("network", (await api.SyncNowAsync()).State);
        Assert.Equal("success", (await api.SyncNowAsync()).State);
        var uploaded = Assert.Single(_home.Cloud.Uploads).Daily;
        Assert.Contains(uploaded, d => d.Date == "2026-11-05" && d.Totals.Requests == 5);
        Assert.Contains(uploaded, d => d.Date == "2026-11-06" && d.Totals.Requests == 4);
        Assert.Equal(0, (await api.GetSyncAsync()).NextSync.Events);
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
    public async Task Explicit_sync_restores_cloud_edits_and_failed_restore_stays_queued()
    {
        using var api = _home.Api();
        await api.SignInAsync();
        await api.SyncNowAsync();
        var original = _home.Cloud.Uploads[^1].Daily;
        Assert.NotEmpty(original);
        // Simulate a Console edit to an already acknowledged daily document.
        var cloud = original.ToDictionary(d => d.Date, d => JsonSerializer.Serialize(d));
        cloud[original[0].Date] = "console-edited-value";
        await api.SyncNowAsync();
        Assert.Empty(_home.Cloud.Uploads[^1].Daily);
        Assert.Equal("console-edited-value", cloud[original[0].Date]);

        var restored = await api.SyncNowAsync(resendAll: true);
        Assert.Equal("success", restored.State);
        foreach (var doc in _home.Cloud.Uploads[^1].Daily)
            cloud[doc.Date] = JsonSerializer.Serialize(doc);
        foreach (var doc in original)
            Assert.Equal(JsonSerializer.Serialize(doc), cloud[doc.Date]);

        _home.Cloud.NextUpload = FakeCloud.Failure.Network;
        Assert.Equal("network", (await api.SyncNowAsync(resendAll: true)).State);
        Assert.Equal("success", (await api.SyncNowAsync()).State);
        Assert.Equal(original.Count, _home.Cloud.Uploads[^1].Daily.Count);
        await api.SyncNowAsync();
        Assert.Empty(_home.Cloud.Uploads[^1].Daily);
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

    [Theory]
    [InlineData("OPERATION_NOT_ALLOWED", "disabled")]
    [InlineData("INVALID_API_KEY", "API key")]
    [InlineData("CONFIGURATION_NOT_FOUND", "configuration")]
    [InlineData("INVALID_IDP_RESPONSE", "OAuth client")]
    [InlineData("USER_DISABLED", "disabled")]
    [InlineData("UNKNOWN_SERVER_DETAIL_secret-token", "Firebase rejected")]
    public async Task Sign_in_reports_safe_firebase_configuration_errors(string code, string expected)
    {
        using var api = _home.Api();
        _home.Cloud.SignInError = new UToken.Sync.Auth.CloudAuthException("raw-secret-response", errorCode: code);
        var result = await api.SignInAsync();
        Assert.Equal("rejected", result.State);
        Assert.Contains(expected, result.Message);
        Assert.DoesNotContain("secret", result.Message);
    }

    [Fact]
    public async Task Sign_in_distinguishes_google_network_and_session_storage_errors()
    {
        using var api = _home.Api();
        _home.Cloud.SignInError = new UToken.Sync.Auth.GoogleSignInException("Google sign-in was cancelled. Try again.");
        Assert.Contains("cancelled", (await api.SignInAsync()).Message);
        _home.Cloud.SignInError = new HttpRequestException("private-endpoint-and-key");
        var network = await api.SignInAsync();
        Assert.Contains("Auth Emulator", network.Message);
        Assert.DoesNotContain("private", network.Message);
        _home.Cloud.SignInError = new System.Security.Cryptography.CryptographicException("private-token");
        Assert.Contains("securely save", (await api.SignInAsync()).Message);
        _home.Cloud.SignInError = new TaskCanceledException("private-response");
        Assert.Equal("expired", (await api.SignInAsync()).State);
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
        Assert.All(sources.Sources.Where(s => s.Id != "antigravity"), s => Assert.Equal("not_found", s.CollectorState));
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
