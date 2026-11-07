using System.Text.Encodings.Web;
using System.Text.Json;
using UToken.Collectors;
using UToken.Core.Aggregation;
using UToken.Core.Efficiency;
using UToken.Core.Models;
using UToken.Core.Pricing;
using UToken.Core.Tasks;
using UToken.Storage;

namespace UToken.Engine;

/// <summary>Kết quả một lần quét log.</summary>
public sealed record ScanReport(
    int FilesRead,
    int FilesUnchanged,
    int NewEvents,
    int TurnsUpdated,
    int MalformedLines,
    IReadOnlyCollection<DateOnly> TouchedDates,
    IReadOnlyList<string> Errors);

/// <summary>Kết quả trọn một vòng: quét, tính lại daily của các ngày có thay đổi và efficiency/current.</summary>
public sealed record AnalysisSnapshot(ScanReport Scan, IReadOnlyList<DailyDoc> ChangedDaily, EfficiencyDoc Efficiency);

/// <summary>
/// Điểm vào của phần core trên desktop. Luồng: collectors đọc phần log mới → SQLite → gom task → DailyDoc / EfficiencyDoc.
/// Lớp sync chỉ cần gọi <see cref="Run"/> rồi đẩy <see cref="AnalysisSnapshot.ChangedDaily"/> và
/// <see cref="AnalysisSnapshot.Efficiency"/> lên Firestore. Không thread-safe: gọi tuần tự (một vòng sync một lúc).
/// </summary>
public sealed class UsageEngine(
    SqliteStore store,
    IEnumerable<ILogCollector> collectors,
    string homeDirectory,
    TimeZoneInfo? timeZone = null,
    IPriceBook? prices = null,
    TimeProvider? clock = null,
    TaskBuilderOptions? taskOptions = null)
{
    private readonly IReadOnlyList<ILogCollector> _collectors = collectors.ToList();
    public TimeZoneInfo TimeZone { get; } = timeZone ?? TimeZoneInfo.Local;
    public IPriceBook Prices { get; } = prices ?? StaticPriceBook.Default;
    private readonly TimeProvider _clock = clock ?? TimeProvider.System;
    private readonly TaskBuilderOptions _taskOptions = taskOptions ?? new TaskBuilderOptions();

    public DateTimeOffset Now => _clock.GetUtcNow();
    public DateOnly Today => DailyAggregator.LocalDate(Now, TimeZone);

    public static readonly JsonSerializerOptions JsonOptions = new()
    {
        Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping, // giữ nguyên "|" và tiếng Việt cho dễ đọc
    };

    public static string ToJson(object doc, bool indented = false) =>
        JsonSerializer.Serialize(doc, doc.GetType(), new JsonSerializerOptions(JsonOptions) { WriteIndented = indented });

    // ───────────────────────── Quét log ─────────────────────────

    /// <summary>Đọc phần mới của mọi file log trong allowlist. Đọc lại bao nhiêu lần cũng không cộng trùng.</summary>
    public ScanReport Scan(CancellationToken ct = default)
    {
        int read = 0, unchanged = 0, newEvents = 0, turns = 0, malformed = 0;
        var dates = new HashSet<DateOnly>();
        var errors = new List<string>();

        foreach (var collector in _collectors)
        {
            IEnumerable<string> files;
            try { files = collector.DiscoverFiles(homeDirectory).ToList(); }
            catch (Exception ex) { errors.Add($"{collector.Provider.ToWire()}: {ex.GetType().Name}"); continue; }

            foreach (var path in files)
            {
                ct.ThrowIfCancellationRequested();
                try
                {
                    var info = new FileInfo(path);
                    long size = info.Length, mtime = info.LastWriteTimeUtc.Ticks;
                    var stored = store.GetSourceFile(path);
                    bool sameParser = stored?.ParserVersion == collector.ParserVersion;

                    if (stored is not null && sameParser && (stored.Completed || (stored.Size == size && stored.MTime == mtime)))
                    {
                        unchanged++;
                        continue;
                    }

                    // Đổi parser hoặc file bị cắt ngắn/ghi lại → đọc từ đầu (khóa chống trùng giữ cho số liệu không bị cộng hai lần).
                    var state = stored is not null && sameParser && size >= stored.ReadOffset
                        ? new SourceFileState(path, stored.ReadOffset, stored.Completed, stored.ContextJson)
                        : new SourceFileState(path, 0, false);

                    var result = collector.ReadNew(state);
                    newEvents += store.SaveRead(path, collector.Provider, collector.ParserVersion, size, mtime,
                        result.NewState.ReadOffset, result.NewState.Completed, result.NewState.ContextJson,
                        result.Events, result.Turns, result.Projects);

                    read++;
                    turns += result.Turns.Count;
                    malformed += result.MalformedLines;
                    foreach (var e in result.Events) dates.Add(DailyAggregator.LocalDate(e.OccurredAt, TimeZone));
                    foreach (var t in result.Turns) dates.Add(DailyAggregator.LocalDate(t.LastActivityAt, TimeZone));
                }
                catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or InvalidOperationException
                                               or System.Text.Json.JsonException or Microsoft.Data.Sqlite.SqliteException)
                {
                    // Chỉ ghi tên file và loại lỗi, không ghi nội dung log.
                    errors.Add($"{collector.Provider.ToWire()}: {Path.GetFileName(path)}: {ex.GetType().Name}");
                }
            }
        }
        return new ScanReport(read, unchanged, newEvents, turns, malformed, dates.OrderBy(d => d).ToList(), errors);
    }

    // ───────────────────────── Tính toán ─────────────────────────

    /// <summary>Document daily của một ngày người dùng. Gọi lại bao nhiêu lần cũng cho cùng nội dung (trừ updated_at).</summary>
    public DailyDoc BuildDaily(DateOnly date)
    {
        var (from, to) = DayRangeUtc(date);
        // Lấy rộng thêm hai bên để gom đúng task vắt qua nửa đêm.
        var events = store.GetEvents(from.AddDays(-1), to.AddDays(1));
        var turns = store.GetTurns(from.AddDays(-1), to.AddDays(1));
        var tasks = TaskBuilder.Build(turns, events, Prices, Now, _taskOptions);
        return DailyAggregator.Build(date, TimeZone, events, turns, tasks, Prices, Now);
    }

    /// <summary>EfficiencyReport 30 ngày gần nhất (document efficiency/current).</summary>
    public EfficiencyDoc BuildEfficiency()
    {
        var (from, to) = PeriodRangeUtc();
        var events = store.GetEvents(from, to);
        var turns = store.GetTurns(from, to);
        var tasks = TaskBuilder.Build(turns, events, Prices, Now, _taskOptions);
        store.ReplaceTasks(from, to, tasks); // giữ bản chi tiết trên máy cho màn hình desktop
        return EfficiencyCalculator.Build(Now, TimeZone, events, turns, tasks, Prices);
    }

    /// <summary>Danh sách task 30 ngày (chi tiết, chỉ dùng trên máy).</summary>
    public IReadOnlyList<TaskRecord> BuildTasks()
    {
        var (from, to) = PeriodRangeUtc();
        return TaskBuilder.Build(store.GetTurns(from, to), store.GetEvents(from, to), Prices, Now, _taskOptions);
    }

    /// <summary>
    /// Một vòng đầy đủ: quét log, tính lại daily của hôm nay và các ngày có dữ liệu mới, tính efficiency.
    /// <see cref="AnalysisSnapshot.ChangedDaily"/> chỉ gồm document có nội dung khác lần trước (để mỗi lần sync ghi ít nhất).
    /// </summary>
    public AnalysisSnapshot Run(CancellationToken ct = default)
    {
        var scan = Scan(ct);
        var dates = new SortedSet<DateOnly>(scan.TouchedDates) { Today };
        // Task của hôm qua có thể vừa đóng (quá 2 phút không có turn mới) nên tính lại luôn.
        dates.Add(Today.AddDays(-1));

        var changed = new List<DailyDoc>();
        foreach (var date in dates)
        {
            var doc = BuildDaily(date);
            if (doc.Totals.Requests == 0 && date != Today) continue;
            if (store.SaveDailyLocal(doc.Date, ToJson(doc), doc.UpdatedAt)) changed.Add(doc);
        }
        return new AnalysisSnapshot(scan, changed, BuildEfficiency());
    }

    private (DateTimeOffset From, DateTimeOffset To) DayRangeUtc(DateOnly date)
    {
        var start = date.ToDateTime(TimeOnly.MinValue);
        var from = new DateTimeOffset(start, TimeZone.GetUtcOffset(start));
        var end = date.AddDays(1).ToDateTime(TimeOnly.MinValue);
        var to = new DateTimeOffset(end, TimeZone.GetUtcOffset(end));
        return (from, to);
    }

    private (DateTimeOffset From, DateTimeOffset To) PeriodRangeUtc()
    {
        var (from, _) = DayRangeUtc(Today.AddDays(-(EfficiencyCalculator.PeriodDays - 1)));
        var (_, to) = DayRangeUtc(Today);
        return (from.AddDays(-1), to); // thêm một ngày để task vắt qua đầu kỳ vẫn đủ turn
    }
}
