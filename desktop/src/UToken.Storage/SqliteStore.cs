using System.Reflection;
using Dapper;
using Microsoft.Data.Sqlite;
using UToken.Core.Models;

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

    public void Dispose() => _db.Dispose();
}
