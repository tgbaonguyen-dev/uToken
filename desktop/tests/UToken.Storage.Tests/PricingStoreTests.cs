using UToken.Core.Models;
using UToken.Core.Pricing;
using UToken.Storage;
using Xunit;

namespace UToken.Storage.Tests;

public class PricingStoreTests
{
    private static readonly DateTimeOffset Day1 = new(2026, 11, 1, 0, 0, 0, TimeSpan.Zero);
    private static readonly DateTimeOffset Day5 = new(2026, 11, 5, 0, 0, 0, TimeSpan.Zero);
    private static readonly Price Old = new(3m, 0.3m, 3.75m, 15m);
    private static readonly Price New = new(2m, 0.1m, 2.5m, 10m);
    private static readonly Price OldTier = new(6m, 0.6m, 7.5m, 22.5m);
    private static readonly Price NewTier = new(4m, 0.2m, 5m, 15m);

    private static SqliteStore NewStore() => new(":memory:");

    [Fact]
    public void Unchanged_prices_are_not_written_again()
    {
        using var store = NewStore();
        var list = new[] { Model(Old, OldTier) };
        Assert.Equal(1, store.SavePrices(list, "v1", Day1));
        Assert.Equal(0, store.SavePrices(list, "v2", Day5));
    }

    [Fact]
    public void FindPrice_uses_price_effective_at_event_time()
    {
        using var store = NewStore();
        store.SavePrices([Model(Old, OldTier)], "v1", Day1);
        store.SavePrices([Model(New, NewTier)], "v2", Day5);

        var mid = store.FindPrice(Provider.ClaudeCode, "claude-sonnet-5-5-20260928", Day1.AddDays(2));
        var late = store.FindPrice(Provider.ClaudeCode, "claude-sonnet-5-5", Day5.AddDays(1));
        var early = store.FindPrice(Provider.ClaudeCode, "claude-sonnet-5-5", Day1.AddDays(-30));

        Assert.Equal(new PricedModel(Schedule(Old, OldTier), "v1"), mid);
        Assert.Equal(new PricedModel(Schedule(New, NewTier), "v2"), late);
        Assert.Equal(new PricedModel(Schedule(Old, OldTier), "v1"), early); // trước lần tải đầu → bản cũ nhất
    }

    [Fact]
    public void FindPrice_returns_null_for_unknown_model()
    {
        using var store = NewStore();
        store.SavePrices([Model(New, NewTier)], "v1", Day1);
        Assert.Null(store.FindPrice(Provider.ClaudeCode, "claude-unknown-9", Day5));
        Assert.Null(store.FindPrice(Provider.Codex, "gpt-5.6-terra", Day5));
    }

    [Fact]
    public void Decimal_prices_round_trip_exactly()
    {
        using var store = NewStore();
        var p = new Price(0.075m, 0.0075m, null, 0.3m);
        var tier = new Price(0.15m, 0.015m, null, 0.6m);
        var schedule = new PriceSchedule(p, [new PriceTier(200_000, tier)]);
        store.SavePrices([new ModelPrice("google", "gemini-x", schedule)], "v1", Day1);
        Assert.Equal(schedule, store.FindPrice(Provider.Antigravity, "gemini-x", Day5)!.Schedule);
    }

    [Fact]
    public void Changing_only_a_tier_writes_a_new_version()
    {
        using var store = NewStore();
        Assert.Equal(1, store.SavePrices([Model(Old, OldTier)], "v1", Day1));
        Assert.Equal(1, store.SavePrices([Model(Old, NewTier)], "v2", Day5));
        Assert.Equal(Schedule(Old, NewTier), store.FindPrice(Provider.ClaudeCode, "claude-sonnet-5-5", Day5)!.Schedule);
    }

    [Fact]
    public void Reusing_a_version_throws_and_keeps_the_first_schedule()
    {
        using var store = NewStore();
        store.SavePrices([Model(Old, OldTier)], "v1", Day1);

        Assert.Throws<InvalidOperationException>(() => store.SavePrices([Model(New, NewTier)], "v1", Day5));
        Assert.Equal(Schedule(Old, OldTier), store.FindPrice(Provider.ClaudeCode, "claude-sonnet-5-5", Day5)!.Schedule);
    }

    [Fact]
    public void Parsed_duplicate_tiers_are_stable_across_sync_versions()
    {
        const string json = """
            { "openai": { "models": { "gpt-tiered": { "cost": {
              "input": 1, "output": 2,
              "tiers": [
                { "input": 3, "output": 4, "tier": { "type": "context", "size": 100000 } },
                { "input": 5, "output": 6, "tier": { "type": "context", "size": 100000 } }
              ]
            } } } } }
            """;
        using var store = NewStore();
        var prices = ModelsDevCatalog.Parse(json);

        Assert.Single(prices.Single().Schedule.Tiers);
        Assert.Equal(3m, prices.Single().Schedule.Tiers.Single().Price.InputPerMTok);
        Assert.Equal(1, store.SavePrices(prices, "v1", Day1));
        Assert.Equal(0, store.SavePrices(prices, "v2", Day5));
    }

    private static ModelPrice Model(Price @base, Price tier) =>
        new("anthropic", "claude-sonnet-5-5", Schedule(@base, tier));

    private static PriceSchedule Schedule(Price @base, Price tier) =>
        new(@base, [new PriceTier(100_000, tier)]);
}
