using System.Text.Json;
using UToken.Collectors.Common;
using UToken.Core.Models;

namespace UToken.Collectors.Codex;

/// <summary>Parser log Codex (SRS §10.4). Input của Codex đã gồm cached; Output đã gồm reasoning.</summary>
public sealed class CodexCollector : ILogCollector
{
    public const string ParserVersion = "codex-1";
    public Provider Provider => Provider.Codex;

    public IEnumerable<string> DiscoverFiles(string home)
    {
        var dir = Path.Combine(home, ".codex", "sessions");
        if (!Directory.Exists(dir)) yield break;
        foreach (var f in Directory.EnumerateFiles(dir, "rollout-*.jsonl", SearchOption.AllDirectories)) yield return f;
        foreach (var f in Directory.EnumerateFiles(dir, "rollout-*.jsonl.zst", SearchOption.AllDirectories)) yield return f;
    }

    public (IReadOnlyList<UsageEvent> Events, SourceFileState NewState) ReadNew(SourceFileState state)
    {
        if (state.Completed) return (Array.Empty<UsageEvent>(), state);
        var parser = new Parser(Path.GetFileNameWithoutExtension(state.Path));
        long newOffset = state.ReadOffset;

        if (state.Path.EndsWith(".zst", StringComparison.OrdinalIgnoreCase))
        {
            foreach (var line in LineReader.ReadZstdLines(state.Path)) parser.Feed(line);
            return (parser.Events, state with { Completed = true });
        }
        foreach (var line in LineReader.ReadCompleteLines(state.Path, state.ReadOffset, o => newOffset = o))
            parser.Feed(line);
        return (parser.Events, state with { ReadOffset = newOffset });
    }

    /// <summary>Tách riêng để test bằng fixture mà không cần file thật.</summary>
    public sealed class Parser(string fallbackSessionId)
    {
        private string _sessionId = fallbackSessionId;
        private string _model = "unknown";
        private string? _effort;
        private bool _isSide;
        public List<UsageEvent> Events { get; } = [];

        public void Feed(string line)
        {
            using var doc = JsonDocument.Parse(line);
            var root = doc.RootElement;
            if (!root.TryGetProperty("type", out var typeEl)) return;
            var payload = root.TryGetProperty("payload", out var p) ? p : default;

            switch (typeEl.GetString())
            {
                case "session_meta":
                    if (payload.TryGetProperty("id", out var id)) _sessionId = id.GetString() ?? _sessionId;
                    _isSide = payload.TryGetProperty("thread_source", out var ts) && ts.GetString() == "guardian_review"
                              || payload.TryGetProperty("source", out var src) && src.ValueKind == JsonValueKind.Object && src.TryGetProperty("subagent", out _);
                    break;
                case "turn_context":
                    if (payload.TryGetProperty("model", out var m)) _model = m.GetString() ?? _model;
                    _effort = payload.TryGetProperty("effort", out var e) ? e.GetString() : null;
                    break;
                case "token_usage_record":
                    var u = payload.GetProperty("usage");
                    Events.Add(new UsageEvent(
                        Provider.Codex,
                        payload.GetProperty("response_id").GetString()!,
                        _sessionId,
                        payload.TryGetProperty("turn_id", out var t) ? t.GetString() : null,
                        _model, _effort,
                        root.TryGetProperty("timestamp", out var tsEl) && tsEl.TryGetDateTimeOffset(out var at) ? at : DateTimeOffset.UtcNow,
                        Input: u.GetProperty("input_tokens").GetInt64(),
                        Cached: u.GetProperty("cached_input_tokens").GetInt64(),
                        CacheWrite: u.TryGetProperty("cache_write_input_tokens", out var cw) ? cw.GetInt64() : 0,
                        Output: u.GetProperty("output_tokens").GetInt64(),
                        Thinking: u.TryGetProperty("reasoning_output_tokens", out var r) ? r.GetInt64() : null,
                        DurationMs: null,
                        IsSideSession: _isSide,
                        ProjectKey: null));
                    break;
                // TODO(FR-ANLY-003): item_completed (CommandExecution.exit_code, FileChange), task_complete.error, turn_aborted → TaskSignals
            }
        }
    }
}
