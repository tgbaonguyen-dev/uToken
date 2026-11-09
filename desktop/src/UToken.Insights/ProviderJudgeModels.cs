using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
namespace UToken.Insights;
internal sealed class JudgeModelException(string code) : Exception(code) { public string Code { get; } = code; }
public abstract class HttpJudgeModel(HttpClient http, string apiKey, string model, string provider) : IJudgeModel
{
    protected readonly HttpClient Http = http; protected readonly string ApiKey = apiKey; public string Provider => provider; public string Model => model;
    public async Task<InsightDoc> JudgeAsync(JudgeBrief brief, CancellationToken cancellationToken)
    {
        if (brief.Chats < 5 || !brief.HasEvents) return Empty(brief, "insufficient_data", null);
        try { using var response = await SendAsync(brief, cancellationToken); var body = await response.Content.ReadAsStringAsync(cancellationToken); if (response.StatusCode is HttpStatusCode.Unauthorized or HttpStatusCode.Forbidden || body.Contains("API_KEY_INVALID", StringComparison.OrdinalIgnoreCase)) return Empty(brief, "failed", "invalid_api_key"); if ((int)response.StatusCode == 429) return Empty(brief, "failed", "rate_limited"); if ((int)response.StatusCode >= 500 || !response.IsSuccessStatusCode) return Empty(brief, "failed", "provider_error"); return Parse(await ExtractTextAsync(response, body), brief); }
        catch (JudgeModelException ex) { return Empty(brief, "failed", ex.Code); } catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested) { return Empty(brief, "failed", "truncated"); } catch (HttpRequestException) { return Empty(brief, "failed", "provider_error"); } catch (JsonException) { return Empty(brief, "failed", "provider_error"); }
    }
    protected abstract Task<HttpResponseMessage> SendAsync(JudgeBrief brief, CancellationToken ct); protected abstract Task<string> ExtractTextAsync(HttpResponseMessage response, string body);
    private InsightDoc Parse(string text, JudgeBrief brief) { var value = JsonSerializer.Deserialize<InsightDoc>(text) ?? throw new JsonException("Empty structured response."); return InsightValidator.Validate(value, brief, DateTimeOffset.UtcNow, Model, long.MaxValue) with { Provider = Provider }; }
    protected InsightDoc Empty(JudgeBrief b, string status, string? error) => new(status, DateTimeOffset.UtcNow.ToString("O"), b.PeriodStart, b.PeriodEnd, Provider, Model, b.PricingVersion, null, null, "", [], [], error);
    protected static string BriefJson(JudgeBrief b) => JsonSerializer.Serialize(new { catalog = b.Catalog, period_start = b.PeriodStart, period_end = b.PeriodEnd });
}
public sealed class GeminiJudgeModel(HttpClient http, string apiKey, string model) : HttpJudgeModel(http, apiKey, model, JudgeProviders.Google)
{
    protected override Task<HttpResponseMessage> SendAsync(JudgeBrief b, CancellationToken ct) { var body = new JsonObject { ["systemInstruction"] = new JsonObject { ["parts"] = new JsonArray(new JsonObject { ["text"] = "Chỉ dùng catalog, trả JSON." }) }, ["contents"] = new JsonArray(new JsonObject { ["role"] = "user", ["parts"] = new JsonArray(new JsonObject { ["text"] = BriefJson(b) }) }), ["generationConfig"] = new JsonObject { ["responseMimeType"] = "application/json", ["responseJsonSchema"] = JsonSerializer.SerializeToNode(ProviderSchema.Create()) } }; var r = new HttpRequestMessage(HttpMethod.Post, $"https://generativelanguage.googleapis.com/v1beta/models/{Uri.EscapeDataString(Model)}:generateContent") { Content = new StringContent(body.ToJsonString(), Encoding.UTF8, "application/json") }; r.Headers.TryAddWithoutValidation("x-goog-api-key", ApiKey); return Http.SendAsync(r, HttpCompletionOption.ResponseHeadersRead, ct); }
    protected override Task<string> ExtractTextAsync(HttpResponseMessage response, string body) { var root = JsonNode.Parse(body)!; var finish = root["candidates"]?[0]?["finishReason"]?.GetValue<string>(); if (finish == "SAFETY") throw new JudgeModelException("refused"); if (finish == "MAX_TOKENS") throw new JudgeModelException("truncated"); return Task.FromResult(root["candidates"]?[0]?["content"]?["parts"]?[0]?["text"]?.GetValue<string>() ?? throw new JsonException("Missing Gemini text.")); }
}
public sealed class OpenAiJudgeModel(HttpClient http, string apiKey, string model) : HttpJudgeModel(http, apiKey, model, JudgeProviders.OpenAi)
{
    protected override Task<HttpResponseMessage> SendAsync(JudgeBrief b, CancellationToken ct) { var body = new JsonObject { ["model"] = Model, ["messages"] = new JsonArray(new JsonObject { ["role"] = "system", ["content"] = "Đánh giá catalog." }, new JsonObject { ["role"] = "user", ["content"] = BriefJson(b) }), ["response_format"] = new JsonObject { ["type"] = "json_schema", ["json_schema"] = new JsonObject { ["name"] = "insights", ["strict"] = true, ["schema"] = JsonSerializer.SerializeToNode(ProviderSchema.Create()) } } }; var r = new HttpRequestMessage(HttpMethod.Post, "https://api.openai.com/v1/chat/completions") { Content = new StringContent(body.ToJsonString(), Encoding.UTF8, "application/json") }; r.Headers.Authorization = new AuthenticationHeaderValue("Bearer", ApiKey); return Http.SendAsync(r, HttpCompletionOption.ResponseHeadersRead, ct); }
    protected override Task<string> ExtractTextAsync(HttpResponseMessage response, string body) { var root = JsonNode.Parse(body)!; if (root["choices"]?[0]?["message"]?["refusal"] is not null) throw new JudgeModelException("refused"); if (root["choices"]?[0]?["finish_reason"]?.GetValue<string>() == "length") throw new JudgeModelException("truncated"); return Task.FromResult(root["choices"]?[0]?["message"]?["content"]?.GetValue<string>() ?? throw new JsonException("Missing OpenAI content.")); }
}
