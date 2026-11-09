using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using UToken.Desktop.App.Models;

namespace UToken.Desktop.App.ViewModels;

public partial class MainViewModel
{
    [ObservableProperty, NotifyPropertyChangedFor(nameof(FilteredPricingRows)), NotifyPropertyChangedFor(nameof(IsPricingEmpty))]
    private PricingData? _pricing;

    [ObservableProperty, NotifyPropertyChangedFor(nameof(FilteredPricingRows)), NotifyPropertyChangedFor(nameof(IsPricingEmpty))]
    private string _pricingSearch = "";

    public bool IsPricingPage => Page == "pricing";

    public PricingRow[] FilteredPricingRows
    {
        get
        {
            var rows = Pricing?.Rows ?? [];
            var search = PricingSearch.Trim();
            return search.Length == 0
                ? rows
                : rows.Where(row => $"{row.VendorLabel} {row.Model} {row.Rate}"
                    .Contains(search, StringComparison.OrdinalIgnoreCase)).ToArray();
        }
    }

    public bool IsPricingEmpty => FilteredPricingRows.Length == 0;

    [RelayCommand]
    private Task ShowPricingAsync() => NavigateAsync(async () =>
    {
        Pricing = await api.GetPricingAsync(CancellationToken.None);
        Page = "pricing";
    });
}
