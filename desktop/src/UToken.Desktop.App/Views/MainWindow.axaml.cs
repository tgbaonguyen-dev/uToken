using Avalonia;
using Avalonia.Animation;
using Avalonia.Animation.Easings;
using Avalonia.Controls;
using Avalonia.Media;
using Avalonia.Styling;
using Avalonia.VisualTree;
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
    /// <summary>Hiệu ứng vào trang: mờ dần + trượt nhẹ 8px, 180ms. Chỉ đổi Opacity/RenderTransform nên không đo lại layout.</summary>
    private static readonly Animation PageEnter = new()
    {
        Duration = TimeSpan.FromMilliseconds(180),
        Easing = new CubicEaseOut(),
        FillMode = FillMode.Forward,
        Children =
        {
            new KeyFrame { Cue = new Cue(0), Setters = { new Setter(OpacityProperty, 0d), new Setter(TranslateTransform.YProperty, 8d) } },
            new KeyFrame { Cue = new Cue(1), Setters = { new Setter(OpacityProperty, 1d), new Setter(TranslateTransform.YProperty, 0d) } },
        },
    };
    private CancellationTokenSource? _pageAnimation;
    private void OnViewModelChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
    {
        if (e.PropertyName != nameof(ViewModels.MainViewModel.Page)) return;
        PageHost.Offset = default; // trang mới luôn bắt đầu từ đầu
        _pageAnimation?.Cancel();
        _pageAnimation = new CancellationTokenSource();
        _ = PageEnter.RunAsync(PageHost, _pageAnimation.Token);
    }
    /// <summary>Kéo topbar để di chuyển cửa sổ (bỏ qua khi bấm trúng nút).</summary>
    private void TopbarPointerPressed(object? sender, Avalonia.Input.PointerPressedEventArgs e)
    {
        if (e.Source is Visual v && (v as Button ?? v.FindAncestorOfType<Button>()) is not null) return;
        if (e.GetCurrentPoint(this).Properties.IsLeftButtonPressed && e.ClickCount == 1) BeginMoveDrag(e);
    }
    private void TopbarDoubleTapped(object? sender, Avalonia.Input.TappedEventArgs e)
    {
        if (e.Source is Visual v && (v as Button ?? v.FindAncestorOfType<Button>()) is not null) return;
        WindowState = WindowState == WindowState.Maximized ? WindowState.Normal : WindowState.Maximized;
    }
    public MainWindow()
    {
        InitializeComponent();
        // Windows: topbar thay thanh tiêu đề (nút thu nhỏ/phóng to/đóng của hệ thống vẽ ở góc phải).
        // Linux/macOS giữ khung của hệ điều hành để không mất snap/resize; topbar nằm ngay dưới.
        if (OperatingSystem.IsWindows())
        {
            ExtendClientAreaToDecorationsHint = true;
            ExtendClientAreaChromeHints = Avalonia.Platform.ExtendClientAreaChromeHints.PreferSystemChrome;
            ExtendClientAreaTitleBarHeightHint = 52;
            TopbarActions.Margin = new Thickness(0, 0, 150, 0);
        }
        DataContextChanged += (_, _) =>
        {
            if (_viewModel is not null)
            {
                _viewModel.OverviewDiagnosticsRequested -= ShowOverviewDiagnostics;
                _viewModel.PermissionInstructionsRequested -= ShowPermissionInstructions;
                _viewModel.SourceSetupGuideRequested -= ShowSourceSetupGuide;
                _viewModel.NotificationRequested -= ShowNotification;
                _viewModel.OpenFolderRequested -= OpenFolder;
                _viewModel.PropertyChanged -= OnViewModelChanged;
            }
            _viewModel = DataContext as ViewModels.MainViewModel;
            if (_viewModel is not null)
            {
                _viewModel.OverviewDiagnosticsRequested += ShowOverviewDiagnostics;
                _viewModel.PermissionInstructionsRequested += ShowPermissionInstructions;
                _viewModel.SourceSetupGuideRequested += ShowSourceSetupGuide;
                _viewModel.NotificationRequested += ShowNotification;
                _viewModel.OpenFolderRequested += OpenFolder;
                _viewModel.PropertyChanged += OnViewModelChanged;
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
                _viewModel.PropertyChanged -= OnViewModelChanged;
            }
            _pageAnimation?.Cancel();
        };
        Opened += async (_, _) =>
        {
            if (_opened) return;
            _opened = true;
            _ = SvgLogo.WarmAsync("codex", "claude", "antigravity");
            LazyView.WarmUpAll(this.GetVisualDescendants().OfType<LazyView>());
            if (DataContext is ViewModels.MainViewModel vm) await vm.LoadCommand.ExecuteAsync(null);
        };
    }
}
