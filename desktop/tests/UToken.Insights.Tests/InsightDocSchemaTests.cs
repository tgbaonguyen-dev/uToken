using System.Text.Json;
using System.Text.Json.Nodes;
using Json.Schema;
using UToken.Insights;
using Xunit;

namespace UToken.Insights.Tests;

/// <summary>Every document the desktop can upload must match the Firestore contract.</summary>
public sealed class InsightDocSchemaTests
{
    private static readonly JsonSchema Schema = JsonSchema.FromFile(
        Path.Combine(AppContext.BaseDirectory, "schemas", "insights.schema.json"));

    private static readonly JudgeBrief Brief = new(
        "2026-10-11", "2026-11-09", "models.dev@x",
        new Dictionary<string, MetricEntry>
        {
            ["usage.cache_hit_rate"] = new("Cache hit rate", "94.2%", 0.942),
        },
        Chats: 10, HasEvents: true, MonthlyCostMicro: 50_000_000);

    private static void AssertValid(InsightDoc doc)
    {
        var result = Schema.Evaluate(JsonNode.Parse(JsonSerializer.Serialize(doc)),
            new EvaluationOptions { OutputFormat = OutputFormat.List });
        Assert.True(result.IsValid, JsonSerializer.Serialize(doc));
    }

    [Fact]
    public async Task Ok_insufficient_and_failed_documents_match_the_contract()
    {
        var service = new JudgeService();
        const string output = """
            {"score":82,"grade":"B","headline":"Ổn","dimensions":[
              {"id":"cache","score":90,"comment":"Tốt"}],
             "insights":[{"id":"cache-1","title":"Cache","severity":"low","category":"cache",
              "provider":"codex","evidence":[{"metric":"usage.cache_hit_rate"}],
              "recommendation":"Giữ nguyên","estimated_impact":null,
              "estimated_saving_usd_per_month":1.5,"confidence":"high"}]}
            """;

        AssertValid(await service.RunAsync(Brief, new FakeModel(output), default));
        AssertValid(await service.RunAsync(Brief with { Chats = 1 }, new FakeModel(output), default));
        AssertValid(await service.RunAsync(Brief, new FakeModel("not json"), default));
    }

    private sealed class FakeModel(string text) : IJudgeModel
    {
        public string Provider => JudgeProviders.Google;
        public string Model => "gemini-flash-latest";

        public Task<string> CompleteAsync(string systemPrompt, string briefJson,
            IReadOnlyDictionary<string, JsonElement> schema, CancellationToken ct) =>
            Task.FromResult(text);
    }
}
