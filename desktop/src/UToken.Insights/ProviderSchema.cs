using System.Reflection;
using System.Text.Json;

namespace UToken.Insights;

/// <summary>Loads the shared strict structured-output schema.</summary>
public static class ProviderSchema
{
    public static IReadOnlyDictionary<string, JsonElement> Create()
    {
        using var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream(
            "UToken.Insights.Resources.judge-output.schema.json")
            ?? throw new InvalidOperationException("Judge output schema resource is missing.");
        return JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(stream)
            ?? throw new InvalidDataException("Judge output schema is empty.");
    }
}
