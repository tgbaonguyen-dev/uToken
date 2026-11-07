using UToken.Core.Models;
using UToken.Core.Pricing;
using UToken.Core.Tasks;

namespace UToken.Core.Aggregation;

/// <summary>
/// Tính DailySummary của một ngày người dùng (FR-DATA-002). Hàm thuần: cùng đầu vào cho cùng document,
/// nên tính lại thì ghi đè chứ không cộng chồng.
/// </summary>
public static class DailyAggregator
{
    /// <summary>Context growth lớn hơn ngưỡng này thì chat bị coi là phình to (SRS §10.1).</summary>
    public const double BloatedGrowth = 3.0;

    /// <param name="date">Ngày theo múi giờ <paramref name="tz"/>.</param>
    /// <param name="events">Event bất kỳ; hàm tự lọc theo ngày địa phương.</param>
    /// <param name="turns">Turn bất kỳ; dùng thời lượng của turn có EndedAt trong ngày.</param>
    /// <param name="tasks">Task bất kỳ; đếm task đã đóng có EndedAt trong ngày.</param>
    public static DailyDoc Build(
        DateOnly date,
        TimeZoneInfo tz,
        IEnumerable<UsageEvent> events,
        IEnumerable<TurnRecord> turns,
        IEnumerable<TaskRecord> tasks,
        IPriceBook prices,
        DateTimeOffset now)
    {
        bool OnDate(DateTimeOffset t) => LocalDate(t, tz) == date;

        var dayEvents = events.Where(e => e.IsValid && OnDate(e.OccurredAt)).ToList();
        var costs = new Dictionary<UsageEvent, long?>(ReferenceEqualityComparer.Instance);
        foreach (var e in dayEvents) costs[e] = prices.CostMicro(e);

        // Thời lượng: lấy theo turn (Codex task_complete.duration_ms), gán vào khóa của event đầu tiên trong turn.
        var turnKey = dayEvents.Where(e => e.TurnId is not null)
            .GroupBy(e => (e.Provider, e.SessionId, e.TurnId!))
            .ToDictionary(g => g.Key, g => KeyOf(g.OrderBy(e => e.OccurredAt).First()));
        var durations = turns
            .Where(t => t.DurationMs is not null && t.EndedAt is { } end && OnDate(end))
            .Select(t => (Key: turnKey.GetValueOrDefault((t.Provider, t.SessionId, t.TurnId)), Ms: t.DurationMs!.Value))
            .ToList();

        var byKey = dayEvents
            .GroupBy(KeyOf)
            .OrderBy(g => g.Key, StringComparer.Ordinal)
            .ToDictionary(
                g => g.Key,
                g => Bucket(g.ToList(), costs, durations.Where(d => d.Key == g.Key).Select(d => d.Ms).ToList()),
                StringComparer.Ordinal);

        var totals = Bucket(dayEvents, costs, durations.Select(d => d.Ms).ToList());

        var dayTasks = tasks.Where(t => t.Closed && OnDate(t.EndedAt)).ToList();
        var byState = new TasksByState(
            dayTasks.Count(t => t.Outcome == OutcomeState.VerifiedSuccess),
            dayTasks.Count(t => t.Outcome == OutcomeState.VerifiedFailure),
            dayTasks.Count(t => t.Outcome == OutcomeState.LikelySuccess),
            dayTasks.Count(t => t.Outcome == OutcomeState.LikelyFailure),
            dayTasks.Count(t => t.Outcome == OutcomeState.Undetermined));

        return new DailyDoc(
            date.ToString("yyyy-MM-dd"),
            totals,
            byKey,
            byState,
            prices.Version,
            now.UtcDateTime.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'"));
    }

    public static DateOnly LocalDate(DateTimeOffset t, TimeZoneInfo tz) =>
        DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(t, tz).DateTime);

    private static string KeyOf(UsageEvent e) => DailyDoc.Key(e.Provider.ToWire(), e.Model, e.ProjectKey);

    private static UsageBucket Bucket(
        IReadOnlyList<UsageEvent> evts,
        IReadOnlyDictionary<UsageEvent, long?> costs,
        IReadOnlyList<long> durationsMs)
    {
        var side = evts.Where(e => e.IsSideSession).ToList();

        // Context growth tính trên chat chính có ≥ 2 lần gọi trong nhóm này.
        var growths = evts.Where(e => !e.IsSideSession)
            .GroupBy(e => (e.Provider, e.SessionId))
            .Select(g => g.OrderBy(e => e.OccurredAt).ToList())
            .Where(l => l.Count >= 2 && l[0].Input > 0)
            .Select(l => (double)l[^1].Input / l[0].Input)
            .ToList();

        return new UsageBucket(
            Chats: evts.Where(e => !e.IsSideSession).Select(e => (e.Provider, e.SessionId)).Distinct().Count(),
            Requests: evts.Count,
            ErrorRequests: evts.Count(e => e.IsError),
            Input: evts.Sum(e => e.Input),
            Cached: evts.Sum(e => e.Cached),
            CacheWrite: evts.Sum(e => e.CacheWrite),
            Output: evts.Sum(e => e.Output),
            Thinking: evts.Any(e => e.Thinking is not null) ? evts.Sum(e => e.Thinking ?? 0) : null,
            CostMicro: SumKnown(evts.Select(e => costs[e])),
            SideRequests: side.Count,
            SideTokens: side.Sum(e => e.TotalTokens),
            SideCostMicro: side.Count == 0 ? 0 : SumKnown(side.Select(e => costs[e])),
            ContextGrowthSum: Math.Round(growths.Sum(), 6),
            ContextGrowthCount: growths.Count,
            BloatedChats: growths.Count(g => g > BloatedGrowth),
            DurationSumMs: durationsMs.Count > 0 ? durationsMs.Sum() : null,
            DurationCount: durationsMs.Count > 0 ? durationsMs.Count : null);
    }

    /// <summary>Cộng các chi phí đã biết; null khi không event nào có giá (hiển thị "thiếu giá").</summary>
    public static long? SumKnown(IEnumerable<long?> values)
    {
        long sum = 0;
        bool any = false;
        foreach (var v in values)
        {
            if (v is null) continue;
            sum += v.Value;
            any = true;
        }
        return any ? sum : null;
    }
}
