using UToken.Insights;
using Xunit;

namespace UToken.Insights.Tests;

public sealed class InsightValidatorTests
{
    private static JudgeBrief Brief() => new("2026-01-01", "2026-01-30", "p",
        new Dictionary<string, MetricEntry> { ["usage.chats"] = new("Catalog Chats", "9", 9) },
        9, true, 100);

    private static InsightItem Item(string id, string metric = "usage.chats",
        string severity = "low", string confidence = "low", string? provider = "rogue") =>
        new(id, id, severity, "cache", provider,
            [new InsightEvidence(metric, "model label", "999")], "r", null, 200, confidence);

    private static InsightDoc Candidate(IReadOnlyList<InsightItem> items) => new(
        "ok", "", "", "", "bogus", "m", "p", 200, "Z", "h",
        [new InsightDimension("bogus", 200, "x")], items, null);

    private static InsightDoc Validate(InsightDoc candidate) => InsightValidator.Validate(
        candidate, Brief(), DateTimeOffset.Parse("2026-01-01T00:00:00Z"), "m", 100);

    [Fact]
    public void RemovesUnknownEvidenceAndEmptyInsights()
    {
        var result = Validate(Candidate([Item("unknown", "bad")]));
        Assert.Empty(result.Insights);
    }

    [Fact]
    public void ReplacesEvidenceLabelAndValueFromCatalog() {
        var evidence = Validate(Candidate([Item("i")])).Insights.Single().Evidence.Single();
        Assert.Equal("Catalog Chats", evidence.Label);
        Assert.Equal("9", evidence.Value);
    }

    [Fact]
    public void FiltersInvalidContractFieldsAndClampsScore() {
        var result = Validate(Candidate([Item("i", severity: "bad", confidence: "bad")]));
        Assert.Empty(result.Insights);
        Assert.Equal(100, result.Score);
        Assert.Null(result.Grade);
        Assert.Equal("m", result.Model);
        Assert.Empty(result.Dimensions);
    }

    [Fact]
    public void NullsInvalidProviderAndClampsSaving() {
        var result = Validate(Candidate([Item("i")]));
        Assert.Null(result.Insights.Single().Provider);
        Assert.Equal(100, result.Insights.Single().EstimatedSavingMicroPerMonth);
    }

    [Fact]
    public void DeduplicatesIdsAndLimitsInsightsToFive() {
        var items = Enumerable.Range(0, 8)
            .Select(i => Item(i < 2 ? "duplicate" : $"i{i}"))
            .ToArray();
        var result = Validate(Candidate(items));
        Assert.Equal(5, result.Insights.Count);
        Assert.Equal(1, result.Insights.Count(i => i.Id == "duplicate"));
    }
}
