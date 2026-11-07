using Avalonia.Controls;
using Avalonia.Controls.Shapes;
using Avalonia.Media;
using Avalonia.VisualTree;
using Avalonia.Headless.XUnit;
using UToken.Desktop.App.Services;
using UToken.Desktop.App.ViewModels;
using UToken.Desktop.App.Views;
using Xunit;

namespace UToken.Desktop.Tests;

public class WindowsVisualAuditTests
{
    [AvaloniaFact]
    public async Task Windows_D01_to_D25_render_with_status_indicators_and_navigation()
    {
        var vm = new MainViewModel(new MockDesktopApi());
        await vm.LoadCommand.ExecuteAsync(null);
        var window = new MainWindow { DataContext = vm };
        window.Show();
        try
        {
            while (vm.IsBusy) await Task.Delay(20);
            await vm.ShowFirstRunCommand.ExecuteAsync(null); Capture("D01");
            await vm.ContinueSetupCommand.ExecuteAsync(null);
            await vm.SkipSetupCommand.ExecuteAsync(null); Capture("D02");
            await vm.ShowSyncCommand.ExecuteAsync(null);
            await vm.DisconnectCommand.ExecuteAsync(null);
            await vm.ShowPairingCommand.ExecuteAsync(null); Capture("D03");
            await vm.ShowActivityCommand.ExecuteAsync(null); Capture("D04");
            vm.ShowSourcesCommand.Execute(null); Capture("D05");
            vm.ShowPermissionInstructionsCommand.Execute("guide");
            var permissions = Assert.Single(window.OwnedWindows.OfType<DiagnosticsWindow>());
            Assert.Contains("All supported sources", Assert.IsType<string>(permissions.DataContext));
            permissions.Close();
            await vm.OpenSourceCommand.ExecuteAsync(vm.SourceList!.Sources[0]); Capture("D06");
            await vm.ShowPairingCommand.ExecuteAsync(null);
            foreach (var (digit, value) in vm.PairingDigits.Zip("482913")) digit.Text = value.ToString();
            await vm.PairDeviceCommand.ExecuteAsync(null);
            await vm.ShowSyncCommand.ExecuteAsync(null); Capture("D07");
            await vm.ShowSettingsCommand.ExecuteAsync(null); Capture("D08");
            vm.ShowOverviewCommand.Execute(null);
            await Overview("offline"); Capture("D09");
            AssertSidebar("#F04D57");
            vm.ShowSourcesCommand.Execute(null);
            await Sources("permission-required"); Capture("D10");
            AssertSidebar("#FFAD38");
            vm.ShowOverviewCommand.Execute(null);
            await Overview("empty"); Capture("D11");
            await vm.ShowSyncCommand.ExecuteAsync(null);
            Sync("sync-failed"); Capture("D12"); AssertSidebar("#D14DA6");
            Sync("not-paired"); Capture("D13");
            await vm.ShowPairingCommand.ExecuteAsync(null);
            foreach (var (id, code) in new[] { ("waiting", "D14"), ("verifying", "D15"), ("expired", "D16"), ("rejected", "D17"), ("success", "D18") })
            {
                vm.SelectedPairingScenario = vm.PairingScenarios.Single(s => s.Id == id);
                Capture(code);
                var headerDot = window.FindControl<Ellipse>("PairingStateHeaderDot")!;
                Assert.True(headerDot.IsEffectivelyVisible);
                Assert.Equal(Color.Parse(vm.ActivePairingScenario!.Accent), Assert.IsAssignableFrom<ISolidColorBrush>(headerDot.Fill).Color);
            }
            vm.ShowSourcesCommand.Execute(null);
            await Sources("normal");
            var scan = vm.RescanSourcesCommand.ExecuteAsync(null);
            while (vm.SourceScan is null && !scan.IsCompleted) await Task.Delay(20);
            Assert.True(vm.IsScanningSources); Capture("D19");
            vm.CancelSourceScanCommand.Execute(null);
            await scan;
            await vm.ShowSyncCommand.ExecuteAsync(null);
            Sync("syncing"); Capture("D20");
            vm.ShowSourcesCommand.Execute(null);
            await Sources("source-not-found"); Capture("D21");
            await Sources("up-to-date"); Capture("D22");
            Assert.True(window.FindControl<Ellipse>("SourceStateHeaderDot")!.IsEffectivelyVisible);
            await vm.ShowSyncCommand.ExecuteAsync(null);
            Sync("revoked"); Capture("D23");
            vm.ShowOverviewCommand.Execute(null);
            await Overview("update"); Capture("D24");
            await vm.ShowSyncCommand.ExecuteAsync(null);
            Sync("network"); Capture("D25");
            Assert.Equal(6_830_000, vm.Overview!.TotalTokens);
        }
        finally { window.Close(); }

        async Task Overview(string id)
        {
            vm.SelectedOverviewScenario = vm.OverviewPreviewOptions.Single(s => s.Id == id);
            await vm.ChangeOverviewScenarioCommand.ExecutionTask!;
        }
        async Task Sources(string id)
        {
            vm.SelectedPermissionScenario = vm.SourcePreviewOptions.Single(s => s.Id == id);
            if (vm.ChangePermissionScenarioCommand.ExecutionTask is { } task) await task;
        }
        void Sync(string id) => vm.SelectedSyncScenario = vm.SyncPreviewOptions.Single(s => s.Id == id);
        void AssertSidebar(string color) => Assert.Equal(Color.Parse(color),
            Assert.IsAssignableFrom<ISolidColorBrush>(window.FindControl<Ellipse>("SidebarStatusDot")!.Fill).Color);

        void Capture(string id)
        {
            Assert.Null(vm.Error);
            window.Width = 1180; window.Height = 760;
            DesktopDemoTests.Render(window, "audit-" + id);
            window.Width = 1020; window.Height = 650;
            DesktopDemoTests.Render(window, "audit-" + id + "-small");
            if (id == "D06")
            {
                var bars = window.GetVisualDescendants().OfType<Border>()
                    .Where(b => b.IsEffectivelyVisible && b.DataContext is UToken.Desktop.App.Models.TrendBar).ToArray();
                Assert.NotEmpty(bars);
                Assert.All(bars, b => Assert.True(b.Bounds.Width > 0, "Chart bars must have visible width."));
            }
            if (id == "D11")
            {
                var badge = window.GetVisualDescendants().OfType<Border>().Single(b => b.Name == "EmptyCollectorHealthBadge");
                Assert.True(badge.IsEffectivelyVisible);
                var dot = Assert.Single(badge.GetVisualDescendants().OfType<Ellipse>());
                Assert.Equal(Color.Parse("#2EC790"), Assert.IsAssignableFrom<ISolidColorBrush>(dot.Fill).Color);
            }
            Assert.All(window.GetVisualDescendants().OfType<Ellipse>().Where(e => e.IsEffectivelyVisible && e.Classes.Contains("status-dot")), dot =>
            {
                Assert.NotNull(dot.Fill);
                Assert.True(dot.Bounds.Width > 0 && dot.Bounds.Height > 0);
            });
            window.Width = 1180; window.Height = 760;
        }
    }
}
