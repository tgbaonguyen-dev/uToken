using System.Text.Json;
using Anthropic;
using Anthropic.Exceptions;
using Anthropic.Models.Messages;

namespace UToken.Insights;

/// <summary>Anthropic SDK judge adapter.</summary>
public sealed class AnthropicJudgeModel : IJudgeModel
{
    private readonly AnthropicClient _client;
    public AnthropicJudgeModel(string apiKey, string model)
    {
        _client = new AnthropicClient { ApiKey = apiKey };
        Model = model;
    }
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
            var json = JsonSerializer.SerializeToNode(response.Content)?.AsArray();
            return json?.Select(value => value?["text"]?.GetValue<string>())
                .FirstOrDefault(value => value is not null)
                ?? throw new JsonException("Anthropic response has no text.");
        }
        catch (AnthropicUnauthorizedException)
        {
            throw new JudgeModelException("invalid_api_key");
        }
        catch (AnthropicRateLimitException)
        {
            throw new JudgeModelException("rate_limited");
        }
        catch (AnthropicUnexpectedStatusCodeException)
        {
            throw new JudgeModelException("provider_error");
        }
        catch (IOException)
        {
            throw new JudgeModelException("provider_error");
        }
        catch (HttpRequestException)
        {
            throw new JudgeModelException("provider_error");
        }
    }
}
