using Avalonia.Controls;
using Avalonia.Headless.XUnit;
using Avalonia.VisualTree;
using UToken.Desktop.App.Services;
using UToken.Desktop.App.ViewModels;
using UToken.Desktop.App.Views;
using Xunit;

namespace UToken.Desktop.Tests;
public sealed class FirstRunTrayTests : IDisposable
{
    private readonly string _directory = Path.Combine(AppContext.BaseDirectory, "Setup-" + Guid.NewGuid().ToString("N"));
    private MockDesktopApi CreateApi() => new(localSettings: new LocalSettingsStore(_directory));

    [AvaloniaFact]
    public async Task First_run_progresses_to_pairing_and_does_not_reappear_on_restart()
    {
        var api = CreateApi();
        var vm = new MainViewModel(api, showSetupOnStart: true);
        await vm.LoadCommand.ExecuteAsync(null);
        Assert.Null(vm.Error);
        Assert.True(vm.IsFirstRunPage);
        Assert.Equal(3, vm.SetupRows.Length);
        Assert.All(vm.SetupRows, row => Assert.False(row.Completed));
        var window = new MainWindow { DataContext = vm };
        window.Show();
        while (vm.IsBusy) await Task.Delay(20);
        DesktopDemoTests.Render(window, "first-run");
        Assert.False(vm.CanNavigate);
        Assert.False(vm.SkipSetupCommand.CanExecute(null));
        Assert.All(window.GetVisualDescendants().OfType<Button>().Where(b => b.Classes.Contains("nav")),
            b => Assert.False(b.IsEffectivelyEnabled));
        vm.ShowOverviewCommand.Execute(null);
        vm.ShowSourcesCommand.Execute(null);
        await vm.ShowSyncCommand.ExecuteAsync(null);
        await vm.ShowSettingsCommand.ExecuteAsync(null);
        await vm.ShowActivityCommand.ExecuteAsync(null);
        await vm.ShowPairingCommand.ExecuteAsync(null);
        await vm.SkipSetupCommand.ExecuteAsync(null);
        Assert.True(vm.IsFirstRunPage);
        Assert.False(await api.IsSetupCompleteAsync());
        await vm.ContinueSetupCommand.ExecuteAsync(null);
        Assert.True(vm.SetupRows[0].Completed);
        await vm.ContinueSetupCommand.ExecuteAsync(null);
        Assert.True(vm.SetupRows[1].Completed);
        window.Width = 1020; window.Height = 650;
        DesktopDemoTests.Render(window, "first-run-small");
        await vm.ContinueSetupCommand.ExecuteAsync(null);
        Assert.Null(vm.Error);
        Assert.True(vm.IsPairingPage);
        Assert.True(vm.CanNavigate);
        Assert.True(await CreateApi().IsSetupCompleteAsync());
        var restarted = new MainViewModel(CreateApi(), showSetupOnStart: true);
        await restarted.LoadCommand.ExecuteAsync(null);
        Assert.True(restarted.IsOverview);
        await restarted.ShowFirstRunCommand.ExecuteAsync(null);
        Assert.True(restarted.IsFirstRunPage);
        await restarted.ContinueSetupCommand.ExecuteAsync(null);
        Assert.True(restarted.CanSkipSetup);
        await restarted.SkipSetupCommand.ExecuteAsync(null);
        Assert.True(restarted.IsOverview);
        window.Close();
    }

    [AvaloniaFact]
    public async Task Close_hides_to_tray_open_restores_and_quit_closes()
    {
        var vm = new MainViewModel(new MockDesktopApi());
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
            var vm = new MainViewModel(new MockDesktopApi());
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

    public void Dispose()
    {
        if (!Directory.Exists(_directory)) return;
        foreach (var file in Directory.GetFiles(_directory)) File.Delete(file);
        Directory.Delete(_directory);
    }
}
