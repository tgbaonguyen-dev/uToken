using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace UToken.Insights;

/// <summary>Common transport implementation used by provider adapters; handlers can be injected in tests.</summary>
public abstract class HttpJudgeModel(HttpClient http, string apiKey, string model, string provider) : IJudgeModel
{
    public string Provider => provider;
    public string Model => model;

    public async Task<InsightDoc> JudgeAsync(JudgeBrief brief, CancellationToken cancellationToken)
    {
        if (brief.Chats < 5 || !brief.HasEvents)
            return Empty(brief, "insufficient_data", null);
        try
        {
            using var response = await SendAsync(BuildPrompt(brief), cancellationToken);
            var body = await response.Content.ReadAsStringAsync(cancellationToken);
            if (response.StatusCode == HttpStatusCode.Unauthorized || response.StatusCode == HttpStatusCode.Forbidden) return Empty(brief, "failed", "invalid_api_key");
            if ((int)response.StatusCode == 429) return Empty(brief, "failed", "rate_limited");
            if (!response.IsSuccessStatusCode) return Empty(brief, "failed", "provider_error");
            var result = Parse(body, brief);
            return result with { Provider = Provider, Model = Model };
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested) { return Empty(brief, "failed", "truncated"); }
        catch (HttpRequestException) { return Empty(brief, "failed", "provider_error"); }
        catch (JsonException) { return Empty(brief, "failed", "provider_error"); }
    }

    protected abstract Task<HttpResponseMessage> SendAsync(string prompt, CancellationToken cancellationToken);
    protected abstract JsonNode? Extract(JsonNode body);

    private InsightDoc Parse(string body, JudgeBrief brief)
    {
        var root = JsonNode.Parse(body) ?? throw new JsonException("Provider returned an empty response.");
        var result = Extract(root)?.Deserialize<InsightDoc>() ?? throw new JsonException("Provider returned no structured result.");
        return InsightValidator.Validate(result, brief, DateTimeOffset.UtcNow, Model, long.MaxValue);
    }
    private static string BuildPrompt(JudgeBrief brief) => JsonSerializer.Serialize(new { catalog = brief.Catalog, period_start = brief.PeriodStart, period_end = brief.PeriodEnd });
    private InsightDoc Empty(JudgeBrief brief, string status, string? error) => new(status, DateTimeOffset.UtcNow.ToString("O"), brief.PeriodStart, brief.PeriodEnd, Provider, Model, brief.PricingVersion, null, null, "", [], [], error);
}

public sealed class GeminiJudgeModel(HttpClient http, string apiKey, string model) : HttpJudgeModel(http, apiKey, model, JudgeProviders.Google)
{
    protected override Task<HttpResponseMessage> SendAsync(string prompt, CancellationToken ct) =>
        throw new NotSupportedException("Configure Gemini endpoint in the application host.");
    protected override JsonNode? Extract(JsonNode body) => body["candidates"]?[0]?["content"]?["parts"]?[0]?["text"] is JsonValue text && text.TryGetValue<string>(out var value) ? JsonNode.Parse(value) : null;
}

public sealed class AnthropicJudgeModel(HttpClient http, string apiKey, string model) : HttpJudgeModel(http, apiKey, model, JudgeProviders.Anthropic)
{
    protected override Task<HttpResponseMessage> SendAsync(string prompt, CancellationToken ct) => throw new NotSupportedException("Use the Anthropic SDK adapter in the application host.");
    protected override JsonNode? Extract(JsonNode body) => body["content"]?[0]?["text"] is JsonValue text && text.TryGetValue<string>(out var value) ? JsonNode.Parse(value) : null;
}

public sealed class OpenAiJudgeModel(HttpClient http, string apiKey, string model) : HttpJudgeModel(http, apiKey, model, JudgeProviders.OpenAi)
{
    protected override Task<HttpResponseMessage> SendAsync(string prompt, CancellationToken ct) => throw new NotSupportedException("Configure OpenAI endpoint in the application host.");
    protected override JsonNode? Extract(JsonNode body) => body["choices"]?[0]?["message"]?["content"] is JsonValue text && text.TryGetValue<string>(out var value) ? JsonNode.Parse(value) : null;
}
