namespace UToken.Core.Efficiency;

/// <summary>Công thức thống kê SRS §10.1 (Miller 2024).</summary>
public static class Stats
{
    public const double Z95 = 1.96;
    public const double ZPower80 = 0.84;

    public static double StandardError(double p, int n) =>
        n <= 0 ? double.NaN : Math.Sqrt(p * (1 - p) / n);

    /// <summary>Khoảng Wilson 95% cho tỷ lệ, dùng khi n nhỏ.</summary>
    public static (double Low, double High) Wilson(int successes, int n, double z = Z95)
    {
        if (n <= 0) return (double.NaN, double.NaN);
        double p = (double)successes / n, z2 = z * z;
        double denom = 1 + z2 / n;
        double centre = (p + z2 / (2 * n)) / denom;
        double half = z * Math.Sqrt(p * (1 - p) / n + z2 / (4.0 * n * n)) / denom;
        return (centre - half, centre + half);
    }

    public static double DiffStandardError(double seA, double seB) => Math.Sqrt(seA * seA + seB * seB);

    /// <summary>Chênh lệch nhỏ nhất phát hiện được (95% tin cậy, 80% power).</summary>
    public static double Mde(double seDiff) => (Z95 + ZPower80) * seDiff;

    /// <summary>Số task cần cho mỗi setup để phát hiện chênh lệch <paramref name="mde"/>.</summary>
    public static int RequiredN(double p, double mde) =>
        (int)Math.Ceiling(Math.Pow(Z95 + ZPower80, 2) * 2 * p * (1 - p) / (mde * mde));

    /// <summary>Phân vị với nội suy tuyến tính; q trong [0, 1].</summary>
    public static double Percentile(IReadOnlyList<double> values, double q)
    {
        if (values.Count == 0) return double.NaN;
        var s = values.OrderBy(v => v).ToArray();
        var pos = (s.Length - 1) * q;
        var lo = (int)Math.Floor(pos);
        var hi = (int)Math.Ceiling(pos);
        return s[lo] + (s[hi] - s[lo]) * (pos - lo);
    }
}
