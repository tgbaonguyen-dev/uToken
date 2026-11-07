using Avalonia.Headless.XUnit;
using UToken.Collectors.ClaudeCode;
using UToken.Collectors.Codex;
using UToken.Desktop.App.Models;
using UToken.Desktop.App.Services;
using UToken.Desktop.App.ViewModels;
using UToken.Engine;
using UToken.Storage;
using Xunit;

namespace UToken.Desktop.Tests;

/// <summary>RealDesktopApi chạy trên thư mục home giả dựng từ contracts/fixtures (không đụng log thật của máy).</summary>
public sealed class RealDesktopApiTests : IDisposable
{
    private static readonly TimeZoneInfo Utc7 = TimeZoneInfo.CreateCustomTimeZone("UTC+7", TimeSpan.FromHours(7), "UTC+7", "UTC+7");
    private readonly DirectoryInfo _home = Directory.CreateTempSubdirectory("utoken-ui-");
    private readonly FixedClock _clock = new(DateTimeOffset.Parse("2026-11-06T01:00:00Z"));

    public RealDesktopApiTests()
    {
        Copy("codex/task-signals.jsonl", ".codex/sessions/2026/11/05/rollout-main.jsonl");
        Copy("codex/guardian.jsonl", ".codex/sessions/2026/11/05/rollout-guard.jsonl");
        Copy("claude_code/task-signals.jsonl", ".claude/projects/-work-demo-app/c-100.jsonl");
    }

    private void Copy(string fixture, string rel)
    {
        var dest = Path.Combine(_home.FullName, rel);
        Directory.CreateDirectory(Path.GetDirectoryName(dest)!);
        File.Copy(Path.Combine(AppContext.BaseDirectory, "fixtures", fixture), dest);
    }

    private RealDesktopApi NewApi(HttpClient? http = null)
    {
        var db = Path.Combine(_home.FullName, "utoken.db");
        var store = new SqliteStore(db);
        var engine = new UsageEngine(store, [new CodexCollector(), new ClaudeCodeCollector()], _home.FullName, Utc7, clock: _clock);
        var locations = RealDesktopApi.DefaultLocations(
            Path.Combine(_home.FullName, ".codex"), Path.Combine(_home.FullName, ".claude"), _home.FullName, ["codex", "claude_code", "antigravity"]);
        return new RealDesktopApi(engine, store, locations, db, clock: _clock) { PriceHttpClient = http };
    }

    [Fact]
    public async Task Sources_and_overview_come_from_scanned_logs()
    {
        using var api = NewApi();
        var sources = await api.GetSourcesAsync();
        var codex = sources.Sources.Single(s => s.Id == "codex");
        var claude = sources.Sources.Single(s => s.Id == "claude");
        var gemini = sources.Sources.Single(s => s.Id == "gemini");

        // Codex: 3 lần gọi phiên chính + 1 phiên guardian; Claude: 5 phản hồi (đã bỏ trùng).
        Assert.Equal(20_500 + 30_300 + 40_100 + 50_200, codex.Tokens);
        Assert.Equal("running", codex.CollectorState);
        Assert.Equal("Connected", codex.Status);
        Assert.Contains(codex.Models, m => m.Name == "codex-auto-review");
        Assert.True(claude.Tokens > 0);
        Assert.Equal("not_found", gemini.CollectorState);
        Assert.Equal(100, sources.Sources.Sum(s => s.Share), 1);
        Assert.True(codex.EstimatedCost > 0);

        var overview = await api.GetOverviewAsync();
        Assert.Equal(codex.Tokens + claude.Tokens, overview.TotalTokens);
        Assert.Equal(5, overview.Activity.Length);
        Assert.Equal("running", overview.Collector.State);
        Assert.Null(overview.Collector.LastSyncAt);
    }

    [Theory]
    [InlineData("1 day", "hour")]
    [InlineData("Week", "day")]
    [InlineData("30 days", "day")]
    [InlineData("Total", "week")]
    public async Task Every_period_builds_a_trend(string period, string granularity)
    {
        using var api = NewApi();
        var codex = await api.GetSourceAsync("codex", period);
        Assert.Equal(granularity, codex.Granularity);
        Assert.NotEmpty(codex.Trend);
        Assert.All(codex.Trend, p => Assert.InRange(p.Cached, 0, p.Tokens));
    }

    [Fact]
    public async Task Activity_filters_and_exports_real_events()
    {
        using var api = NewApi();
        var all = await api.GetActivityAsync(new ActivityQuery(Period: "Last 7 days"));
        Assert.Equal(9, all.Events.Length);
        Assert.Contains("Codex", all.Providers);
        Assert.Contains("claude-opus-5-5", all.Models);

        var codexOnly = await api.GetActivityAsync(new ActivityQuery(Provider: "Codex", Period: "Last 7 days"));
        Assert.Equal(4, codexOnly.Events.Length);
        var search = await api.GetActivityAsync(new ActivityQuery(Period: "All time", Search: "msg_b"));
        Assert.Single(search.Events);

        var csv = await api.ExportActivityAsync(new ActivityQuery(Period: "Last 7 days"));
        Assert.Equal(10, csv.Split("\r\n", StringSplitOptions.RemoveEmptyEntries).Length);
    }

    [Fact]
    public async Task Rescan_reports_progress_per_source()
    {
        using var api = NewApi();
        var reports = new List<SourceScanProgress>();
        var sources = await api.RescanSourcesAsync(progress: new SyncProgress<SourceScanProgress>(reports.Add));
        Assert.Equal(3, reports[^1].Completed);
        Assert.Equal("not-found", reports[^1].Providers.Single(p => p.Name == "Gemini").State);
        Assert.Equal("complete", reports[^1].Providers.Single(p => p.Name == "Codex").State);
        Assert.True(sources.Sources.Single(s => s.Id == "codex").Tokens > 0);
    }

    [Fact]
    public async Task Sync_without_uploader_analyzes_locally_and_says_so()
    {
        using var api = NewApi();
        var result = await api.SyncNowAsync();
        Assert.Equal("not_paired", result.State);
        Assert.Null(result.Data.Device);
        Assert.Equal("Local only", Assert.Single(result.Data.History).Result);
        Assert.NotNull(api.LastSnapshot);
        Assert.True(result.Data.NextSync.Events > 0); // daily chờ đẩy lên cloud

        var queue = await api.GetSyncStateConfigAsync();
        Assert.Contains(queue.Queue, q => q.Id == "codex" && q.Events > 0);
        Assert.Equal("rejected", (await api.PairDeviceAsync("123456")).State);
    }

    [Fact]
    public async Task Sync_with_uploader_marks_summaries_as_sent()
    {
        using var api = NewApi();
        int uploads = 0;
        api.Uploader = (snap, _) => { uploads++; return Task.FromResult((long)snap.ChangedDaily.Count * 1000); };
        var first = await api.SyncNowAsync();
        Assert.Equal("success", first.State);
        Assert.Equal(0, first.Data.NextSync.Events);
        var second = await api.SyncNowAsync();
        Assert.Equal("no_new_usage", second.State);
        Assert.Equal(2, uploads);
    }

    [Fact]
    public async Task Diagnostics_describe_real_storage()
    {
        using var api = NewApi();
        await api.GetSourcesAsync();
        var report = await api.GetDiagnosticsAsync();
        Assert.Contains("9 usage events", report);
        Assert.Contains("Codex: ~/.codex/sessions → Running", report);
        Assert.DoesNotContain("Mock", report);
    }

    [Fact]
    public async Task Prices_are_updated_from_models_dev_once_per_day()
    {
        int calls = 0;
        var handler = new StubHandler(() =>
        {
            calls++;
            return """{"anthropic":{"models":{"claude-opus-5-5":{"cost":{"input":4,"output":20,"cache_read":0.2,"cache_write":5}}}}}""";
        });
        using var api = NewApi(new HttpClient(handler));
        await api.GetSourcesAsync(); // quét log trước
        Assert.True(await api.UpdatePricesAsync());
        Assert.False(await api.UpdatePricesAsync()); // còn mới → không gọi lại
        Assert.Equal(1, calls);
        var report = await api.GetDiagnosticsAsync();
        Assert.Contains("Price catalog: 1 models from models.dev", report);
        Assert.Contains("codex-auto-review (fallback price)", report);
    }

    [Fact]
    public async Task Price_update_failure_keeps_working()
    {
        using var api = NewApi(new HttpClient(new StubHandler(() => throw new HttpRequestException("offline"))));
        Assert.False(await api.UpdatePricesAsync());
        Assert.True((await api.GetSourcesAsync()).Sources.Single(s => s.Id == "codex").EstimatedCost > 0);
    }

    [AvaloniaFact]
    public async Task Main_view_model_loads_with_real_api()
    {
        using var api = NewApi();
        var vm = new MainViewModel(api);
        await vm.LoadCommand.ExecuteAsync(null);
        Assert.Null(vm.Error);
        Assert.Equal(3, vm.SourceList!.Sources.Length);
        Assert.True(vm.Overview!.TotalTokens > 0);
    }

    public void Dispose()
    {
        Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools();
        _home.Delete(true);
    }

    private sealed class StubHandler(Func<string> body) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct) =>
            Task.FromResult(new HttpResponseMessage(System.Net.HttpStatusCode.OK) { Content = new StringContent(body()) });
    }

    private sealed class FixedClock(DateTimeOffset now) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => now;
    }

    /// <summary>IProgress gọi đồng bộ (Progress&lt;T&gt; mặc định gọi qua SynchronizationContext).</summary>
    private sealed class SyncProgress<T>(Action<T> report) : IProgress<T>
    {
        public void Report(T value) => report(value);
    }
}
