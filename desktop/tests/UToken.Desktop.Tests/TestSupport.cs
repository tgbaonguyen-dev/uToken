using Avalonia;
using Avalonia.Controls;
using Avalonia.Headless;
using Avalonia.Threading;
using UToken.Collectors.ClaudeCode;
using UToken.Collectors.Codex;
using UToken.Core.Aggregation;
using UToken.Core.Efficiency;
using UToken.Desktop.App.Services;
using UToken.Engine;
using UToken.Insights;
using UToken.Storage;
using UToken.Sync;
using UToken.Sync.Auth;
using Xunit;

[assembly: AvaloniaTestApplication(typeof(UToken.Desktop.Tests.TestApp))]
namespace UToken.Desktop.Tests;

public static class TestApp
{
    public static AppBuilder BuildAvaloniaApp() => AppBuilder.Configure<App.App>()
        .WithInterFont().UseSkia().UseHeadless(new AvaloniaHeadlessPlatformOptions { UseHeadlessDrawing = false });

    /// <summary>Vẽ cửa sổ headless và lưu PNG vào bin/.../Screenshots để xem lại giao diện.</summary>
    internal static void Render(Window window, string name)
    {
        window.UpdateLayout();
        Dispatcher.UIThread.RunJobs();
        AvaloniaHeadlessPlatform.ForceRenderTimerTick();
        using var bitmap = window.CaptureRenderedFrame();
        Assert.NotNull(bitmap);
        var directory = Path.Combine(AppContext.BaseDirectory, "Screenshots");
        Directory.CreateDirectory(directory);
        bitmap.Save(Path.Combine(directory, name + ".png"));
    }

    /// <summary>Chờ lệnh đang chạy (ví dụ lần tải khi cửa sổ mở) xong.</summary>
    internal static async Task WaitIdle(UToken.Desktop.App.ViewModels.MainViewModel vm)
    {
        var deadline = DateTime.UtcNow.AddSeconds(10);
        while ((vm.IsBusy || vm.IsLoading) && DateTime.UtcNow < deadline) await Task.Delay(20);
    }
}

/// <summary>
/// Thư mục home giả dựng từ contracts/fixtures: log Codex (phiên chính + guardian) và Claude Code.
/// Mỗi test một thư mục riêng, có SQLite, settings, autostart và đồng hồ cố định riêng.
/// </summary>
public sealed class RealHome : IDisposable
{
    public static readonly TimeZoneInfo Utc7 = TimeZoneInfo.CreateCustomTimeZone("UTC+7", TimeSpan.FromHours(7), "UTC+7", "UTC+7");
    private readonly DirectoryInfo _root = Directory.CreateTempSubdirectory("utoken-ui-");
    public MutableClock Clock { get; } = new(DateTimeOffset.Parse("2026-11-06T01:00:00Z"));
    public FakeCloud Cloud { get; } = new();
    public string Home => _root.FullName;
    public string DataDirectory => Path.Combine(Home, "appdata");
    public string AutostartDirectory => Path.Combine(Home, "autostart");
    public string DatabasePath => Path.Combine(DataDirectory, "utoken.db");
    public LocalSettingsStore Settings => new(DataDirectory);

    public RealHome(bool withLogs = true)
    {
        Directory.CreateDirectory(DataDirectory);
        if (!withLogs) return;
        CopyFixture("codex/task-signals.jsonl", ".codex/sessions/2026/11/05/rollout-main.jsonl");
        CopyFixture("codex/guardian.jsonl", ".codex/sessions/2026/11/05/rollout-guard.jsonl");
        CopyFixture("claude_code/task-signals.jsonl", ".claude/projects/-work-demo-app/c-100.jsonl");
    }

    public void CopyFixture(string fixture, string relative)
    {
        var dest = Path.Combine(Home, relative);
        Directory.CreateDirectory(Path.GetDirectoryName(dest)!);
        File.Copy(Path.Combine(AppContext.BaseDirectory, "fixtures", fixture), dest, overwrite: true);
    }

    /// <summary>API dữ liệu thật trên thư mục này. <paramref name="cloud"/> = false: chưa cấu hình đăng nhập Google.</summary>
    public RealDesktopApi Api(bool cloud = true, ICloudSync? cloudSync = null,
        string? judgeDirectory = null,
        Func<string, string, string, IJudgeModel>? judgeFactory = null)
    {
        var store = new SqliteStore(DatabasePath);
        var engine = new UsageEngine(store, [new CodexCollector(), new ClaudeCodeCollector()], Home, Utc7, clock: Clock);
        var locations = RealDesktopApi.DefaultLocations(Path.Combine(Home, ".codex"), Path.Combine(Home, ".claude"), Home, ["codex", "claude_code"]);
        return new RealDesktopApi(engine, store, locations, DatabasePath, Settings, clock: Clock, cloud: cloudSync ?? (cloud ? Cloud : null))
        {
            Startup = new StartupRegistration(AutostartDirectory, "/opt/utoken/UToken.Desktop.App"),
            PriceHttpClient = new HttpClient(new OfflineHandler()), // test không gọi mạng
            JudgeHttpClient = new HttpClient(new OfflineHandler()),
            JudgeDirectory = judgeDirectory,
            JudgeModelFactory = judgeFactory,
        };
    }

    public void Dispose()
    {
        Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools();
        try { _root.Delete(true); } catch (IOException) { }
    }

    private sealed class OfflineHandler : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct) =>
            throw new HttpRequestException("offline in tests");
    }
}

public sealed class MutableClock(DateTimeOffset now) : TimeProvider
{
    public DateTimeOffset Now { get; set; } = now;
    public override DateTimeOffset GetUtcNow() => Now;
}

/// <summary>ICloudSync giả: ghi lại những gì được đẩy lên, có thể giả lập phiên hết hạn hoặc mất mạng.</summary>
public sealed class FakeCloud : ICloudSync
{
    public enum Failure { None, Revoked, Network, Server }
    public CloudAccount? Account { get; private set; }
    public Failure NextUpload { get; set; }
    public bool SignInFails { get; set; }
    public Exception? SignInError { get; set; }
    public List<(IReadOnlyList<DailyDoc> Daily, EfficiencyDoc Efficiency)> Uploads { get; } = [];
    public List<InsightDoc> InsightUploads { get; } = [];

    public Task<CloudAccount?> RestoreAsync(CancellationToken ct = default) => Task.FromResult(Account);

    public Task<CloudAccount> SignInAsync(CancellationToken ct = default)
    {
        if (SignInError is not null) throw SignInError;
        if (SignInFails) throw new CloudAuthException("cancelled");
        Account = new CloudAccount("uid-1", "ana@example.com", "Ana", "utoken-78191", Emulator: true);
        return Task.FromResult(Account);
    }

    public Task SignOutAsync(CancellationToken ct = default) { Account = null; return Task.CompletedTask; }

    public Task<long> UploadAsync(IReadOnlyList<DailyDoc> daily, EfficiencyDoc efficiency, CancellationToken ct = default)
    {
        var failure = NextUpload;
        NextUpload = Failure.None;
        return failure switch
        {
            Failure.Revoked => throw new CloudAuthException("revoked"),
            Failure.Network => throw new HttpRequestException("no route to host"),
            Failure.Server => throw new HttpRequestException("server", null, System.Net.HttpStatusCode.ServiceUnavailable),
            _ => Record(),
        };

        Task<long> Record()
        {
            Uploads.Add((daily, efficiency));
            return Task.FromResult(1000L * (daily.Count + 1));
        }
    }

    public Task<long> UploadInsightsAsync(InsightDoc insights, CancellationToken ct = default)
    {
        InsightUploads.Add(insights);
        return Task.FromResult(500L);
    }

    /// <summary>Yêu cầu mobile đang chờ; Finished ghi lại (id, error_code) khi desktop trả lời.</summary>
    public List<MobileSyncRequest> PendingRequests { get; } = [];
    public List<(string Id, string? Error)> Finished { get; } = [];

    public Task<IReadOnlyList<MobileSyncRequest>> ClaimSyncRequestsAsync(CancellationToken ct = default)
    {
        var claimed = PendingRequests.ToList();
        PendingRequests.Clear();
        return Task.FromResult<IReadOnlyList<MobileSyncRequest>>(claimed);
    }

    public Task FinishSyncRequestsAsync(IReadOnlyList<string> ids, string? errorCode, CancellationToken ct = default)
    {
        foreach (var id in ids) Finished.Add((id, errorCode));
        return Task.CompletedTask;
    }
}
