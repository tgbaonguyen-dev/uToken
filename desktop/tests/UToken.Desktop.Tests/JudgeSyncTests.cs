using System.Text.Json;
using UToken.Desktop.App.Services;
using UToken.Insights;
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
        Assert.Equal("success", (await api.SyncNowAsync()).State);

        var failed = _home.Cloud.InsightUploads[^1];
        Assert.Equal("failed", failed.Status);
        Assert.Equal("rate_limited", failed.ErrorCode);
        Assert.Equal(72, failed.Score); // giữ điểm cũ
        Assert.Equal(72, api.GetJudgeState().LastInsights!.Score);
        Assert.Equal("rate_limited", api.GetJudgeState().LastErrorCode);
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

    public void Dispose() => _home.Dispose();

    public sealed class FakeJudge
    {
        public string Response { get; set; } = Reply;
        public string? Error { get; set; }
        public int Calls { get; private set; }
        public string? LastKey { get; private set; }

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
                if (owner.Error is not null) throw new JudgeModelException(owner.Error);
                return Task.FromResult(owner.Response);
            }
        }
    }
}
