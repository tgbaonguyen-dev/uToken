using System.Text.Json;
using UToken.Collectors.Common;
using UToken.Core.Models;

namespace UToken.Collectors.Codex;

/// <summary>
/// Parser log Codex (SRS §10.4). Input của Codex đã gồm cached; Output đã gồm reasoning.
/// Tín hiệu task: task_started / task_complete (error, duration_ms), turn_aborted,
/// item_completed (CommandExecution: exit_code, status; FileChange; McpToolCall).
/// </summary>
/// <param name="codexHome">Thư mục ~/.codex; null thì lấy theo thư mục home truyền vào DiscoverFiles.</param>
public sealed class CodexCollector(string? codexHome = null) : ILogCollector
{
    public const string Version = "codex-2";
    public string ParserVersion => Version;
    public Provider Provider => Provider.Codex;

    public IEnumerable<string> DiscoverFiles(string home)
    {
        var dir = Path.Combine(codexHome ?? Path.Combine(home, ".codex"), "sessions");
        if (!Directory.Exists(dir)) yield break;
        foreach (var f in Directory.EnumerateFiles(dir, "rollout-*.jsonl", SearchOption.AllDirectories)) yield return f;
        foreach (var f in Directory.EnumerateFiles(dir, "rollout-*.jsonl.zst", SearchOption.AllDirectories)) yield return f;
    }

    public CollectResult ReadNew(SourceFileState state)
    {
        if (state.Completed) return CollectResult.Empty(state);
        var name = Path.GetFileName(state.Path);
        var parser = new Parser(name[..name.IndexOf('.')], ParserState.Load<Context>(state.ContextJson));

        if (state.Path.EndsWith(".zst", StringComparison.OrdinalIgnoreCase))
        {
            foreach (var line in LineReader.ReadZstdLines(state.Path)) parser.Feed(line);
            parser.CloseOpenTurn(); // file nén là log cũ, không còn ghi tiếp
            return parser.Result(state with { Completed = true, ContextJson = null });
        }

        long newOffset = state.ReadOffset;
        foreach (var line in LineReader.ReadCompleteLines(state.Path, state.ReadOffset, o => newOffset = o))
            parser.Feed(line);
        return parser.Result(state with { ReadOffset = newOffset, ContextJson = ParserState.Save(parser.Ctx) });
    }

    /// <summary>Ngữ cảnh lưu giữa các lần đọc.</summary>
    public sealed class Context
    {
        public string? SessionId { get; set; }
        public string Model { get; set; } = "unknown";
        public string? Effort { get; set; }
        public bool IsSide { get; set; }
        public string? ProjectKey { get; set; }
        public TurnAccumulator? Turn { get; set; }
    }

    /// <summary>Tách riêng để test bằng fixture mà không cần file thật.</summary>
    public sealed class Parser(string fallbackSessionId, Context? ctx = null)
    {
        public Context Ctx { get; } = ctx ?? new Context();
        public List<UsageEvent> Events { get; } = [];
        public int MalformedLines { get; private set; }
        private readonly List<TurnAccumulator> _touched = [];
        private readonly Dictionary<string, string> _projects = [];

        private string SessionId => Ctx.SessionId ?? fallbackSessionId;

        /// <summary>Turn đã thay đổi trong lần đọc này (kể cả turn đang mở).</summary>
        public IReadOnlyList<TurnRecord> Turns =>
            _touched.Select(t => t.ToRecord(Provider.Codex, SessionId, Ctx.IsSide, Ctx.ProjectKey)).ToList();

        public CollectResult Result(SourceFileState s) => new(Events, Turns, _projects, MalformedLines, s);

        public void Feed(string line)
        {
            JsonDocument doc;
            try { doc = JsonDocument.Parse(line); }
            catch (JsonException) { MalformedLines++; return; }

            using (doc)
            {
                var root = doc.RootElement;
                if (root.ValueKind != JsonValueKind.Object || !root.TryGetProperty("type", out var typeEl)) return;
                var payload = root.TryGetProperty("payload", out var p) && p.ValueKind == JsonValueKind.Object ? p : default;
                var at = root.TryGetProperty("timestamp", out var tsEl) && tsEl.TryGetDateTimeOffset(out var t) ? t : (DateTimeOffset?)null;

                switch (typeEl.GetString())
                {
                    case "session_meta":
                        if (Json.Str(payload, "id") is { } id) Ctx.SessionId = id;
                        Ctx.IsSide = Json.Str(payload, "thread_source") == "guardian_review"
                                     || payload.TryGetProperty("source", out var src) && src.ValueKind == JsonValueKind.Object && src.TryGetProperty("subagent", out _);
                        SetProject(Json.Str(payload, "cwd"));
                        break;

                    case "turn_context":
                        if (Json.Str(payload, "model") is { } m) Ctx.Model = m;
                        Ctx.Effort = Json.Str(payload, "effort");
                        SetProject(Json.Str(payload, "cwd"));
                        break;

                    case "token_usage_record":
                        AddUsage(payload, at);
                        break;

                    case "event_msg":
                        OnEventMsg(payload, at);
                        break;
                }
            }
        }

        private void AddUsage(JsonElement payload, DateTimeOffset? at)
        {
            if (!payload.TryGetProperty("usage", out var u) || Json.Str(payload, "response_id") is not { } responseId)
            {
                MalformedLines++;
                return;
            }
            var turnId = Json.Str(payload, "turn_id");
            var when = at ?? DateTimeOffset.UtcNow;
            if (turnId is not null) TurnFor(turnId, when).Seen(when);

            Events.Add(new UsageEvent(
                Provider.Codex, responseId, SessionId, turnId, Ctx.Model, Ctx.Effort, when,
                Input: Json.Long(u, "input_tokens"),
                Cached: Json.Long(u, "cached_input_tokens"),
                CacheWrite: Json.Long(u, "cache_write_input_tokens"),
                Output: Json.Long(u, "output_tokens"),
                Thinking: Json.LongOrNull(u, "reasoning_output_tokens"),
                DurationMs: null,
                IsSideSession: Ctx.IsSide,
                ProjectKey: Ctx.ProjectKey));
        }

        private void OnEventMsg(JsonElement payload, DateTimeOffset? at)
        {
            var turnId = Json.Str(payload, "turn_id");
            if (turnId is null || at is not { } when) return;

            switch (Json.Str(payload, "type"))
            {
                case "task_started":
                    TurnFor(turnId, when);
                    break;

                case "item_completed":
                    if (!payload.TryGetProperty("item", out var item)) return;
                    var turn = TurnFor(turnId, when);
                    turn.Seen(when);
                    switch (Json.Str(item, "type"))
                    {
                        case "CommandExecution":
                            long? exit = Json.LongOrNull(item, "exit_code");
                            bool failed = Json.Str(item, "status") == "failed" || exit is not null and not 0;
                            turn.Command(failed, TestCommandDetector.IsTestOrBuild(CommandText(item)));
                            break;
                        case "McpToolCall":
                            turn.Command(Json.Str(item, "status") == "failed", false);
                            break;
                        case "FileChange":
                            if (Json.Str(item, "status") == "completed") turn.FileChanged();
                            break;
                    }
                    break;

                case "task_complete":
                    var done = TurnFor(turnId, when);
                    if (payload.TryGetProperty("error", out var err) && err.ValueKind is not (JsonValueKind.Null or JsonValueKind.Undefined))
                        done.TurnError = true;
                    done.DurationMs = Json.LongOrNull(payload, "duration_ms");
                    done.Close(when);
                    break;

                case "turn_aborted":
                    var aborted = TurnFor(turnId, when);
                    aborted.Aborted = true;
                    aborted.Close(when);
                    break;
            }
        }

        /// <summary>Lệnh chỉ dùng trong bộ nhớ để nhận diện test/build, không lưu.</summary>
        private static string? CommandText(JsonElement item)
        {
            if (!item.TryGetProperty("command", out var c)) return null;
            return c.ValueKind switch
            {
                JsonValueKind.String => c.GetString(),
                JsonValueKind.Array => string.Join(' ', c.EnumerateArray().Where(x => x.ValueKind == JsonValueKind.String).Select(x => x.GetString())),
                _ => null,
            };
        }

        private TurnAccumulator TurnFor(string turnId, DateTimeOffset at)
        {
            if (Ctx.Turn is { } cur && cur.TurnId == turnId) return Touch(cur);
            if (Ctx.Turn is { Closed: false } prev) Touch(prev).Close(prev.LastSeenAt);
            Ctx.Turn = TurnAccumulator.Start(turnId, at);
            return Touch(Ctx.Turn);
        }

        private TurnAccumulator Touch(TurnAccumulator t)
        {
            if (!Ctx.IsSide && !_touched.Contains(t)) _touched.Add(t);
            return t;
        }

        public void CloseOpenTurn()
        {
            if (Ctx.Turn is { Closed: false } t) Touch(t).Close(t.LastSeenAt);
        }

        private void SetProject(string? cwd)
        {
            if (ProjectKey.FromPath(cwd) is not { } key) return;
            Ctx.ProjectKey = key;
            _projects[key] = ProjectKey.DisplayName(cwd!);
        }
    }
}
