using System.Globalization;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using Dapper;
using Microsoft.Data.Sqlite;
using UToken.Core.Efficiency;
using UToken.Core.Models;
using UToken.Core.Tasks;
using UToken.Core.Pricing;

namespace UToken.Storage;

/// <summary>Trạng thái đã lưu của một file log.</summary>
public sealed record StoredSourceFile(long Size, long MTime, long ReadOffset, bool Completed, string ParserVersion, string? ContextJson);

public sealed class SqliteStore : IDisposable
{
    public const int SchemaVersion = 2;
    // Không có pricing/pricing_tier: giá tải từ models.dev, không suy ra lại từ log được nên giữ qua các lần nâng schema.
    private static readonly string[] Tables =
        ["schema_info", "source_files", "sessions", "projects", "usage_events", "turns", "task_outcomes", "daily_local", "sync_queue"];

    private readonly SqliteConnection _db;

    public SqliteStore(string dbPath)
    {
        _db = new SqliteConnection($"Data Source={dbPath}");
        _db.Open();
        _db.Execute("PRAGMA journal_mode = WAL;");
        Migrate();
    }

    private void Migrate()
    {
        var version = _db.ExecuteScalar<long>("PRAGMA user_version;");
        if (version != SchemaVersion)
        {
            // Dữ liệu đều suy ra từ log: xóa bảng cũ rồi quét lại từ đầu.
            using var tx = _db.BeginTransaction();
            foreach (var t in Tables) _db.Execute($"DROP TABLE IF EXISTS {t};", transaction: tx);
            tx.Commit();
        }
        using var s = Assembly.GetExecutingAssembly().GetManifestResourceStream("UToken.Storage.Schema.sql")!;
        using var r = new StreamReader(s);
        _db.Execute(r.ReadToEnd());
        _db.Execute($"PRAGMA user_version = {SchemaVersion};");
    }

    // ───────────── Thời gian: lưu UTC dạng chuỗi cố định để so sánh được ─────────────

    public static string Ts(DateTimeOffset t) => t.UtcDateTime.ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'", CultureInfo.InvariantCulture);
    private static string? Ts(DateTimeOffset? t) => t is { } v ? Ts(v) : null;
    private static DateTimeOffset ParseTs(string s) => DateTimeOffset.Parse(s, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal);

    private static string PathHash(string path) =>
        Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(path)));

    // ───────────── source_files ─────────────

    public StoredSourceFile? GetSourceFile(string path)
    {
        var r = _db.QueryFirstOrDefault(
            "SELECT size, mtime, read_offset, completed, parser_version, ctx_json FROM source_files WHERE path_hash = @h",
            new { h = PathHash(path) });
        return r is null
            ? null
            : new StoredSourceFile((long)r.size, (long)r.mtime, (long)r.read_offset, (long)r.completed != 0, (string)r.parser_version, (string?)r.ctx_json);
    }

    // ───────────── Ghi kết quả một lần đọc file (một transaction) ─────────────

    /// <summary>
    /// Ghi event (trùng khóa thì bỏ qua, FR-DATA-001), turn (ghi đè), tên project và vị trí đọc mới trong một transaction,
    /// để lỡ tắt app giữa chừng thì lần sau đọc lại đúng phần chưa ghi. Trả về số event mới.
    /// </summary>
    public int SaveRead(
        string path, Provider provider, string parserVersion, long size, long mtime,
        long readOffset, bool completed, string? contextJson,
        IEnumerable<UsageEvent> events, IEnumerable<TurnRecord> turns, IReadOnlyDictionary<string, string> projects)
    {
        using var tx = _db.BeginTransaction();
        int n = 0;
        foreach (var e in events)
        {
            if (!e.IsValid) continue; // METRIC_INVALID
            n += _db.Execute("""
                INSERT OR IGNORE INTO usage_events
                (provider, source_event_id, session_id, turn_id, model, effort, occurred_at,
                 input, cached, cache_write, output, thinking, duration_ms, status, is_side, project_key, parser_version)
                VALUES (@Provider, @SourceEventId, @SessionId, @TurnId, @Model, @Effort, @OccurredAt,
                 @Input, @Cached, @CacheWrite, @Output, @Thinking, @DurationMs, @Status, @IsSide, @ProjectKey, @ParserVersion)
                """,
                new
                {
                    Provider = e.Provider.ToWire(), e.SourceEventId, e.SessionId, e.TurnId, e.Model, e.Effort,
                    OccurredAt = Ts(e.OccurredAt), e.Input, e.Cached, e.CacheWrite, e.Output, e.Thinking, e.DurationMs,
                    Status = e.IsError ? "error" : "ok", IsSide = e.IsSideSession, e.ProjectKey, ParserVersion = parserVersion,
                }, tx);
        }

        foreach (var t in turns)
        {
            _db.Execute("""
                INSERT OR REPLACE INTO turns
                (provider, session_id, turn_id, started_at, last_seen_at, ended_at, commands_total, commands_failed,
                 max_consecutive_failures, test_runs, last_test_passed, files_changed, turn_error, aborted, duration_ms, is_side, project_key)
                VALUES (@Provider, @SessionId, @TurnId, @StartedAt, @LastSeenAt, @EndedAt, @CommandsTotal, @CommandsFailed,
                 @MaxConsecutiveFailures, @TestRuns, @LastTestPassed, @FilesChanged, @TurnError, @Aborted, @DurationMs, @IsSideSession, @ProjectKey)
                """,
                new
                {
                    Provider = t.Provider.ToWire(), t.SessionId, t.TurnId, StartedAt = Ts(t.StartedAt), LastSeenAt = Ts(t.LastSeenAt),
                    EndedAt = Ts(t.EndedAt), t.CommandsTotal, t.CommandsFailed, t.MaxConsecutiveFailures, t.TestRuns, t.LastTestPassed,
                    t.FilesChanged, t.TurnError, t.Aborted, t.DurationMs, t.IsSideSession, t.ProjectKey,
                }, tx);
        }

        foreach (var (key, name) in projects)
            _db.Execute("INSERT OR REPLACE INTO projects (project_key, display_name) VALUES (@key, @name)", new { key, name }, tx);

        _db.Execute("""
            INSERT OR REPLACE INTO source_files (path_hash, provider, size, mtime, read_offset, completed, parser_version, ctx_json, last_ok_at)
            VALUES (@h, @provider, @size, @mtime, @readOffset, @completed, @parserVersion, @contextJson, @now)
            """,
            new
            {
                h = PathHash(path), provider = provider.ToWire(), size, mtime, readOffset, completed, parserVersion, contextJson,
                now = Ts(DateTimeOffset.UtcNow),
            }, tx);

        tx.Commit();
        return n;
    }

    // ───────────── Đọc ─────────────

    public IReadOnlyList<UsageEvent> GetEvents(DateTimeOffset fromUtc, DateTimeOffset toUtc)
    {
        var rows = _db.Query("""
            SELECT provider, source_event_id, session_id, turn_id, model, effort, occurred_at, input, cached, cache_write,
                   output, thinking, duration_ms, status, is_side, project_key
            FROM usage_events WHERE occurred_at >= @from AND occurred_at < @to
            """, new { from = Ts(fromUtc), to = Ts(toUtc) });
        return rows.Select(r => new UsageEvent(
            ProviderNames.FromWire((string)r.provider), (string)r.source_event_id, (string)r.session_id, (string?)r.turn_id,
            (string)r.model, (string?)r.effort, ParseTs((string)r.occurred_at),
            (long)r.input, (long)r.cached, (long)r.cache_write, (long)r.output, (long?)r.thinking, (long?)r.duration_ms,
            (long)r.is_side != 0, (string?)r.project_key)
        {
            IsError = (string)r.status == "error",
        }).ToList();
    }

    public IReadOnlyList<TurnRecord> GetTurns(DateTimeOffset fromUtc, DateTimeOffset toUtc)
    {
        var rows = _db.Query("""
            SELECT provider, session_id, turn_id, started_at, last_seen_at, ended_at, commands_total, commands_failed,
                   max_consecutive_failures, test_runs, last_test_passed, files_changed, turn_error, aborted, duration_ms, is_side, project_key
            FROM turns WHERE started_at >= @from AND started_at < @to
            """, new { from = Ts(fromUtc), to = Ts(toUtc) });
        return rows.Select(r => new TurnRecord(
            ProviderNames.FromWire((string)r.provider), (string)r.session_id, (string)r.turn_id,
            ParseTs((string)r.started_at), ParseTs((string)r.last_seen_at), r.ended_at is string e ? ParseTs(e) : null,
            (int)(long)r.commands_total, (int)(long)r.commands_failed, (int)(long)r.max_consecutive_failures, (int)(long)r.test_runs,
            r.last_test_passed is long ltp ? ltp != 0 : null,
            (long)r.files_changed != 0, (long)r.turn_error != 0, (long)r.aborted != 0, (long?)r.duration_ms,
            (long)r.is_side != 0, (string?)r.project_key)).ToList();
    }

    /// <summary>Lần đọc log thành công gần nhất của một nguồn (null nếu chưa đọc).</summary>
    public DateTimeOffset? GetLastReadAt(Provider provider) =>
        _db.ExecuteScalar<string?>("SELECT MAX(last_ok_at) FROM source_files WHERE provider = @p", new { p = provider.ToWire() })
            is string s ? ParseTs(s) : null;

    /// <summary>Thời điểm event mới nhất của một nguồn, hoặc của mọi nguồn khi <paramref name="provider"/> null.</summary>
    public DateTimeOffset? GetLastEventAt(Provider? provider = null) =>
        _db.ExecuteScalar<string?>(
            provider is null ? "SELECT MAX(occurred_at) FROM usage_events" : "SELECT MAX(occurred_at) FROM usage_events WHERE provider = @p",
            new { p = provider?.ToWire() }) is string s ? ParseTs(s) : null;

    public DateTimeOffset? GetFirstEventAt() =>
        _db.ExecuteScalar<string?>("SELECT MIN(occurred_at) FROM usage_events") is string s ? ParseTs(s) : null;

    public IReadOnlyDictionary<string, string> GetProjects() =>
        _db.Query<(string, string)>("SELECT project_key, display_name FROM projects").ToDictionary(r => r.Item1, r => r.Item2);

    public (long Events, long Turns, long Files) Counts() => (
        _db.ExecuteScalar<long>("SELECT COUNT(*) FROM usage_events"),
        _db.ExecuteScalar<long>("SELECT COUNT(*) FROM turns"),
        _db.ExecuteScalar<long>("SELECT COUNT(*) FROM source_files"));

    // ───────────── Kết quả tính toán ─────────────

    /// <summary>Ghi đè task có started_at trong khoảng [from, to) bằng kết quả mới (tính lại idempotent).</summary>
    public void ReplaceTasks(DateTimeOffset fromUtc, DateTimeOffset toUtc, IEnumerable<TaskRecord> tasks)
    {
        using var tx = _db.BeginTransaction();
        _db.Execute("DELETE FROM task_outcomes WHERE started_at >= @from AND started_at < @to",
            new { from = Ts(fromUtc), to = Ts(toUtc) }, tx);
        foreach (var t in tasks)
        {
            _db.Execute("""
                INSERT OR REPLACE INTO task_outcomes
                (task_id, provider, session_id, model, effort, project_key, task_group, started_at, ended_at, turns, requests,
                 redo_turns, commands_total, commands_failed, max_consecutive_failures, test_runs, last_test_passed, files_changed,
                 turn_error, aborted, outcome_state, cost_micro, total_tokens, context_growth, state)
                VALUES (@TaskId, @Provider, @SessionId, @Model, @Effort, @ProjectKey, @Group, @StartedAt, @EndedAt, @Turns, @Requests,
                 @RedoTurns, @CommandsTotal, @CommandsFailed, @MaxConsecutiveFailures, @TestRuns, @LastTestPassed, @FilesChanged,
                 @TurnError, @Aborted, @Outcome, @CostMicro, @TotalTokens, @ContextGrowth, @State)
                """,
                new
                {
                    t.TaskId, Provider = t.Provider.ToWire(), t.SessionId, t.Model, t.Effort, t.ProjectKey,
                    Group = t.Group.ToWire(), StartedAt = Ts(t.StartedAt), EndedAt = Ts(t.EndedAt),
                    t.Turns, t.Requests, t.RedoTurns, t.Signals.CommandsTotal, t.Signals.CommandsFailed,
                    t.Signals.MaxConsecutiveFailures, t.TestRuns, t.Signals.LastTestPassed, t.Signals.FilesChanged,
                    t.Signals.TurnError, t.Signals.Aborted, Outcome = t.Outcome.ToWire(), t.CostMicro, t.TotalTokens,
                    t.ContextGrowth, State = t.Closed ? "closed" : "open",
                }, tx);
        }
        tx.Commit();
    }

    /// <summary>Lưu bản nháp document daily trên máy; chỉ đánh dấu dirty khi nội dung đổi (FR-SYNC-002).</summary>
    public bool SaveDailyLocal(string date, string json, string updatedAt)
    {
        var old = _db.QueryFirstOrDefault<string?>("SELECT json FROM daily_local WHERE date = @date", new { date });
        if (old is not null && StripUpdatedAt(old) == StripUpdatedAt(json)) return false;
        _db.Execute("INSERT OR REPLACE INTO daily_local (date, json, dirty, updated_at) VALUES (@date, @json, 1, @updatedAt)",
            new { date, json, updatedAt });
        return true;
    }

    public IReadOnlyList<(string Date, string Json)> GetDirtyDaily() =>
        _db.Query<(string, string)>("SELECT date, json FROM daily_local WHERE dirty = 1 ORDER BY date").ToList();

    public void MarkDailySynced(string date) =>
        _db.Execute("UPDATE daily_local SET dirty = 0 WHERE date = @date", new { date });

    private static string StripUpdatedAt(string json) =>
        System.Text.RegularExpressions.Regex.Replace(json, "\"updated_at\":\"[^\"]*\"", "");
    /// <summary>
    /// Ghi bảng giá mới với một pricing_version. Model nào giá không đổi so với bản gần nhất thì bỏ qua,
    /// nên bảng chỉ lớn lên khi giá thật sự thay đổi. Trả về số dòng đã ghi.
    /// </summary>
    public int SavePrices(IEnumerable<ModelPrice> prices, string pricingVersion, DateTimeOffset effectiveFrom)
    {
        using var tx = _db.BeginTransaction();
        var n = 0;
        foreach (var mp in prices)
        {
            var versionExists = _db.ExecuteScalar<long>("""
                SELECT COUNT(*) FROM pricing
                WHERE pricing_version = @pricingVersion AND provider = @Vendor AND model = @Model
                """, new { pricingVersion, mp.Vendor, mp.Model }, tx) > 0;
            if (versionExists)
                throw new InvalidOperationException(
                    $"Bảng giá đã tồn tại: pricing_version={pricingVersion}, provider={mp.Vendor}, model={mp.Model}.");

            var latest = _db.QueryFirstOrDefault<PriceRow>("""
                SELECT pricing_version AS PricingVersion, input_per_mtok AS Input, cached_input_per_mtok AS Cached,
                       cache_write_per_mtok AS CacheWrite, output_per_mtok AS Output
                FROM pricing WHERE provider = @Vendor AND model = @Model
                ORDER BY effective_from DESC LIMIT 1
                """, new { mp.Vendor, mp.Model }, tx);
            if (latest is not null)
            {
                var latestTiers = LoadTiers(latest.PricingVersion, mp.Vendor, mp.Model, tx);
                if (new PriceSchedule(latest.ToPrice(), latestTiers) == mp.Schedule) continue;
            }

            n += _db.Execute("""
                INSERT INTO pricing
                (pricing_version, provider, model, input_per_mtok, cached_input_per_mtok,
                 cache_write_per_mtok, output_per_mtok, effective_from)
                VALUES (@Version, @Vendor, @Model, @Input, @Cached, @CacheWrite, @Output, @From)
                """,
                new
                {
                    Version = pricingVersion, mp.Vendor, mp.Model,
                    Input = Str(mp.Schedule.Base.InputPerMTok), Cached = Str(mp.Schedule.Base.CachedPerMTok),
                    CacheWrite = mp.Schedule.Base.CacheWritePerMTok is { } w ? Str(w) : null,
                    Output = Str(mp.Schedule.Base.OutputPerMTok), From = effectiveFrom.ToUniversalTime().ToString("O"),
                }, tx);
            foreach (var tier in mp.Schedule.Tiers)
            {
                _db.Execute("""
                    INSERT INTO pricing_tier
                    (pricing_version, provider, model, context_above, input_per_mtok,
                     cached_input_per_mtok, cache_write_per_mtok, output_per_mtok)
                    VALUES (@Version, @Vendor, @Model, @ContextAbove, @Input, @Cached, @CacheWrite, @Output)
                    """,
                    new
                    {
                        Version = pricingVersion, mp.Vendor, mp.Model, tier.ContextAbove,
                        Input = Str(tier.Price.InputPerMTok), Cached = Str(tier.Price.CachedPerMTok),
                        CacheWrite = tier.Price.CacheWritePerMTok is { } tierWrite ? Str(tierWrite) : null,
                        Output = Str(tier.Price.OutputPerMTok),
                    }, tx);
            }
        }
        tx.Commit();
        return n;
    }

    /// <summary>
    /// Giá áp dụng cho model tại thời điểm <paramref name="at"/>: bản mới nhất có effective_from ≤ at.
    /// Event xảy ra trước lần tải giá đầu tiên thì dùng bản cũ nhất đang có. Không tìm thấy → null (chưa có giá).
    /// </summary>
    public PricedModel? FindPrice(Provider provider, string model, DateTimeOffset at)
    {
        var vendor = ModelIdNormalizer.VendorOf(provider, model);
        if (vendor is null) return null;
        var atText = at.ToUniversalTime().ToString("O");
        foreach (var id in ModelIdNormalizer.Candidates(model))
        {
            var row = _db.QueryFirstOrDefault<PriceRow>("""
                SELECT pricing_version AS PricingVersion, input_per_mtok AS Input, cached_input_per_mtok AS Cached,
                       cache_write_per_mtok AS CacheWrite, output_per_mtok AS Output
                FROM pricing WHERE provider = @vendor AND model = @id
                ORDER BY (effective_from <= @atText) DESC,
                         CASE WHEN effective_from <= @atText THEN effective_from END DESC,
                         effective_from ASC
                LIMIT 1
                """, new { vendor, id, atText });
            if (row is not null)
            {
                var tiers = LoadTiers(row.PricingVersion, vendor, id, null);
                return new PricedModel(new PriceSchedule(row.ToPrice(), tiers), row.PricingVersion);
            }
        }
        return null;
    }

    /// <summary>Toàn bộ các phiên bản giá đã lưu, kèm bậc context, để dựng <see cref="TieredPriceBook"/> trong bộ nhớ.</summary>
    public IReadOnlyList<PriceEntry> LoadAllPrices()
    {
        var rows = _db.Query<PriceRowWithKey>("""
            SELECT pricing_version AS PricingVersion, provider AS Vendor, model AS Model, effective_from AS EffectiveFrom,
                   input_per_mtok AS Input, cached_input_per_mtok AS Cached, cache_write_per_mtok AS CacheWrite, output_per_mtok AS Output
            FROM pricing
            """).ToList();
        var tiers = _db.Query<PriceTierRowWithKey>("""
            SELECT pricing_version AS PricingVersion, provider AS Vendor, model AS Model, context_above AS ContextAbove,
                   input_per_mtok AS Input, cached_input_per_mtok AS Cached, cache_write_per_mtok AS CacheWrite, output_per_mtok AS Output
            FROM pricing_tier
            """).ToLookup(t => (t.PricingVersion, t.Vendor, t.Model));
        return rows.Select(r => new PriceEntry(
            r.Vendor, r.Model,
            DateTimeOffset.Parse(r.EffectiveFrom, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal),
            r.PricingVersion,
            new PriceSchedule(r.ToPrice(), tiers[(r.PricingVersion, r.Vendor, r.Model)].Select(t => t.ToTier()).ToArray())))
            .ToList();
    }

    private sealed class PriceRowWithKey
    {
        public string PricingVersion { get; set; } = "";
        public string Vendor { get; set; } = "";
        public string Model { get; set; } = "";
        public string EffectiveFrom { get; set; } = "";
        public string Input { get; set; } = "";
        public string Cached { get; set; } = "";
        public string? CacheWrite { get; set; }
        public string Output { get; set; } = "";

        public Price ToPrice() => new PriceRow { Input = Input, Cached = Cached, CacheWrite = CacheWrite, Output = Output }.ToPrice();
    }

    private sealed class PriceTierRowWithKey
    {
        public string PricingVersion { get; set; } = "";
        public string Vendor { get; set; } = "";
        public string Model { get; set; } = "";
        public long ContextAbove { get; set; }
        public string Input { get; set; } = "";
        public string Cached { get; set; } = "";
        public string? CacheWrite { get; set; }
        public string Output { get; set; } = "";

        public PriceTier ToTier() => new PriceTierRow
        {
            ContextAbove = ContextAbove, Input = Input, Cached = Cached, CacheWrite = CacheWrite, Output = Output,
        }.ToTier();
    }

    private static string Str(decimal d) => d.ToString(CultureInfo.InvariantCulture);

    private IReadOnlyList<PriceTier> LoadTiers(
        string pricingVersion,
        string vendor,
        string model,
        SqliteTransaction? transaction)
    {
        var rows = _db.Query<PriceTierRow>("""
            SELECT context_above AS ContextAbove, input_per_mtok AS Input, cached_input_per_mtok AS Cached,
                   cache_write_per_mtok AS CacheWrite, output_per_mtok AS Output
            FROM pricing_tier
            WHERE pricing_version = @pricingVersion AND provider = @vendor AND model = @model
            ORDER BY context_above
            """, new { pricingVersion, vendor, model }, transaction);
        return rows.Select(row => row.ToTier()).ToArray();
    }

    private sealed class PriceRow
    {
        public string PricingVersion { get; set; } = "";
        public string Input { get; set; } = "";
        public string Cached { get; set; } = "";
        public string? CacheWrite { get; set; }
        public string Output { get; set; } = "";

        public Price ToPrice() => new(
            decimal.Parse(Input, CultureInfo.InvariantCulture),
            decimal.Parse(Cached, CultureInfo.InvariantCulture),
            CacheWrite is null ? null : decimal.Parse(CacheWrite, CultureInfo.InvariantCulture),
            decimal.Parse(Output, CultureInfo.InvariantCulture));
    }

    private sealed class PriceTierRow
    {
        public long ContextAbove { get; set; }
        public string Input { get; set; } = "";
        public string Cached { get; set; } = "";
        public string? CacheWrite { get; set; }
        public string Output { get; set; } = "";

        public PriceTier ToTier() => new(ContextAbove, new Price(
            decimal.Parse(Input, CultureInfo.InvariantCulture),
            decimal.Parse(Cached, CultureInfo.InvariantCulture),
            CacheWrite is null ? null : decimal.Parse(CacheWrite, CultureInfo.InvariantCulture),
            decimal.Parse(Output, CultureInfo.InvariantCulture)));
    }

    public void Dispose() => _db.Dispose();
}

/// <summary>Giá kèm pricing_version để ghi vào usage_events.pricing_version.</summary>
public sealed record PricedModel(PriceSchedule Schedule, string PricingVersion);
