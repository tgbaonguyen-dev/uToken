using System.Text.Json.Nodes;
using Json.Schema;
using UToken.Collectors.ClaudeCode;
using UToken.Collectors.Codex;
using UToken.Storage;
using Xunit;

namespace UToken.Engine.Tests;

/// <summary>Chạy trọn luồng trên một thư mục home giả dựng từ fixture.</summary>
public sealed class EngineTests : IDisposable
{
    private static readonly TimeZoneInfo Utc7 = TimeZoneInfo.CreateCustomTimeZone("UTC+7", TimeSpan.FromHours(7), "UTC+7", "UTC+7");
    private readonly DirectoryInfo _home = Directory.CreateTempSubdirectory("utoken-home-");
    private readonly string _db;
    private readonly FakeClock _clock = new(DateTimeOffset.Parse("2026-11-06T01:00:00Z")); // 08:00 ngày 06/11 giờ UTC+7

    public EngineTests()
    {
        _db = Path.Combine(_home.FullName, "utoken.db");
        Copy("codex/task-signals.jsonl", ".codex/sessions/2026/11/05/rollout-2026-11-05T18-00-00-main.jsonl");
        Copy("codex/guardian.jsonl", ".codex/sessions/2026/11/05/rollout-2026-11-05T18-00-40-guard.jsonl");
        Copy("claude_code/task-signals.jsonl", ".claude/projects/-work-demo-app/c-100.jsonl");
    }

    private void Copy(string fixture, string rel)
    {
        var dest = Path.Combine(_home.FullName, rel);
        Directory.CreateDirectory(Path.GetDirectoryName(dest)!);
        File.Copy(Path.Combine(AppContext.BaseDirectory, "fixtures", fixture), dest);
    }

    private (UsageEngine, SqliteStore) NewEngine()
    {
        var store = new SqliteStore(_db);
        return (new UsageEngine(store, [new CodexCollector(), new ClaudeCodeCollector()], _home.FullName, Utc7, clock: _clock), store);
    }

    [Fact] // Nghiệm thu FR-DATA-001: đọc lại cùng log nhiều lần, số liệu không bị cộng trùng
    public void Scanning_twice_does_not_double_count()
    {
        var (engine, store) = NewEngine();
        using (store)
        {
            var first = engine.Run();
            Assert.Equal(3, first.Scan.FilesRead);
            Assert.Equal(9, first.Scan.NewEvents); // Codex 3 + guardian 1 + Claude 5
            Assert.Empty(first.Scan.Errors);
            var day1 = engine.BuildDaily(new DateOnly(2026, 11, 6));

            var second = engine.Run();
            Assert.Equal(0, second.Scan.FilesRead);
            Assert.Equal(0, second.Scan.NewEvents);
            Assert.Empty(second.ChangedDaily); // không đổi gì thì không cần ghi Firestore
            Assert.Equal(day1.Totals, engine.BuildDaily(new DateOnly(2026, 11, 6)).Totals);
        }

        // Mở lại DB (khởi động lại app) vẫn không cộng trùng.
        var (engine2, store2) = NewEngine();
        using (store2) Assert.Equal(0, engine2.Scan().NewEvents);
    }

    [Fact]
    public void Sync_after_sources_scan_and_restart_builds_historical_summaries()
    {
        var (scanner, scannedStore) = NewEngine();
        using (scannedStore) Assert.Equal(9, scanner.Scan().NewEvents);
        _clock.Advance(TimeSpan.FromDays(7));
        var (engine, store) = NewEngine();
        using (store)
        {
            var result = engine.Run();
            Assert.Equal(0, result.Scan.NewEvents);
            Assert.Contains(store.GetDirtyDaily(), d => d.Date == "2026-11-05");
            Assert.Contains(store.GetDirtyDaily(), d => d.Date == "2026-11-06");
            Assert.Empty(engine.Run().ChangedDaily);
        }
    }

    [Fact]
    public void Daily_documents_follow_local_dates()
    {
        var (engine, store) = NewEngine();
        using (store)
        {
            engine.Run();
            // Codex lúc 18:00Z ngày 05/11 = 01:00 ngày 06/11 giờ UTC+7; Claude lúc 10:00Z = 17:00 ngày 05/11.
            var nov6 = engine.BuildDaily(new DateOnly(2026, 11, 6));
            var nov5 = engine.BuildDaily(new DateOnly(2026, 11, 5));
            Assert.Equal(4, nov6.Totals.Requests);
            Assert.Equal(1, nov6.Totals.SideRequests);
            Assert.Equal(1, nov6.TasksByState.VerifiedSuccess);
            Assert.Equal(1, nov6.TasksByState.VerifiedFailure);
            Assert.Equal(5, nov5.Totals.Requests);
            Assert.Equal(1, nov5.TasksByState.VerifiedSuccess);
            Assert.Equal(1, nov5.TasksByState.LikelyFailure);
            Assert.Single(store.GetProjects());
        }
    }

    [Fact]
    public void Appended_log_is_read_incrementally()
    {
        var (engine, store) = NewEngine();
        using (store)
        {
            engine.Run();
            var path = Path.Combine(_home.FullName, ".claude/projects/-work-demo-app/c-100.jsonl");
            File.AppendAllText(path,
                """{"type":"assistant","sessionId":"c-100","cwd":"/work/demo-app","isSidechain":false,"timestamp":"2026-11-05T10:31:00.000Z","message":{"id":"msg_e","model":"claude-opus-5-5","usage":{"input_tokens":5,"cache_read_input_tokens":12000,"cache_creation_input_tokens":0,"output_tokens":20}}}""" + "\n");
            var again = engine.Run();
            Assert.Equal(1, again.Scan.FilesRead);
            Assert.Equal(1, again.Scan.NewEvents);
            Assert.Contains(again.ChangedDaily, d => d.Date == "2026-11-05");
        }
    }

    [Fact] // Giá models.dev lưu trong SQLite được dùng cho daily và còn nguyên khi mở lại app
    public void Catalog_prices_drive_daily_cost_and_persist()
    {
        var (engine, store) = NewEngine();
        using (store)
        {
            engine.Run();
            var before = engine.BuildDaily(new DateOnly(2026, 11, 5));
            Assert.False(engine.PricesAreFresh());

            // Claude rẻ đi một nửa so với bảng để cứng.
            var catalog = new[]
            {
                new Core.Pricing.ModelPrice("anthropic", "claude-opus-5-5",
                    new Core.Pricing.PriceSchedule(new Core.Pricing.Price(2.5m, 0.25m, 3.125m, 12.5m), [])),
            };
            Assert.Equal(1, engine.ApplyPriceCatalog(catalog));
            Assert.True(engine.PricesAreFresh());
            var after = engine.BuildDaily(new DateOnly(2026, 11, 5));
            Assert.StartsWith("models.dev@", after.PricingVersion);
            var claudeKey = after.ByKey.Keys.Single(k => k.StartsWith("claude_code|claude-opus-5-5|"));
            Assert.InRange(after.ByKey[claudeKey].CostMicro!.Value, before.ByKey[claudeKey].CostMicro!.Value / 2 - 1, before.ByKey[claudeKey].CostMicro!.Value / 2 + 1);
            // Haiku (phiên phụ) không có trong catalog giả → vẫn tính bằng giá dự phòng.
            Assert.NotNull(after.ByKey.Single(k => k.Key.Contains("claude-haiku")).Value.CostMicro);
        }
        var (engine2, store2) = NewEngine();
        using (store2) Assert.StartsWith("models.dev@", engine2.Prices.Version);
    }

    [Fact] // Hợp đồng với mobile: JSON phải khớp contracts/firestore/*.schema.json
    public void Output_matches_firestore_contracts()
    {
        var (engine, store) = NewEngine();
        using (store)
        {
            var snap = engine.Run();
            var dailySchema = JsonSchema.FromFile(Path.Combine(AppContext.BaseDirectory, "schemas", "daily.schema.json"));
            var effSchema = JsonSchema.FromFile(Path.Combine(AppContext.BaseDirectory, "schemas", "efficiency.schema.json"));

            foreach (var d in snap.ChangedDaily)
                AssertValid(dailySchema, UsageEngine.ToJson(d));
            AssertValid(effSchema, UsageEngine.ToJson(snap.Efficiency));
            Assert.NotEmpty(snap.Efficiency.Setups);

            // Bộ kiểm tra phải bắt được document sai (thiếu trường, sai schema_version).
            Assert.False(dailySchema.Evaluate(JsonNode.Parse("""{"date":"2026-11-06","schema_version":1}""")).IsValid);
            var broken = JsonNode.Parse(UsageEngine.ToJson(snap.Efficiency))!;
            broken["setups"]![0]!["verdict"] = "best";
            Assert.False(effSchema.Evaluate(broken).IsValid);
        }
    }

    private static void AssertValid(JsonSchema schema, string json)
    {
        var result = schema.Evaluate(JsonNode.Parse(json), new EvaluationOptions { OutputFormat = OutputFormat.List });
        var errors = (result.Details ?? []).Where(d => d.Errors is { Count: > 0 })
            .SelectMany(d => d.Errors!.Select(e => $"{d.InstanceLocation}: {e.Value}"));
        Assert.True(result.IsValid, string.Join("\n", errors) + "\n" + json);
    }

    public void Dispose()
    {
        Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools();
        _home.Delete(true);
    }

    private sealed class FakeClock(DateTimeOffset now) : TimeProvider
    {
        public void Advance(TimeSpan duration) => now += duration;
        public override DateTimeOffset GetUtcNow() => now;
    }
}
