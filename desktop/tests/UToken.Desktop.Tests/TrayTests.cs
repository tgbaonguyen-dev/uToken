using Avalonia.Controls;
using Avalonia.Headless.XUnit;
using Avalonia.VisualTree;
using UToken.Desktop.App.Services;
using UToken.Desktop.App.ViewModels;
using UToken.Desktop.App.Views;
using Xunit;

namespace UToken.Desktop.Tests;
public sealed class TrayTests : IDisposable
{
    private readonly RealHome _home = new();

    [AvaloniaFact]
    public async Task Close_hides_to_tray_open_restores_and_quit_closes()
    {
        var vm = new MainViewModel(_home.Api());
        await vm.ShowSettingsCommand.ExecuteAsync(null);
        var window = new Window();
        var closed = false;
        window.Closed += (_, _) => closed = true;
        var controller = new DesktopWindowController(window, vm, () => window.Close(), trayAvailable: true);
        window.Show();
        vm.BackgroundCollection = false; // Unsaved changes must not affect lifecycle.
        window.Close();
        Assert.False(window.IsVisible);
        Assert.False(closed);
        controller.Open();
        Assert.True(window.IsVisible);
        controller.Quit();
        Assert.True(closed);
    }

    [AvaloniaFact]
    public async Task Close_exits_when_background_is_saved_off_or_tray_is_unavailable()
    {
        foreach (var trayAvailable in new[] { true, false })
        {
            var vm = new MainViewModel(_home.Api());
            await vm.ShowSettingsCommand.ExecuteAsync(null);
            if (trayAvailable)
            {
                vm.BackgroundCollection = false;
                await vm.SaveSettingsCommand.ExecuteAsync(null);
            }
            var window = new Window();
            var closed = false;
            window.Closed += (_, _) => closed = true;
            _ = new DesktopWindowController(window, vm, () => window.Close(), trayAvailable);
            window.Show();
            window.Close();
            Assert.True(closed);
        }
    }

    public void Dispose() => _home.Dispose();
}
