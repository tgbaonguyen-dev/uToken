using System.Text.Json;
using UToken.Desktop.App.Services;
using UToken.Insights;
using UToken.Sync;
using Xunit;

namespace UToken.Desktop.Tests;

/// <summary>AI review chạy sau Sync bằng model giả: không gọi mạng thật.</summary>
public sealed class JudgeSyncTests : IDisposable
{
    private const string Reply =
        """
        {"score":72,"grade":"B","headline":"Good cache use","dimensions":[],"insights":[]}
        """;

    private readonly RealHome _home = new();
    private readonly FakeJudge _judge = new();

    public JudgeSyncTests()
    {
        _home.Clock.Now = DateTimeOffset.Parse("2026-11-06T16:00:00Z");
        // Fixture gốc chỉ có vài chat; nhân bản phiên Claude để đủ ngưỡng 5 chat của judge.
        var source = File.ReadAllText(Path.Combine(
            AppContext.BaseDirectory, "fixtures", "claude_code", "task-signals.jsonl"));
        for (var i = 1; i <= 5; i++)
        {
            var copy = source.Replace("\"c-100\"", $"\"c-10{i}\"")
                .Replace("\"msg_", $"\"msg{i}_")
                .Replace("\"uuid\":\"", $"\"uuid\":\"s{i}-")
                .Replace("\"parentUuid\":\"", $"\"parentUuid\":\"s{i}-");
            File.WriteAllText(Path.Combine(_home.Home, ".claude", "projects", "-work-demo-app",
                $"c-10{i}.jsonl"), copy);
        }
    }

    private RealDesktopApi Api() => _home.Api(
        judgeDirectory: _home.DataDirectory,
        judgeFactory: (provider, model, key) => _judge.For(provider, model, key));

    [Fact]
    public async Task Pending_insights_survive_restart_and_retry_without_another_model_call()
    {
        using (var api = Api())
        {
            await api.SaveJudgeSettingsAsync(JudgeDefaults.For(JudgeProviders.Google), "key-1");
            await api.SignInAsync();
            _home.Cloud.FailInsightUpload = true;
            await api.SyncNowAsync();
            Assert.Empty(_home.Cloud.InsightUploads);
            Assert.Single(api.GetJudgeState().PendingUploads!);
            Assert.Equal(1, _judge.Calls);
        }
        _home.Cloud.FailInsightUpload = false;
        _home.Clock.Now += TimeSpan.FromHours(1);
        using var reopened = Api();
        await reopened.SyncNowAsync();
        Assert.Equal(72, Assert.Single(_home.Cloud.InsightUploads).Score);
        Assert.Empty(reopened.GetJudgeState().PendingUploads!);
        Assert.Equal(1, _judge.Calls);
        await reopened.SyncNowAsync();
        Assert.Single(_home.Cloud.InsightUploads);
    }

    [Fact]
    public async Task Pending_insights_retry_even_when_review_is_disabled()
    {
        using var api = Api();
        await api.SaveJudgeSettingsAsync(JudgeDefaults.For(JudgeProviders.Google), "key-1");
        await api.SignInAsync();
        _home.Cloud.FailInsightUpload = true;
        await api.SyncNowAsync();
        await api.SaveJudgeSettingsAsync(JudgeDefaults.For(JudgeProviders.Google) with { Enabled = false }, null);
        _home.Cloud.FailInsightUpload = false;
        await api.SyncNowAsync();
        Assert.Single(_home.Cloud.InsightUploads);
        Assert.Equal(1, _judge.Calls);
    }

    [Fact]
    public async Task Pending_insights_are_only_retried_for_the_original_account()
    {
        using var api = Api();
        await api.SaveJudgeSettingsAsync(JudgeDefaults.For(JudgeProviders.Google), "key-1");
        await api.SignInAsync();
        _home.Cloud.FailInsightUpload = true;
        await api.SyncNowAsync();
        await api.DisconnectAsync();
        _home.Cloud.NextSignInAccount = new("uid-2", "second@example.test", "Second", "utoken-78191", true);
        await api.SignInAsync();
        _home.Cloud.FailInsightUpload = false;
        await api.SyncNowAsync();
        Assert.Empty(_home.Cloud.InsightUploads);
        Assert.Single(api.GetJudgeState().PendingUploads!);
        await api.DisconnectAsync();
        _home.Cloud.NextSignInAccount = null;
        await api.SignInAsync();
        await api.SyncNowAsync();
        Assert.Single(_home.Cloud.InsightUploads);
        Assert.Equal(1, _judge.Calls);
    }

    [Fact]
    public async Task Sync_runs_judge_and_uploads_insights()
    {
        using var api = Api();
        await api.SaveJudgeSettingsAsync(JudgeDefaults.For(JudgeProviders.Google), "key-1");
        await api.SignInAsync();

        Assert.Equal("success", (await api.SyncNowAsync()).State);

        var upload = Assert.Single(_home.Cloud.InsightUploads);
        Assert.Equal("ok", upload.Status);
        Assert.Equal(72, upload.Score);
        Assert.Equal(1, _judge.Calls);
        Assert.Equal("key-1", _judge.LastKey);
        Assert.NotNull(api.GetJudgeState().LastRunAt);
        Assert.Contains("AI review: on · google", await api.GetDiagnosticsAsync());
        Assert.DoesNotContain("key-1", await api.GetDiagnosticsAsync());
    }

    [Fact]
    public async Task Judge_failure_keeps_sync_successful_and_previous_insights()
    {
        using var api = Api();
        await api.SaveJudgeSettingsAsync(JudgeDefaults.For(JudgeProviders.Google), "key-1");
        await api.SignInAsync();
        _judge.Response = Reply;
        Assert.Equal("success", (await api.RunJudgeAsync(force: true)).State);

        _judge.Error = "rate_limited";
        _home.Clock.Now = _home.Clock.Now.AddDays(2);
        AddFreshChats();
        Assert.Equal("success", (await api.SyncNowAsync()).State);

        var failed = _home.Cloud.InsightUploads[^1];
        Assert.Equal("failed", failed.Status);
        Assert.Equal("rate_limited", failed.ErrorCode);
        Assert.Equal(72, failed.Score); // giữ điểm cũ
        Assert.Equal(72, api.GetJudgeState().LastInsights!.Score);
        Assert.Equal("rate_limited", api.GetJudgeState().LastErrorCode);
    }

    [Fact]
    public async Task Mobile_ai_review_request_forces_a_fresh_review()
    {
        using var api = Api();
        await api.SaveJudgeSettingsAsync(JudgeDefaults.For(JudgeProviders.Google), "key-1");
        await api.SignInAsync();
        await api.SyncNowAsync(); // lần chạy theo lịch
        Assert.Equal(1, _judge.Calls);

        // Mới chạy xong (chưa đến hạn), nhưng điện thoại xin đánh giá lại: phải chạy ngay, đúng một lần.
        _home.Clock.Now = _home.Clock.Now.AddMinutes(5);
        AddFreshChats();
        _home.Cloud.PendingRequests.Add(new("r-review", "ai_review"));
        _home.Cloud.PendingRequests.Add(new("r-sync", "manual_refresh"));
        Assert.NotNull(await api.ServeMobileSyncRequestsAsync());

        Assert.Equal(2, _judge.Calls);
        Assert.Contains(("r-review", (string?)null), _home.Cloud.Finished);
        Assert.Contains(("r-sync", (string?)null), _home.Cloud.Finished);
    }

    [Fact]
    public async Task Mobile_review_without_new_usage_can_repeat_the_30_day_review()
    {
        using var api = Api();
        await api.SaveJudgeSettingsAsync(JudgeDefaults.For(JudgeProviders.Google), "key-1");
        await api.SignInAsync();
        await api.SyncNowAsync();
        _home.Cloud.PendingRequests.Add(new("r-review", "ai_review"));
        Assert.NotNull(await api.ServeMobileSyncRequestsAsync());
        Assert.Equal(2, _judge.Calls);
        Assert.Contains(("r-review", (string?)null), _home.Cloud.Finished);
    }

    [Fact]
    public async Task Mobile_ai_review_reports_missing_key()
    {
        using var api = Api();
        await api.SignInAsync();
        _home.Cloud.PendingRequests.Add(new("r-review", "ai_review"));
        await api.ServeMobileSyncRequestsAsync();
        Assert.Equal(("r-review", "missing_key"), Assert.Single(_home.Cloud.Finished));
    }

    [Fact]
    public async Task Judge_does_not_rerun_before_min_hours()
    {
        using var api = Api();
        await api.SaveJudgeSettingsAsync(JudgeDefaults.For(JudgeProviders.Google), "key-1");
        await api.SignInAsync();
        await api.SyncNowAsync();
        var uploads = _home.Cloud.InsightUploads.Count;

        _home.Clock.Now = _home.Clock.Now.AddHours(2);
        await api.SyncNowAsync();
        Assert.Equal(uploads, _home.Cloud.InsightUploads.Count);
        Assert.Equal("not_due", (await api.RunJudgeAsync(force: false)).State);

        _home.Clock.Now = _home.Clock.Now.AddHours(23);
        AddFreshChats();
        await api.SyncNowAsync();
        Assert.Equal(uploads + 1, _home.Cloud.InsightUploads.Count);
    }

    [Fact]
    public async Task Missing_key_or_disabled_skips_judge()
    {
        using var api = Api();
        await api.SignInAsync();
        await api.SyncNowAsync();
        Assert.Empty(_home.Cloud.InsightUploads);
        Assert.Equal("missing_key", (await api.RunJudgeAsync(force: true)).State);

        await api.SaveJudgeSettingsAsync(
            JudgeDefaults.For(JudgeProviders.Google) with { Enabled = false }, "key-1");
        Assert.Equal("disabled", (await api.RunJudgeAsync(force: false)).State);
        Assert.Equal(0, _judge.Calls);
    }

    [Fact]
    public async Task Settings_and_last_insights_survive_restart()
    {
        using (var api = Api())
        {
            await api.SaveJudgeSettingsAsync(
                JudgeDefaults.For(JudgeProviders.Anthropic) with { Model = "m-1" }, "key-a");
            await api.RunJudgeAsync(force: true);
        }
        using var reopened = Api();
        var state = reopened.GetJudgeState();
        Assert.Equal(JudgeProviders.Anthropic, state.Settings.Provider);
        Assert.Equal("m-1", state.Settings.Model);
        Assert.NotNull(state.LastRunAt);
        Assert.True(reopened.HasJudgeKey(JudgeProviders.Anthropic));
        var stateFile = File.ReadAllText(Path.Combine(_home.DataDirectory, "judge-state.json"));
        Assert.DoesNotContain("key-a", stateFile);
    }

    [Fact]
    public async Task Connection_test_maps_errors()
    {
        using var api = Api();
        Assert.Equal("missing_key",
            (await api.TestJudgeConnectionAsync(JudgeProviders.Google, "g", null)).State);
        _judge.Response = Reply;
        Assert.Equal("success",
            (await api.TestJudgeConnectionAsync(JudgeProviders.Google, "g", "k")).State);
        _judge.Error = "invalid_api_key";
        var bad = await api.TestJudgeConnectionAsync(JudgeProviders.Google, "g", "k");
        Assert.Equal("invalid_api_key", bad.State);
        Assert.Contains("rejected", bad.Message);
    }

    private int _freshBatch;
    private void AddFreshChats(int count = 6)
    {
        var batch = ++_freshBatch;
        var folder = Path.Combine(_home.Home, ".claude", "projects", "fresh-review");
        Directory.CreateDirectory(folder);
        for (var i = 0; i < count; i++)
            File.WriteAllText(Path.Combine(folder, $"review-{batch}-{i}.jsonl"), JsonSerializer.Serialize(new
            {
                type = "assistant", uuid = $"fresh-{batch}-{i}", sessionId = $"review-{batch}-{i}",
                timestamp = _home.Clock.Now.AddSeconds(-1).ToString("O"),
                message = new { id = $"fresh-{batch}-{i}", model = "claude-sonnet-4", usage = new { input_tokens = 100, output_tokens = 10 } },
            }) + "\n");
    }

    [Fact]
    public async Task Repeated_desktop_reviews_use_the_full_30_day_window_even_after_restart()
    {
        string firstBrief;
        using (var api = Api())
        {
            await api.SaveJudgeSettingsAsync(JudgeDefaults.For(JudgeProviders.Google), "key-1");
            Assert.Equal("success", (await api.RunJudgeAsync(force: true)).State);
            firstBrief = _judge.LastBrief!;
            var statePath = Path.Combine(_home.DataDirectory, "judge-state.json");
            var legacy = System.Text.Json.Nodes.JsonNode.Parse(File.ReadAllText(statePath))!;
            legacy["LastReviewedThrough"] = "2099-01-01T00:00:00Z";
            File.WriteAllText(statePath, legacy.ToJsonString());
        }
        using var reopened = Api();
        Assert.Equal("success", (await reopened.RunJudgeAsync(force: true)).State);
        Assert.Equal(2, _judge.Calls);
        Assert.Equal(firstBrief, _judge.LastBrief);
    }

    public void Dispose() => _home.Dispose();

    public sealed class FakeJudge
    {
        public string Response { get; set; } = Reply;
        public string? Error { get; set; }
        public int Calls { get; private set; }
        public string? LastKey { get; private set; }
        public string? LastBrief { get; private set; }
        public Action? BeforeReply;

        public IJudgeModel For(string provider, string model, string key)
        {
            LastKey = key;
            return new FakeModel(this, provider, model);
        }

        private sealed class FakeModel(FakeJudge owner, string provider, string model) : IJudgeModel
        {
            public string Provider => provider;
            public string Model => model;
            public Task<string> CompleteAsync(string systemPrompt, string briefJson,
                IReadOnlyDictionary<string, JsonElement> schema, CancellationToken ct)
            {
                owner.Calls++;
                owner.LastBrief = briefJson;
                owner.BeforeReply?.Invoke();
                if (owner.Error is not null) throw new JudgeModelException(owner.Error);
                return Task.FromResult(owner.Response);
            }
        }
    }
}
