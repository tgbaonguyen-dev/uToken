using System.Globalization;
using UToken.Insights;

namespace UToken.Desktop.App.Models;

/// <summary>Một model chọn được cho AI review, kèm chi phí ước tính mỗi lần chấm.</summary>
public sealed record JudgeModelOption(string Provider, string Model, decimal? CostPerRunUsd)
{
    public string CostLabel => CostPerRunUsd is { } cost
        ? "≈ $" + cost.ToString(cost < 0.01m ? "0.0000" : "0.000", CultureInfo.InvariantCulture)
          + " per review"
        : "Price unknown";

    public override string ToString() => Model;
}

/// <summary>Dữ liệu card Settings → AI review. Không bao giờ chứa API key.</summary>
public sealed record JudgeSettingsData(
    JudgeProviderSettings Settings,
    bool HasKey,
    DateTimeOffset? LastRunAt,
    string? LastStatus,
    string? LastErrorCode,
    InsightDoc? LastInsights,
    JudgeModelOption[] Models)
{
    /// <summary>Số token ước tính mỗi lần chấm: brief + rubric vào, JSON insights ra.</summary>
    public const int EstimatedInputTokens = 6_000;
    public const int EstimatedOutputTokens = 2_000;
}
