using UToken.Core.Models;
using UToken.Core.Pricing;
using Xunit;

namespace UToken.Core.Tests;

public class TieredPriceBookTests
{
    private static readonly DateTimeOffset Fetch1 = DateTimeOffset.Parse("2026-11-01T00:00:00Z");
    private static readonly DateTimeOffset Fetch2 = DateTimeOffset.Parse("2026-11-05T00:00:00Z");

    private static PriceEntry Entry(string vendor, string model, DateTimeOffset at, decimal input, decimal output, params PriceTier[] tiers) =>
        new(vendor, model, at, "models.dev@" + at.ToString("O"), new PriceSchedule(new Price(input, input / 10, null, output), tiers));

    private static TieredPriceBook Book() => new(
    [
        Entry("openai", "gpt-5.6-sol", Fetch1, 4m, 20m, new PriceTier(272_000, new Price(8m, 0.8m, null, 30m))),
        Entry("anthropic", "claude-opus-5-5", Fetch1, 5m, 25m),
        Entry("anthropic", "claude-opus-5-5", Fetch2, 4m, 20m), // giảm giá từ 05/11
    ], StaticPriceBook.Default);

    private static UsageEvent Ev(Provider p, string model, DateTimeOffset at, long input = 1000) =>
        new(p, "e", "s", null, model, null, at, input, 0, 0, 100, null, null, false, null);

    [Fact] // Context lớn hơn 272K thì dùng bậc giá cao hơn
    public void Context_tier_is_chosen_by_normalized_input()
    {
        var book = Book();
        Assert.Equal(4m, book.PriceFor(Ev(Provider.Codex, "gpt-5.6-sol", Fetch2, input: 272_000))!.InputPerMTok);
        Assert.Equal(8m, book.PriceFor(Ev(Provider.Codex, "gpt-5.6-sol", Fetch2, input: 272_001))!.InputPerMTok);
    }

    [Fact] // Event dùng bản giá có hiệu lực tại thời điểm xảy ra; trước lần tải đầu thì dùng bản cũ nhất
    public void Price_version_follows_event_time()
    {
        var book = Book();
        Assert.Equal(5m, book.PriceFor(Ev(Provider.ClaudeCode, "claude-opus-5-5", Fetch2.AddDays(-1)))!.InputPerMTok);
        Assert.Equal(4m, book.PriceFor(Ev(Provider.ClaudeCode, "claude-opus-5-5", Fetch2.AddDays(1)))!.InputPerMTok);
        Assert.Equal(5m, book.PriceFor(Ev(Provider.ClaudeCode, "claude-opus-5-5", Fetch1.AddDays(-30)))!.InputPerMTok);
        Assert.Equal(4m, book.Find(Provider.ClaudeCode, "claude-opus-5-5")!.InputPerMTok); // giá hiện hành
    }

    [Theory] // Tên model trong log được chuẩn hóa trước khi tra
    [InlineData("claude-opus-5-5[1m]")]
    [InlineData("anthropic/claude-opus-5-5")]
    [InlineData("claude-opus-5-5-20261101")]
    public void Model_ids_are_normalized(string logModel) =>
        Assert.True(Book().HasCatalogPrice(Provider.ClaudeCode, logModel));

    [Fact] // Không có trên models.dev → bảng giá để cứng; không có ở đâu → null ("thiếu giá")
    public void Missing_models_fall_back_to_built_in_prices()
    {
        var book = Book();
        Assert.False(book.HasCatalogPrice(Provider.Codex, "codex-auto-review"));
        Assert.Equal(1.75m, book.PriceFor(Ev(Provider.Codex, "codex-auto-review", Fetch2))!.InputPerMTok);
        Assert.Null(book.PriceFor(Ev(Provider.Codex, "mystery-model", Fetch2)));
    }

    [Fact]
    public void Version_and_cost_use_catalog()
    {
        var book = Book();
        Assert.Equal("models.dev@" + Fetch2.ToString("O"), book.Version);
        Assert.Equal(Fetch2, book.LastFetchedAt);
        // 1M input không cache × $4 + 0 output
        var e = new UsageEvent(Provider.Codex, "e", "s", null, "gpt-5.6-sol", null, Fetch2, 1_000_000, 0, 0, 0, null, null, false, null);
        Assert.Equal(8_000_000, book.CostMicro(e)); // > 272K → bậc $8
        var empty = new TieredPriceBook([], StaticPriceBook.Default);
        Assert.Equal(StaticPriceBook.Default.Version, empty.Version);
        Assert.Null(empty.LastFetchedAt);
    }
}
