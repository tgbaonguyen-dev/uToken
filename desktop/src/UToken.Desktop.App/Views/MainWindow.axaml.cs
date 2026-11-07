using Avalonia.Controls;
using Avalonia.Controls.Notifications;
using Avalonia.Platform.Storage;

namespace UToken.Desktop.App.Views;

public partial class MainWindow : Window
{
    private bool _opened;
    private ViewModels.MainViewModel? _viewModel;
    private DiagnosticsWindow? _diagnostics;
    private void ShowOverviewDiagnostics(string report) =>
        ShowReport(report, "Collector diagnostics", "Application environment and recent log entries");
    private void ShowPermissionInstructions(string report) =>
        ShowReport(report, "Restore log access", "uToken never changes system permissions.");
    private void ShowSourceSetupGuide(string report) =>
        ShowReport(report, "Configure sources", "Supported tools and expected log paths.");
    private void ShowReport(string report, string heading, string subtitle)
    {
        if (!IsVisible) return;
        if (_diagnostics is not null) { _diagnostics.Activate(); return; }
        var dialog = new DiagnosticsWindow(report, heading, subtitle);
        _diagnostics = dialog;
        dialog.Closed += (_, _) => _diagnostics = null;
        _ = dialog.ShowDialog(this);
    }
    private WindowNotificationManager? _notifications;
    private void ShowNotification(string title, string message, bool isError)
    {
        _notifications ??= new WindowNotificationManager(this) { Position = NotificationPosition.BottomRight, MaxItems = 3 };
        _notifications.Show(new Notification(title, message, isError ? NotificationType.Warning : NotificationType.Success, TimeSpan.FromSeconds(8)));
    }
    private async void OpenFolder(string path)
    {
        try
        {
            var ok = Directory.Exists(path) && await Launcher.LaunchDirectoryInfoAsync(new DirectoryInfo(path));
            if (!ok) ShowNotification("Cannot open folder", path, true);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or NotSupportedException)
        { ShowNotification("Cannot open folder", path, true); }
    }
    public MainWindow()
    {
        InitializeComponent();
        DataContextChanged += (_, _) =>
        {
            if (_viewModel is not null)
            {
                _viewModel.OverviewDiagnosticsRequested -= ShowOverviewDiagnostics;
                _viewModel.PermissionInstructionsRequested -= ShowPermissionInstructions;
                _viewModel.SourceSetupGuideRequested -= ShowSourceSetupGuide;
                _viewModel.NotificationRequested -= ShowNotification;
                _viewModel.OpenFolderRequested -= OpenFolder;
            }
            _viewModel = DataContext as ViewModels.MainViewModel;
            if (_viewModel is not null)
            {
                _viewModel.OverviewDiagnosticsRequested += ShowOverviewDiagnostics;
                _viewModel.PermissionInstructionsRequested += ShowPermissionInstructions;
                _viewModel.SourceSetupGuideRequested += ShowSourceSetupGuide;
                _viewModel.NotificationRequested += ShowNotification;
                _viewModel.OpenFolderRequested += OpenFolder;
            }
        };
        Closed += (_, _) =>
        {
            if (_viewModel is not null)
            {
                _viewModel.NotificationRequested -= ShowNotification;
                _viewModel.OpenFolderRequested -= OpenFolder;
                _viewModel.OverviewDiagnosticsRequested -= ShowOverviewDiagnostics;
                _viewModel.PermissionInstructionsRequested -= ShowPermissionInstructions;
                _viewModel.SourceSetupGuideRequested -= ShowSourceSetupGuide;
            }
        };
        Opened += async (_, _) =>
        {
            if (_opened) return;
            _opened = true;
            if (DataContext is ViewModels.MainViewModel vm) await vm.LoadCommand.ExecuteAsync(null);
        };
    }
}
