using System.Text.Json;
using System.Text.Json.Nodes;

namespace UToken.Insights;

/// <summary>Shared strict schema sent to every provider.</summary>
public static class ProviderSchema
{
    public static IReadOnlyDictionary<string, JsonElement> Create()
    {
        var schema = new JsonObject
        {
            ["type"] = "object", ["additionalProperties"] = false,
            ["required"] = new JsonArray("score", "grade", "headline", "dimensions", "insights"),
            ["properties"] = new JsonObject
            {
                ["score"] = Nullable("integer"),
                ["grade"] = new JsonObject { ["type"] = new JsonArray("string", "null"), ["enum"] = new JsonArray("A", "B", "C", "D", null) },
                ["headline"] = new JsonObject { ["type"] = "string" },
                ["dimensions"] = ArrayOf(Dimension()),
                ["insights"] = ArrayOf(Insight()),
            },
        };
        return schema.Deserialize<Dictionary<string, JsonElement>>()!;
    }

    private static JsonObject Nullable(string type) => new() { ["type"] = new JsonArray(type, "null") };
    private static JsonObject ArrayOf(JsonObject item) => new() { ["type"] = "array", ["items"] = item };
    private static JsonObject Dimension() => new()
    {
        ["type"] = "object", ["additionalProperties"] = false,
        ["required"] = new JsonArray("id", "score", "comment"),
        ["properties"] = new JsonObject { ["id"] = new JsonObject { ["enum"] = new JsonArray("cache", "context", "reasoning", "reliability", "outcomes", "hidden_cost") }, ["score"] = Nullable("integer"), ["comment"] = new JsonObject { ["type"] = "string" } },
    };
    private static JsonObject Insight() => new()
    {
        ["type"] = "object", ["additionalProperties"] = false,
        ["required"] = new JsonArray("id", "title", "severity", "category", "provider", "evidence", "recommendation", "estimated_impact", "estimated_saving_usd_per_month", "confidence"),
        ["properties"] = new JsonObject
        {
            ["id"] = new JsonObject { ["type"] = "string" }, ["title"] = new JsonObject { ["type"] = "string" },
            ["severity"] = new JsonObject { ["enum"] = new JsonArray("high", "medium", "low") },
            ["category"] = new JsonObject { ["enum"] = new JsonArray("cache", "context", "reasoning", "reliability", "outcomes", "hidden_cost") },
            ["provider"] = new JsonObject { ["type"] = new JsonArray("string", "null"), ["enum"] = new JsonArray("codex", "claude_code", "antigravity", null) },
            ["evidence"] = ArrayOf(new JsonObject { ["type"] = "object", ["additionalProperties"] = false, ["required"] = new JsonArray("metric"), ["properties"] = new JsonObject { ["metric"] = new JsonObject { ["type"] = "string" } } }),
            ["recommendation"] = new JsonObject { ["type"] = "string" }, ["estimated_impact"] = Nullable("string"), ["estimated_saving_usd_per_month"] = Nullable("number"),
            ["confidence"] = new JsonObject { ["enum"] = new JsonArray("high", "medium", "low") },
        },
    };
}
