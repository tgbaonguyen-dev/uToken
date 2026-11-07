using UToken.Core.Models;

namespace UToken.Core.Pricing;

public interface IPriceBook
{
    string Version { get; }

    /// <summary>Giá cơ bản hiện hành của model (không xét thời điểm hay bậc context).</summary>
    Price? Find(Provider provider, string model);

    /// <summary>Giá áp cho một event cụ thể: có thể phụ thuộc thời điểm và kích thước context.</summary>
    Price? PriceFor(UsageEvent e) => Find(e.Provider, e.Model);
}

/// <summary>
/// Bảng giá để cứng, dùng làm dự phòng khi models.dev chưa tải được hoặc không có model (xem TieredPriceBook).
/// Giá USD trên 1 triệu token, ƯỚC TÍNH theo giá API công bố; nhóm cập nhật khi giá đổi và tăng Version.
/// Khớp model theo tiền tố dài nhất, nên "claude-opus-5-5" dùng giá của "claude-opus".
/// </summary>
public sealed class StaticPriceBook : IPriceBook
{
    public static readonly StaticPriceBook Default = new("static-2026-11-06",
    [
        // Codex. codex-auto-review là model của phiên tự duyệt (guardian_review): tạm tính bằng giá gpt-5 (giả định).
        (Provider.Codex, "gpt-5", new Price(1.75m, 0.175m, null, 14.00m)),
        (Provider.Codex, "codex-auto-review", new Price(1.75m, 0.175m, null, 14.00m)),
        (Provider.Codex, "gpt-4.1", new Price(2.00m, 0.50m, null, 8.00m)),
        (Provider.Codex, "o3", new Price(2.00m, 0.50m, null, 8.00m)),
        (Provider.Codex, "o4-mini", new Price(1.10m, 0.275m, null, 4.40m)),
        // Claude Code. Cache write tính theo mức 5 phút.
        (Provider.ClaudeCode, "claude-opus", new Price(5.00m, 0.50m, 6.25m, 25.00m)),
        (Provider.ClaudeCode, "claude-sonnet", new Price(3.00m, 0.30m, 3.75m, 15.00m)),
        (Provider.ClaudeCode, "claude-haiku", new Price(1.00m, 0.10m, 1.25m, 5.00m)),
        // Antigravity: log chưa có token (OQ-10), giữ giá để tính khi có dữ liệu.
        (Provider.Antigravity, "gemini", new Price(1.25m, 0.31m, null, 10.00m)),
    ]);

    private readonly (Provider Provider, string Prefix, Price Price)[] _rows;

    public StaticPriceBook(string version, IEnumerable<(Provider, string, Price)> rows)
    {
        Version = version;
        _rows = rows.OrderByDescending(r => r.Item2.Length).ToArray();
    }

    public string Version { get; }

    public Price? Find(Provider provider, string model)
    {
        foreach (var r in _rows)
            if (r.Provider == provider && model.StartsWith(r.Prefix, StringComparison.OrdinalIgnoreCase))
                return r.Price;
        return null;
    }
}

public static class PriceBookExtensions
{
    /// <summary>Chi phí micro-USD của một event; null khi model chưa có giá ("thiếu giá").</summary>
    public static long? CostMicro(this IPriceBook book, UsageEvent e) =>
        book.PriceFor(e) is { } p ? CostCalculator.CostMicroUsd(e, p) : null;
}
