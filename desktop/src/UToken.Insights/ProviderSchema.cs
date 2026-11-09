using System.Text.Json;
using System.Text.Json.Nodes;
namespace UToken.Insights;
public static class ProviderSchema
{
    public static IReadOnlyDictionary<string, JsonElement> Create()
    {
        var json = JsonNode.Parse("""{"type":"object","additionalProperties":false,"properties":{"score":{"type":["integer","null"],"minimum":0,"maximum":100},"grade":{"type":["string","null"]},"headline":{"type":"string"},"dimensions":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["id","score","comment"],"properties":{"id":{"type":"string"},"score":{"type":["integer","null"]},"comment":{"type":"string"}}}},"insights":{"type":"array","maxItems":5,"items":{"type":"object","additionalProperties":false,"required":["id","title","severity","category","provider","evidence","recommendation","estimated_impact","estimated_saving_usd_per_month","confidence"],"properties":{"id":{"type":"string"},"title":{"type":"string"},"severity":{"type":"string"},"category":{"type":"string"},"provider":{"type":["string","null"]},"evidence":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["metric"],"properties":{"metric":{"type":"string"}}}},"recommendation":{"type":"string"},"estimated_impact":{"type":["string","null"]},"estimated_saving_usd_per_month":{"type":["number","null"]},"confidence":{"type":"string"}}}}},"required":["score","grade","headline","dimensions","insights"]}""")!.AsObject();
        return json.Deserialize<Dictionary<string, JsonElement>>()!;
    }
}
