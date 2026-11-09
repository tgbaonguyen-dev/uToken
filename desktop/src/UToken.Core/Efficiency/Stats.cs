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

    /// <summary>
    /// Sai số chuẩn của tỷ lệ khi task gom theo phiên (cụm), vì task cùng phiên không độc lập (Miller 2024).
    /// Khi SR = 0% hoặc 100% thì dùng sai số Agresti–Coull, để không ra MDE = 0.
    /// </summary>
    public static double ClusterStandardError(IReadOnlyList<(string Cluster, bool Success)> items)
    {
        int n = items.Count;
        if (n == 0) return double.NaN;
        int x = items.Count(i => i.Success);
        double p = (double)x / n;

        if (x == 0 || x == n)
        {
            double pAc = (x + 2.0) / (n + 4.0);
            return Math.Sqrt(pAc * (1 - pAc) / n);
        }

        var clusters = items.GroupBy(i => i.Cluster).ToList();
        int g = clusters.Count;
        if (g < 2) return StandardError(p, n);

        double ss = clusters.Sum(c =>
        {
            double r = c.Sum(i => (i.Success ? 1.0 : 0.0) - p);
            return r * r;
        });
        return Math.Sqrt((double)g / (g - 1) * ss) / n;
    }

    /// <summary>
    /// Khoảng tin cậy 95% bootstrap theo phiên cho tỷ số Σa/Σb (ví dụ CPST = Σ chi phí / Σ task thành công).
    /// Seed cố định để tính lại cho cùng kết quả. Lần lấy mẫu có Σb = 0 bị bỏ.
    /// </summary>
    public static (double Low, double High)? BootstrapRatioCi(
        IReadOnlyList<(double A, double B)> clusters, int iterations = 1000, int seed = 42)
    {
        if (clusters.Count == 0) return null;
        var rng = new Random(seed);
        var ratios = new List<double>(iterations);
        for (int it = 0; it < iterations; it++)
        {
            double a = 0, b = 0;
            for (int k = 0; k < clusters.Count; k++)
            {
                var c = clusters[rng.Next(clusters.Count)];
                a += c.A;
                b += c.B;
            }
            if (b > 0) ratios.Add(a / b);
        }
        if (ratios.Count < iterations / 2) return null; // quá nhiều mẫu không có task thành công
        return (Percentile(ratios, 0.025), Percentile(ratios, 0.975));
    }

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
