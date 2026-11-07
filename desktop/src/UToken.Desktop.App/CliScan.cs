using UToken.Engine;

namespace UToken.Desktop.App;

/// <summary>
/// Chạy core không cần giao diện:
///   dotnet run --project src/UToken.Desktop.App -- --scan [--db đường-dẫn.db] [--out thư-mục] [--update-prices]
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
                Console.WriteLine(changed is null ? "Giá: còn mới, không tải lại" : $"Giá: đã tải models.dev, {changed} model đổi giá");
            }
            catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or System.Text.Json.JsonException or InvalidDataException)
            {
                Console.WriteLine($"Giá: không tải được models.dev ({ex.GetType().Name}), dùng giá đã lưu");
            }
            Console.WriteLine($"Bảng giá: {engine.Prices.Version}");

            var started = DateTime.UtcNow;
            var snap = engine.Run();
            var s = snap.Scan;
            var counts = store.Counts();

            Console.WriteLine($"SQLite: {db}");
            Console.WriteLine($"Quét: {s.FilesRead} file đọc, {s.FilesUnchanged} file không đổi, {s.NewEvents} event mới, " +
                              $"{s.TurnsUpdated} turn cập nhật, {s.MalformedLines} dòng lỗi, {(DateTime.UtcNow - started).TotalMilliseconds:F0} ms");
            Console.WriteLine($"Tổng trong SQLite: {counts.Events} event, {counts.Turns} turn, {counts.Files} file");
            foreach (var e in s.Errors) Console.WriteLine($"  lỗi: {e}");
            Console.WriteLine($"Daily thay đổi: {string.Join(", ", snap.ChangedDaily.Select(d => d.Date))}");

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
                Console.WriteLine($"Đã ghi JSON vào {Path.GetFullPath(outDir)}");
            }
        }
        return 0;
    }

    private static string? Arg(string[] args, string name)
    {
        var i = Array.IndexOf(args, name);
        return i >= 0 && i + 1 < args.Length ? args[i + 1] : null;
    }
}
