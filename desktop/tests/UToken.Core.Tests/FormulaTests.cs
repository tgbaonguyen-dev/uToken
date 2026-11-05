using UToken.Core.Efficiency;
using UToken.Core.Models;
using UToken.Core.Pricing;
using Xunit;

namespace UToken.Core.Tests;

/// <summary>Các ví dụ nghiệm thu trong SRS.</summary>
public class FormulaTests
{
    [Fact] // FR-ANLY-001: cached và thinking không cộng thêm
    public void Total_is_input_plus_output()
    {
        var e = new UsageEvent(Provider.Codex, "r", "s", null, "m", null, DateTimeOffset.UnixEpoch,
            Input: 100, Cached: 40, CacheWrite: 0, Output: 20, Thinking: 10, null, false, null);
        Assert.Equal(120, e.TotalTokens);
        Assert.True(e.IsValid);
    }

    [Fact] // FR-DATA-001: ví dụ Codex
    public void Codex_example_total()
    {
        var e = new UsageEvent(Provider.Codex, "r", "s", null, "m", null, DateTimeOffset.UnixEpoch,
            Input: 30_764, Cached: 5_504, CacheWrite: 0, Output: 142, Thinking: 79, null, false, null);
        Assert.Equal(30_906, e.TotalTokens);
    }

    [Fact] // FR-COST-001
    public void Cost_example()
    {
        var price = new Price(1.75m, 0.175m, null, 14.00m);
        var micro = CostCalculator.CostMicroUsd(input: 120_000, cached: 20_000, cacheWrite: 0, output: 30_000, price);
        Assert.Equal(598_500, micro); // 0.5985 USD
    }

    [Theory] // SRS §10.1: cỡ mẫu với SR ≈ 80%
    [InlineData(0.20, 63)]
    [InlineData(0.15, 112)]
    [InlineData(0.10, 251)]
    [InlineData(0.05, 1004)]
    public void Required_sample_size(double mde, int expected) =>
        Assert.Equal(expected, Stats.RequiredN(0.8, mde));

    [Fact] // FR-ANLY-003 nghiệm thu: B rẻ hơn, chưa thấy kém A
    public void Verdict_cheaper_not_worse()
    {
        var b = new SetupStats(60, 0.82, Stats.StandardError(0.82, 60), 0.18, 0.15, 0.21);
        var a = new SetupStats(60, 0.85, Stats.StandardError(0.85, 60), 0.42, 0.36, 0.48);
        var c = VerdictRules.Compare(b, a);
        Assert.Equal(Verdict.CheaperNotWorse, c.Verdict);
        Assert.Equal(Confidence.Medium, c.Confidence);
        Assert.InRange(c.Mde, 0.18, 0.20);
    }

    [Fact]
    public void Verdict_insufficient_when_few_tasks()
    {
        var a = new SetupStats(12, 0.9, Stats.StandardError(0.9, 12), 0.1, 0.05, 0.15);
        var b = new SetupStats(60, 0.8, Stats.StandardError(0.8, 60), 0.3, 0.25, 0.35);
        Assert.Equal(Verdict.Insufficient, VerdictRules.Compare(a, b).Verdict);
    }

    [Theory] // FR-ANLY-003 mục B
    [InlineData(true, false, false, false, OutcomeState.VerifiedSuccess)]
    [InlineData(false, false, false, false, OutcomeState.VerifiedFailure)]
    [InlineData(null, true, false, false, OutcomeState.LikelySuccess)]
    [InlineData(null, true, true, false, OutcomeState.LikelyFailure)]
    [InlineData(null, false, false, true, OutcomeState.VerifiedFailure)]
    [InlineData(null, false, false, false, OutcomeState.Undetermined)]
    public void Outcome_rules(bool? lastTest, bool files, bool reasked, bool turnError, OutcomeState expected)
    {
        var s = new TaskSignals(1, 0, 1, 0, 0, lastTest, files, turnError, false, reasked);
        Assert.Equal(expected, OutcomeClassifier.Classify(s));
    }
}
