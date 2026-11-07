using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using UToken.Desktop.App.Models;
namespace UToken.Desktop.App.ViewModels;

public partial class MainViewModel
{
    [ObservableProperty, NotifyPropertyChangedFor(nameof(IsPermissionRequired)),
        NotifyPropertyChangedFor(nameof(IsSourcesNormal)), NotifyPropertyChangedFor(nameof(IsSourceNotFound)), NotifyPropertyChangedFor(nameof(CanNavigate)),
        NotifyPropertyChangedFor(nameof(PageTitle)), NotifyPropertyChangedFor(nameof(Subtitle)),
        NotifyCanExecuteChangedFor(nameof(CancelSourceScanCommand))]
    private bool _isScanningSources;
    [ObservableProperty, NotifyPropertyChangedFor(nameof(IsPreparingSourceScan))] private SourceScanProgress? _sourceScan;
    public bool IsPreparingSourceScan => SourceScan is null;
    private CancellationTokenSource? _sourceScanCancellation;
    private int _sourceScanGeneration;

    [RelayCommand(CanExecute = nameof(IsScanningSources))]
    private void CancelSourceScan() => _sourceScanCancellation?.Cancel();

    [RelayCommand] private Task RescanSourcesAsync() => NavigateAsync(async () =>
    {
        if (!IsSources) return;
        SectionScenario = null;
        using var cancellation = new CancellationTokenSource();
        _sourceScanCancellation = cancellation;
        var generation = ++_sourceScanGeneration;
        SourceScan = null;
        IsScanningSources = true;
        var progress = new Progress<SourceScanProgress>(value =>
        {
            if (IsScanningSources && generation == _sourceScanGeneration) SourceScan = value;
        });
        try
        {
            var sources = await api.RescanSourcesAsync(cancellation.Token, progress);
            var permission = await api.GetSourcePermissionAsync(cancellation.Token);
            var overview = await api.GetOverviewAsync(cancellation.Token);
            cancellation.Token.ThrowIfCancellationRequested();
            ApplySourcePermission(permission with { Sources = sources }); Overview = overview;
            Notice = $"Demo scan complete - {sources.Sources.Length} sources checked."
                + (HasNoSupportedSources ? " No supported source found." : HasPermissionIssue ? " Some sources still require permission." : "");
        }
        catch (OperationCanceledException) when (cancellation.IsCancellationRequested)
        {
            Notice = "Demo scan canceled. Previous source results and usage history are retained.";
        }
        finally
        {
            IsScanningSources = false;
            _sourceScanCancellation = null;
        }
    });
}
