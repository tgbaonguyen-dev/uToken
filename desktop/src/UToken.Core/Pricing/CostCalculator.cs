using UToken.Core.Models;

namespace UToken.Core.Pricing;

/// <summary>Giá USD trên 1 triệu token (PricingVersion).</summary>
public sealed record Price(decimal InputPerMTok, decimal CachedPerMTok, decimal? CacheWritePerMTok, decimal OutputPerMTok);

public static class CostCalculator
{
    /// <summary>
    /// Chi phí theo SRS §10.1, trả về micro-USD (số nguyên).
    /// Vì giá tính trên 1 triệu token, micro-USD = Σ token × giá/MTok.
    /// </summary>
    public static long CostMicroUsd(long input, long cached, long cacheWrite, long output, Price p)
    {
        var uncached = input - cached - cacheWrite;
        var write = p.CacheWritePerMTok ?? p.InputPerMTok;
        var micro = uncached * p.InputPerMTok + cached * p.CachedPerMTok + cacheWrite * write + output * p.OutputPerMTok;
        return (long)Math.Round(micro, MidpointRounding.AwayFromZero);
    }

    public static long CostMicroUsd(UsageEvent e, Price p) => CostMicroUsd(e.Input, e.Cached, e.CacheWrite, e.Output, p);

    public static long CostMicroUsd(UsageEvent e, PriceSchedule schedule) => CostMicroUsd(e, schedule.For(e.Input));
}
