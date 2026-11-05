using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace UToken.Desktop.App.ViewModels;

/// <summary>Màn D02 Overview (FR-ACT-001). Các màn khác: Sources, Sync, Settings.</summary>
public partial class MainViewModel : ObservableObject
{
    [ObservableProperty] private string _status = "Collector đang chạy";
    [ObservableProperty] private long _totalTokens;
    [ObservableProperty] private string _lastSync = "Chưa đồng bộ";

    [RelayCommand]
    private Task RescanSourcesAsync() => Task.CompletedTask; // TODO(FR-SRC-001)
}
