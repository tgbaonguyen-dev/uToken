using System.Net;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace UToken.Insights;

/// <summary>Gemini REST judge adapter.</summary>
public sealed class GeminiJudgeModel : IJudgeModel
{
    private readonly HttpClient _http;
    private readonly string _apiKey;

    public GeminiJudgeModel(HttpClient http, string apiKey, string model)
    {
        _http = http;
        _apiKey = apiKey;
        Model = model;
    }

    public string Provider => JudgeProviders.Google;
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
            ["systemInstruction"] = new JsonObject
            {
                ["parts"] = new JsonArray(new JsonObject { ["text"] = systemPrompt }),
            },
            ["contents"] = new JsonArray(new JsonObject
            {
                ["role"] = "user",
                ["parts"] = new JsonArray(new JsonObject { ["text"] = briefJson }),
            }),
            ["generationConfig"] = new JsonObject
            {
                ["responseMimeType"] = "application/json",
                ["responseJsonSchema"] = JsonSerializer.SerializeToNode(schema),
            },
        };
        var request = new HttpRequestMessage(
            HttpMethod.Post,
            $"https://generativelanguage.googleapis.com/v1beta/models/" +
            $"{Uri.EscapeDataString(Model)}:generateContent")
        {
            Content = new StringContent(
                payload.ToJsonString(),
                Encoding.UTF8,
                "application/json"),
        };
        request.Headers.TryAddWithoutValidation("x-goog-api-key", _apiKey);
        return request;
    }

    private static string ReadText(string body)
    {
        var root = JsonNode.Parse(body) ?? throw new JsonException("Empty Gemini response.");
        var finish = root["candidates"]?[0]?["finishReason"]?.GetValue<string>();
        if (finish == "SAFETY") throw new JudgeModelException("refused");
        if (finish == "MAX_TOKENS") throw new JudgeModelException("truncated");
        return root["candidates"]?[0]?["content"]?["parts"]?[0]?["text"]?.GetValue<string>()
            ?? throw new JsonException("Gemini response has no text.");
    }
}
