using System.Text.Json;
using UToken.Collectors.Common;
using UToken.Core.Models;

namespace UToken.Collectors.ClaudeCode;

/// <summary>
/// Parser log Claude Code (SRS §10.4). input_tokens KHÔNG gồm cache → input chuẩn = input + cache_read + cache_creation.
/// Một phản hồi bị ghi thành nhiều dòng cùng usage → gộp theo message.id.
/// Tín hiệu task: mỗi prompt của người dùng mở một turn; tool_use (Bash, Edit, Write…) và tool_result.is_error.
/// </summary>
/// <param name="claudeHome">Thư mục ~/.claude; null thì lấy theo thư mục home truyền vào DiscoverFiles.</param>
public sealed class ClaudeCodeCollector(string? claudeHome = null) : ILogCollector
{
    public const string Version = "claude-3";
    public string ParserVersion => Version;
    public Provider Provider => Provider.ClaudeCode;

    private static readonly HashSet<string> ShellTools = ["Bash", "bash"];
    private static readonly HashSet<string> FileTools = ["Edit", "Write", "MultiEdit", "NotebookEdit"];

    public IEnumerable<string> DiscoverFiles(string home)
    {
        var dir = Path.Combine(claudeHome ?? Path.Combine(home, ".claude"), "projects");
        return Directory.Exists(dir) ? Directory.EnumerateFiles(dir, "*.jsonl", SearchOption.AllDirectories) : [];
    }

    public CollectResult ReadNew(SourceFileState state)
    {
        var parser = new Parser(ParserState.Load<Context>(state.ContextJson));
        long newOffset = state.ReadOffset;
        foreach (var line in LineReader.ReadCompleteLines(state.Path, state.ReadOffset, o => newOffset = o))
            parser.Feed(line);
        return parser.Result(state with { ReadOffset = newOffset, ContextJson = ParserState.Save(parser.Ctx) });
    }

    public sealed class Context
    {
        public string? SessionId { get; set; }
        public string? ProjectKey { get; set; }
        public TurnAccumulator? Turn { get; set; }

        /// <summary>tool_use id → loại ("test", "shell", "file", "tool") để xử lý tool_result tương ứng.</summary>
        public Dictionary<string, string> PendingTools { get; set; } = [];
    }

    public sealed class Parser(Context? ctx = null)
    {
        public Context Ctx { get; } = ctx ?? new Context();
        public List<UsageEvent> Events { get; } = [];
        public int MalformedLines { get; private set; }
        private readonly HashSet<string> _seen = [];
        private readonly List<TurnAccumulator> _touched = [];
        private readonly Dictionary<string, string> _projects = [];

        public IReadOnlyList<TurnRecord> Turns =>
            _touched.Select(t => t.ToRecord(Provider.ClaudeCode, Ctx.SessionId ?? "unknown", false, Ctx.ProjectKey)).ToList();

        public CollectResult Result(SourceFileState s) => new(Events, Turns, _projects, MalformedLines, s);

        public void Feed(string line)
        {
            JsonDocument doc;
            try { doc = JsonDocument.Parse(line); }
            catch (JsonException) { MalformedLines++; return; }

            using (doc)
            {
                var root = doc.RootElement;
                if (root.ValueKind != JsonValueKind.Object) return;
                var type = Json.Str(root, "type");
                if (type is not ("user" or "assistant")) return;

                if (Json.Str(root, "sessionId") is { } sid) Ctx.SessionId = sid;
                SetProject(Json.Str(root, "cwd"));
                var at = root.TryGetProperty("timestamp", out var ts) && ts.TryGetDateTimeOffset(out var t) ? t : (DateTimeOffset?)null;
                bool side = Json.True(root, "isSidechain");
                if (!root.TryGetProperty("message", out var msg) || msg.ValueKind != JsonValueKind.Object) return;

                if (type == "assistant") OnAssistant(root, msg, at, side);
                else if (!side) OnUser(root, msg, at);
            }
        }

        private void OnAssistant(JsonElement root, JsonElement msg, DateTimeOffset? at, bool side)
        {
            var when = at ?? DateTimeOffset.UtcNow;
            if (!side && Ctx.Turn is { } turn) Touch(turn).Seen(when);

            // tool_use có thể nằm ở bất kỳ dòng lặp nào của cùng message.id, nên xử lý trước khi bỏ trùng.
            if (!side && msg.TryGetProperty("content", out var content) && content.ValueKind == JsonValueKind.Array)
            {
                foreach (var block in content.EnumerateArray())
                {
                    if (Json.Str(block, "type") != "tool_use" || Json.Str(block, "id") is not { } toolId) continue;
                    var name = Json.Str(block, "name") ?? "";
                    Ctx.PendingTools[toolId] =
                        ShellTools.Contains(name)
                            ? TestCommandDetector.IsTestOrBuild(block.TryGetProperty("input", out var inp) ? Json.Str(inp, "command") : null) ? "test" : "shell"
                            : FileTools.Contains(name) ? "file" : "tool";
                }
            }

            if (!msg.TryGetProperty("usage", out var u) || u.ValueKind != JsonValueKind.Object) return;
            if (Json.Str(msg, "id") is not { } id) { MalformedLines++; return; }
            if (!_seen.Add(id)) return; // dòng trùng của cùng một phản hồi
            // "<synthetic>" là tin nhắn Claude Code tự tạo (báo lỗi, ngắt lượt), không phải lần gọi model.
            if (Json.Str(msg, "model") == "<synthetic>") return;

            long input = Json.Long(u, "input_tokens");
            long read = Json.Long(u, "cache_read_input_tokens");
            long write = Json.Long(u, "cache_creation_input_tokens");
            long? thinking = u.TryGetProperty("output_tokens_details", out var od) ? Json.LongOrNull(od, "thinking_tokens") : null;

            Events.Add(new UsageEvent(
                Provider.ClaudeCode, id,
                Ctx.SessionId ?? "unknown",
                side ? null : Ctx.Turn?.TurnId,
                Json.Str(msg, "model") ?? "unknown",
                Json.Str(root, "effort"),
                when,
                Input: input + read + write,
                Cached: read,
                CacheWrite: write,
                Output: Json.Long(u, "output_tokens"),
                Thinking: thinking,
                DurationMs: null,
                IsSideSession: side,
                ProjectKey: Ctx.ProjectKey)
            {
                IsError = Json.True(root, "isApiErrorMessage"),
            });
        }

        private void OnUser(JsonElement root, JsonElement msg, DateTimeOffset? at)
        {
            if (Json.True(root, "isMeta") || Json.True(root, "isCompactSummary") || at is not { } when) return;
            if (!msg.TryGetProperty("content", out var content)) return;

            bool hasToolResult = false, hasText = content.ValueKind == JsonValueKind.String;
            if (content.ValueKind == JsonValueKind.Array)
            {
                foreach (var block in content.EnumerateArray())
                {
                    switch (Json.Str(block, "type"))
                    {
                        case "tool_result":
                            hasToolResult = true;
                            OnToolResult(block, when);
                            break;
                        case "text":
                            hasText = true;
                            break;
                    }
                }
            }

            // Prompt mới của người dùng (không phải kết quả tool) mở turn mới.
            if (hasText && !hasToolResult)
            {
                if (Ctx.Turn is { Closed: false } prev) Touch(prev).Close(prev.LastSeenAt);
                Ctx.Turn = TurnAccumulator.Start(Json.Str(root, "uuid") ?? $"t-{when.ToUnixTimeMilliseconds()}", when);
                Ctx.PendingTools.Clear();
                Touch(Ctx.Turn);
            }
        }

        private void OnToolResult(JsonElement block, DateTimeOffset when)
        {
            if (Ctx.Turn is not { } turn) return;
            Touch(turn).Seen(when);
            var toolId = Json.Str(block, "tool_use_id");
            var kind = toolId is not null && Ctx.PendingTools.Remove(toolId, out var k) ? k : "tool";
            bool failed = Json.True(block, "is_error");

            turn.Command(failed, kind == "test");
            if (kind == "file" && !failed) turn.FileChanged();
        }

        private TurnAccumulator Touch(TurnAccumulator t)
        {
            if (!_touched.Contains(t)) _touched.Add(t);
            return t;
        }

        private void SetProject(string? cwd)
        {
            if (ProjectKey.FromPath(cwd) is not { } key || key == Ctx.ProjectKey) return;
            Ctx.ProjectKey = key;
            _projects[key] = ProjectKey.DisplayName(cwd!);
        }
    }
}
