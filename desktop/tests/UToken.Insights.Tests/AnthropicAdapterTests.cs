using System.Net;
using System.Text;
using System.Text.Json;
using Anthropic;
using UToken.Insights;
using Xunit;

namespace UToken.Insights.Tests;

public sealed class AnthropicAdapterTests
{
    private static readonly IReadOnlyDictionary<string, JsonElement> Schema =
        ProviderSchema.Create();

    private static (AnthropicJudgeModel Model, StubHandler Handler) Create(
        HttpStatusCode status, string body)
    {
        var handler = new StubHandler(status, body);
        var client = new AnthropicClient
        {
            ApiKey = "sk-test-secret",
            HttpClient = new HttpClient(handler),
            BaseUrl = "https://anthropic.test",
            MaxRetries = 0,
        };
        return (new AnthropicJudgeModel(client, "claude-sonnet-5-5"), handler);
    }

    private static string Message(string stopReason, string text) => $$$"""
        {"id":"msg_1","type":"message","role":"assistant","model":"claude-sonnet-5-5",
         "content":[{"type":"text","text":{{{JsonSerializer.Serialize(text)}}}}],
         "stop_reason":"{{{stopReason}}}","stop_sequence":null,
         "usage":{"input_tokens":10,"output_tokens":5}}
        """;

    [Fact]
    public async Task Returns_text_block_and_sends_model_prompt_and_schema()
    {
        var (model, handler) = Create(HttpStatusCode.OK, Message("end_turn", """{"score":80}"""));

        var text = await model.CompleteAsync("system prompt", "{}", Schema, default);

        Assert.Equal("""{"score":80}""", text);
        Assert.Contains("sk-test-secret", handler.Request!.Headers.Authorization?.ToString());
        Assert.Contains("claude-sonnet-5-5", handler.Body);
        Assert.Contains("system prompt", handler.Body);
        Assert.Contains("json_schema", handler.Body);
    }

    [Theory]
    [InlineData("refusal", "refused")]
    [InlineData("max_tokens", "truncated")]
    public async Task Maps_stop_reasons(string stopReason, string code)
    {
        var (model, _) = Create(HttpStatusCode.OK, Message(stopReason, "{}"));

        var error = await Assert.ThrowsAsync<JudgeModelException>(
            () => model.CompleteAsync("s", "{}", Schema, default));

        Assert.Equal(code, error.Code);
    }

    [Theory]
    [InlineData(HttpStatusCode.Unauthorized, "invalid_api_key")]
    [InlineData(HttpStatusCode.Forbidden, "invalid_api_key")]
    [InlineData(HttpStatusCode.TooManyRequests, "rate_limited")]
    [InlineData(HttpStatusCode.InternalServerError, "provider_error")]
    public async Task Maps_http_errors(HttpStatusCode status, string code)
    {
        const string body = """{"type":"error","error":{"type":"api_error","message":"x"}}""";
        var (model, _) = Create(status, body);

        var error = await Assert.ThrowsAsync<JudgeModelException>(
            () => model.CompleteAsync("s", "{}", Schema, default));

        Assert.Equal(code, error.Code);
    }

    private sealed class StubHandler(HttpStatusCode status, string body) : HttpMessageHandler
    {
        public HttpRequestMessage? Request { get; private set; }
        public string Body { get; private set; } = "";

        protected override async Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Request = request;
            Body = request.Content is null
                ? ""
                : await request.Content.ReadAsStringAsync(cancellationToken);
            return new HttpResponseMessage(status)
            {
                Content = new StringContent(body, Encoding.UTF8, "application/json"),
            };
        }
    }
}
