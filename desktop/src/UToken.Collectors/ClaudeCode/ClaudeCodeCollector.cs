using System.Text.Json;
using UToken.Collectors.Common;
using UToken.Core.Models;

namespace UToken.Collectors.ClaudeCode;

/// <summary>
/// Parser log Claude Code (SRS §10.4). input_tokens KHÔNG gồm cache → input chuẩn = input + cache_read + cache_creation.
/// Một phản hồi bị ghi thành nhiều dòng cùng usage → gộp theo message.id.
/// </summary>
public sealed class ClaudeCodeCollector : ILogCollector
{
    public const string ParserVersion = "claude-1";
    public Provider Provider => Provider.ClaudeCode;

    public IEnumerable<string> DiscoverFiles(string home)
    {
        var dir = Path.Combine(home, ".claude", "projects");
        return Directory.Exists(dir) ? Directory.EnumerateFiles(dir, "*.jsonl", SearchOption.AllDirectories) : [];
    }

    public (IReadOnlyList<UsageEvent> Events, SourceFileState NewState) ReadNew(SourceFileState state)
    {
        var parser = new Parser();
        long newOffset = state.ReadOffset;
        foreach (var line in LineReader.ReadCompleteLines(state.Path, state.ReadOffset, o => newOffset = o))
            parser.Feed(line);
        return (parser.Events, state with { ReadOffset = newOffset });
    }

    public sealed class Parser
    {
        private readonly HashSet<string> _seen = [];
        public List<UsageEvent> Events { get; } = [];

        public void Feed(string line)
        {
            using var doc = JsonDocument.Parse(line);
            var root = doc.RootElement;
            if (!root.TryGetProperty("type", out var t) || t.GetString() != "assistant") return;
            if (!root.TryGetProperty("message", out var msg) || !msg.TryGetProperty("usage", out var u)) return;
            var id = msg.GetProperty("id").GetString()!;
            if (!_seen.Add(id)) return; // dòng trùng của cùng một phản hồi

            long input = u.GetProperty("input_tokens").GetInt64();
            long read = u.TryGetProperty("cache_read_input_tokens", out var cr) ? cr.GetInt64() : 0;
            long write = u.TryGetProperty("cache_creation_input_tokens", out var cc) ? cc.GetInt64() : 0;
            long? thinking = u.TryGetProperty("output_tokens_details", out var od) && od.TryGetProperty("thinking_tokens", out var th)
                ? th.GetInt64() : null;

            Events.Add(new UsageEvent(
                Provider.ClaudeCode, id,
                root.TryGetProperty("sessionId", out var s) ? s.GetString()! : "unknown",
                null,
                msg.TryGetProperty("model", out var m) ? m.GetString()! : "unknown",
                root.TryGetProperty("effort", out var ef) && ef.ValueKind == JsonValueKind.String ? ef.GetString() : null,
                root.TryGetProperty("timestamp", out var ts) && ts.TryGetDateTimeOffset(out var at) ? at : DateTimeOffset.UtcNow,
                Input: input + read + write,
                Cached: read,
                CacheWrite: write,
                Output: u.GetProperty("output_tokens").GetInt64(),
                Thinking: thinking,
                DurationMs: null,
                IsSideSession: root.TryGetProperty("isSidechain", out var sc) && sc.ValueKind == JsonValueKind.True,
                ProjectKey: null));
        }
    }
}
