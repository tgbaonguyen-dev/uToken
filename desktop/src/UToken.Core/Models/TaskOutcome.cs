namespace UToken.Core.Models;

public enum OutcomeState { Undetermined, VerifiedSuccess, VerifiedFailure, LikelySuccess, LikelyFailure }

public enum TaskGroup { Small, Medium, Large }

/// <summary>Tín hiệu kết quả của một task, chỉ gồm số đếm và cờ (không có tên lệnh hay nội dung).</summary>
public sealed record TaskSignals(
    int Turns,
    int RedoTurns,
    int CommandsTotal,
    int CommandsFailed,
    int MaxConsecutiveFailures,
    bool? LastTestPassed,
    bool FilesChanged,
    bool TurnError,
    bool Aborted,
    bool ReaskedWithin2Min);

/// <summary>Luật FR-ANLY-003 mục B. Thứ tự ưu tiên: thất bại có bằng chứng → thành công có bằng chứng → có thể thất bại → có thể thành công.</summary>
public static class OutcomeClassifier
{
    public static OutcomeState Classify(TaskSignals s)
    {
        if (s.TurnError || s.Aborted || s.LastTestPassed == false)
            return OutcomeState.VerifiedFailure;
        if (s.LastTestPassed == true)
            return OutcomeState.VerifiedSuccess;
        if (s.MaxConsecutiveFailures >= 3 || s.ReaskedWithin2Min)
            return OutcomeState.LikelyFailure;
        if (s.FilesChanged)
            return OutcomeState.LikelySuccess;
        return OutcomeState.Undetermined;
    }
}
