using System.Text.Json;
using Anthropic;
using Anthropic.Exceptions;
using Anthropic.Models.Messages;

namespace UToken.Insights;

/// <summary>Anthropic SDK judge adapter.</summary>
public sealed class AnthropicJudgeModel : IJudgeModel
{
    private readonly AnthropicClient _client;

    /// <summary>Creates an adapter that calls the public Anthropic API.</summary>
    public AnthropicJudgeModel(string apiKey, string model)
    {
        _client = new AnthropicClient { ApiKey = apiKey };
        Model = model;
    }
    /// <summary>Creates an adapter around a configured client (used by tests).</summary>
    public AnthropicJudgeModel(AnthropicClient client, string model)
    {
        _client = client;
        Model = model;
    }
    public string Provider => JudgeProviders.Anthropic;
    public string Model { get; }
    public async Task<string> CompleteAsync(
        string systemPrompt,
        string briefJson,
        IReadOnlyDictionary<string, JsonElement> schema,
        CancellationToken cancellationToken)
    {
        try
        {
            var response = await _client.Messages.Create(new MessageCreateParams
            {
                Model = Model,
                MaxTokens = 16000,
                System = systemPrompt,
                Messages = [new UserMessageParam { Content = briefJson }],
                Thinking = new ThinkingConfigAdaptive(),
                OutputConfig = new OutputConfig
                {
                    Effort = Effort.Medium,
                    Format = new JsonOutputFormat { Schema = schema },
                },
            }, cancellationToken);
            if (response.StopReason == StopReason.Refusal)
                throw new JudgeModelException("refused");
            if (response.StopReason == StopReason.MaxTokens)
                throw new JudgeModelException("truncated");
            foreach (var block in response.Content)
            {
                if (block.TryPickText(out TextBlock? text)) return text.Text;
            }
            throw new JsonException("Anthropic response has no text.");
        }
        catch (Exception exception) when (exception is AnthropicUnauthorizedException
            or AnthropicForbiddenException)
        {
            throw new JudgeModelException("invalid_api_key");
        }
        catch (AnthropicRateLimitException)
        {
            throw new JudgeModelException("rate_limited");
        }
        catch (Exception exception) when (exception is AnthropicException
            or HttpRequestException or IOException)
        {
            // 5xx, lỗi kết nối, dữ liệu trả về không đọc được: lỗi phía nhà cung cấp.
            throw new JudgeModelException("provider_error");
        }
    }
}
