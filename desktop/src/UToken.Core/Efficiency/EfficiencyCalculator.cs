using UToken.Core.Aggregation;
using UToken.Core.Models;
using UToken.Core.Pricing;
using UToken.Core.Tasks;

namespace UToken.Core.Efficiency;

/// <summary>
/// Tính EfficiencyReport 30 ngày (FR-ANLY-003, FR-ANLY-004). Hàm thuần, chỉ đọc dữ liệu truyền vào.
/// Ngưỡng nhãn là giả định trong SRS, cần hiệu chỉnh bằng dữ liệu thật.
/// </summary>
public static class EfficiencyCalculator
{
    public const int PeriodDays = 30;
    public const int MinChatsForLabel = 5;
    public const int MinTasksPerWeek = 5;
    public const double MaxWeeklySrSwing = 0.10;
    public const double MaxCostTail = 3.0;

    public static EfficiencyDoc Build(
        DateTimeOffset now,
        TimeZoneInfo tz,
        IEnumerable<UsageEvent> events,
        IEnumerable<TurnRecord> turns,
        IEnumerable<TaskRecord> tasks,
        IPriceBook prices)
    {
        var endDate = DailyAggregator.LocalDate(now, tz);
        var startDate = endDate.AddDays(-(PeriodDays - 1));
        bool InPeriod(DateTimeOffset t)
        {
            var d = DailyAggregator.LocalDate(t, tz);
            return d >= startDate && d <= endDate;
        }

        var evts = events.Where(e => e.IsValid && InPeriod(e.OccurredAt)).ToList();
        var trns = turns.Where(t => !t.IsSideSession && InPeriod(t.StartedAt)).ToList();
        var tsks = tasks.Where(t => t.Closed && InPeriod(t.EndedAt)).ToList();

        var metrics = new List<ProcessMetric>();
        metrics.AddRange(ProcessMetrics(null, evts, trns, tsks, prices, now, tz));
        foreach (var p in evts.Select(e => e.Provider).Distinct().OrderBy(p => p))
            metrics.AddRange(ProcessMetrics(p,
                evts.Where(e => e.Provider == p).ToList(),
                trns.Where(t => t.Provider == p).ToList(),
                tsks.Where(t => t.Provider == p).ToList(),
                prices, now, tz));

        return new EfficiencyDoc(
            startDate.ToString("yyyy-MM-dd"),
            endDate.ToString("yyyy-MM-dd"),
            now.UtcDateTime.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'"),
            tsks.Count(t => t.Outcome == OutcomeState.Undetermined),
            metrics,
            Setups(tsks, startDate, tz),
            prices.Version)
        {
            Overall = Overall(tsks, startDate, tz),
        };
    }

    /// <summary>SR chính/phụ, CPST, P50/P90 chi phí mỗi task trên mọi task trong kỳ (không chia setup).</summary>
    private static OutcomeSummary? Overall(IReadOnlyList<TaskRecord> tasks, DateOnly start, TimeZoneInfo tz)
    {
        if (tasks.Count == 0) return null;
        var r = Describe(default, "", null, default, tasks, start, tz).Report;
        return new OutcomeSummary(r.NTasks, r.NVerified, r.Sr, r.SrCiLow, r.SrCiHigh, r.SrAlt,
            r.CpstMicro, r.CpstCiLowMicro, r.CpstCiHighMicro, r.CostP50Micro, r.CostP90Micro, r.RedoRate, r.StabilityFlag);
    }

    // ───────────────────────── A. Chỉ số quá trình ─────────────────────────

    private static IEnumerable<ProcessMetric> ProcessMetrics(
        Provider? provider,
        IReadOnlyList<UsageEvent> evts,
        IReadOnlyList<TurnRecord> turns,
        IReadOnlyList<TaskRecord> tasks,
        IPriceBook prices,
        DateTimeOffset now,
        TimeZoneInfo tz)
    {
        string? prov = provider?.ToWire();
        var main = evts.Where(e => !e.IsSideSession).ToList();
        int chats = main.Select(e => (e.Provider, e.SessionId)).Distinct().Count();
        bool enough = chats >= MinChatsForLabel;

        ProcessMetric M(string name, double? value, Func<double, bool> isReview)
        {
            if (value is { } raw && (double.IsNaN(raw) || double.IsInfinity(raw))) value = null;
            return Make(name, value, isReview);
        }

        ProcessMetric Make(string name, double? value, Func<double, bool> isReview) => new(
            name, prov, value is { } v ? Math.Round(v, 4) : null,
            value is null || !enough ? Labels.NoData : isReview(value.Value) ? Labels.Review : Labels.Good);

        // Cache hit rate: cached / input (input đã chuẩn hóa). Review khi < 50%.
        long input = evts.Sum(e => e.Input);
        yield return M("cache_hit_rate", input > 0 ? (double)evts.Sum(e => e.Cached) / input : null, v => v < 0.5);

        // Context growth: trung vị theo chat (≥ 2 lượt). Review khi > 5×.
        var growths = main.GroupBy(e => (e.Provider, e.SessionId))
            .Select(g => g.OrderBy(e => e.OccurredAt).ToList())
            .Where(l => l.Count >= 2 && l[0].Input > 0)
            .Select(l => (double)l[^1].Input / l[0].Input)
            .ToList();
        yield return M("context_growth", growths.Count > 0 ? Stats.Percentile(growths, 0.5) : null, v => v > 5);

        // Thinking share: thinking / output. Review khi 7 ngày gần nhất > 2× trung vị theo ngày trong kỳ.
        var withThinking = evts.Where(e => e.Thinking is not null).ToList();
        long outTok = withThinking.Sum(e => e.Output);
        double? thinking = outTok > 0 ? (double)withThinking.Sum(e => e.Thinking!.Value) / outTok : null;
        var dailyShares = withThinking.GroupBy(e => DailyAggregator.LocalDate(e.OccurredAt, tz))
            .Where(g => g.Sum(e => e.Output) > 0)
            .Select(g => (double)g.Sum(e => e.Thinking!.Value) / g.Sum(e => e.Output))
            .ToList();
        var recentCut = now.AddDays(-7);
        var recent = withThinking.Where(e => e.OccurredAt >= recentCut).ToList();
        double? recentShare = recent.Sum(e => e.Output) > 0
            ? (double)recent.Sum(e => e.Thinking!.Value) / recent.Sum(e => e.Output) : null;
        double medianShare = dailyShares.Count > 0 ? Stats.Percentile(dailyShares, 0.5) : double.NaN;
        yield return M("thinking_share", thinking,
            _ => recentShare is { } r && medianShare > 0 && r > 2 * medianShare);

        // Error rate: lệnh/tool lỗi / tổng lệnh. Review khi > 10% hoặc có task ≥ 3 lỗi liên tiếp.
        int cmds = turns.Sum(t => t.CommandsTotal);
        yield return M("error_rate", cmds > 0 ? (double)turns.Sum(t => t.CommandsFailed) / cmds : null,
            v => v > 0.10 || tasks.Any(t => t.Signals.MaxConsecutiveFailures >= 3));

        // Retry rate: request gửi lại trong ≤ 2 phút sau một request lỗi cùng phiên. Review khi > 10%.
        yield return M("retry_rate", evts.Count > 0 ? (double)CountRetries(evts) / evts.Count : null, v => v > 0.10);

        // Tokens per turn so với trung vị: (token/turn 7 ngày / trung vị token/turn theo ngày − 1). Review khi > +50%.
        yield return M("tokens_per_turn_vs_median", TokensPerTurnVsMedian(main, now, tz), v => v > 0.5);

        // Độ đuôi chi phí mỗi task: P90 / P50. Review khi > 3.
        var taskCosts = tasks.Where(t => t.CostMicro is > 0).Select(t => (double)t.CostMicro!.Value).ToList();
        double? tail = taskCosts.Count >= 2 ? Stats.Percentile(taskCosts, 0.9) / Stats.Percentile(taskCosts, 0.5) : null;
        yield return M("cost_tail", tail, v => v > MaxCostTail);

        // Hidden cost share (FR-ANLY-004): chi phí phiên phụ / tổng chi phí; thiếu giá thì tính theo token.
        var costs = evts.Select(e => (e, c: prices.CostMicro(e))).ToList();
        long totalCost = costs.Sum(x => x.c ?? 0);
        double? hidden = totalCost > 0
            ? (double)costs.Where(x => x.e.IsSideSession).Sum(x => x.c ?? 0) / totalCost
            : evts.Sum(e => e.TotalTokens) is > 0 and var tok
                ? (double)evts.Where(e => e.IsSideSession).Sum(e => e.TotalTokens) / tok
                : null;
        yield return M("hidden_cost_share", hidden, v => v > 0.30);
    }

    private static int CountRetries(IReadOnlyList<UsageEvent> evts)
    {
        int retries = 0;
        foreach (var session in evts.GroupBy(e => (e.Provider, e.SessionId)))
        {
            DateTimeOffset? lastError = null;
            foreach (var e in session.OrderBy(e => e.OccurredAt))
            {
                if (lastError is { } le && e.OccurredAt - le <= TimeSpan.FromMinutes(2)) retries++;
                lastError = e.IsError ? e.OccurredAt : null;
            }
        }
        return retries;
    }

    private static double? TokensPerTurnVsMedian(IReadOnlyList<UsageEvent> main, DateTimeOffset now, TimeZoneInfo tz)
    {
        var withTurn = main.Where(e => e.TurnId is not null).ToList();
        var perDay = withTurn.GroupBy(e => DailyAggregator.LocalDate(e.OccurredAt, tz))
            .Select(g => (double)g.Sum(e => e.TotalTokens) / g.Select(e => (e.SessionId, e.TurnId)).Distinct().Count())
            .ToList();
        if (perDay.Count < 3) return null;

        var recent = withTurn.Where(e => e.OccurredAt >= now.AddDays(-7)).ToList();
        int recentTurns = recent.Select(e => (e.SessionId, e.TurnId)).Distinct().Count();
        if (recentTurns == 0) return null;

        double median = Stats.Percentile(perDay, 0.5);
        return median > 0 ? recent.Sum(e => e.TotalTokens) / (double)recentTurns / median - 1 : null;
    }

    // ───────────────────────── C–E. Chỉ số kết quả và so sánh setup ─────────────────────────

    private sealed record SetupData(
        Provider Provider, string Model, string? Effort, TaskGroup Group,
        IReadOnlyList<TaskRecord> Tasks, SetupReport Report, SetupStats? Stats);

    private static IReadOnlyList<SetupReport> Setups(IReadOnlyList<TaskRecord> tasks, DateOnly start, TimeZoneInfo tz)
    {
        var data = tasks
            .GroupBy(t => (t.Provider, t.Model, t.Effort, t.Group))
            .Select(g => Describe(g.Key.Provider, g.Key.Model, g.Key.Effort, g.Key.Group, g.ToList(), start, tz))
            .ToList();

        var result = new List<SetupReport>();
        // Bước 0 và 1: chỉ so trong cùng công cụ và cùng nhóm việc.
        foreach (var bucket in data.GroupBy(d => (d.Provider, d.Group)))
        {
            var ranked = bucket.OrderByDescending(d => d.Report.NTasks).ThenBy(d => d.Model, StringComparer.Ordinal).ToList();
            for (int i = 0; i < ranked.Count; i++)
            {
                var self = ranked[i];
                // Mỗi setup so với setup nhiều task nhất trong nhóm; setup đó so với setup đứng thứ hai.
                var other = i == 0 ? ranked.ElementAtOrDefault(1) : ranked[0];
                var report = Compare(self, other);
                // MDE trên 100 điểm phần trăm (rất ít task) không mang thông tin, để trống.
                result.Add(report with { Mde = report.Mde is > 1 ? null : report.Mde });
            }
        }
        return result
            .OrderBy(r => r.Provider, StringComparer.Ordinal)
            .ThenBy(r => r.TaskGroup, StringComparer.Ordinal)
            .ThenByDescending(r => r.NTasks)
            .ToList();
    }

    private static SetupReport Compare(SetupData self, SetupData? other)
    {
        var r = self.Report;
        if (other is null)
        {
            // Không có setup để so: vẫn báo MDE nếu so với một setup cùng cỡ mẫu.
            double? mdeAlone = self.Stats is { } s ? Math.Round(Stats.Mde(Math.Sqrt(2) * s.SrSe), 4) : null;
            return r with { Verdict = Verdict.Insufficient.ToWire(), Mde = mdeAlone };
        }

        string label = other.Effort is null ? other.Model : $"{other.Model} · {other.Effort}";
        if (self.Stats is null || other.Stats is null)
        {
            double? mde = self.Stats is { } a && other.Stats is { } b
                ? Stats.Mde(Stats.DiffStandardError(a.SrSe, b.SrSe)) : null;
            return r with { Verdict = Verdict.Insufficient.ToWire(), ComparedTo = label, Mde = mde is { } m ? Math.Round(m, 4) : null };
        }

        var c = VerdictRules.Compare(self.Stats, other.Stats);
        return r with
        {
            Verdict = c.Verdict.ToWire(),
            Confidence = c.Confidence?.ToWire(),
            Mde = Math.Round(c.Mde, 4),
            ComparedTo = label,
        };
    }

    private static SetupData Describe(
        Provider provider, string model, string? effort, TaskGroup group,
        IReadOnlyList<TaskRecord> tasks, DateOnly start, TimeZoneInfo tz)
    {
        int vs = tasks.Count(t => t.Outcome == OutcomeState.VerifiedSuccess);
        int vf = tasks.Count(t => t.Outcome == OutcomeState.VerifiedFailure);
        int ls = tasks.Count(t => t.Outcome == OutcomeState.LikelySuccess);
        int und = tasks.Count(t => t.Outcome == OutcomeState.Undetermined);
        int nVerified = vs + vf;

        // SR chính (chỉ task có bằng chứng) với khoảng Wilson; SR phụ nới thêm likely.
        double? sr = nVerified > 0 ? (double)vs / nVerified : null;
        (double Low, double High)? ci = nVerified > 0 ? Stats.Wilson(vs, nVerified) : null;
        int determined = tasks.Count - und;
        double? srAlt = determined > 0 ? (double)(vs + ls) / determined : null;

        // CPST = tổng chi phí của setup / số task thành công (theo SR chính).
        long? totalCost = DailyAggregator.SumKnown(tasks.Select(t => t.CostMicro));
        long? cpst = totalCost is { } tc && vs > 0 ? (long)Math.Round((double)tc / vs) : null;

        var bySession = tasks.GroupBy(t => t.SessionId).ToList();
        var cpstCi = totalCost is not null && vs > 0
            ? Stats.BootstrapRatioCi(bySession
                .Select(g => ((double)g.Sum(t => t.CostMicro ?? 0), (double)g.Count(t => t.Outcome == OutcomeState.VerifiedSuccess)))
                .ToList())
            : null;

        var costs = tasks.Where(t => t.CostMicro is not null).Select(t => (double)t.CostMicro!.Value).ToList();
        long? p50 = costs.Count > 0 ? (long)Math.Round(Stats.Percentile(costs, 0.5)) : null;
        long? p90 = costs.Count > 0 ? (long)Math.Round(Stats.Percentile(costs, 0.9)) : null;

        // SR theo tuần: tuần 7 ngày tính từ đầu kỳ, chỉ tuần có ≥ 5 task đã xác minh.
        var weekly = new double?[(PeriodDays + 6) / 7];
        foreach (var w in tasks.Where(t => t.Outcome is OutcomeState.VerifiedSuccess or OutcomeState.VerifiedFailure)
                     .GroupBy(t => (DailyAggregator.LocalDate(t.EndedAt, tz).DayNumber - start.DayNumber) / 7))
        {
            if (w.Key < 0 || w.Key >= weekly.Length || w.Count() < MinTasksPerWeek) continue;
            weekly[w.Key] = Math.Round((double)w.Count(t => t.Outcome == OutcomeState.VerifiedSuccess) / w.Count(), 4);
        }
        var weeklyValues = weekly.Where(v => v is not null).Select(v => v!.Value).ToList();
        bool unstable = (weeklyValues.Count >= 2 && weeklyValues.Max() - weeklyValues.Min() > MaxWeeklySrSwing)
                        || (p50 is > 0 && p90 is { } hi && (double)hi / p50.Value > MaxCostTail);

        SetupStats? stats = null;
        if (sr is { } srv && cpst is { } cp && cpstCi is { } cc)
        {
            var se = Stats.ClusterStandardError(tasks
                .Where(t => t.Outcome is OutcomeState.VerifiedSuccess or OutcomeState.VerifiedFailure)
                .Select(t => (t.SessionId, t.Outcome == OutcomeState.VerifiedSuccess))
                .ToList());
            stats = new SetupStats(tasks.Count, srv, se, cp, cc.Low, cc.High);
        }

        var report = new SetupReport(
            Provider: provider.ToWire(),
            Model: model,
            Effort: effort,
            TaskGroup: group.ToWire(),
            NTasks: tasks.Count,
            NSessions: bySession.Count,
            NVerified: nVerified,
            Sr: Round(sr),
            SrCiLow: Round(ci?.Low),
            SrCiHigh: Round(ci?.High),
            SrAlt: Round(srAlt),
            CpstMicro: cpst,
            CpstCiLowMicro: cpstCi is { } l ? (long)Math.Round(l.Low) : null,
            CpstCiHighMicro: cpstCi is { } h ? (long)Math.Round(h.High) : null,
            CostP50Micro: p50,
            CostP90Micro: p90,
            WeeklySr: weekly,
            RedoRate: tasks.Count > 0 ? Round((double)tasks.Count(t => t.RedoTurns > 0) / tasks.Count) : null,
            Mde: null,
            StabilityFlag: unstable,
            Verdict: Verdict.Insufficient.ToWire(),
            Confidence: null,
            ComparedTo: null,
            CrossTool: false);

        return new SetupData(provider, model, effort, group, tasks, report, stats);
    }

    private static double? Round(double? v) => v is { } x && !double.IsNaN(x) ? Math.Round(x, 4) : null;
}
