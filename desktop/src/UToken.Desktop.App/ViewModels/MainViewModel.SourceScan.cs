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
            Notice = $"Scan complete - {sources.Sources.Length} sources checked, {sources.NewEvents ?? 0} new events. Local scan only; use Sync now to upload to mobile."
                + (HasNoSupportedSources ? " No supported source found." : HasPermissionIssue ? " Some sources still require permission." : "");
            // D22: quét xong, nguồn bình thường nhưng không có usage mới.
            if (sources.NewEvents == 0 && !HasNoSupportedSources && !HasPermissionIssue)
                SectionScenario = OverviewScenarios.FirstOrDefault(s => s.Id == "up-to-date") is { } upToDate
                    ? WithLiveDetails(upToDate)
                    : null;
        }
        catch (OperationCanceledException) when (cancellation.IsCancellationRequested)
        {
            Notice = "Scan canceled. Previous source results and usage history are retained.";
        }
        finally
        {
            IsScanningSources = false;
            _sourceScanCancellation = null;
        }
    });
}
