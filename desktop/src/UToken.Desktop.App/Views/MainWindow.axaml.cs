using Avalonia.Controls;

namespace UToken.Desktop.App.Views;

public partial class MainWindow : Window
{
    private bool _opened;
    private ViewModels.MainViewModel? _viewModel;
    private DiagnosticsWindow? _diagnostics;
    private void ShowOverviewDiagnostics(string report) =>
        ShowReport(report, "Collector diagnostics", "Application environment and recent log entries");
    private void ShowPermissionInstructions(string report) =>
        ShowReport(report, "Restore log access", "UI demo - no system permissions are changed.");
    private void ShowSourceSetupGuide(string report) =>
        ShowReport(report, "Configure sources", "UI demo - supported tools and expected log paths.");
    private void ShowReport(string report, string heading, string subtitle)
    {
        if (!IsVisible) return;
        if (_diagnostics is not null) { _diagnostics.Activate(); return; }
        var dialog = new DiagnosticsWindow(report, heading, subtitle);
        _diagnostics = dialog;
        dialog.Closed += (_, _) => _diagnostics = null;
        _ = dialog.ShowDialog(this);
    }
    public MainWindow()
    {
        InitializeComponent();
        var pairingTimer = new Avalonia.Threading.DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
        pairingTimer.Tick += (_, _) => _viewModel?.UpdatePairingCountdown();
        DataContextChanged += (_, _) =>
        {
            if (_viewModel is not null)
            {
                _viewModel.OverviewDiagnosticsRequested -= ShowOverviewDiagnostics;
                _viewModel.PermissionInstructionsRequested -= ShowPermissionInstructions;
                _viewModel.SourceSetupGuideRequested -= ShowSourceSetupGuide;
            }
            _viewModel = DataContext as ViewModels.MainViewModel;
            if (_viewModel is not null)
            {
                _viewModel.OverviewDiagnosticsRequested += ShowOverviewDiagnostics;
                _viewModel.PermissionInstructionsRequested += ShowPermissionInstructions;
                _viewModel.SourceSetupGuideRequested += ShowSourceSetupGuide;
            }
        };
        Closed += (_, _) =>
        {
            pairingTimer.Stop();
            if (_viewModel is not null)
            {
                _viewModel.OverviewDiagnosticsRequested -= ShowOverviewDiagnostics;
                _viewModel.PermissionInstructionsRequested -= ShowPermissionInstructions;
                _viewModel.SourceSetupGuideRequested -= ShowSourceSetupGuide;
            }
        };
        Opened += async (_, _) =>
        {
            pairingTimer.Start();
            _viewModel?.UpdatePairingCountdown();
            if (_opened) return;
            _opened = true;
            if (DataContext is ViewModels.MainViewModel vm) await vm.LoadCommand.ExecuteAsync(null);
        };
    }
}
