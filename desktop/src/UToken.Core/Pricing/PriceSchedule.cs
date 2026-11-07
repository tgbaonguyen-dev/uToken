namespace UToken.Core.Pricing;

/// <summary>Giá áp dụng khi context lớn hơn ngưỡng chỉ định.</summary>
public sealed record PriceTier(long ContextAbove, Price Price);

/// <summary>Bảng giá cơ bản và các bậc giá theo kích thước context.</summary>
public sealed class PriceSchedule : IEquatable<PriceSchedule>
{
    private readonly PriceTier[] _tiers;
    private readonly IReadOnlyList<PriceTier> _tiersView;

    public PriceSchedule(Price @base, IReadOnlyList<PriceTier> tiers)
    {
        if (tiers.Select(tier => tier.ContextAbove).Distinct().Count() != tiers.Count)
            throw new ArgumentException("Các bậc giá không được trùng ngưỡng context.", nameof(tiers));

        Base = @base;
        _tiers = tiers.OrderBy(tier => tier.ContextAbove).ToArray();
        _tiersView = Array.AsReadOnly(_tiers);
    }

    public Price Base { get; }

    public IReadOnlyList<PriceTier> Tiers => _tiersView;

    /// <summary>Chọn bậc có ngưỡng lớn nhất nhưng vẫn nhỏ hơn số token context.</summary>
    public Price For(long contextTokens)
    {
        var result = Base;
        foreach (var tier in _tiers)
        {
            if (contextTokens <= tier.ContextAbove) break;
            result = tier.Price;
        }
        return result;
    }

    public bool Equals(PriceSchedule? other) =>
        other is not null && Base == other.Base && _tiers.SequenceEqual(other._tiers);

    public override bool Equals(object? obj) => obj is PriceSchedule other && Equals(other);

    public override int GetHashCode()
    {
        var hash = new HashCode();
        hash.Add(Base);
        foreach (var tier in _tiers) hash.Add(tier);
        return hash.ToHashCode();
    }

    public static bool operator ==(PriceSchedule? left, PriceSchedule? right) => Equals(left, right);

    public static bool operator !=(PriceSchedule? left, PriceSchedule? right) => !Equals(left, right);
}
