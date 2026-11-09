using System.Globalization;

namespace UToken.Desktop.App.Models;

public sealed record PricingRow(
    string Vendor,
    string Model,
    string Rate,
    decimal Input,
    decimal CachedInput,
    decimal? CacheWrite,
    decimal Output)
{
    public string VendorLabel => Vendor switch
    {
        "anthropic" => "Anthropic",
        "openai" => "OpenAI",
        "google" => "Google",
        _ => Vendor,
    };

    public string VendorColor => Vendor switch
    {
        "anthropic" => "#E64C9D",
        "openai" => "#4089EF",
        "google" => "#F26039",
        _ => "#9096A1",
    };

    public string InputLabel => PriceLabel(Input);
    public string CachedInputLabel => PriceLabel(CachedInput);
    public string CacheWriteLabel => CacheWrite is { } value ? PriceLabel(value) : "Input rate";
    public string OutputLabel => PriceLabel(Output);

    private static string PriceLabel(decimal value) =>
        "$" + value.ToString("0.######", CultureInfo.InvariantCulture);
}

public sealed record PricingData(
    string Version,
    DateTimeOffset? UpdatedAt,
    PricingRow[] Rows)
{
    public int ModelCount => Rows.Select(row => (row.Vendor, row.Model)).Distinct().Count();
    public string ModelCountLabel => ModelCount == 1 ? "1 model" : $"{ModelCount:N0} models";
    public string UpdatedLabel => UpdatedAt is { } value
        ? value.ToOffset(DisplayFormat.DisplayOffset).ToString("dd MMM yyyy, HH:mm", CultureInfo.InvariantCulture)
        : "Not downloaded yet";
    public bool IsEmpty => Rows.Length == 0;
}
