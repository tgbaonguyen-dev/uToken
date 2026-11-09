namespace UToken.Insights;

/// <summary>Single rubric shared by all judge providers.</summary>
public static class JudgePrompt
{
    public const string System = "Bạn là người đánh giá cách dùng token AI. Chấm 6 chiều cache, context, reasoning, reliability, outcomes, hidden_cost; chỉ trỏ metric id có trong catalog, không bịa số, viết tiếng Việt, tối đa 5 insight. Ước tính tiết kiệm chỉ dựa trên chi phí thực trong catalog.";
}
