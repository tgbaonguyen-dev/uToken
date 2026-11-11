using UToken.Core.Aggregation;
using UToken.Core.Efficiency;
using UToken.Core.Models;
using UToken.Core.Pricing;
using UToken.Core.Tasks;
using Xunit;

namespace UToken.Core.Tests;

/// <summary>Dữ liệu dựng tay cho TaskBuilder, DailyAggregator, EfficiencyCalculator.</summary>
internal static class Make
{
    public static readonly DateTimeOffset T0 = DateTimeOffset.Parse("2026-11-05T03:00:00Z");
    public static readonly TimeZoneInfo Utc7 = TimeZoneInfo.CreateCustomTimeZone("UTC+7", TimeSpan.FromHours(7), "UTC+7", "UTC+7");

    public static UsageEvent Ev(string session, string? turn, DateTimeOffset at, long input = 1000, long cached = 0, long output = 100,
        string model = "gpt-5.6-sol", string? effort = "medium", bool side = false, Provider provider = Provider.Codex, string? project = "p1",
        long? thinking = null) =>
        new(provider, Guid.NewGuid().ToString(), session, turn, model, effort, at, input, cached, 0, output, thinking, null, side, project);

    public static TurnRecord Turn(string session, string turn, DateTimeOffset start, TimeSpan? length = null,
        bool? lastTest = null, bool files = false, bool error = false, int maxFail = 0, long? durationMs = null,
        Provider provider = Provider.Codex) =>
        new(provider, session, turn, start, start + (length ?? TimeSpan.FromSeconds(30)), start + (length ?? TimeSpan.FromSeconds(30)),
            CommandsTotal: maxFail + (lastTest is null ? 0 : 1), CommandsFailed: maxFail + (lastTest == false ? 1 : 0),
            MaxConsecutiveFailures: maxFail, TestRuns: lastTest is null ? 0 : 1, LastTestPassed: lastTest,
            FilesChanged: files, TurnError: error, Aborted: false, DurationMs: durationMs, IsSideSession: false, ProjectKey: "p1");
}

public class TaskBuilderTests
{
    private static readonly DateTimeOffset Now = Make.T0.AddHours(5);

    [Fact] // SRS §5.1: turn mới trong ≤ 2 phút gộp vào task, tăng số lần làm lại
    public void Turns_within_two_minutes_merge_into_one_task()
    {
        var turns = new[]
        {
            Make.Turn("s", "t1", Make.T0, files: true),
            Make.Turn("s", "t2", Make.T0.AddSeconds(30 + 60), lastTest: true), // 60 giây sau khi t1 xong
            Make.Turn("s", "t3", Make.T0.AddMinutes(30)),                       // cách xa → task mới
        };
        var events = new[]
        {
            Make.Ev("s", "t1", Make.T0.AddSeconds(5)),
            Make.Ev("s", "t2", Make.T0.AddSeconds(95)),
            Make.Ev("s", "t3", Make.T0.AddMinutes(30).AddSeconds(5)),
        };
        var tasks = TaskBuilder.Build(turns, events, StaticPriceBook.Default, Now);

        Assert.Equal(2, tasks.Count);
        var first = tasks.OrderBy(t => t.StartedAt).First();
        Assert.Equal(2, first.Turns);
        Assert.Equal(1, first.RedoTurns);
        Assert.Equal(OutcomeState.VerifiedSuccess, first.Outcome); // test cuối pass sau khi sửa file
        Assert.Equal(OutcomeState.Undetermined, tasks.OrderBy(t => t.StartedAt).Last().Outcome);
    }

    [Fact]
    public void File_change_after_test_clears_test_result()
    {
        var turns = new[]
        {
            Make.Turn("s", "t1", Make.T0, lastTest: true),
            Make.Turn("s", "t2", Make.T0.AddSeconds(60), files: true),
        };
        var signals = TaskBuilder.MergeSignals(turns);
        Assert.Null(signals.LastTestPassed);
        Assert.True(signals.ReaskedWithin2Min);
    }

    [Fact]
    public void Open_task_is_undetermined_until_two_minutes_pass()
    {
        var turns = new[] { Make.Turn("s", "t1", Make.T0, lastTest: true) };
        var events = new[] { Make.Ev("s", "t1", Make.T0.AddSeconds(5)) };
        var open = TaskBuilder.Build(turns, events, StaticPriceBook.Default, Make.T0.AddMinutes(1)).Single();
        Assert.False(open.Closed);
        Assert.Equal(OutcomeState.Undetermined, open.Outcome);

        var closed = TaskBuilder.Build(turns, events, StaticPriceBook.Default, Make.T0.AddMinutes(10)).Single();
        Assert.True(closed.Closed);
        Assert.Equal(OutcomeState.VerifiedSuccess, closed.Outcome);
    }

    [Fact]
    public void Task_group_follows_request_count_and_cost_is_summed()
    {
        var turns = new[] { Make.Turn("s", "t1", Make.T0) };
        var events = Enumerable.Range(0, 12).Select(i => Make.Ev("s", "t1", Make.T0.AddSeconds(i), input: 1_000_000, output: 0)).ToList();
        var task = TaskBuilder.Build(turns, events, StaticPriceBook.Default, Now).Single();
        Assert.Equal(TaskGroup.Medium, task.Group);
        Assert.Equal(12 * 1_750_000L, task.CostMicro); // 1M input không cache × $1.75
        Assert.Equal(1.0, task.ContextGrowth);
    }

    [Fact]
    public void Side_session_events_do_not_form_tasks()
    {
        var events = new[] { Make.Ev("g", "t1", Make.T0, side: true) };
        Assert.Empty(TaskBuilder.Build([], events, StaticPriceBook.Default, Now));
    }
}

public class DailyAggregatorTests
{
    [Fact] // Nghiệm thu FR-DATA-002: ở UTC+7, event lúc 01:00 giờ địa phương thuộc ngày địa phương đó
    public void Event_belongs_to_local_date()
    {
        var at = DateTimeOffset.Parse("2026-11-05T18:00:00Z"); // 01:00 ngày 06/11 giờ UTC+7
        var doc = DailyAggregator.Build(new DateOnly(2026, 11, 6), Make.Utc7, [Make.Ev("s", "t", at)], [], [], StaticPriceBook.Default, at);
        Assert.Equal(1, doc.Totals.Requests);

        var prev = DailyAggregator.Build(new DateOnly(2026, 11, 5), Make.Utc7, [Make.Ev("s", "t", at)], [], [], StaticPriceBook.Default, at);
        Assert.Equal(0, prev.Totals.Requests);
    }

    [Fact] // Nghiệm thu FR-DATA-002: tính lại thì ghi đè, không cộng chồng
    public void Recompute_gives_identical_document()
    {
        var events = new[] { Make.Ev("s", "t", Make.T0), Make.Ev("s", "t", Make.T0.AddMinutes(1), input: 3000) };
        var a = DailyAggregator.Build(new DateOnly(2026, 11, 5), Make.Utc7, events, [], [], StaticPriceBook.Default, Make.T0);
        var b = DailyAggregator.Build(new DateOnly(2026, 11, 5), Make.Utc7, events, [], [], StaticPriceBook.Default, Make.T0);
        Assert.Equal(a.Totals, b.Totals);
        Assert.Equal(a.ByKey.Keys, b.ByKey.Keys);
    }

    [Fact]
    public void Totals_by_key_side_cost_and_growth()
    {
        var events = new[]
        {
            Make.Ev("s1", "t", Make.T0, input: 1000, cached: 400, output: 100, thinking: 40),
            Make.Ev("s1", "t", Make.T0.AddMinutes(1), input: 5000, cached: 4000, output: 100, thinking: 10),
            Make.Ev("s2", "t", Make.T0, input: 2000, output: 10, model: "claude-opus-5-5", provider: Provider.ClaudeCode, project: null),
            Make.Ev("g", null, Make.T0, input: 1_000_000, output: 0, model: "codex-auto-review", side: true),
            Make.Ev("s3", "t", Make.T0, model: "mystery-model"),
        };
        var turns = new[] { Make.Turn("s1", "t", Make.T0, durationMs: 4000) };
        var doc = DailyAggregator.Build(new DateOnly(2026, 11, 5), Make.Utc7, events, turns, [], StaticPriceBook.Default, Make.T0);

        Assert.Equal(3, doc.Totals.Chats);                 // phiên phụ không tính là chat
        Assert.Equal(5, doc.Totals.Requests);
        Assert.Equal(1, doc.Totals.SideRequests);
        Assert.Equal(1_000_000, doc.Totals.SideTokens);
        Assert.Equal(1_750_000, doc.Totals.SideCostMicro);
        Assert.Equal(50, doc.Totals.Thinking);
        Assert.Equal(1, doc.Totals.ContextGrowthCount);
        Assert.Equal(5.0, doc.Totals.ContextGrowthSum);
        Assert.Equal(1, doc.Totals.BloatedChats);
        Assert.Equal(4000, doc.Totals.DurationSumMs);

        Assert.Contains("codex|gpt-5.6-sol|p1", doc.ByKey.Keys);
        Assert.Contains("claude_code|claude-opus-5-5|none", doc.ByKey.Keys);
        Assert.Null(doc.ByKey["codex|mystery-model|p1"].CostMicro);   // thiếu giá
        Assert.Null(doc.ByKey["claude_code|claude-opus-5-5|none"].Thinking); // nguồn không cung cấp
        Assert.Equal(4000, doc.ByKey["codex|gpt-5.6-sol|p1"].DurationSumMs);
        Assert.Equal(doc.Totals.Input, doc.ByKey.Values.Sum(b => b.Input));
    }
}

public class EfficiencyTests
{
    private static readonly DateTimeOffset Now = DateTimeOffset.Parse("2026-11-06T12:00:00Z");

    /// <summary>Tạo n task đã đóng của một setup, mỗi phiên <paramref name="perSession"/> task, tỷ lệ verified_success ≈ sr.</summary>
    private static IEnumerable<TaskRecord> Tasks(string model, int n, double sr, long costMicro, int seed, int perSession = 1)
    {
        int successes = (int)Math.Round(n * sr);
        for (int i = 0; i < n; i++)
        {
            var at = Now.AddDays(-1 - (i % 25)).AddMinutes(-i);
            var outcome = i < successes ? OutcomeState.VerifiedSuccess : OutcomeState.VerifiedFailure;
            yield return new TaskRecord($"{model}-{seed}-{i}", Provider.Codex, $"{model}-sess-{i / perSession}", model, "medium", "p1",
                TaskGroup.Small, at, at.AddMinutes(1), 1, 3,
                new TaskSignals(1, 0, 1, 0, 0, outcome == OutcomeState.VerifiedSuccess, true, false, false, false),
                1, outcome, costMicro, 1000, null, true);
        }
    }

    [Fact] // Nghiệm thu FR-ANLY-003: A 60 task SR 85% $0.42, B 60 task SR 82% $0.18 → B "cheaper_not_worse"
    public void Cheaper_not_worse_setup()
    {
        var tasks = Tasks("model-a", 60, 0.85, 357_000, 1).Concat(Tasks("model-b", 60, 0.82, 147_600, 2)).ToList();
        var doc = EfficiencyCalculator.Build(Now, Make.Utc7, [], [], tasks, StaticPriceBook.Default);

        var b = doc.Setups.Single(s => s.Model == "model-b");
        Assert.Equal("cheaper_not_worse", b.Verdict);
        Assert.Equal("medium", b.Confidence);
        Assert.Equal("model-a · medium", b.ComparedTo);
        Assert.InRange(b.Mde!.Value, 0.15, 0.25);
        Assert.Equal(60, b.NTasks);
        Assert.Equal(60, b.NSessions);
        Assert.Equal(180_000, b.CpstMicro!.Value, 1_000d);

        var a = doc.Setups.Single(s => s.Model == "model-a");
        Assert.Equal("model-b · medium", a.ComparedTo);
        Assert.Equal("worse", a.Verdict); // đắt hơn rõ, SR không tốt hơn rõ
    }

    [Fact] // Nghiệm thu: setup 12 task → "insufficient", không xếp hạng
    public void Few_tasks_is_insufficient()
    {
        var tasks = Tasks("model-a", 12, 0.9, 100_000, 1).Concat(Tasks("model-b", 60, 0.8, 100_000, 2)).ToList();
        var doc = EfficiencyCalculator.Build(Now, Make.Utc7, [], [], tasks, StaticPriceBook.Default);
        var a = doc.Setups.Single(s => s.Model == "model-a");
        Assert.Equal("insufficient", a.Verdict);
        Assert.Equal(12, a.NTasks);
        Assert.Null(a.Confidence);
    }

    [Fact]
    public void Sr_ci_cpst_and_weekly_values()
    {
        var tasks = Tasks("model-a", 40, 0.75, 200_000, 1).ToList();
        var doc = EfficiencyCalculator.Build(Now, Make.Utc7, [], [], tasks, StaticPriceBook.Default);
        var s = Assert.Single(doc.Setups);
        Assert.Equal(0.75, s.Sr);
        Assert.True(s.SrCiLow < 0.75 && s.SrCiHigh > 0.75);
        Assert.Equal(266_667, s.CpstMicro);          // 40 × 0.2$ / 30 thành công
        Assert.Equal(200_000, s.CostP50Micro);
        Assert.Equal("insufficient", s.Verdict);     // không có setup khác để so
        Assert.Null(s.ComparedTo);
        Assert.Equal(5, s.WeeklySr.Count);
        Assert.False(s.CrossTool);
    }

    [Fact] // M05/M05B: SR chính ± khoảng tin cậy, SR phụ, CPST và P50/P90 tính trên mọi setup
    public void Overall_outcome_spans_all_setups()
    {
        var tasks = Tasks("model-a", 40, 0.75, 200_000, 1).Concat(Tasks("model-b", 20, 0.5, 100_000, 2)).ToList();
        var doc = EfficiencyCalculator.Build(Now, Make.Utc7, [], [], tasks, StaticPriceBook.Default);
        var o = doc.Overall!;
        Assert.Equal(60, o.NTasks);
        Assert.Equal(60, o.NVerified);
        Assert.Equal(0.6667, o.Sr);                  // (30 + 10) / 60
        Assert.True(o.SrCiLow < o.Sr && o.SrCiHigh > o.Sr);
        Assert.Equal(o.Sr, o.SrAlt);                 // không có task likely
        Assert.Equal(250_000, o.CpstMicro);          // (40 × 0.2$ + 20 × 0.1$) / 40 thành công
        Assert.Equal(200_000, o.CostP50Micro);
        Assert.Equal(200_000, o.CostP90Micro);
    }

    [Fact]
    public void Overall_is_null_without_tasks() =>
        Assert.Null(EfficiencyCalculator.Build(Now, Make.Utc7, [], [], [], StaticPriceBook.Default).Overall);

    [Fact] // Cần ≥ 5 chat trong kỳ mới gắn nhãn
    public void Process_metrics_need_five_chats()
    {
        var few = Enumerable.Range(0, 3).Select(i => Make.Ev($"s{i}", "t", Now.AddHours(-i), input: 1000, cached: 100)).ToList();
        var doc = EfficiencyCalculator.Build(Now, Make.Utc7, few, [], [], StaticPriceBook.Default);
        var cache = doc.ProcessMetrics.Single(m => m.Metric == "cache_hit_rate" && m.Provider is null);
        Assert.Equal(0.1, cache.Value);
        Assert.Equal(Labels.NoData, cache.Label);

        var many = Enumerable.Range(0, 6).Select(i => Make.Ev($"s{i}", "t", Now.AddHours(-i), input: 1000, cached: 100)).ToList();
        doc = EfficiencyCalculator.Build(Now, Make.Utc7, many, [], [], StaticPriceBook.Default);
        Assert.Equal(Labels.Review, doc.ProcessMetrics.Single(m => m.Metric == "cache_hit_rate" && m.Provider is null).Label);
        Assert.Contains(doc.ProcessMetrics, m => m.Provider == "codex");
    }

    [Fact] // FR-ANLY-004: chi phí phiên phụ > 30% → Review
    public void Hidden_cost_share_over_30_percent_is_review()
    {
        var events = Enumerable.Range(0, 5).Select(i => Make.Ev($"s{i}", "t", Now.AddHours(-i), input: 1000))
            .Append(Make.Ev("g", null, Now.AddHours(-1), input: 100_000, model: "codex-auto-review", side: true)).ToList();
        var doc = EfficiencyCalculator.Build(Now, Make.Utc7, events, [], [], StaticPriceBook.Default);
        var hidden = doc.ProcessMetrics.Single(m => m.Metric == "hidden_cost_share" && m.Provider is null);
        Assert.True(hidden.Value > 0.9);
        Assert.Equal(Labels.Review, hidden.Label);
    }
}

public class StatsAndPricingTests
{
    [Fact]
    public void Cluster_se_is_larger_when_sessions_are_correlated()
    {
        // 10 phiên, mỗi phiên 4 task cùng kết quả → tương quan mạnh trong cụm.
        var correlated = Enumerable.Range(0, 40).Select(i => ($"s{i / 4}", (i / 4) % 2 == 0)).ToList();
        var independent = Enumerable.Range(0, 40).Select(i => ($"s{i}", i % 2 == 0)).ToList();
        Assert.True(Stats.ClusterStandardError(correlated) > 1.5 * Stats.ClusterStandardError(independent));
    }

    [Fact]
    public void Bootstrap_is_deterministic()
    {
        var clusters = Enumerable.Range(0, 20).Select(i => ((double)(100 + i * 10), (double)(i % 3 == 0 ? 0 : 1))).ToList();
        var a = Stats.BootstrapRatioCi(clusters);
        var b = Stats.BootstrapRatioCi(clusters);
        Assert.Equal(a, b);
        Assert.True(a!.Value.Low < a.Value.High);
    }

    [Theory]
    [InlineData(Provider.ClaudeCode, "claude-opus-5-5", 5.00)]
    [InlineData(Provider.ClaudeCode, "claude-sonnet-5-5", 3.00)]
    [InlineData(Provider.Codex, "gpt-5.6-sol", 1.75)]
    [InlineData(Provider.Codex, "codex-auto-review", 1.75)]
    public void Price_lookup_by_prefix(Provider p, string model, double input) =>
        Assert.Equal((decimal)input, StaticPriceBook.Default.Find(p, model)!.InputPerMTok);

    [Fact]
    public void Unknown_model_has_no_price() => Assert.Null(StaticPriceBook.Default.Find(Provider.Codex, "mystery"));

    [Theory]
    [InlineData("/bin/bash -lc pytest -q", true)]
    [InlineData("npm test", true)]
    [InlineData("pnpm run build", true)]
    [InlineData("dotnet test desktop/", true)]
    [InlineData("flutter test", true)]
    [InlineData("cd app && cargo build --release", true)]
    [InlineData("make", true)]
    [InlineData("ls -la", false)]
    [InlineData("cat package.json", false)]
    [InlineData("git status", false)]
    public void Test_command_detection(string cmd, bool expected) =>
        Assert.Equal(expected, TestCommandDetector.IsTestOrBuild(cmd));

    [Fact]
    public void Project_key_is_stable_hash()
    {
        Assert.Equal(ProjectKey.FromPath("/work/app"), ProjectKey.FromPath("/work/app/"));
        Assert.Equal(12, ProjectKey.FromPath("/work/app")!.Length);
        Assert.Equal("app", ProjectKey.DisplayName("/work/app"));
        Assert.Null(ProjectKey.FromPath(null));
    }
}
