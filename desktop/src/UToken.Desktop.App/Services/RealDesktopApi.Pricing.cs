using System.Text.Json;
using UToken.Core.Models;
using UToken.Core.Pricing;

namespace UToken.Desktop.App.Services;

/// <summary>Cập nhật bảng giá models.dev (tối đa ~1 lần/ngày). Chỉ là một GET tới models.dev, không gửi dữ liệu người dùng.</summary>
public sealed partial class RealDesktopApi
{
    private static readonly Lazy<HttpClient> Http = new(() =>
    {
        var client = new HttpClient { Timeout = TimeSpan.FromSeconds(20) };
        client.DefaultRequestHeaders.UserAgent.ParseAdd("uToken-desktop");
        return client;
    });

    /// <summary>Thay HttpClient trong test; null = client mặc định.</summary>
    public HttpClient? PriceHttpClient { get; init; }

    /// <summary>
    /// Tải giá mới nếu giá đang dùng đã cũ. Gọi phía sau (không chặn giao diện); lỗi mạng chỉ ghi log, giá cũ vẫn dùng.
    /// Trả về true khi đã áp bảng giá mới.
    /// </summary>
    public async Task<bool> UpdatePricesAsync(CancellationToken ct = default)
    {
        if (await WithStoreAsync(() => _engine.PricesAreFresh(), ct)) return false;
        try
        {
            // Gọi mạng ngoài khóa SQLite; chỉ phần lưu đi qua khóa.
            var catalog = await ModelsDevCatalog.FetchAsync(PriceHttpClient ?? Http.Value, ct);
            int changed = await WithStoreAsync(() => _engine.ApplyPriceCatalog(catalog), ct);
            _localSettings?.Record($"Prices updated from models.dev: {catalog.Count} models, {changed} changed");
            return true;
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or JsonException or InvalidDataException)
        {
            _localSettings?.Record("Price update failed: " + ex.GetType().Name);
            return false;
        }
    }

    /// <summary>Model xuất hiện trong 30 ngày qua nhưng không có giá models.dev (đang dùng giá dự phòng hoặc thiếu giá).</summary>
    private IReadOnlyList<string> ModelsWithoutCatalogPrice()
    {
        if (Prices is not TieredPriceBook book) return [];
        return _store.GetEvents(Now.AddDays(-30), Now.AddSeconds(1))
            .Select(e => (e.Provider, e.Model)).Distinct()
            .Where(m => !book.HasCatalogPrice(m.Provider, m.Model))
            .Select(m => book.Fallback.Find(m.Provider, m.Model) is null ? $"{m.Model} (no price)" : $"{m.Model} (fallback price)")
            .Order(StringComparer.Ordinal)
            .ToList();
    }
}
