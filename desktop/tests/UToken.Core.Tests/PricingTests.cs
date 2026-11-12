using UToken.Core.Models;
using UToken.Core.Pricing;
using Xunit;

namespace UToken.Core.Tests;

public class PricingTests
{
    private const string Sample = """
        {
          "anthropic": { "id": "anthropic", "models": {
            "claude-sonnet-5-5": { "cost": { "input": 2, "output": 10, "cache_read": 0.1, "cache_write": 2.5 } }
          }},
          "openai": { "id": "openai", "models": {
            "gpt-5.6-terra": { "cost": { "input": 2, "output": 12, "cache_read": 0.2,
                               "tiers": [
                                 { "input": 4, "output": 18, "cache_write": 5, "tier": { "type": "context", "size": 272000 } },
                                 { "input": 8, "output": 36, "tier": { "type": "context", "size": 272000 } },
                                 { "input": 99, "output": 99, "tier": { "type": "region", "size": 1 } }
                               ] } },
            "gpt-legacy": { "cost": { "input": 1, "output": 2,
                            "context_over_200k": { "input": 2, "output": 3 } } },
            "gpt-image-1.5": { "name": "no cost" }
          }},
          "google": { "id": "google", "models": {
            "gemini-3.8-flash": { "cost": { "input": 0.75, "output": 3.75 } }
          }},
          "openrouter": { "id": "openrouter", "models": {
            "anthropic/claude-sonnet-5.5": { "cost": { "input": 99, "output": 99 } }
          }}
        }
        """;

    [Fact]
    public void Parse_reads_known_vendors_only_and_skips_models_without_cost()
    {
        var prices = ModelsDevCatalog.Parse(Sample);
        Assert.Equal(["claude-sonnet-5-5", "gpt-5.6-terra", "gpt-legacy", "gemini-3.8-flash"], prices.Select(p => p.Model));
        Assert.Equal(new Price(2m, 0.1m, 2.5m, 10m), prices[0].Schedule.Base);
    }

    [Fact]
    public void Parse_falls_back_to_input_price_when_base_cache_read_missing()
    {
        var prices = ModelsDevCatalog.Parse(Sample).ToDictionary(p => p.Model, p => p.Schedule);
        Assert.Equal(new Price(0.75m, 0.75m, null, 3.75m), prices["gemini-3.8-flash"].Base);
        Assert.Equal(new Price(2m, 0.2m, null, 12m), prices["gpt-5.6-terra"].Base);
    }

    [Fact]
    public void Parse_reads_context_tiers_and_skips_unknown_types()
    {
        var schedule = ModelsDevCatalog.Parse(Sample).Single(p => p.Model == "gpt-5.6-terra").Schedule;

        Assert.Equal(
            [new PriceTier(272_000, new Price(4m, 4m, 5m, 18m))],
            schedule.Tiers);
    }

    [Fact]
    public void Parse_ignores_legacy_context_price_without_tiers()
    {
        var schedule = ModelsDevCatalog.Parse(Sample).Single(p => p.Model == "gpt-legacy").Schedule;
        Assert.Empty(schedule.Tiers);
    }

    [Fact]
    public void PriceSchedule_selects_price_using_strict_context_thresholds()
    {
        var @base = new Price(1m, 1m, null, 1m);
        var first = new Price(2m, 2m, null, 2m);
        var second = new Price(3m, 3m, null, 3m);
        var schedule = new PriceSchedule(@base, [new PriceTier(200_000, second), new PriceTier(100_000, first)]);

        Assert.Equal(@base, schedule.For(100_000));
        Assert.Equal(first, schedule.For(100_001));
        Assert.Equal(first, schedule.For(200_000));
        Assert.Equal(second, schedule.For(200_001));
        Assert.Equal(@base, new PriceSchedule(@base, []).For(long.MaxValue));
    }

    [Fact]
    public void PriceSchedule_rejects_duplicate_context_thresholds()
    {
        var price = new Price(1m, 1m, null, 1m);
        var tiers = new[] { new PriceTier(100_000, price), new PriceTier(100_000, price) };

        Assert.Throws<ArgumentException>(() => new PriceSchedule(price, tiers));
    }

    [Fact]
    public void Cost_uses_one_tier_for_the_whole_event_when_context_exceeds_threshold()
    {
        var schedule = TerraSchedule();
        var e = Event(input: 300_000, cached: 100_000, cacheWrite: 20_000, output: 10_000);

        // 180k×4 + 100k×0,4 + 20k×5 + 10k×18 = 1.040.000 micro-USD.
        Assert.Equal(1_040_000, CostCalculator.CostMicroUsd(e, schedule));
    }

    [Fact]
    public void Cost_uses_base_price_when_context_equals_threshold()
    {
        var schedule = TerraSchedule();
        var e = Event(input: 272_000, cached: 100_000, cacheWrite: 20_000, output: 10_000);

        // 152k×2 + 100k×0,2 + 20k×2,5 + 10k×12 = 494.000 micro-USD.
        Assert.Equal(494_000, CostCalculator.CostMicroUsd(e, schedule));
    }

    private static PriceSchedule TerraSchedule() => new(
        new Price(2m, 0.2m, 2.5m, 12m),
        [new PriceTier(272_000, new Price(4m, 0.4m, 5m, 18m))]);

    private static UsageEvent Event(long input, long cached, long cacheWrite, long output) => new(
        Provider.Codex, "event", "session", null, "gpt-5.6-terra", null, DateTimeOffset.UnixEpoch,
        input, cached, cacheWrite, output, null, null, false, null);

    [Theory]
    [InlineData(Provider.ClaudeCode, "claude-sonnet-5-5-20260928", "anthropic")]
    [InlineData(Provider.ClaudeCode, "gpt-5.6-terra", "openai")] // qua proxy
    [InlineData(Provider.Codex, "gpt-5.6-terra", "openai")]
    [InlineData(Provider.Codex, "o4-mini", "openai")]
    [InlineData(Provider.Antigravity, "gemini-3.8-flash", "google")]
    [InlineData(Provider.Antigravity, "Claude-Opus-5-5", "anthropic")]
    [InlineData(Provider.Antigravity, "deep-research-max-preview-04-2026", "google")]
    [InlineData(Provider.ClaudeCode, "some-unknown-model", "anthropic")]
    [InlineData(Provider.Antigravity, "some-unknown-model", "google")]
    public void VendorOf_guesses_from_prefix_then_provider(Provider provider, string model, string? vendor) =>
        Assert.Equal(vendor, ModelIdNormalizer.VendorOf(provider, model));

    [Theory]
    [InlineData("claude-sonnet-5-5-20260928", new[] { "claude-sonnet-5-5-20260928", "claude-sonnet-5-5" })]
    [InlineData("claude-opus-5-5[1m]", new[] { "claude-opus-5-5" })]
    [InlineData("anthropic/claude-haiku-5-5", new[] { "claude-haiku-5-5" })]
    [InlineData("GPT-5.6-Terra", new[] { "gpt-5.6-terra" })]
    public void Candidates_try_exact_then_undated(string model, string[] expected) =>
        Assert.Equal(expected, ModelIdNormalizer.Candidates(model));
}
