using System.Net;
using System.Text;
using UToken.Insights;
using Xunit;

namespace UToken.Insights.Tests;

public sealed class ProviderTests
{
    [Fact]
    public void SharedSchemaIsStrictForObjects() => Assert.False(ProviderSchema.Create()["additionalProperties"].GetBoolean());

    [Theory]
    [InlineData("google")]
    [InlineData("openai")]
    public async Task RestAdaptersDoNotCallNetworkForInsufficientData(string provider)
    {
        var handler = new CaptureHandler();
        using var http = new HttpClient(handler);
        var brief = new JudgeBrief("2026-01-01", "2026-01-30", "pricing", new Dictionary<string, MetricEntry>(), 0, false);
        IJudgeModel model = provider == "google" ? new GeminiJudgeModel(http, "secret", "gemini-2.5-flash") : new OpenAiJudgeModel(http, "secret", "gpt-4.1-mini");
        var result = await model.JudgeAsync(brief, CancellationToken.None);
        Assert.Equal("insufficient_data", result.Status);
        Assert.Null(handler.Request);
    }

    private sealed class CaptureHandler : HttpMessageHandler
    {
        public HttpRequestMessage? Request { get; private set; }
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Request = request;
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent("{}", Encoding.UTF8, "application/json") });
        }
    }
}
