using System.Globalization;
using System.Text.Json;
using UToken.Core.Aggregation;
using UToken.Core.Efficiency;
using UToken.Desktop.App.Services;
using UToken.Engine;
using UToken.Insights;
using UToken.Storage;

namespace UToken.Desktop.App;

/// <summary>
/// Chạy core không cần giao diện:
///   dotnet run --project src/UToken.Desktop.App -- --scan [--db đường-dẫn.db] [--out thư-mục] [--update-prices]
///   ... -- --judge [--dry-run]: in catalog chỉ số của brief; có key thì gọi AI review thật
///   và in InsightDoc. --dry-run chỉ in brief + prompt, không gọi AI.
/// In tóm tắt và JSON của daily hôm nay + efficiency/current. Có --out thì ghi thêm file JSON vào thư mục đó.
/// </summary>
internal static class CliScan
{
    public static int Run(string[] args)
    {
        var settings = AppSettings.Load();
        var db = Arg(args, "--db") ?? settings.DatabasePath;
        var outDir = Arg(args, "--out");

        var (engine, store) = EngineFactory.Create(
            db,
            settings.Collectors.Enabled,
            AppSettings.ExpandHome(settings.Collectors.CodexHome),
            AppSettings.ExpandHome(settings.Collectors.ClaudeHome));
        using (store)
        {
            try
            {
                using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(20) };
                http.DefaultRequestHeaders.UserAgent.ParseAdd("uToken-desktop");
                var maxAge = args.Contains("--update-prices") ? TimeSpan.Zero : (TimeSpan?)null;
                var changed = engine.UpdatePricesAsync(http, maxAge).GetAwaiter().GetResult();
                Console.WriteLine(changed is null ? "Prices: up to date, not downloaded" : $"Prices: downloaded models.dev, {changed} models changed");
            }
            catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or System.Text.Json.JsonException or InvalidDataException)
            {
                Console.WriteLine($"Prices: could not download models.dev ({ex.GetType().Name}), using saved prices");
            }
            Console.WriteLine($"Price list: {engine.Prices.Version}");

            var started = DateTime.UtcNow;
            var snap = engine.Run();
            var s = snap.Scan;
            var counts = store.Counts();

            Console.WriteLine($"SQLite: {db}");
            Console.WriteLine($"Scan: {s.FilesRead} files read, {s.FilesUnchanged} unchanged, {s.NewEvents} new events, " +
                              $"{s.TurnsUpdated} turns updated, {s.MalformedLines} malformed lines, {(DateTime.UtcNow - started).TotalMilliseconds:F0} ms");
            Console.WriteLine($"SQLite totals: {counts.Events} events, {counts.Turns} turns, {counts.Files} files");
            foreach (var e in s.Errors) Console.WriteLine($"  error: {e}");
            Console.WriteLine($"Changed daily: {string.Join(", ", snap.ChangedDaily.Select(d => d.Date))}");

            var today = engine.BuildDaily(engine.Today);
            Console.WriteLine();
            Console.WriteLine($"== users/{{uid}}/daily/{today.Date}");
            Console.WriteLine(UsageEngine.ToJson(today, indented: true));
            Console.WriteLine();
            Console.WriteLine("== users/{uid}/efficiency/current");
            Console.WriteLine(UsageEngine.ToJson(snap.Efficiency, indented: true));

            if (outDir is not null)
            {
                Directory.CreateDirectory(outDir);
                foreach (var d in snap.ChangedDaily.Append(today).DistinctBy(d => d.Date))
                    File.WriteAllText(Path.Combine(outDir, $"daily-{d.Date}.json"), UsageEngine.ToJson(d, indented: true));
                File.WriteAllText(Path.Combine(outDir, "efficiency-current.json"), UsageEngine.ToJson(snap.Efficiency, indented: true));
                Console.WriteLine($"Wrote JSON to {Path.GetFullPath(outDir)}");
            }
            if (args.Contains("--judge"))
                return RunJudge(args, engine, store, snap.Efficiency);
        }
        return 0;
    }

    private static int RunJudge(
        string[] args, UsageEngine engine, SqliteStore store, EfficiencyDoc efficiency)
    {
        var from = engine.Today.AddDays(-29).ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        var daily = store.GetDailyJsonSince(from)
            .Select(json => JsonSerializer.Deserialize<DailyDoc>(json)!)
            .ToList();
        var brief = JudgeBriefBuilder.Build(efficiency, daily);
        var pretty = new JsonSerializerOptions { WriteIndented = true };
        Console.WriteLine();
        Console.WriteLine($"== AI review catalog ({brief.PeriodStart} → {brief.PeriodEnd}, " +
                          $"{brief.Chats} chat)");
        foreach (var (id, metric) in brief.Catalog)
            Console.WriteLine($"  {id} · {metric.Label}: {metric.Value}");
        if (args.Contains("--dry-run"))
        {
            Console.WriteLine();
            Console.WriteLine("== System prompt");
            Console.WriteLine(JudgePrompt.For(UToken.Desktop.App.Localization.Loc.AiLanguage));
            Console.WriteLine("== Brief JSON (data that will be sent)");
            Console.WriteLine(JsonSerializer.Serialize(brief, pretty));
            return 0;
        }

        var settings = LoadJudgeSettings();
        var key = new ApiKeyStore(AppSettings.DataDirectory).Load()
            .GetValueOrDefault(settings.Provider);
        if (string.IsNullOrEmpty(key))
        {
            Console.WriteLine(
                $"No API key for {settings.Provider}: add one in Settings → AI review.");
            return 2;
        }
        using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(60) };
        var model = JudgeModels.Create(settings.Provider, settings.Model, key, http);
        var doc = new JudgeService().RunAsync(brief, model, CancellationToken.None)
            .GetAwaiter().GetResult();
        Console.WriteLine();
        Console.WriteLine(
            $"== users/{{uid}}/insights/current ({settings.Provider} · {settings.Model})");
        Console.WriteLine(JsonSerializer.Serialize(doc, pretty));
        return doc.Status == "failed" ? 1 : 0;
    }

    private static JudgeProviderSettings LoadJudgeSettings()
    {
        var path = Path.Combine(AppSettings.DataDirectory, "judge-state.json");
        try
        {
            if (File.Exists(path)
                && JsonSerializer.Deserialize<JudgeState>(File.ReadAllText(path)) is { } state)
                return state.Settings;
        }
        catch (JsonException) { }
        return JudgeDefaults.For(JudgeProviders.Google);
    }

    private static string? Arg(string[] args, string name)
    {
        var i = Array.IndexOf(args, name);
        return i >= 0 && i + 1 < args.Length ? args[i + 1] : null;
    }
}
