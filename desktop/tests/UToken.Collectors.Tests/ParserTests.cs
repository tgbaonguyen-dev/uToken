using UToken.Collectors.ClaudeCode;
using UToken.Collectors.Codex;
using Xunit;

namespace UToken.Collectors.Tests;

public class ParserTests
{
    private static IEnumerable<string> Fixture(string rel) =>
        File.ReadLines(Path.Combine(AppContext.BaseDirectory, "fixtures", rel)).Where(l => l.Length > 0);

    [Fact]
    public void Codex_reads_usage_and_model()
    {
        var p = new CodexCollector.Parser("fallback");
        foreach (var line in Fixture("codex/simple-turn.jsonl")) p.Feed(line);
        var e = Assert.Single(p.Events);
        Assert.Equal("gpt-x", e.Model);
        Assert.Equal("low", e.Effort);
        Assert.Equal(30_906, e.TotalTokens);
        Assert.Equal(79, e.Thinking);
    }

    [Fact] // FR-DATA-001: một phản hồi Claude Code ở 3 dòng → 1 event
    public void Claude_dedupes_by_message_id_and_normalizes_input()
    {
        var p = new ClaudeCodeCollector.Parser();
        foreach (var line in Fixture("claude_code/duplicate-lines.jsonl")) p.Feed(line);
        var e = Assert.Single(p.Events);
        Assert.Equal(10 + 9_000 + 500, e.Input);
        Assert.Equal(9_000, e.Cached);
        Assert.Equal(500, e.CacheWrite);
        Assert.Equal(120, e.Thinking);
    }
}
