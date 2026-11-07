using System.Diagnostics;
using System.Globalization;
using UToken.Core.Pricing;

namespace UToken.Storage;

/// <summary>Tải bảng giá models.dev và lưu vào SQLite. Gọi lúc khởi động và khoảng 1 lần/ngày.</summary>
public static class PricingSync
{
    /// <summary>Trả về số dòng giá mới/đổi. Lỗi mạng thì ném ra; giá cũ trong SQLite vẫn dùng được.</summary>
    public static Task<int> RunAsync(HttpClient http, SqliteStore store, DateTimeOffset now) =>
        RunAsync(http, store, now, CancellationToken.None, Task.Delay);

    public static Task<int> RunAsync(HttpClient http, SqliteStore store, DateTimeOffset now, CancellationToken ct) =>
        RunAsync(http, store, now, ct, Task.Delay);

    public static async Task<int> RunAsync(
        HttpClient http,
        SqliteStore store,
        DateTimeOffset now,
        CancellationToken ct,
        Func<TimeSpan, CancellationToken, Task> delay)
    {
        var prices = await FetchWithRetryAsync(http, delay, ct);
        if (prices.Count == 0) throw new InvalidDataException("models.dev trả về bảng giá rỗng");
        return store.SavePrices(prices, VersionFor(now), now);
    }

    public static string VersionFor(DateTimeOffset now) =>
        "models.dev@" + now.UtcDateTime.ToString("O", CultureInfo.InvariantCulture);

    private static async Task<IReadOnlyList<ModelPrice>> FetchWithRetryAsync(
        HttpClient http,
        Func<TimeSpan, CancellationToken, Task> delay,
        CancellationToken ct)
    {
        for (var attempt = 1; ; attempt++)
        {
            ct.ThrowIfCancellationRequested();
            try
            {
                return await ModelsDevCatalog.FetchAsync(http, ct);
            }
            catch (HttpRequestException ex) when (attempt < 3)
            {
                await WaitBeforeRetryAsync(ex, attempt, delay, ct);
            }
            catch (TaskCanceledException ex) when (!ct.IsCancellationRequested && attempt < 3)
            {
                await WaitBeforeRetryAsync(ex, attempt, delay, ct);
            }
        }
    }

    private static async Task WaitBeforeRetryAsync(
        Exception error,
        int attempt,
        Func<TimeSpan, CancellationToken, Task> delay,
        CancellationToken ct)
    {
        var wait = attempt == 1 ? TimeSpan.FromSeconds(1) : TimeSpan.FromSeconds(3);
        Trace.TraceWarning(
            "Không tải được bảng giá models.dev; attempt={0}, next_delay_seconds={1}, error_type={2}, error={3}",
            attempt,
            wait.TotalSeconds,
            error.GetType().Name,
            error.Message);
        await delay(wait, ct);
    }
}
