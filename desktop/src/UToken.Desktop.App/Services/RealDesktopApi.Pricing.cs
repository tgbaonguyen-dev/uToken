using System.Globalization;
using System.Text.Json;
using UToken.Core.Models;
using UToken.Core.Pricing;
using UToken.Desktop.App.Models;

namespace UToken.Desktop.App.Services;

/// <summary>Cập nhật bảng giá models.dev (tối đa ~1 lần/ngày). Chỉ là một GET tới models.dev, không gửi dữ liệu người dùng.</summary>
public sealed partial class RealDesktopApi
{
    private readonly SemaphoreSlim _priceUpdateGate = new(1, 1);

    private static readonly Lazy<HttpClient> Http = new(() =>
    {
        var client = new HttpClient { Timeout = TimeSpan.FromSeconds(20) };
        client.DefaultRequestHeaders.UserAgent.ParseAdd("uToken-desktop");
        return client;
    });

    /// <summary>Thay HttpClient trong test; null = client mặc định.</summary>
    public HttpClient? PriceHttpClient { get; init; }

    public async Task<PricingData> GetPricingAsync(CancellationToken ct)
    {
        // Không chờ mạng: App đã cập nhật giá nền lúc khởi động và trước mỗi Sync.
        return await WithStoreAsync(() =>
        {
            var latest = _store.LoadAllPrices()
                .GroupBy(entry => (entry.Vendor, entry.Model))
                .Select(group => group.MaxBy(entry => entry.EffectiveFrom)!)
                .OrderBy(entry => VendorOrder(entry.Vendor))
                .ThenBy(entry => entry.Model, StringComparer.Ordinal)
                .ToArray();

            var rows = latest.SelectMany(entry =>
                new[] { ToPricingRow(entry.Vendor, entry.Model, "Base rate", entry.Schedule.Base) }
                    .Concat(entry.Schedule.Tiers.Select(tier => ToPricingRow(
                        entry.Vendor,
                        entry.Model,
                        $"Context > {FormatContext(tier.ContextAbove)}",
                        tier.Price))))
                .ToArray();

            return new PricingData(
                Prices.Version,
                latest.Length == 0 ? null : latest.Max(entry => entry.EffectiveFrom),
                rows);
        }, ct);
    }

    /// <summary>
    /// Tải giá mới nếu giá đang dùng đã cũ. Gọi phía sau (không chặn giao diện); lỗi mạng chỉ ghi log, giá cũ vẫn dùng.
    /// Trả về true khi đã áp bảng giá mới.
    /// </summary>
    public async Task<bool> UpdatePricesAsync(CancellationToken ct = default)
    {
        await _priceUpdateGate.WaitAsync(ct);
        try
        {
            if (await WithStoreAsync(() => _engine.PricesAreFresh(), ct)) return false;
            // Gọi mạng ngoài khóa SQLite; chỉ phần lưu đi qua khóa.
            var catalog = await ModelsDevCatalog.FetchAsync(PriceHttpClient ?? Http.Value, ct);
            int changed = await WithStoreAsync(() => _engine.ApplyPriceCatalog(catalog), ct);
            DataChanged();
            _localSettings?.Record($"Prices updated from models.dev: {catalog.Count} models, {changed} changed");
            return true;
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or JsonException or InvalidDataException)
        {
            _localSettings?.Record("Price update failed: " + ex.GetType().Name);
            return false;
        }
        finally
        {
            _priceUpdateGate.Release();
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

    private static PricingRow ToPricingRow(string vendor, string model, string rate, Price price) =>
        new(vendor, model, rate, price.InputPerMTok, price.CachedPerMTok, price.CacheWritePerMTok, price.OutputPerMTok);

    private static int VendorOrder(string vendor) => vendor switch
    {
        "anthropic" => 0,
        "openai" => 1,
        "google" => 2,
        _ => 3,
    };

    private static string FormatContext(long value)
    {
        if (value >= 1_000_000)
            return (value / 1_000_000m).ToString("0.##", CultureInfo.InvariantCulture) + "M";
        if (value >= 1_000)
            return (value / 1_000m).ToString("0.##", CultureInfo.InvariantCulture) + "K";
        return value.ToString(CultureInfo.InvariantCulture);
    }
}
