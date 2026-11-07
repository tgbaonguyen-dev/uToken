using UToken.Core.Models;

namespace UToken.Core.Pricing;

/// <summary>Một phiên bản giá của một model (một dòng bảng pricing kèm các bậc context).</summary>
public sealed record PriceEntry(string Vendor, string Model, DateTimeOffset EffectiveFrom, string PricingVersion, PriceSchedule Schedule);

/// <summary>
/// Bảng giá lấy từ models.dev (đã lưu trong SQLite), tra theo:
/// 1) hãng + id model đã chuẩn hóa (<see cref="ModelIdNormalizer"/>),
/// 2) phiên bản giá có hiệu lực tại thời điểm event (event trước lần tải đầu tiên dùng bản cũ nhất),
/// 3) bậc giá theo kích thước context = input đã chuẩn hóa của event.
/// Model không có trên models.dev (ví dụ codex-auto-review) dùng <paramref name="fallback"/>.
/// </summary>
public sealed class TieredPriceBook(IEnumerable<PriceEntry> entries, IPriceBook fallback) : IPriceBook
{
    private readonly Dictionary<(string Vendor, string Model), PriceEntry[]> _byModel = entries
        .GroupBy(e => (e.Vendor, e.Model))
        .ToDictionary(g => g.Key, g => g.OrderBy(e => e.EffectiveFrom).ToArray());

    private readonly Dictionary<(Provider, string), PriceEntry[]?> _lookupCache = [];
    private readonly Lock _cacheLock = new();

    public IPriceBook Fallback { get; } = fallback;

    /// <summary>Số model có giá từ models.dev.</summary>
    public int ModelCount => _byModel.Count;

    /// <summary>Lần tải giá gần nhất (null nếu chưa tải lần nào).</summary>
    public DateTimeOffset? LastFetchedAt { get; } = entries.Any() ? entries.Max(e => e.EffectiveFrom) : null;

    /// <summary>Phiên bản models.dev mới nhất; chưa tải lần nào thì dùng phiên bản của bảng dự phòng.</summary>
    public string Version => _byModel.Count == 0
        ? fallback.Version
        : _byModel.Values.SelectMany(v => v).MaxBy(e => e.EffectiveFrom)!.PricingVersion;

    public Price? Find(Provider provider, string model) =>
        Versions(provider, model) is { } v ? v[^1].Schedule.Base : fallback.Find(provider, model);

    public Price? PriceFor(UsageEvent e)
    {
        if (Versions(e.Provider, e.Model) is not { } versions) return fallback.PriceFor(e);
        // Bản mới nhất có hiệu lực ≤ thời điểm event; event cũ hơn mọi bản thì dùng bản cũ nhất.
        var entry = versions[0];
        foreach (var v in versions)
        {
            if (v.EffectiveFrom > e.OccurredAt) break;
            entry = v;
        }
        return entry.Schedule.For(e.Input);
    }

    /// <summary>Có giá trên models.dev cho model này không (để hiển thị "giá ước tính" và chẩn đoán).</summary>
    public bool HasCatalogPrice(Provider provider, string model) => Versions(provider, model) is not null;

    private PriceEntry[]? Versions(Provider provider, string model)
    {
        lock (_cacheLock)
        {
            if (_lookupCache.TryGetValue((provider, model), out var cached)) return cached;
            PriceEntry[]? found = null;
            if (ModelIdNormalizer.VendorOf(provider, model) is { } vendor)
                foreach (var id in ModelIdNormalizer.Candidates(model))
                    if (_byModel.TryGetValue((vendor, id), out found)) break;
            _lookupCache[(provider, model)] = found;
            return found;
        }
    }
}
