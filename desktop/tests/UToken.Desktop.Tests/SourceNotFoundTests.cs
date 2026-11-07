using Avalonia.Controls;
using Avalonia.Headless.XUnit;
using UToken.Desktop.App.Services;
using UToken.Desktop.App.ViewModels;
using UToken.Desktop.App.Views;
using Xunit;

namespace UToken.Desktop.Tests;
public class SourceNotFoundTests
{
    [AvaloniaFact]
    public async Task Missing_sources_render_guide_and_rescan_can_stay_missing_or_recover()
    {
        var api = new MockDesktopApi();
        var vm = new MainViewModel(api);
        await vm.LoadCommand.ExecuteAsync(null);
        vm.ShowSourcesCommand.Execute(null);
        var tokens = vm.Overview!.TotalTokens;
        var original = await File.ReadAllTextAsync(Path.Combine(AppContext.BaseDirectory, "MockData", "sources.json"));
        var window = new MainWindow { DataContext = vm };
        window.Show();
        while (vm.IsBusy) await Task.Delay(20);
        var selector = window.FindControl<ComboBox>("PermissionScenarioSelector")!;
        selector.SelectedItem = vm.SourcePermission!.Config.Scenarios.Single(s => s.Id == "source-not-found");
        await vm.ChangePermissionScenarioCommand.ExecutionTask!;
        Assert.True(vm.IsSourceNotFound);
        Assert.False(vm.IsSourcesNormal);
        Assert.False(vm.IsPermissionRequired);
        Assert.All(vm.DiscoveryProviders, p => Assert.Equal("Not found", p.Label));
        DesktopDemoTests.Render(window, "sources-not-found");
        window.Width = 1020; window.Height = 650;
        DesktopDemoTests.Render(window, "sources-not-found-small");
        vm.ConfigureSourcesCommand.Execute(null);
        var popup = Assert.Single(window.OwnedWindows.OfType<DiagnosticsWindow>());
        Assert.Equal("Configure sources", popup.Title);
        Assert.Contains("Expected paths", Assert.IsType<string>(popup.DataContext));
        DesktopDemoTests.Render(popup, "sources-setup-guide");
        popup.Close();
        Assert.True(vm.IsSourceNotFound);
        await vm.RescanSourcesCommand.ExecuteAsync(null);
        Assert.True(vm.IsSourceNotFound);
        Assert.Contains("No supported source found", vm.Notice);
        Assert.All(vm.SourceScan!.Providers, p => Assert.Equal("not-found", p.State));
        selector.SelectedItem = vm.SourcePermission!.Config.Scenarios.Single(s => s.Id == "source-found-on-scan");
        await vm.ChangePermissionScenarioCommand.ExecutionTask!;
        Assert.True(vm.IsSourceNotFound);
        await vm.RescanSourcesCommand.ExecuteAsync(null);
        Assert.Null(vm.Error);
        Assert.True(vm.IsSourcesNormal);
        Assert.False(vm.IsSourceNotFound);
        Assert.Equal("normal", vm.SelectedPermissionScenario!.Id);
        Assert.All((await api.GetSourcesAsync()).Sources, s => Assert.Equal("Connected", s.StatusLabel));
        Assert.Equal(tokens, vm.Overview!.TotalTokens);
        Assert.Equal(original, await File.ReadAllTextAsync(Path.Combine(AppContext.BaseDirectory, "MockData", "sources.json")));
        window.Close();
    }

    [AvaloniaFact]
    public async Task Canceled_discovery_does_not_restore_sources()
    {
        var api = new MockDesktopApi();
        await api.SetSourcePermissionScenarioAsync("source-found-on-scan");
        var vm = new MainViewModel(api);
        await vm.LoadCommand.ExecuteAsync(null);
        vm.ShowSourcesCommand.Execute(null);
        var scan = vm.RescanSourcesCommand.ExecuteAsync(null);
        Assert.True(vm.IsScanningSources);
        vm.CancelSourceScanCommand.Execute(null);
        await scan;
        Assert.Null(vm.Error);
        Assert.True(vm.IsSourceNotFound);
        Assert.All((await api.GetSourcesAsync()).Sources, s => Assert.Equal("not_found", s.CollectorState));
    }

    [Fact]
    public async Task Empty_and_partial_results_choose_the_correct_sources_state()
    {
        var vm = new MainViewModel(new MockDesktopApi());
        await vm.LoadCommand.ExecuteAsync(null);
        vm.ShowSourcesCommand.Execute(null);
        var sources = vm.SourceList!;
        vm.SourceList = sources with { Sources = [] };
        Assert.True(vm.IsSourceNotFound);
        Assert.Equal(3, vm.DiscoveryProviders.Length);
        var partial = sources.Sources.ToArray();
        partial[0] = partial[0] with { CollectorState = "not_found", Health = partial[0].Health with { HasLogAccess = false } };
        vm.SourceList = sources with { Sources = partial };
        Assert.True(vm.IsSourcesNormal);
        Assert.False(vm.HasPermissionIssue);
        partial[1] = partial[1] with { Health = partial[1].Health with { HasLogAccess = false } };
        vm.SourceList = sources with { Sources = partial.ToArray() };
        Assert.True(vm.IsPermissionRequired);
        Assert.Equal("codex", vm.PermissionSource!.Id);
    }
}
