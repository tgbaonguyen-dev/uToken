using System.Text.Json;

namespace UToken.Core.Pricing;

/// <summary>Bảng giá một model của một hãng (vendor theo models.dev: anthropic, openai, google).</summary>
public sealed record ModelPrice(string Vendor, string Model, PriceSchedule Schedule);

/// <summary>
/// Đọc bảng giá từ models.dev (https://models.dev/api.json).
/// Giá ở đó đã tính theo USD/1 triệu token, đúng đơn vị của <see cref="Price"/>.
/// </summary>
public static class ModelsDevCatalog
{
    public const string Url = "https://models.dev/api.json";

    /// <summary>Chỉ lấy các hãng mà collector có thể gặp; models.dev có hơn 200 provider.</summary>
    public static readonly IReadOnlyList<string> Vendors = ["anthropic", "openai", "google"];

    public static async Task<IReadOnlyList<ModelPrice>> FetchAsync(HttpClient http, CancellationToken ct = default)
    {
        await using var s = await http.GetStreamAsync(Url, ct);
        using var doc = await JsonDocument.ParseAsync(s, cancellationToken: ct);
        return Parse(doc.RootElement);
    }

    public static IReadOnlyList<ModelPrice> Parse(string json)
    {
        using var doc = JsonDocument.Parse(json);
        return Parse(doc.RootElement);
    }

    /// <summary>
    /// Bỏ qua model không có giá input/output (vd. model sinh ảnh).
    /// Thiếu cache_read → tính như input thường; thiếu cache_write → để null (CostCalculator dùng giá input).
    /// Chỉ đọc bậc giá theo kích thước context; bỏ qua các loại bậc chưa biết.
    /// </summary>
    public static IReadOnlyList<ModelPrice> Parse(JsonElement root)
    {
        var result = new List<ModelPrice>();
        foreach (var vendor in Vendors)
        {
            if (!root.TryGetProperty(vendor, out var p) || !p.TryGetProperty("models", out var models)) continue;
            foreach (var m in models.EnumerateObject())
            {
                if (!m.Value.TryGetProperty("cost", out var cost)) continue;
                var input = Num(cost, "input");
                var output = Num(cost, "output");
                if (input is null || output is null) continue;
                var price = new Price(input.Value, Num(cost, "cache_read") ?? input.Value, Num(cost, "cache_write"), output.Value);
                result.Add(new ModelPrice(vendor, m.Name, new PriceSchedule(price, ParseTiers(cost))));
            }
        }
        return result;
    }

    private static decimal? Num(JsonElement obj, string name) =>
        obj.TryGetProperty(name, out var v) && v.ValueKind == JsonValueKind.Number ? v.GetDecimal() : null;

    private static IReadOnlyList<PriceTier> ParseTiers(JsonElement cost)
    {
        if (!cost.TryGetProperty("tiers", out var tiers) || tiers.ValueKind != JsonValueKind.Array) return [];

        var result = new List<PriceTier>();
        var contextSizes = new HashSet<long>();
        foreach (var value in tiers.EnumerateArray())
        {
            if (value.ValueKind != JsonValueKind.Object) continue;
            if (!value.TryGetProperty("tier", out var tier) || tier.ValueKind != JsonValueKind.Object) continue;
            if (!tier.TryGetProperty("type", out var type) || type.ValueKind != JsonValueKind.String || type.GetString() != "context") continue;
            if (!tier.TryGetProperty("size", out var size) || size.ValueKind != JsonValueKind.Number || !size.TryGetInt64(out var contextAbove)) continue;
            var input = Num(value, "input");
            var output = Num(value, "output");
            if (input is null || output is null) continue;
            if (!contextSizes.Add(contextAbove)) continue;
            var price = new Price(input.Value, Num(value, "cache_read") ?? input.Value, Num(value, "cache_write"), output.Value);
            result.Add(new PriceTier(contextAbove, price));
        }
        return result.OrderBy(value => value.ContextAbove).ToArray();
    }
}
