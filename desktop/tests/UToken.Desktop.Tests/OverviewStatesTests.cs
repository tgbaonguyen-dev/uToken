using Avalonia.Controls;
using Avalonia.Headless.XUnit;
using Avalonia.VisualTree;
using UToken.Desktop.App.Services;
using UToken.Desktop.App.ViewModels;
using UToken.Desktop.App.Views;
using Xunit;

namespace UToken.Desktop.Tests;
public class OverviewStatesTests
{
    [AvaloniaFact]
    public async Task Every_overview_state_renders_and_recovery_restores_normal_without_changing_usage()
    {
        var api = new MockDesktopApi();
        var vm = new MainViewModel(api);
        await vm.LoadCommand.ExecuteAsync(null);
        var tokens = vm.Overview!.TotalTokens;
        Assert.Equal(9, vm.OverviewScenarios.Length);
        var window = new MainWindow { DataContext = vm };
        window.Show();
        while (vm.IsBusy) await Task.Delay(20);
        var selector = window.FindControl<ComboBox>("OverviewScenarioSelector")!;
        Assert.Equal(new[] { "normal", "offline", "empty", "update" }, vm.OverviewPreviewOptions.Select(s => s.Id));
        Assert.Equal(4, selector.Items.Count);
        vm.SelectedOverviewScenario = vm.OverviewScenarios.Single(s => s.Id == "not-found");
        await vm.ChangeOverviewScenarioCommand.ExecutionTask!;
        Assert.Equal("normal", vm.SelectedOverviewScenario!.Id);
        Assert.True(vm.IsOverviewDashboard);
        foreach (var scenario in vm.OverviewPreviewOptions.Where(s => s.Id != "normal"))
        {
            selector.SelectedItem = scenario;
            await vm.ChangeOverviewScenarioCommand.ExecutionTask!;
            Assert.Null(vm.Error);
            Assert.True(vm.IsOverviewState);
            Assert.False(vm.IsOverviewDashboard);
            Assert.Equal(scenario.Id, vm.OverviewPreview!.Scenario.Id);
            Assert.Equal(scenario.Title, vm.PageTitle);
            Assert.False(DataValidationErrors.GetHasErrors(selector));
            Assert.Equal(tokens, vm.Overview.TotalTokens);
            Assert.Equal(scenario.EmptyUsage ? 0 : tokens, vm.OverviewPreview.Data.TotalTokens);
            DesktopDemoTests.Render(window, "overview-" + scenario.Id);
            Assert.Contains(window.GetVisualDescendants().OfType<TextBlock>(),
                t => t.IsVisible && t.Text == scenario.Headline);
            window.Width = 1020; window.Height = 650;
            DesktopDemoTests.Render(window, "overview-" + scenario.Id + "-small");
            window.Width = 1180; window.Height = 760;
        }
        await vm.OverviewStateActionCommand.ExecuteAsync("retry");
        Assert.True(vm.IsOverviewDashboard);
        Assert.Equal("normal", vm.SelectedOverviewScenario!.Id);
        Assert.Equal(tokens, (await api.GetOverviewAsync()).TotalTokens);
        window.Close();
    }

    [AvaloniaFact]
    public async Task State_actions_open_diagnostics_sources_and_unpaired_flow()
    {
        var api = new MockDesktopApi();
        var vm = new MainViewModel(api);
        await vm.LoadCommand.ExecuteAsync(null);
        vm.SelectedOverviewScenario = vm.OverviewScenarios.Single(s => s.Id == "offline");
        await vm.ChangeOverviewScenarioCommand.ExecutionTask!;
        Assert.Equal("Offline", vm.DisplayedCollector!.Label);
        await vm.OverviewStateActionCommand.ExecuteAsync("restart");
        Assert.True(vm.IsOverviewDashboard);
        Assert.Equal("Running", vm.DisplayedCollector.Label);
        vm.SelectedOverviewScenario = vm.OverviewScenarios.Single(s => s.Id == "offline");
        await vm.ChangeOverviewScenarioCommand.ExecutionTask!;
        var window = new MainWindow { DataContext = vm };
        window.Show();
        while (vm.IsBusy) await Task.Delay(20);
        await vm.OverviewStateActionCommand.ExecuteAsync("diagnostics");
        Assert.True(vm.IsOverview);
        Assert.Equal("offline", vm.OverviewPreview!.Scenario.Id);
        var popup = Assert.Single(window.OwnedWindows.OfType<DiagnosticsWindow>());
        Assert.True(popup.IsVisible);
        Assert.Contains("Runtime:", Assert.IsType<string>(popup.DataContext));
        DesktopDemoTests.Render(popup, "overview-diagnostics-popup");
        popup.Close();
        Assert.True(vm.IsOverview);
        Assert.Equal("offline", vm.SelectedOverviewScenario!.Id);
        vm.ShowOverviewCommand.Execute(null);
        await vm.OverviewStateActionCommand.ExecuteAsync("sources");
        Assert.True(vm.IsSources);
        vm.ShowOverviewCommand.Execute(null);
        await vm.OverviewStateActionCommand.ExecuteAsync("pair");
        Assert.True(vm.IsPairingPage);
        Assert.True(vm.CanEnterPairing);
        Assert.Null((await api.GetSyncAsync()).Device);
        Assert.True((await api.GetOverviewAsync()).TotalTokens > 0);
        window.Close();
    }

    [Fact]
    public async Task Unknown_state_fails_without_mutating_base_data()
    {
        var api = new MockDesktopApi();
        var before = await api.GetOverviewAsync();
        await Assert.ThrowsAsync<InvalidDataException>(() => api.GetOverviewPreviewAsync("invalid"));
        var empty = await api.GetOverviewPreviewAsync("empty");
        Assert.Empty(empty.Data.Activity);
        Assert.Equal(0, empty.Data.TotalTokens);
        Assert.Equal(0, empty.Data.EstimatedCost);
        Assert.Equal(0, empty.Data.Cached);
        var after = await api.GetOverviewAsync();
        Assert.Equal(before.TotalTokens, after.TotalTokens);
        Assert.Equal(before.Activity, after.Activity);
    }
}
