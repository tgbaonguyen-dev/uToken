using Avalonia.Controls;
using Avalonia.Headless.XUnit;
using Avalonia.VisualTree;
using UToken.Core.Pricing;
using UToken.Desktop.App.ViewModels;
using UToken.Desktop.App.Views;
using UToken.Storage;
using Xunit;

namespace UToken.Desktop.Tests;

/// <summary>Luồng giao diện chạy trên dữ liệu thật (fixture), kèm ảnh chụp từng màn trong bin/.../Screenshots.</summary>
public sealed class DesktopFlowTests : IDisposable
{
    private readonly RealHome _home = new();

    private static async Task<(MainViewModel Vm, MainWindow Window)> OpenAsync(App.Services.IDesktopApi api, bool setup = false)
    {
        var vm = new MainViewModel(api, showSetupOnStart: setup);
        var window = new MainWindow { DataContext = vm };
        window.Show();
        await TestApp.WaitIdle(vm);
        Assert.Null(vm.Error);
        return (vm, window);
    }

    [AvaloniaFact]
    public async Task Dashboard_sources_details_and_activity_render_real_usage()
    {
        using var api = _home.Api();
        var (vm, window) = await OpenAsync(api);
        try
        {
            Assert.True(vm.IsOverviewDashboard);
            Assert.Equal("normal", vm.OverviewStateId);
            Assert.True(vm.Overview!.TotalTokens > 0);
            Assert.DoesNotContain(window.GetVisualDescendants().OfType<ComboBox>(), c => c.Name?.EndsWith("ScenarioSelector") == true);
            TestApp.Render(window, "real-overview");

            vm.ShowSourcesCommand.Execute(null);
            Assert.True(vm.IsSourcesNormal);
            TestApp.Render(window, "real-sources");
            foreach (var source in vm.SourceList!.Sources.Where(s => s.Tokens > 0))
            {
                await vm.OpenSourceCommand.ExecuteAsync(source);
                Assert.Equal(source.Name, vm.PageTitle);
                foreach (var period in vm.Periods)
                {
                    vm.SelectedPeriod = period;
                    if (vm.ChangePeriodCommand.ExecutionTask is { } t) await t;
                    Assert.Null(vm.Error);
                    Assert.Equal(period, vm.SelectedPeriod);
                }
                TestApp.Render(window, "real-detail-" + source.Id);
                vm.ShowSourcesCommand.Execute(null);
            }

            await vm.ShowActivityCommand.ExecuteAsync(null);
            vm.ActivityPeriod = "All time";
            await vm.RefreshActivityCommand.ExecuteAsync(null);
            Assert.Equal(9, vm.ActivityPage!.Events.Length);
            TestApp.Render(window, "real-activity");
        }
        finally { window.Close(); }
    }

    [AvaloniaFact]
    public async Task Pricing_renders_cached_models_dev_rates_and_context_tiers()
    {
        using (var store = new SqliteStore(_home.DatabasePath))
        {
            store.SavePrices(
                [new ModelPrice(
                    "openai",
                    "gpt-test",
                    new PriceSchedule(
                        new Price(2m, 0.2m, null, 10m),
                        [new PriceTier(200_000, new Price(4m, 0.4m, 5m, 15m))]))],
                "models.dev@test",
                _home.Clock.Now);
        }

        using var api = _home.Api();
        var (vm, window) = await OpenAsync(api);
        try
        {
            await vm.ShowPricingCommand.ExecuteAsync(null);

            Assert.True(vm.IsPricingPage);
            Assert.Equal("models.dev@test", vm.Pricing!.Version);
            Assert.Equal(1, vm.Pricing.ModelCount);
            Assert.Equal("1 model", vm.Pricing.ModelCountLabel);
            Assert.Equal(2, vm.Pricing.Rows.Length);
            Assert.Contains(vm.Pricing.Rows, row => row.Rate == "Context > 200K" && row.CacheWriteLabel == "$5");

            window.UpdateLayout();
            Avalonia.Threading.Dispatcher.UIThread.RunJobs();
            var table = window.GetVisualDescendants().OfType<ItemsControl>().Single(control =>
                Avalonia.Automation.AutomationProperties.GetAutomationId(control) == "PricingTable");
            Assert.Equal(2, ((IEnumerable<UToken.Desktop.App.Models.PricingRow>)table.ItemsSource!).Count());

            vm.PricingSearch = "context";
            Assert.Single(vm.FilteredPricingRows);
            vm.PricingSearch = "";
            TestApp.Render(window, "real-pricing");
        }
        finally { window.Close(); }
    }

    [AvaloniaFact]
    public async Task Rescan_without_new_logs_shows_up_to_date_state()
    {
        using var api = _home.Api();
        var (vm, window) = await OpenAsync(api);
        try
        {
            vm.ShowSourcesCommand.Execute(null);
            await vm.RescanSourcesCommand.ExecuteAsync(null);
            Assert.True(vm.IsSourcesStatePreview);
            Assert.Equal("up-to-date", vm.SectionScenario!.Id);
            Assert.Contains("0 new events", vm.Notice);
            TestApp.Render(window, "real-sources-up-to-date");
        }
        finally { window.Close(); }
    }

    [AvaloniaFact]
    public async Task Empty_and_offline_states_follow_real_folders()
    {
        using var empty = new RealHome(withLogs: false);
        Directory.CreateDirectory(Path.Combine(empty.Home, ".codex", "sessions")); // có công cụ nhưng chưa có usage
        using (var api = empty.Api())
        {
            var (vm, window) = await OpenAsync(api);
            Assert.Equal("empty", vm.OverviewStateId);
            Assert.True(vm.IsOverviewState);
            Assert.Contains(vm.OverviewPreview!.Scenario.Details, d => d.Label == "Log access" && d.Value == "1 of 3 folders readable");
            TestApp.Render(window, "real-overview-empty");
            window.Close();
        }

        using var none = new RealHome(withLogs: false);
        using (var api = none.Api())
        {
            var (vm, window) = await OpenAsync(api);
            Assert.Equal("offline", vm.OverviewStateId);
            vm.ShowSourcesCommand.Execute(null);
            Assert.True(vm.IsSourceNotFound);
            TestApp.Render(window, "real-sources-not-found");
            window.Close();
        }
    }

    [AvaloniaFact]
    public async Task Sign_in_and_sync_go_through_real_states()
    {
        using var api = _home.Api();
        var (vm, window) = await OpenAsync(api);
        try
        {
            await vm.ShowSyncCommand.ExecuteAsync(null);
            Assert.Equal("not-paired", vm.ActiveSyncScenario!.Id);
            await vm.SyncNowCommand.ExecuteAsync(null);
            Assert.Equal("not-paired", vm.ActiveSyncScenario!.Id);
            Assert.Contains("Sign in with Google", vm.SyncMessage);
            TestApp.Render(window, "real-sync-signed-out");

            await vm.ShowPairingCommand.ExecuteAsync(null);
            Assert.True(vm.IsPairingFormVisible);
            Assert.Equal("Sign in with Google", vm.PageTitle);
            TestApp.Render(window, "real-account-signed-out");
            await vm.SignInCommand.ExecuteAsync(null);
            Assert.Equal("success", vm.ActivePairingScenario!.Id);
            Assert.True(vm.ShowPairedDeviceSummary);
            Assert.Equal("Signed in · ana@example.com", vm.CloudSyncLabel);
            TestApp.Render(window, "real-account-signed-in");

            await vm.ShowSyncCommand.ExecuteAsync(null);
            await vm.SyncNowCommand.ExecuteAsync(null);
            Assert.True(vm.IsSyncNormal);
            Assert.Equal("#2EC790", vm.SyncMessageColor);
            Assert.Single(_home.Cloud.Uploads);
            Assert.NotEqual("Not synchronized yet", vm.DisplayedCollector!.LastSyncCaption);
            TestApp.Render(window, "real-sync-signed-in");

            _home.Cloud.NextUpload = FakeCloud.Failure.Network;
            await vm.SyncNowCommand.ExecuteAsync(null);
            Assert.Equal("network", vm.ActiveSyncScenario!.Id);
            Assert.Contains(vm.SyncStateDetails, d => d.Label == "Pending");
            TestApp.Render(window, "real-sync-network");

            _home.Cloud.NextUpload = FakeCloud.Failure.Revoked;
            await vm.SyncNowCommand.ExecuteAsync(null);
            Assert.Equal("revoked", vm.ActiveSyncScenario!.Id);
            await vm.SectionStateActionCommand.ExecuteAsync("pair");
            Assert.True(vm.IsPairingPage);

            await vm.DisconnectCommand.ExecuteAsync(null);
            Assert.False(vm.HasDevice);
            Assert.Equal("Not signed in", vm.CloudSyncLabel);
        }
        finally { window.Close(); }
    }

    [AvaloniaFact]
    public async Task First_run_signs_in_checks_logs_and_completes_once()
    {
        using (var api = _home.Api())
        {
            var (vm, window) = await OpenAsync(api, setup: true);
            Assert.True(vm.IsFirstRunPage);
            Assert.False(vm.CanNavigate);
            Assert.All(window.GetVisualDescendants().OfType<Button>().Where(b => b.Classes.Contains("nav")), b => Assert.False(b.IsEffectivelyEnabled));
            TestApp.Render(window, "real-first-run");

            await vm.ContinueSetupCommand.ExecuteAsync(null); // đăng nhập Google
            Assert.True(vm.SetupRows[0].Completed);
            Assert.Contains("ana@example.com", vm.SetupMessage);
            await vm.ContinueSetupCommand.ExecuteAsync(null); // quét thư mục log
            Assert.True(vm.SetupRows[1].Completed);
            Assert.Contains("Reading Codex, Claude", vm.SetupMessage);
            Assert.Contains("9 events stored", vm.SetupMessage);
            TestApp.Render(window, "real-first-run-scanned");
            await vm.ContinueSetupCommand.ExecuteAsync(null);
            Assert.True(vm.IsOverview);
            Assert.True(vm.CanNavigate);
            window.Close();
        }
        using var again = _home.Api();
        var restarted = new MainViewModel(again, showSetupOnStart: true);
        await restarted.LoadCommand.ExecuteAsync(null);
        Assert.True(restarted.IsOverview); // không hiện lại setup
    }

    [AvaloniaFact]
    public async Task First_run_can_continue_without_google_and_be_skipped()
    {
        _home.Cloud.SignInFails = true;
        using var api = _home.Api();
        var (vm, window) = await OpenAsync(api, setup: true);
        try
        {
            await vm.ContinueSetupCommand.ExecuteAsync(null);
            Assert.False(vm.SetupRows[0].Completed);
            Assert.Contains("skip setup", vm.SetupMessage);
            Assert.True(vm.SkipSetupCommand.CanExecute(null));
            await vm.SkipSetupCommand.ExecuteAsync(null);
            Assert.True(vm.IsOverview);
            Assert.True(await api.IsSetupCompleteAsync());
        }
        finally { window.Close(); }
    }

    [AvaloniaFact]
    public async Task Settings_clear_data_and_background_sync_with_notifications()
    {
        using var api = _home.Api();
        var (vm, window) = await OpenAsync(api);
        try
        {
            await vm.ShowSettingsCommand.ExecuteAsync(null);
            Assert.DoesNotContain(window.GetVisualDescendants().OfType<ToggleSwitch>(), t => t.Name == "Automatic updates" ||
                Avalonia.Automation.AutomationProperties.GetName(t) == "Automatic updates");
            TestApp.Render(window, "real-settings");

            vm.BackgroundCollection = true; vm.UsageNotifications = true; vm.LaunchAtStartup = true;
            await vm.SaveSettingsCommand.ExecuteAsync(null);
            Assert.True(File.Exists(Path.Combine(_home.AutostartDirectory, "utoken.desktop")));

            var notes = new List<(string Title, bool Error)>();
            vm.NotificationRequested += (title, _, error) => notes.Add((title, error));
            await vm.SignInCommand.ExecuteAsync(null);
            await vm.BackgroundSyncAsync();
            Assert.Contains(notes, n => n.Title == "Usage synced" && !n.Error);
            _home.Cloud.NextUpload = FakeCloud.Failure.Revoked;
            await vm.BackgroundSyncAsync();
            Assert.Contains(notes, n => n.Title == "Sync needs attention" && n.Error);

            vm.RequestClearDataCommand.Execute(null);
            await vm.SettingsActionCommand.ExecuteAsync("clear");
            Assert.Contains("Cleared 9 usage events", vm.SettingsMessage);
            Assert.Equal(0, vm.Overview!.TotalTokens);
            Assert.Equal("empty", vm.OverviewStateId);
        }
        finally { window.Close(); }
    }

    [AvaloniaFact]
    public async Task Background_sync_is_off_unless_enabled()
    {
        using var api = _home.Api();
        var vm = new MainViewModel(api);
        await vm.LoadCommand.ExecuteAsync(null);
        vm.BackgroundCollection = false;
        await vm.SaveSettingsCommand.ExecuteAsync(null);
        await vm.SignInCommand.ExecuteAsync(null);
        await vm.BackgroundSyncAsync();
        Assert.Empty(_home.Cloud.Uploads);
    }

    public void Dispose() => _home.Dispose();
}
