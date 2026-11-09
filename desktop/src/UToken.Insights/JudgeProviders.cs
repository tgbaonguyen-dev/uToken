using System.Text.Json;

namespace UToken.Insights;

public static class JudgeProviders
{
    public const string Google = "google";
    public const string Anthropic = "anthropic";
    public const string OpenAi = "openai";
    public static readonly IReadOnlySet<string> All = new HashSet<string>(StringComparer.Ordinal) { Google, Anthropic, OpenAi };
}

/// <summary>Provider settings selected by the user.</summary>
public sealed record JudgeProviderSettings(string Provider, string Model, bool Enabled, int MinHoursBetweenRuns);

/// <summary>Sends a common rubric and returns the provider's raw JSON response.</summary>
public interface IJudgeModel
{
    string Provider { get; }
    string Model { get; }
    Task<string> CompleteAsync(
        string systemPrompt,
        string briefJson,
        IReadOnlyDictionary<string, JsonElement> schema,
        CancellationToken cancellationToken);
}

public static class JudgeDefaults
{
    public static JudgeProviderSettings For(string provider) => provider switch
    {
        JudgeProviders.Google => new(provider, "gemini-flash-latest", true, 24),
        JudgeProviders.Anthropic => new(provider, "claude-sonnet-5-5", true, 24),
        JudgeProviders.OpenAi => new(provider, "gpt-6-luna", true, 24),
        _ => throw new ArgumentOutOfRangeException(nameof(provider), provider, "Unsupported judge provider."),
    };
}
