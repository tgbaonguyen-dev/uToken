using System.Net;
using System.Text;
using System.Text.Json;
using Json.Schema;
using UToken.Insights;
using Xunit;

namespace UToken.Insights.Tests;

public sealed class AdapterContractTests
{
    [Theory]
    [InlineData("google")]
    [InlineData("openai")]
    public async Task Adapters_send_schema_auth_and_prompt_and_read_text(string provider)
    {
        var handler = new ReplyHandler(HttpStatusCode.OK, provider == "google"
            ? """{"candidates":[{"content":{"parts":[{"text":"answer"}]},"finishReason":"STOP"}]}"""
            : """{"choices":[{"message":{"content":"answer"},"finish_reason":"stop"}]}""");
        using var http = new HttpClient(handler);
        IJudgeModel model = provider == "google"
            ? new GeminiJudgeModel(http, "key-test", "gemini-test")
            : new OpenAiJudgeModel(http, "key-test", "gpt-test");
        Assert.Equal("answer", await model.CompleteAsync("system-prompt", "brief-json", ProviderSchema.Create(), CancellationToken.None));
        var request = handler.Request!;
        Assert.Equal(HttpMethod.Post, request.Method);
        Assert.Equal(provider == "google" ? "https://generativelanguage.googleapis.com/v1beta/models/gemini-test:generateContent" : "https://api.openai.com/v1/chat/completions", request.RequestUri!.ToString());
        Assert.Equal(provider == "google" ? "key-test" : "Bearer key-test", provider == "google" ? request.Headers.GetValues("x-goog-api-key").Single() : request.Headers.Authorization!.ToString());
        var body = JsonDocument.Parse(handler.Body!).RootElement;
        Assert.Contains("system-prompt", body.ToString());
        Assert.Contains("brief-json", body.ToString());
        Assert.True(body.ToString().Contains("schema", StringComparison.OrdinalIgnoreCase));
        if (provider == "openai") Assert.Equal("gpt-test", body.GetProperty("model").GetString());
    }

    [Theory]
    [InlineData("google", "SAFETY", "refused")]
    [InlineData("google", "MAX_TOKENS", "truncated")]
    [InlineData("openai", "refusal", "refused")]
    [InlineData("openai", "length", "truncated")]
    public async Task Adapters_map_refusal_and_truncation(string provider, string reason, string expected)
    {
        var response = provider == "google"
            ? "{\"candidates\":[{\"finishReason\":\"" + reason + "\",\"content\":{\"parts\":[{\"text\":\"x\"}]}}]}"
            : reason == "refusal" ? "{\"choices\":[{\"message\":{\"refusal\":\"no\"}}]}" : "{\"choices\":[{\"finish_reason\":\"" + reason + "\",\"message\":{\"content\":\"x\"}}]}";
        var model = Create(provider, new ReplyHandler(HttpStatusCode.OK, response));
        var error = await Assert.ThrowsAsync<JudgeModelException>(() => model.CompleteAsync("s", "b", ProviderSchema.Create(), CancellationToken.None));
        Assert.Equal(expected, error.Code);
    }

    [Theory]
    [InlineData(401, "{}", "invalid_api_key")]
    [InlineData(403, "{}", "invalid_api_key")]
    [InlineData(400, "{\"error\":{\"code\":\"API_KEY_INVALID\"}}", "invalid_api_key")]
    [InlineData(429, "{}", "rate_limited")]
    [InlineData(500, "{}", "provider_error")]
    public async Task Adapters_map_http_errors(int status, string body, string expected)
    {
        foreach (var provider in new[] { "google", "openai" })
        {
            var model = Create(provider, new ReplyHandler((HttpStatusCode)status, body));
            var error = await Assert.ThrowsAsync<JudgeModelException>(() => model.CompleteAsync("s", "b", ProviderSchema.Create(), CancellationToken.None));
            Assert.Equal(expected, error.Code);
        }
    }

    private static IJudgeModel Create(string provider, HttpMessageHandler handler)
    {
        var http = new HttpClient(handler);
        return provider == "google" ? new GeminiJudgeModel(http, "secret", "model") : new OpenAiJudgeModel(http, "secret", "model");
    }

    private sealed class ReplyHandler(HttpStatusCode status, string body) : HttpMessageHandler
    {
        public HttpRequestMessage? Request { get; private set; }
        public string? Body { get; private set; }
        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Request = new HttpRequestMessage(request.Method, request.RequestUri);
            Request.Headers.Authorization = request.Headers.Authorization;
            if (request.Headers.TryGetValues("x-goog-api-key", out var keys)) Request.Headers.TryAddWithoutValidation("x-goog-api-key", keys);
            Body = await request.Content!.ReadAsStringAsync(cancellationToken);
            return new HttpResponseMessage(status) { Content = new StringContent(body, Encoding.UTF8, "application/json") };
        }
    }
}
