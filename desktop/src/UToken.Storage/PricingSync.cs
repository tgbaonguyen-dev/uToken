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
        var prices = await FetchAsync(http, ct, delay);
        if (prices.Count == 0) throw new InvalidDataException("models.dev returned an empty price list");
        return store.SavePrices(prices, VersionFor(now), now);
    }

    public static string VersionFor(DateTimeOffset now) =>
        "models.dev@" + now.UtcDateTime.ToString("O", CultureInfo.InvariantCulture);

    /// <summary>
    /// Tải bảng giá models.dev, thử tối đa <paramref name="attempts"/> lần (chờ 1 giây rồi 3 giây) khi lỗi mạng,
    /// lỗi 5xx/408/429 hoặc hết thời gian chờ; lỗi 4xx khác ném ngay vì thử lại cũng vô ích.
    /// Người gọi hủy <paramref name="ct"/> thì dừng ngay. <paramref name="delay"/> = null dùng Task.Delay (test truyền hàm không chờ).
    /// </summary>
    public static async Task<IReadOnlyList<ModelPrice>> FetchAsync(
        HttpClient http,
        CancellationToken ct = default,
        Func<TimeSpan, CancellationToken, Task>? delay = null,
        int attempts = 3)
    {
        delay ??= Task.Delay;
        for (var attempt = 1; ; attempt++)
        {
            ct.ThrowIfCancellationRequested();
            try
            {
                return await ModelsDevCatalog.FetchAsync(http, ct);
            }
            catch (HttpRequestException ex) when (attempt < attempts && IsTransient(ex))
            {
                await WaitBeforeRetryAsync(ex, attempt, delay, ct);
            }
            catch (TaskCanceledException ex) when (!ct.IsCancellationRequested && attempt < attempts)
            {
                await WaitBeforeRetryAsync(ex, attempt, delay, ct);
            }
        }
    }

    /// <summary>Không có mã HTTP (lỗi mạng, DNS) hoặc mã đáng thử lại.</summary>
    private static bool IsTransient(HttpRequestException ex) =>
        ex.StatusCode is null or >= System.Net.HttpStatusCode.InternalServerError
            or System.Net.HttpStatusCode.RequestTimeout or System.Net.HttpStatusCode.TooManyRequests;

    private static async Task WaitBeforeRetryAsync(
        Exception error,
        int attempt,
        Func<TimeSpan, CancellationToken, Task> delay,
        CancellationToken ct)
    {
        var wait = attempt == 1 ? TimeSpan.FromSeconds(1) : TimeSpan.FromSeconds(3);
        Trace.TraceWarning(
            "Could not download models.dev prices; attempt={0}, next_delay_seconds={1}, error_type={2}, error={3}",
            attempt,
            wait.TotalSeconds,
            error.GetType().Name,
            error.Message);
        await delay(wait, ct);
    }
}
