using Avalonia.Controls;
using UToken.Desktop.App.ViewModels;
namespace UToken.Desktop.App.Services;

public sealed class DesktopWindowController
{
    private readonly Window _window;
    private readonly MainViewModel _viewModel;
    private readonly Action _shutdown;
    private readonly bool _trayAvailable;
    private bool _quitting;

    public DesktopWindowController(Window window, MainViewModel viewModel, Action shutdown, bool trayAvailable)
    {
        _window = window; _viewModel = viewModel; _shutdown = shutdown; _trayAvailable = trayAvailable;
        _window.Closing += OnClosing;
    }

    private void OnClosing(object? sender, WindowClosingEventArgs e)
    {
        if (_quitting || !_trayAvailable || _viewModel.Settings?.Values.BackgroundCollection != true ||
            e.CloseReason is WindowCloseReason.ApplicationShutdown or WindowCloseReason.OSShutdown or WindowCloseReason.OwnerWindowClosing)
            return;
        e.Cancel = true;
        _viewModel.Notice = "Window hidden to tray. Usage is still collected and synced in the background. Use Open to return or Quit to exit.";
        _window.Hide();
    }

    public void Open()
    {
        _window.Show();
        if (_window.WindowState == WindowState.Minimized) _window.WindowState = WindowState.Normal;
        _window.Activate();
    }

    public void Quit()
    {
        _quitting = true;
        _shutdown();
    }
}
