using System.Text;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Headless.XUnit;
using Avalonia.VisualTree;
using UToken.Desktop.App.Models;
using UToken.Desktop.App.Services;
using UToken.Desktop.App.ViewModels;
using UToken.Desktop.App.Views;
using Xunit;

namespace UToken.Desktop.Tests;

public class LocalFeaturesTests : IDisposable
{
    private readonly string _directory = Path.Combine(AppContext.BaseDirectory, "local-features-" + Guid.NewGuid().ToString("N"));
    private DesktopUiStateStore Store() => new(new LocalSettingsStore(_directory));

    [AvaloniaFact]
    public async Task Pairing_timer_expires_without_submit_and_restart_gets_a_new_countdown()
    {
        var clock = new Clock();
        var api = new MockDesktopApi(timeProvider: clock);
        var vm = new MainViewModel(api, timeProvider: clock);
        var window = new MainWindow { DataContext = vm };
        window.Show();
        try
        {
            while (vm.IsBusy) await Task.Delay(20);
            await vm.ShowSyncCommand.ExecuteAsync(null);
            await vm.DisconnectCommand.ExecuteAsync(null);
            await vm.ShowPairingCommand.ExecuteAsync(null);
            Assert.Equal("Code expires in 10:00", vm.PairingCountdownLabel);
            clock.Now = clock.Now.AddMinutes(2).AddSeconds(3);
            vm.UpdatePairingCountdown();
            Assert.Equal("Code expires in 07:57", vm.PairingCountdownLabel);
            clock.Now = clock.Now.AddMinutes(8);
            var deadline = DateTime.UtcNow.AddSeconds(4);
            while (vm.PairingState != "expired" && DateTime.UtcNow < deadline) await Task.Delay(40);
            Assert.Equal("expired", vm.ActivePairingScenario!.Id);
            Assert.Equal(TimeSpan.Zero, vm.PairingRemaining);
            Assert.Equal("expired", (await api.PairDeviceAsync("482913")).State);
            await vm.PairingStateActionCommand.ExecuteAsync("restart");
            Assert.True(vm.IsPairingFormVisible);
            Assert.Equal("Code expires in 10:00", vm.PairingCountdownLabel);
            vm.SelectedPairingScenario = vm.PairingScenarios.Single(s => s.Id == "waiting");
            clock.Now = clock.Now.AddHours(1);
            vm.UpdatePairingCountdown();
            Assert.Equal("waiting", vm.ActivePairingScenario!.Id);
            Assert.True(vm.IsPairingPreview);
            vm.SelectedPairingScenario = vm.PairingScenarios.Single(s => s.Id == "normal");
            vm.UpdatePairingCountdown();
            Assert.Equal("expired", vm.ActivePairingScenario!.Id);
            DesktopDemoTests.Render(window, "local-pairing-expired");
        }
        finally { window.Close(); }
    }

    [AvaloniaFact]
    public async Task Activity_and_source_filters_survive_a_new_viewmodel_and_stale_models_fall_back()
    {
        var store = Store();
        var vm = new MainViewModel(new MockDesktopApi(), uiStateStore: store);
        await vm.LoadCommand.ExecuteAsync(null);
        vm.ActivityProvider = "Codex"; vm.ActivityModel = "gpt-5.3-codex";
        vm.ActivityPeriod = "Last 7 days"; vm.ActivitySearch = "codex"; vm.SelectedPeriod = "Week";
        await vm.ShowActivityCommand.ExecuteAsync(null);
        Assert.NotEmpty(vm.ActivityPage!.Events);
        var restored = new MainViewModel(new MockDesktopApi(), uiStateStore: Store());
        await restored.LoadCommand.ExecuteAsync(null);
        await restored.ShowActivityCommand.ExecuteAsync(null);
        Assert.Equal(vm.CurrentActivityQuery, restored.CurrentActivityQuery);
        Assert.Equal("Week", restored.SelectedPeriod);
        Assert.All(restored.ActivityPage!.Events, e => Assert.Equal("Codex", e.Provider));
        Store().SaveFilters(new("Removed provider", "Removed model", "All time"), "Total");
        var stale = new MainViewModel(new MockDesktopApi(), uiStateStore: Store());
        await stale.LoadCommand.ExecuteAsync(null);
        await stale.ShowActivityCommand.ExecuteAsync(null);
        Assert.Equal("All sources", stale.ActivityProvider);
        Assert.Equal("All models", stale.ActivityModel);
        Assert.Equal("Total", stale.SelectedPeriod);
        Assert.Null(stale.Error);
    }

    [AvaloniaFact]
    public void Window_placement_persists_normal_bounds_and_maximized_state_even_when_minimized()
    {
        var store = Store();
        var window = new Window { Width = 1180, Height = 760, MinWidth = 1020, MinHeight = 650 };
        var controller = new WindowPlacementController(window, store);
        window.Show();
        try
        {
            window.Width = 1100; window.Height = 700;
            DesktopDemoTests.Render(window, "local-window-placement");
            controller.Save();
            var normal = Store().State.Window;
            Assert.True(normal.Width >= 1020 && normal.Height >= 650);
            window.WindowState = WindowState.Maximized;
            window.WindowState = WindowState.Minimized;
            controller.Save();
            Assert.True(Store().State.Window.Maximized);
            Assert.Equal(normal.Width, Store().State.Window.Width);
            window.WindowState = WindowState.Normal;
            controller.Save();
            Assert.False(Store().State.Window.Maximized);
        }
        finally { window.Close(); }
    }

    [Fact]
    public void Placement_fits_DPI_and_keeps_positions_on_negative_coordinate_monitors()
    {
        var negative = WindowPlacementController.Fit(new(1180, 760, -1600, 100), new PixelRect(-1920, 0, 1920, 1040), 1, 1020, 650);
        Assert.Equal(-1600, negative.X); Assert.Equal(100, negative.Y);
        var disconnected = WindowPlacementController.Fit(new(5000, 4000, 9000, 9000), new PixelRect(0, 0, 1920, 1080), 1.5, 1020, 650);
        Assert.Equal(1280, disconnected.Width); Assert.Equal(720, disconnected.Height);
        Assert.Equal(0, disconnected.X); Assert.Equal(0, disconnected.Y);
    }

    [Fact]
    public void Invalid_UI_json_does_not_break_app_settings_and_failed_saves_leave_no_temp_files()
    {
        var store = Store(); Directory.CreateDirectory(_directory);
        File.WriteAllText(store.FilePath, "{}");
        Assert.Equal(DesktopUiState.Default, Store().State);
        Assert.False(File.Exists(Path.Combine(_directory, "settings.json")));
        File.Delete(store.FilePath);
        Directory.CreateDirectory(store.FilePath);
        try
        {
            Assert.False(store.SaveFilters(new(), "Week"));
            Assert.Empty(Directory.GetFiles(_directory, "*.tmp"));
        }
        finally { Directory.Delete(store.FilePath); }
    }

    [AvaloniaFact]
    public async Task Diagnostic_copy_uses_clipboard_and_report_exports_UTF8_without_trailing_old_content()
    {
        const string report = "uToken diagnostics\nTiếng Việt: kiểm tra dữ liệu";
        var window = new DiagnosticsWindow(report);
        window.Show();
        try
        {
            var actions = Assert.Single(window.GetVisualDescendants().OfType<ReportActions>());
            await actions.CopyReportAsync();
            Assert.Equal(report, await window.Clipboard!.GetTextAsync());
            Assert.Equal("Report copied.", actions.FindControl<TextBlock>("ReportActionStatus")!.Text);
            DesktopDemoTests.Render(window, "local-diagnostics-copy-save");
            using var stream = new MemoryStream();
            await stream.WriteAsync(Encoding.UTF8.GetBytes(new string('x', 1000)));
            await ReportActions.WriteReportAsync(stream, report);
            Assert.Equal(report, Encoding.UTF8.GetString(stream.ToArray()).TrimStart('\uFEFF'));
        }
        finally { window.Close(); }
    }

    public void Dispose()
    {
        if (!Directory.Exists(_directory)) return;
        foreach (var file in Directory.EnumerateFiles(_directory)) File.Delete(file);
        Directory.Delete(_directory);
    }
    private sealed class Clock : TimeProvider
    {
        public DateTimeOffset Now = DateTimeOffset.Parse("2026-11-07T10:00:00+07:00");
        public override DateTimeOffset GetUtcNow() => Now;
    }
}
