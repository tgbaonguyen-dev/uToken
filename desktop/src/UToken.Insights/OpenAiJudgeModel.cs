using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace UToken.Insights;

/// <summary>OpenAI Chat Completions judge adapter.</summary>
public sealed class OpenAiJudgeModel : IJudgeModel
{
    private readonly HttpClient _http;
    private readonly string _apiKey;

    public OpenAiJudgeModel(HttpClient http, string apiKey, string model)
    {
        _http = http;
        _apiKey = apiKey;
        Model = model;
    }

    public string Provider => JudgeProviders.OpenAi;
    public string Model { get; }

    public async Task<string> CompleteAsync(
        string systemPrompt,
        string briefJson,
        IReadOnlyDictionary<string, JsonElement> schema,
        CancellationToken cancellationToken)
    {
        using var request = BuildRequest(systemPrompt, briefJson, schema);
        using var response = await _http.SendAsync(
            request,
            HttpCompletionOption.ResponseHeadersRead,
            cancellationToken);
        var body = await response.Content.ReadAsStringAsync(cancellationToken);
        var error = HttpErrorMapper.Error(response.StatusCode, body);
        if (error is not null) throw new JudgeModelException(error);
        return ReadText(body);
    }

    private HttpRequestMessage BuildRequest(
        string systemPrompt,
        string briefJson,
        IReadOnlyDictionary<string, JsonElement> schema)
    {
        var payload = new JsonObject
        {
            ["model"] = Model,
            ["messages"] = new JsonArray(
                new JsonObject { ["role"] = "system", ["content"] = systemPrompt },
                new JsonObject { ["role"] = "user", ["content"] = briefJson }),
            ["response_format"] = new JsonObject
            {
                ["type"] = "json_schema",
                ["json_schema"] = new JsonObject
                {
                    ["name"] = "insights",
                    ["strict"] = true,
                    ["schema"] = JsonSerializer.SerializeToNode(schema),
                },
            },
        };
        var request = new HttpRequestMessage(
            HttpMethod.Post,
            "https://api.openai.com/v1/chat/completions")
        {
            Content = new StringContent(
                payload.ToJsonString(),
                Encoding.UTF8,
                "application/json"),
        };
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _apiKey);
        return request;
    }

    private static string ReadText(string body)
    {
        var root = JsonNode.Parse(body) ?? throw new JsonException("Empty OpenAI response.");
        var message = root["choices"]?[0]?["message"];
        if (message?["refusal"] is not null) throw new JudgeModelException("refused");
        if (root["choices"]?[0]?["finish_reason"]?.GetValue<string>() == "length")
            throw new JudgeModelException("truncated");
        return message?["content"]?.GetValue<string>()
            ?? throw new JsonException("OpenAI response has no content.");
    }
}
