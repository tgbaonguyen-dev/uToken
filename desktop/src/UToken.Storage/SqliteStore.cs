using System.Globalization;
using System.Reflection;
using Dapper;
using Microsoft.Data.Sqlite;
using UToken.Core.Models;
using UToken.Core.Pricing;

namespace UToken.Storage;

public sealed class SqliteStore : IDisposable
{
    private readonly SqliteConnection _db;

    public SqliteStore(string dbPath)
    {
        _db = new SqliteConnection($"Data Source={dbPath}");
        _db.Open();
        Migrate();
    }

    private void Migrate()
    {
        using var s = Assembly.GetExecutingAssembly().GetManifestResourceStream("UToken.Storage.Schema.sql")!;
        using var r = new StreamReader(s);
        _db.Execute(r.ReadToEnd());
    }

    /// <summary>Ghi event; trùng khóa (provider, source_event_id) thì bỏ qua (FR-DATA-001).</summary>
    public int InsertEvents(IEnumerable<UsageEvent> events, string parserVersion)
    {
        using var tx = _db.BeginTransaction();
        var n = 0;
        foreach (var e in events)
        {
            if (!e.IsValid) continue; // METRIC_INVALID: TODO ghi log collector
            n += _db.Execute("""
                INSERT OR IGNORE INTO usage_events
                (provider, source_event_id, session_id, turn_id, model, effort, occurred_at,
                 input, cached, cache_write, output, thinking, duration_ms, is_side, project_key, parser_version)
                VALUES (@Provider, @SourceEventId, @SessionId, @TurnId, @Model, @Effort, @OccurredAt,
                 @Input, @Cached, @CacheWrite, @Output, @Thinking, @DurationMs, @IsSideSession, @ProjectKey, @ParserVersion)
                """,
                new
                {
                    Provider = e.Provider.ToString(), e.SourceEventId, e.SessionId, e.TurnId, e.Model, e.Effort,
                    OccurredAt = e.OccurredAt.ToString("O"), e.Input, e.Cached, e.CacheWrite, e.Output, e.Thinking,
                    e.DurationMs, e.IsSideSession, e.ProjectKey, ParserVersion = parserVersion,
                }, tx);
        }
        tx.Commit();
        return n;
    }

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
