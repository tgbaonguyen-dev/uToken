using System.Text.Json;
using Anthropic;
using Anthropic.Exceptions;
using Anthropic.Models.Messages;

namespace UToken.Insights;

public sealed class AnthropicJudgeModel : IJudgeModel
{
    private readonly AnthropicClient _client;
    public AnthropicJudgeModel(string apiKey, string model) { _client = new AnthropicClient { ApiKey = apiKey }; Model = model; }
    public AnthropicJudgeModel(AnthropicClient client, string model) { _client = client; Model = model; }
    public string Provider => JudgeProviders.Anthropic;
    public string Model { get; }
    public async Task<InsightDoc> JudgeAsync(JudgeBrief brief, CancellationToken cancellationToken)
    {
        if (brief.Chats < 5 || !brief.HasEvents) return Empty(brief, "insufficient_data", null);
        try
        {
            var response = await _client.Messages.Create(new MessageCreateParams { Model = Model, MaxTokens = 16000, System = "Đánh giá catalog, không bịa số, trả tiếng Việt.", Messages = [new UserMessageParam { Content = JsonSerializer.Serialize(brief) }], Thinking = new ThinkingConfigAdaptive(), OutputConfig = new OutputConfig { Effort = Effort.Medium, Format = new JsonOutputFormat { Schema = ProviderSchema.Create() } } }, cancellationToken);
            if (response.StopReason == StopReason.Refusal) return Empty(brief, "failed", "refused");
            if (response.StopReason == StopReason.MaxTokens) return Empty(brief, "failed", "truncated");
            var contentJson = JsonSerializer.SerializeToNode(response.Content)?.AsArray();
            var text = contentJson?.Select(value => value?["text"]?.GetValue<string>()).FirstOrDefault(value => value is not null) ?? throw new JsonException("Anthropic response has no text.");
            var result = JsonSerializer.Deserialize<InsightDoc>(text) ?? throw new JsonException("Empty structured response.");
            return InsightValidator.Validate(result, brief, DateTimeOffset.UtcNow, Model, long.MaxValue) with { Provider = Provider };
        }
        catch (AnthropicUnauthorizedException) { return Empty(brief, "failed", "invalid_api_key"); }
        catch (AnthropicRateLimitException) { return Empty(brief, "failed", "rate_limited"); }
        catch (AnthropicUnexpectedStatusCodeException) { return Empty(brief, "failed", "provider_error"); }
        catch (HttpRequestException) { return Empty(brief, "failed", "provider_error"); }
        catch (JsonException) { return Empty(brief, "failed", "provider_error"); }
    }
    private InsightDoc Empty(JudgeBrief b, string status, string? error) => new(status, DateTimeOffset.UtcNow.ToString("O"), b.PeriodStart, b.PeriodEnd, Provider, Model, b.PricingVersion, null, null, "", [], [], error);
}
