using System.Text.Json;
using UToken.Insights;
using Xunit;

namespace UToken.Insights.Tests;

public sealed class JudgeServiceTests
{
    private static JudgeBrief Brief(int chats = 8, bool events = true) => new(
        "2026-01-01", "2026-01-30", "price-v1",
        new Dictionary<string, MetricEntry> { ["usage.chats"] = new("Chats", "8", 8) },
        chats, events, 500_000);

    [Theory]
    [InlineData(4, true)]
    [InlineData(8, false)]
    public async Task InsufficientBriefDoesNotCallModel(int chats, bool events)
    {
        var model = new FakeModel("", "google");
        var result = await new JudgeService().RunAsync(Brief(chats, events), model, default);
        Assert.Equal("insufficient_data", result.Status);
        Assert.Equal(0, model.Calls);
    }

    [Fact]
    public async Task MapsMetadataAndClampsUsdSaving()
    {
        var model = new FakeModel(
            """{"score":8,"grade":"A","headline":"h","dimensions":[],"insights":[
            {"id":"i","title":"t","severity":"low","category":"cache","provider":null,
            "evidence":[{"metric":"usage.chats"}],"recommendation":"r","estimated_impact":null,
            "estimated_saving_usd_per_month":1.25,"confidence":"high"}]}""",
            "anthropic", model: "m");
        var result = await new JudgeService().RunAsync(Brief(), model, default);
        Assert.Equal("ok", result.Status);
        Assert.Equal("anthropic", result.Provider);
        Assert.Equal("m", result.Model);
        Assert.Equal("2026-01-01", result.PeriodStart);
        Assert.Equal("2026-01-30", result.PeriodEnd);
        Assert.Equal("price-v1", result.PricingVersion);
        Assert.Equal(500_000, result.Insights.Single().EstimatedSavingMicroPerMonth);
    }

    [Fact]
    public async Task InvalidJsonReturnsProviderError() =>
        Assert.Equal("provider_error", (await new JudgeService().RunAsync(
            Brief(), new FakeModel("{", "google"), default)).ErrorCode);

    [Fact]
    public async Task PreservesModelErrorCode() =>
        Assert.Equal("rate_limited", (await new JudgeService().RunAsync(
            Brief(), new FakeModel("", "google", "rate_limited"), default)).ErrorCode);

    [Fact]
    public async Task UnrequestedCancellationReturnsProviderError() =>
        Assert.Equal("provider_error", (await new JudgeService().RunAsync(
            Brief(), new FakeModel("", "google", canceled: true), default)).ErrorCode);

    [Fact]
    public async Task SerializedDocumentDoesNotContainApiKey() =>
        Assert.DoesNotContain("api-key-secret", JsonSerializer.Serialize(
            await new JudgeService().RunAsync(Brief(), new FakeModel("{", "google"), default)));

    private sealed class FakeModel(
        string response, string provider, string? error = null, bool canceled = false,
        string model = "model") : IJudgeModel
    {
        public string Provider => provider;
        public string Model => model;
        public int Calls { get; private set; }
        public Task<string> CompleteAsync(string systemPrompt, string briefJson,
            IReadOnlyDictionary<string, JsonElement> schema, CancellationToken cancellationToken)
        {
            Calls++;
            if (error is not null) throw new JudgeModelException(error);
            if (canceled) throw new TaskCanceledException();
            return Task.FromResult(response);
        }
    }
}
