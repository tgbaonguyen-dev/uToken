using UToken.Core.Models;
using UToken.Core.Pricing;

namespace UToken.Core.Tasks;

/// <summary>Task đã gom từ các turn liền nhau của một phiên chính (FR-ANLY-003, máy trạng thái TaskOutcome).</summary>
public sealed record TaskRecord(
    string TaskId,
    Provider Provider,
    string SessionId,
    string Model,
    string? Effort,
    string? ProjectKey,
    TaskGroup Group,
    DateTimeOffset StartedAt,
    DateTimeOffset EndedAt,
    int Turns,
    int Requests,
    TaskSignals Signals,
    int TestRuns,
    OutcomeState Outcome,
    long? CostMicro,
    long TotalTokens,
    double? ContextGrowth,
    bool Closed)
{
    public int RedoTurns => Signals.RedoTurns;
}

public sealed class TaskBuilderOptions
{
    /// <summary>Turn mới trong khoảng này sau turn trước thì gộp vào cùng task (SRS §5.1).</summary>
    public TimeSpan MergeGap { get; init; } = TimeSpan.FromMinutes(2);

    /// <summary>Luật chia nhóm việc theo số lần gọi model (giả định, OQ-03 điểm 3).</summary>
    public int SmallMaxRequests { get; init; } = 10;
    public int MediumMaxRequests { get; init; } = 40;

    public TaskGroup GroupOf(int requests) =>
        requests <= SmallMaxRequests ? TaskGroup.Small
        : requests <= MediumMaxRequests ? TaskGroup.Medium
        : TaskGroup.Large;
}

/// <summary>Gom turn thành task và gán trạng thái kết quả. Hàm thuần, tính lại bao nhiêu lần cũng ra cùng kết quả.</summary>
public static class TaskBuilder
{
    public static IReadOnlyList<TaskRecord> Build(
        IEnumerable<TurnRecord> turns,
        IEnumerable<UsageEvent> events,
        IPriceBook prices,
        DateTimeOffset now,
        TaskBuilderOptions? options = null)
    {
        options ??= new TaskBuilderOptions();
        var eventsByTurn = events
            .Where(e => !e.IsSideSession && e.TurnId is not null)
            .GroupBy(e => (e.Provider, e.SessionId, TurnId: e.TurnId!))
            .ToDictionary(g => g.Key, g => g.OrderBy(e => e.OccurredAt).ToList());

        var result = new List<TaskRecord>();
        foreach (var session in turns.Where(t => !t.IsSideSession).GroupBy(t => (t.Provider, t.SessionId)))
        {
            var ordered = session.OrderBy(t => t.StartedAt).ToList();
            var current = new List<TurnRecord>();
            foreach (var turn in ordered)
            {
                if (current.Count > 0 && turn.StartedAt - current[^1].LastActivityAt > options.MergeGap)
                {
                    AddTask(current);
                    current = [];
                }
                current.Add(turn);
            }
            if (current.Count > 0) AddTask(current);
        }
        return result;

        void AddTask(List<TurnRecord> group)
        {
            var evts = group
                .SelectMany(t => eventsByTurn.TryGetValue((t.Provider, t.SessionId, t.TurnId), out var l) ? l : [])
                .ToList();
            if (evts.Count == 0) return; // không có lần gọi model nào → không phải task tính được

            var first = group[0];
            var last = group[^1];
            var lastActivity = group.Max(t => t.LastActivityAt);

            // Model và effort của task = model chiếm nhiều token nhất.
            var main = evts.GroupBy(e => (e.Model, e.Effort))
                .OrderByDescending(g => g.Sum(e => e.TotalTokens)).First().Key;

            var signals = MergeSignals(group);
            var costs = evts.Select(prices.CostMicro).ToList();
            long? cost = costs.Any(c => c is not null) ? costs.Sum(c => c ?? 0) : null;
            double? growth = evts.Count >= 2 && evts[0].Input > 0 ? (double)evts[^1].Input / evts[0].Input : null;
            bool closed = now - lastActivity > options.MergeGap;

            result.Add(new TaskRecord(
                TaskId: $"{first.Provider.ToWire()}:{first.SessionId}:{first.TurnId}",
                Provider: first.Provider,
                SessionId: first.SessionId,
                Model: main.Model,
                Effort: main.Effort,
                ProjectKey: group.Select(t => t.ProjectKey).LastOrDefault(k => k is not null)
                            ?? evts.Select(e => e.ProjectKey).LastOrDefault(k => k is not null),
                Group: options.GroupOf(evts.Count),
                StartedAt: first.StartedAt,
                EndedAt: lastActivity,
                Turns: group.Count,
                Requests: evts.Count,
                Signals: signals,
                TestRuns: group.Sum(t => t.TestRuns),
                Outcome: closed ? OutcomeClassifier.Classify(signals) : OutcomeState.Undetermined,
                CostMicro: cost,
                TotalTokens: evts.Sum(e => e.TotalTokens),
                ContextGrowth: growth,
                Closed: closed));
        }
    }

    /// <summary>
    /// Gộp tín hiệu các turn theo thứ tự thời gian. Turn sau sửa file mà không chạy test thì kết quả test trước bị bỏ.
    /// Có turn gộp vào (người dùng hỏi lại trong ≤ 2 phút) thì tính là hỏi lại (giả định, OQ-03 điểm 1).
    /// </summary>
    public static TaskSignals MergeSignals(IReadOnlyList<TurnRecord> group)
    {
        bool? lastTest = null;
        foreach (var t in group)
        {
            if (t.LastTestPassed is not null) lastTest = t.LastTestPassed;
            else if (t.FilesChanged) lastTest = null;
        }
        return new TaskSignals(
            Turns: group.Count,
            RedoTurns: group.Count - 1,
            CommandsTotal: group.Sum(t => t.CommandsTotal),
            CommandsFailed: group.Sum(t => t.CommandsFailed),
            MaxConsecutiveFailures: group.Max(t => t.MaxConsecutiveFailures),
            LastTestPassed: lastTest,
            FilesChanged: group.Any(t => t.FilesChanged),
            TurnError: group[^1].TurnError,
            Aborted: group[^1].Aborted,
            ReaskedWithin2Min: group.Count > 1);
    }
}
