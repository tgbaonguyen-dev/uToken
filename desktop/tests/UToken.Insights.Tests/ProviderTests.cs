using System.Net;
using System.Text;
using System.Text.Json;
using UToken.Insights;
using Xunit;

namespace UToken.Insights.Tests;

public sealed class ProviderTests
{
    [Fact]
    public void SharedSchemaIsStrictForObjects()
    {
        Assert.False(ProviderSchema.Create()["additionalProperties"].GetBoolean());
    }

    [Theory]
    [InlineData("google")]
    [InlineData("openai")]
    public async Task RestAdaptersSkipInsufficientData(string provider)
    {
        var handler = new CaptureHandler();
        using var http = new HttpClient(handler);
        var brief = Brief(0, false);
        IJudgeModel model = provider == "google"
            ? new GeminiJudgeModel(http, "secret", "gemini-flash-latest")
            : new OpenAiJudgeModel(http, "secret", "gpt-6-luna");
        var result = await new JudgeService().RunAsync(brief, model, CancellationToken.None);
        Assert.Equal("insufficient_data", result.Status);
        Assert.Null(handler.Request);
    }

    [Fact]
    public async Task JudgeServiceMapsOutputAndClampsSaving()
    {
        var model = new FakeModel("""
        {"score":120,"grade":"Z","headline":"ok","dimensions":[],"insights":[{"id":"x","title":"x","severity":"low","category":"cache","provider":null,"evidence":[{"metric":"usage.chats"}],"recommendation":"r","estimated_impact":null,"estimated_saving_usd_per_month":1,"confidence":"low"}]}
        """);
        var result = await new JudgeService().RunAsync(Brief(8, true), model, CancellationToken.None);
        Assert.Equal("ok", result.Status);
        Assert.Equal(100, result.Score);
        Assert.Null(result.Grade);
        Assert.Equal(100, result.Insights[0].EstimatedSavingMicroPerMonth);
    }

    [Fact]
    public async Task JudgeServiceMapsErrorsWithoutLeakingKey()
    {
        var model = new ErrorModel("invalid_api_key");
        var result = await new JudgeService().RunAsync(Brief(8, true), model, CancellationToken.None);
        Assert.Equal("invalid_api_key", result.ErrorCode);
        Assert.DoesNotContain("secret-key", JsonSerializer.Serialize(result));
    }

    private static JudgeBrief Brief(int chats, bool events) => new(
        "2026-01-01", "2026-01-30", "pricing",
        new Dictionary<string, MetricEntry>
        {
            ["usage.chats"] = new("Chats", "8", 8),
        }, chats, events, 100);

    private sealed class CaptureHandler : HttpMessageHandler
    {
        public HttpRequestMessage? Request { get; private set; }
        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Request = request;
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent("{}", Encoding.UTF8, "application/json"),
            });
        }
    }

    private sealed class FakeModel(string response) : IJudgeModel
    {
        public string Provider => "google";
        public string Model => "test";
        public Task<string> CompleteAsync(
            string systemPrompt,
            string briefJson,
            IReadOnlyDictionary<string, JsonElement> schema,
            CancellationToken cancellationToken) => Task.FromResult(response);
    }

    private sealed class ErrorModel(string code) : IJudgeModel
    {
        public string Provider => "google";
        public string Model => "test";
        public Task<string> CompleteAsync(
            string systemPrompt,
            string briefJson,
            IReadOnlyDictionary<string, JsonElement> schema,
            CancellationToken cancellationToken) => throw new JudgeModelException(code);
    }
}
