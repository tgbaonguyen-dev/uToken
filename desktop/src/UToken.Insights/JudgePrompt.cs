namespace UToken.Insights;

/// <summary>Single rubric shared by all judge providers.</summary>
public static class JudgePrompt
{
    public const string System = """
        You review how a developer uses AI coding tokens. Score 6 dimensions:
        cache, context, reasoning, reliability, outcomes, hidden_cost. Only cite
        metric ids present in the catalog and never invent numbers. Write every
        field in clear, concise {LANGUAGE}: a short headline, plain-language titles,
        and one actionable recommendation per insight. At most 5 insights,
        ordered by impact. Base savings estimates only on real costs in the
        catalog.
        """;

    /// <summary>Rubric asking for output in <paramref name="language"/> (English or Vietnamese).</summary>
    public static string For(string language) => System.Replace("{LANGUAGE}", language);
}
