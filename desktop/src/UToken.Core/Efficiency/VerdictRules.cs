namespace UToken.Core.Efficiency;

public enum Verdict { Better, CheaperNotWorse, Tradeoff, Worse, NoClearDifference, Insufficient }
public enum Confidence { High, Medium }

/// <summary>Số liệu của một setup trong một nhóm việc (đã tính trên desktop).</summary>
public sealed record SetupStats(int N, double Sr, double SrSe, double Cpst, double CpstCiLow, double CpstCiHigh);

public sealed record Comparison(Verdict Verdict, Confidence? Confidence, double Mde, double SrDiff, double SrDiffLow, double SrDiffHigh);

/// <summary>Luật kết luận FR-ANLY-003 mục E: so setup A với setup B.</summary>
public static class VerdictRules
{
    public const int MinTasks = 20;         // giả định, OQ-03
    public const double MaxMde = 0.20;      // giả định, OQ-03
    public const double HighConfidenceMde = 0.10;

    public static Comparison Compare(SetupStats a, SetupStats b)
    {
        var seDiff = Stats.DiffStandardError(a.SrSe, b.SrSe);
        var mde = Stats.Mde(seDiff);
        var diff = a.Sr - b.Sr;
        var low = diff - Stats.Z95 * seDiff;
        var high = diff + Stats.Z95 * seDiff;

        if (a.N < MinTasks || b.N < MinTasks || mde > MaxMde)
            return new(Verdict.Insufficient, null, mde, diff, low, high);

        bool srBetter = low > 0, srWorse = high < 0;
        bool costBetter = a.CpstCiHigh < b.CpstCiLow, costWorse = a.CpstCiLow > b.CpstCiHigh;
        bool anyBetter = srBetter || costBetter, anyWorse = srWorse || costWorse;

        var verdict = (anyBetter, anyWorse) switch
        {
            (true, true) => Verdict.Tradeoff,
            (false, true) => Verdict.Worse,
            (true, false) when costBetter && !srBetter => Verdict.CheaperNotWorse,
            (true, false) => Verdict.Better,
            _ => Verdict.NoClearDifference,
        };
        var confidence = mde <= HighConfidenceMde ? Confidence.High : Confidence.Medium;
        return new(verdict, confidence, mde, diff, low, high);
    }
}
