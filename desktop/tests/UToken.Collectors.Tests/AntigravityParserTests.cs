using Microsoft.Data.Sqlite;
using UToken.Collectors;
using UToken.Collectors.Antigravity;
using Xunit;

namespace UToken.Collectors.Tests;

/// <summary>DB tổng hợp theo đúng cấu trúc Antigravity (gen_metadata + steps), không dùng dữ liệu thật.</summary>
public sealed class AntigravityParserTests : IDisposable
{
    private readonly string _dir = Directory.CreateTempSubdirectory("utoken-agp-").FullName;

    // ── protobuf wire format tối thiểu ──
    private static byte[] Varint(ulong v) { var l = new List<byte>(); do { var b = (byte)(v & 0x7F); v >>= 7; l.Add(v == 0 ? b : (byte)(b | 0x80)); } while (v != 0); return [.. l]; }
    private static byte[] V(int field, long value) => [.. Varint((ulong)(field << 3)), .. Varint((ulong)value)];
    private static byte[] L(int field, byte[] bytes) => [.. Varint((ulong)(field << 3 | 2)), .. Varint((ulong)bytes.Length), .. bytes];
    private static byte[] S(int field, string s) => L(field, System.Text.Encoding.UTF8.GetBytes(s));
    private static byte[] M(int field, params byte[][] parts) => L(field, [.. parts.SelectMany(p => p)]);

    private static byte[] Gen(string id, long fresh, long cached, long output, long thinking, long? seconds, string model = "gemini-3.8-flash") =>
        M(1,
            V(3, 1016),
            M(4, V(1, 1016), V(2, fresh), V(3, output), cached > 0 ? V(5, cached) : [], V(6, 24), V(9, thinking), V(10, output - thinking), S(11, id)),
            seconds is { } s ? M(9, V(2, -1), M(4, V(1, s))) : M(9, V(2, -1)),
            S(19, model));

    private string Db(string name, Action<SqliteConnection> fill)
    {
        var path = Path.Combine(_dir, name + ".db");
        using var db = new SqliteConnection($"Data Source={path};Pooling=False");
        db.Open();
        using (var c = db.CreateCommand())
        {
            c.CommandText = "CREATE TABLE gen_metadata (idx integer PRIMARY KEY, data blob, size integer NOT NULL DEFAULT 0);" +
                            "CREATE TABLE steps (idx integer PRIMARY KEY, step_type integer NOT NULL DEFAULT 0, metadata blob, step_payload blob);";
            c.ExecuteNonQuery();
        }
        fill(db);
        return path;
    }

    private static void Insert(SqliteConnection db, string sql, params object[] values)
    {
        using var c = db.CreateCommand();
        c.CommandText = sql;
        for (var i = 0; i < values.Length; i++) c.Parameters.AddWithValue($"$p{i}", values[i]);
        c.ExecuteNonQuery();
    }

    [Fact]
    public void Reads_usage_from_ide_conversation_and_resumes_from_offset()
    {
        var path = Db("ide-1", db =>
        {
            Insert(db, "INSERT INTO gen_metadata(idx, data) VALUES (0, $p0)", Gen("r-0", 18_733, 0, 696, 640, 1_790_855_284));
            Insert(db, "INSERT INTO gen_metadata(idx, data) VALUES (1, $p0)", Gen("r-1", 3_533, 16_253, 461, 399, 1_790_855_292, "gemini-pro-default"));
        });
        var c = new AntigravityCollector();

        var r = c.ReadNew(new SourceFileState(path, 0, false));

        Assert.Equal(0, r.MalformedLines);
        Assert.Equal(2, r.NewState.ReadOffset);
        var second = r.Events[1];
        Assert.Equal("r-1", second.SourceEventId);
        Assert.Equal("ide-1", second.SessionId);
        Assert.Equal("gemini-pro-default", second.Model);
        Assert.Equal(3_533 + 16_253, second.Input); // Input gồm cả phần cache, như Codex
        Assert.Equal(16_253, second.Cached);
        Assert.Equal(461, second.Output);
        Assert.Equal(399, second.Thinking);
        Assert.Equal(DateTimeOffset.FromUnixTimeSeconds(1_790_855_292), second.OccurredAt);
        Assert.All(r.Events, e => Assert.True(e.IsValid));

        using (var db = new SqliteConnection($"Data Source={path};Pooling=False"))
        {
            db.Open();
            Insert(db, "INSERT INTO gen_metadata(idx, data) VALUES (2, $p0)", Gen("r-2", 100, 50, 10, 0, 1_790_855_299));
        }
        var more = c.ReadNew(r.NewState);
        Assert.Equal("r-2", Assert.Single(more.Events).SourceEventId);
    }

    [Fact]
    public void Cli_conversation_takes_time_from_model_steps()
    {
        var path = Db("cli-1", db =>
        {
            Insert(db, "INSERT INTO steps(idx, step_type, metadata, step_payload) VALUES (0, 14, $p0, $p1)", M(1, V(1, 1_793_952_175)), new byte[] { 1 });
            Insert(db, "INSERT INTO steps(idx, step_type, metadata, step_payload) VALUES (1, 15, $p0, $p1)", M(1, V(1, 1_793_952_175)), new byte[] { 1 });
            Insert(db, "INSERT INTO steps(idx, step_type, metadata, step_payload) VALUES (2, 15, $p0, $p1)", M(1, V(1, 1_793_952_179)), new byte[] { 1 });
            Insert(db, "INSERT INTO gen_metadata(idx, data) VALUES (0, $p0)", Gen("c-0", 9_517, 0, 319, 276, null, "gemini-3.8-flash-n"));
            Insert(db, "INSERT INTO gen_metadata(idx, data) VALUES (1, $p0)", Gen("c-1", 9_962, 0, 120, 86, null, "gemini-3.8-flash-n"));
        });

        var r = new AntigravityCollector().ReadNew(new SourceFileState(path, 0, false));

        Assert.Equal(0, r.MalformedLines);
        Assert.Equal([1_793_952_175L, 1_793_952_179L], r.Events.Select(e => e.OccurredAt.ToUnixTimeSeconds()));
    }

    [Fact]
    public void Row_without_usage_is_counted_as_malformed()
    {
        var path = Db("bad", db => Insert(db, "INSERT INTO gen_metadata(idx, data) VALUES (0, $p0)", M(3, V(1, 1))));
        var r = new AntigravityCollector().ReadNew(new SourceFileState(path, 0, false));
        Assert.Empty(r.Events);
        Assert.Equal(1, r.MalformedLines);
        Assert.Equal(1, r.NewState.ReadOffset);
    }

    [Fact]
    public void Call_with_zero_tokens_is_skipped()
    {
        var path = Db("zero", db => Insert(db, "INSERT INTO gen_metadata(idx, data) VALUES (0, $p0)", Gen("z-0", 0, 0, 0, 0, 1_790_855_284)));
        var r = new AntigravityCollector().ReadNew(new SourceFileState(path, 0, false));
        Assert.Empty(r.Events);
        Assert.Equal(0, r.MalformedLines);
        Assert.Equal(1, r.NewState.ReadOffset);
    }

    [Fact]
    public void Non_database_file_keeps_position()
    {
        var path = Path.Combine(_dir, "junk.db");
        File.WriteAllText(path, "not sqlite");
        var state = new SourceFileState(path, 3, false);
        Assert.Same(state, new AntigravityCollector().ReadNew(state).NewState);
    }

    public void Dispose()
    {
        SqliteConnection.ClearAllPools();
        Directory.Delete(_dir, recursive: true);
    }
}
