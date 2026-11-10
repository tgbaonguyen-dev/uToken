using Microsoft.Data.Sqlite;
using UToken.Core.Models;

namespace UToken.Collectors.Antigravity;

/// <summary>
/// Antigravity (CLI và IDE) lưu mỗi hội thoại thành một SQLite <c>conversations/&lt;id&gt;.db</c>.
/// Mỗi dòng bảng <c>gen_metadata</c> là một lần gọi model, cột <c>data</c> là protobuf không có tài liệu.
/// Bản đồ trường dưới đây suy ra từ dữ liệu thật ngày 10/11/2026 (xem docs/antigravity-format.md):
/// <code>
/// 1.19      model (chuỗi, ví dụ gemini-3.8-flash-n)
/// 1.4.2     input không cache        1.4.5   cache read
/// 1.4.3     output (gồm thinking)    1.4.9   thinking
/// 1.4.11    response id (duy nhất)   1.9.4.1 thời điểm, giây Unix (IDE; CLI: xem ModelStepTimes)
/// </code>
/// Chỉ đọc các trường số và tên model ở trên; không đọc bảng <c>steps</c> (nội dung hội thoại).
/// </summary>
public sealed class AntigravityCollector : ILogCollector
{
    public Provider Provider => Provider.Antigravity;
    public string ParserVersion => "antigravity-1";

    /// <summary>
    /// Thư mục dữ liệu của các bản Antigravity, theo thứ tự ưu tiên. Kiểm tra trên máy thật 10/11/2026:
    /// hội thoại nằm trong antigravity-cli (CLI) hoặc antigravity-ide (IDE); ~/.gemini/antigravity chỉ có
    /// conversation_summaries.db (chỉ mục, app_data_dir = "antigravity-cli") và conversations/ rỗng.
    /// Không phải log Gemini CLI.
    /// </summary>
    public static readonly string[] AppDirectories = ["antigravity-cli", "antigravity-ide", "antigravity"];

    public static IEnumerable<string> ConversationDirectories(string home) =>
        AppDirectories.Select(app => Path.Combine(home, ".gemini", app, "conversations"));

    public IEnumerable<string> DiscoverFiles(string home)
    {
        foreach (var dir in ConversationDirectories(home))
        {
            if (!Directory.Exists(dir)) continue;
            foreach (var f in Directory.EnumerateFiles(dir, "*.db")) yield return f;
        }
    }

    /// <summary>ReadOffset = idx đã đọc lớn nhất + 1 trong gen_metadata (bảng chỉ thêm dòng).</summary>
    public CollectResult ReadNew(SourceFileState state)
    {
        var events = new List<UsageEvent>();
        int malformed = 0;
        long next = state.ReadOffset;
        var session = Path.GetFileNameWithoutExtension(state.Path);
        try
        {
            using var db = new SqliteConnection(new SqliteConnectionStringBuilder
            {
                DataSource = state.Path, Mode = SqliteOpenMode.ReadOnly, Pooling = false,
            }.ToString());
            db.Open();
            var stepTimes = ModelStepTimes(db);
            using var cmd = db.CreateCommand();
            cmd.CommandText = "SELECT idx, data FROM gen_metadata WHERE idx >= $from ORDER BY idx";
            cmd.Parameters.AddWithValue("$from", state.ReadOffset);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                long idx = reader.GetInt64(0);
                next = Math.Max(next, idx + 1);
                if (reader.IsDBNull(1)) { malformed++; continue; }
                var fallback = idx < stepTimes.Count ? stepTimes[(int)idx] : stepTimes.LastOrDefault();
                var e = Parse(session, idx, (byte[])reader[1], fallback);
                if (e is null) malformed++;
                else if (e.Input > 0 || e.Output > 0) events.Add(e); // 0 token: lượt bị hủy, không phải request
            }
        }
        catch (SqliteException)
        {
            // Đang bị app khóa hoặc chưa phải DB hợp lệ: giữ vị trí, lần quét sau đọc lại.
            return CollectResult.Empty(state);
        }
        return new CollectResult(events, [], new Dictionary<string, string>(), malformed,
            state with { ReadOffset = next, Completed = false });
    }

    /// <summary>
    /// Bản CLI không ghi thời điểm trong gen_metadata. Lượt trả lời của model là step_type 15, theo đúng
    /// thứ tự dòng gen_metadata; thời điểm ở steps.metadata trường 1.1 (giây Unix). Chỉ đọc cột metadata
    /// (khoảng 30 byte dấu thời gian), không đọc step_payload.
    /// </summary>
    private static List<long> ModelStepTimes(SqliteConnection db)
    {
        var times = new List<long>();
        using var cmd = db.CreateCommand();
        cmd.CommandText = "SELECT metadata FROM steps WHERE step_type = 15 ORDER BY idx";
        try
        {
            using var r = cmd.ExecuteReader();
            while (r.Read())
                if (!r.IsDBNull(0) && Proto.Message((byte[])r[0], 1) is { } ts && Proto.Varint(ts, 1) is { } sec) times.Add(sec);
        }
        catch (SqliteException) { }
        catch (InvalidDataException) { }
        return times;
    }

    internal static UsageEvent? Parse(string session, long idx, byte[] data, long? fallbackSeconds = null)
    {
        try
        {
            var root = Proto.Message(data, 1);
            if (root is null) return null;
            var usage = Proto.Message(root, 4);
            if (usage is null) return null;
            long fresh = Proto.Varint(usage, 2) ?? 0, cached = Proto.Varint(usage, 5) ?? 0;
            long output = Proto.Varint(usage, 3) ?? 0;
            long? thinking = Proto.Varint(usage, 9);
            var model = Proto.String(root, 19) ?? "antigravity-unknown";
            var id = Proto.String(usage, 11) ?? $"{session}:{idx}";
            var seconds = (Proto.Message(root, 9) is { } t1 && Proto.Message(t1, 4) is { } t2 ? Proto.Varint(t2, 1) : null)
                ?? (fallbackSeconds > 0 ? fallbackSeconds : null);
            if (seconds is null) return null;
            if (thinking > output) thinking = output;
            return new UsageEvent(Provider.Antigravity, id, session, null, model, null,
                DateTimeOffset.FromUnixTimeSeconds(seconds.Value),
                fresh + cached, cached, 0, output, thinking, null, false, null);
        }
        catch (Exception ex) when (ex is IndexOutOfRangeException or ArgumentOutOfRangeException or InvalidDataException)
        {
            return null;
        }
    }

    /// <summary>Đọc protobuf tối thiểu theo wire format; chỉ lấy trường đầu tiên khớp số hiệu.</summary>
    internal static class Proto
    {
        private static ulong ReadVarint(ReadOnlySpan<byte> b, ref int i)
        {
            ulong r = 0; int shift = 0;
            while (true)
            {
                if (shift > 63) throw new InvalidDataException("varint too long");
                byte c = b[i++]; r |= (ulong)(c & 0x7F) << shift; shift += 7;
                if (c < 0x80) return r;
            }
        }

        /// <summary>Trả (wireType, value-varint, bytes) của trường đầu tiên có số hiệu <paramref name="field"/>.</summary>
        private static (int Wire, ulong Value, byte[]? Bytes)? Find(byte[] b, int field)
        {
            int i = 0;
            while (i < b.Length)
            {
                ulong key = ReadVarint(b, ref i);
                int f = (int)(key >> 3), wire = (int)(key & 7);
                switch (wire)
                {
                    case 0: { var v = ReadVarint(b, ref i); if (f == field) return (0, v, null); break; }
                    case 1: i += 8; break;
                    case 5: i += 4; break;
                    case 2:
                    {
                        int n = checked((int)ReadVarint(b, ref i));
                        if (n < 0 || i + n > b.Length) throw new InvalidDataException("length out of range");
                        if (f == field) return (2, 0, b.AsSpan(i, n).ToArray());
                        i += n; break;
                    }
                    default: throw new InvalidDataException($"wire type {wire}");
                }
            }
            return null;
        }

        public static byte[]? Message(byte[] b, int field) => Find(b, field) is { Wire: 2 } x ? x.Bytes : null;
        public static long? Varint(byte[] b, int field) => Find(b, field) is { Wire: 0 } x ? (long)x.Value : null;
        public static string? String(byte[] b, int field) =>
            Find(b, field) is { Wire: 2, Bytes: { } s } ? System.Text.Encoding.UTF8.GetString(s) : null;
    }
}
