using UToken.Core.Aggregation;
using UToken.Core.Efficiency;
using UToken.Insights;
using Xunit;

namespace UToken.Insights.Tests;

public sealed class JudgeBriefBuilderTests
{
    [Fact]
    public void Brief_omits_project_key_and_uses_readable_metric_labels()
    {
        var bucket = new UsageBucket(
            Chats: 1, Requests: 2, ErrorRequests: 0, Input: 100, Cached: 20, CacheWrite: 0,
            Output: 30, Thinking: 0, CostMicro: 50, SideRequests: 0, SideTokens: 0,
            SideCostMicro: 0, ContextGrowthSum: 0, ContextGrowthCount: 0, BloatedChats: 0,
            DurationSumMs: null, DurationCount: null);
        var daily = new DailyDoc("2026-01-01", bucket,
            new Dictionary<string, UsageBucket>
            {
                ["codex|gpt-5.6-sol|3f2a9c1b04de"] = bucket,
            }, new TasksByState(0, 0, 0, 0, 0), "pricing", "2026-01-02T00:00:00Z");
        var efficiency = new EfficiencyDoc("2026-01-01", "2026-01-01",
            "2026-01-02T00:00:00Z", 0, [], [], "pricing");

        var brief = JudgeBriefBuilder.Build(efficiency, [daily]);
        var serialized = System.Text.Json.JsonSerializer.Serialize(brief);

        Assert.DoesNotContain("3f2a9c1b04de", serialized);
        Assert.Equal("Tokens", brief.Catalog["usage.codex.gpt-5.6-sol.tokens"].Label);
        Assert.DoesNotContain("good", brief.Catalog.Values.Select(entry => entry.Label));
        Assert.DoesNotContain("review", brief.Catalog.Values.Select(entry => entry.Label));
        Assert.DoesNotContain("no_data", brief.Catalog.Values.Select(entry => entry.Label));
    }
}
