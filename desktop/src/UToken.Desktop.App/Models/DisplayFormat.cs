using System.Globalization;
namespace UToken.Desktop.App.Models;

public static class DisplayFormat
{
    public static readonly TimeSpan DisplayOffset = TimeSpan.FromHours(7);
    public static string Tokens(long value) => value >= 1_000_000
        ? (value / 1_000_000d).ToString("0.00", CultureInfo.InvariantCulture) + "M"
        : value >= 1_000 ? (value / 1_000d).ToString("0.0", CultureInfo.InvariantCulture) + "K"
        : value.ToString(CultureInfo.InvariantCulture);
    public static string Money(decimal value) => value.ToString("$0.00", CultureInfo.InvariantCulture);
    public static string Percent(double value) => value.ToString("0.0", CultureInfo.InvariantCulture) + "%";
    public static string Bytes(long value) => value >= 1_000_000_000 ? (value / 1_000_000_000d).ToString("0.0", CultureInfo.InvariantCulture) + " GB"
        : value >= 1_000_000 ? (value / 1_000_000d).ToString("0.0", CultureInfo.InvariantCulture) + " MB"
        : value >= 1_000 ? (value / 1_000d).ToString("0.0", CultureInfo.InvariantCulture) + " KB" : value + " B";
    public static string Age(DateTimeOffset? at, DateTimeOffset reference)
    {
        if (at is null) return "No data";
        var age = reference - at.Value;
        if (age < TimeSpan.Zero) return "Future timestamp";
        if (age.TotalMinutes < 1) return "Just now";
        if (age.TotalHours < 1) return $"{(int)age.TotalMinutes} min";
        if (age.TotalDays < 1) return $"{(int)age.TotalHours} h";
        return $"{(int)age.TotalDays} days";
    }
    public static string Relative(DateTimeOffset? at, DateTimeOffset reference)
    {
        var age = Age(at, reference);
        return age is "No data" or "Just now" or "Future timestamp" ? age : age + " ago";
    }
}
