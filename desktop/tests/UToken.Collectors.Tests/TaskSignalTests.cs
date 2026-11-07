using UToken.Collectors.ClaudeCode;
using UToken.Collectors.Codex;
using UToken.Core.Models;
using UToken.Core.Pricing;
using UToken.Core.Tasks;
using Xunit;

namespace UToken.Collectors.Tests;

public class TaskSignalTests
{
    private static string FixturePath(string rel) => Path.Combine(AppContext.BaseDirectory, "fixtures", rel);
    private static IEnumerable<string> Fixture(string rel) => File.ReadLines(FixturePath(rel)).Where(l => l.Length > 0);
    private static readonly DateTimeOffset Later = DateTimeOffset.Parse("2026-11-06T00:00:00Z");

    [Fact] // Nghiệm thu FR-ANLY-003: sửa file rồi pytest exit 0, không lỗi turn → verified_success
    public void Codex_file_change_then_passing_test_is_verified_success()
    {
        var p = new CodexCollector.Parser("fallback");
        foreach (var line in Fixture("codex/task-signals.jsonl")) p.Feed(line);

        Assert.Equal(3, p.Events.Count);
        Assert.All(p.Events, e => Assert.Equal("s-main", e.SessionId));
        Assert.All(p.Events, e => Assert.Equal(ProjectKey.FromPath("/work/demo-app"), e.ProjectKey));

        var turns = p.Turns;
        Assert.Equal(2, turns.Count);
        var t1 = turns.Single(t => t.TurnId == "t-1");
        Assert.True(t1.FilesChanged);
        Assert.Equal(1, t1.TestRuns);
        Assert.True(t1.LastTestPassed);
        Assert.Equal(30_000, t1.DurationMs);

        var t2 = turns.Single(t => t.TurnId == "t-2");
        Assert.True(t2.TurnError);
        Assert.Equal(1, t2.CommandsFailed);

        // Turn 2 bắt đầu sau 20 phút → task riêng.
        var tasks = TaskBuilder.Build(turns, p.Events, StaticPriceBook.Default, Later);
        Assert.Equal(2, tasks.Count);
        Assert.Equal(OutcomeState.VerifiedSuccess, tasks.Single(t => t.SessionId == "s-main" && t.Turns == 1 && t.Requests == 2).Outcome);
        Assert.Equal(OutcomeState.VerifiedFailure, tasks.Single(t => t.Requests == 1).Outcome);
    }

    [Fact]
    public void Codex_guardian_session_is_side_and_has_no_turns()
    {
        var p = new CodexCollector.Parser("fallback");
        foreach (var line in Fixture("codex/guardian.jsonl")) p.Feed(line);
        var e = Assert.Single(p.Events);
        Assert.True(e.IsSideSession);
        Assert.Empty(p.Turns);
    }

    [Fact] // Đọc nối tiếp từ offset (giữ ngữ cảnh) phải cho cùng kết quả như đọc một lần
    public void Codex_incremental_read_matches_single_read()
    {
        var lines = File.ReadAllLines(FixturePath("codex/task-signals.jsonl"));
        var dir = Directory.CreateTempSubdirectory("utoken-test-");
        try
        {
            var path = Path.Combine(dir.FullName, "rollout-test.jsonl");
            var c = new CodexCollector();

            File.WriteAllText(path, string.Join('\n', lines[..7]) + "\n");
            var r1 = c.ReadNew(new SourceFileState(path, 0, false));
            File.AppendAllText(path, string.Join('\n', lines[7..]) + "\n");
            var r2 = c.ReadNew(r1.NewState);

            var single = c.ReadNew(new SourceFileState(path, 0, false));
            Assert.Equal(single.Events.Count, r1.Events.Count + r2.Events.Count);
            Assert.Equal(single.Events.Select(e => e.SourceEventId), r1.Events.Concat(r2.Events).Select(e => e.SourceEventId));

            // Turn mới nhất của lần đọc thứ hai phải giống hệt khi đọc một lần.
            var lastTurns = r1.Turns.Concat(r2.Turns).GroupBy(t => t.TurnId).Select(g => g.Last()).OrderBy(t => t.TurnId);
            Assert.Equal(single.Turns.OrderBy(t => t.TurnId), lastTurns);
            Assert.Equal(new FileInfo(path).Length, r2.NewState.ReadOffset);
        }
        finally { dir.Delete(true); }
    }

    [Fact]
    public void Claude_tracks_turns_tools_and_tests()
    {
        var p = new ClaudeCodeCollector.Parser();
        foreach (var line in Fixture("claude_code/task-signals.jsonl")) p.Feed(line);

        Assert.Equal(5, p.Events.Count); // msg_a (2 dòng) gộp làm 1, cộng msg_b, msg_side, msg_c, msg_d
        var side = Assert.Single(p.Events, e => e.IsSideSession);
        Assert.Null(side.TurnId);

        var turns = p.Turns;
        Assert.Equal(2, turns.Count);
        var t1 = turns.Single(t => t.TurnId == "u-1");
        Assert.True(t1.FilesChanged);
        Assert.True(t1.LastTestPassed); // npm test sau lần Edit
        Assert.Equal(2, t1.CommandsTotal);

        var t2 = turns.Single(t => t.TurnId == "u-4");
        Assert.Equal(3, t2.MaxConsecutiveFailures);
        Assert.Null(t2.LastTestPassed);

        var tasks = TaskBuilder.Build(turns, p.Events, StaticPriceBook.Default, Later);
        Assert.Equal(OutcomeState.VerifiedSuccess, tasks.Single(t => t.StartedAt.Minute == 0).Outcome);
        Assert.Equal(OutcomeState.LikelyFailure, tasks.Single(t => t.StartedAt.Minute == 30).Outcome);
        Assert.Equal("claude-opus-5-5", tasks[0].Model);
        Assert.Equal("medium", tasks[0].Effort);
    }

    [Fact]
    public void Claude_synthetic_messages_are_not_model_calls()
    {
        var p = new ClaudeCodeCollector.Parser();
        p.Feed("""{"type":"assistant","sessionId":"c-1","timestamp":"2026-11-05T10:00:00Z","isApiErrorMessage":true,"message":{"id":"syn-1","model":"<synthetic>","usage":{"input_tokens":0,"output_tokens":0}}}""");
        Assert.Empty(p.Events);
    }

    [Fact]
    public void Malformed_line_is_counted_not_thrown()
    {
        var p = new ClaudeCodeCollector.Parser();
        p.Feed("{not json");
        Assert.Equal(1, p.MalformedLines);
        Assert.Empty(p.Events);
    }
}
