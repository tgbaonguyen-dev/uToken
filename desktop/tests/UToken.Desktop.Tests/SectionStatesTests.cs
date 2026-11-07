using Avalonia.Controls;
using Avalonia.Headless.XUnit;
using UToken.Desktop.App.Models;
using UToken.Desktop.App.Services;
using UToken.Desktop.App.ViewModels;
using UToken.Desktop.App.Views;
using Xunit;

namespace UToken.Desktop.Tests;

public class SectionStatesTests
{
    [AvaloniaFact]
    public async Task Sources_and_sync_previews_render_in_their_own_sections_and_recover()
    {
        var api = new MockDesktopApi();
        var vm = new MainViewModel(api);
        var window = new MainWindow { DataContext = vm };
        window.Show();
        while (vm.IsBusy) await Task.Delay(20);
        var tokens = (await api.GetOverviewAsync()).TotalTokens;
        vm.ShowSourcesCommand.Execute(null);
        var sources = window.FindControl<ComboBox>("PermissionScenarioSelector")!;
        Assert.Contains(vm.SourcePreviewOptions, s => s.Id == "scanning");
        Assert.Contains(vm.SourcePreviewOptions, s => s.Id == "source-not-found");
        sources.SelectedItem = vm.SourcePreviewOptions.Single(s => s.Id == "scanning");
        Assert.True(vm.IsScanningSources);
        Assert.False(vm.CanNavigate);
        vm.CancelSourceScanCommand.Execute(null);
        await vm.ChangePermissionScenarioCommand.ExecutionTask!;
        Assert.False(vm.IsScanningSources);
        Assert.Equal("normal", vm.SelectedPermissionScenario!.Id);
        sources.SelectedItem = vm.SourcePreviewOptions.Single(s => s.Id == "up-to-date");
        await vm.ChangePermissionScenarioCommand.ExecutionTask!;
        Assert.True(vm.IsSourcesStatePreview);
        Assert.False(vm.IsSourcesNormal);
        Assert.False(vm.IsPermissionRequired);
        Assert.False(vm.IsSourceNotFound);
        Assert.Equal("Everything is up to date", vm.PageTitle);
        DesktopDemoTests.Render(window, "sources-no-new-usage");
        await vm.SectionStateActionCommand.ExecuteAsync("normal");
        Assert.True(vm.IsOverviewDashboard);
        await vm.ShowSyncCommand.ExecuteAsync(null);
        var sync = window.FindControl<ComboBox>("SyncScenarioSelector")!;
        Assert.Equal(new[] { "normal", "sync-failed", "not-paired", "syncing", "revoked", "network" }, vm.SyncPreviewOptions.Select(s => s.Id));
        foreach (var id in new[] { "network", "revoked" })
        {
            sync.SelectedItem = vm.SyncPreviewOptions.Single(s => s.Id == id);
            Assert.True(vm.IsSyncStatePreview);
            Assert.False(vm.IsSyncNormal);
            Assert.True(vm.IsSyncSection);
            DesktopDemoTests.Render(window, "sync-" + id);
            Assert.False(DataValidationErrors.GetHasErrors(sync));
            window.Width = 1020; window.Height = 650;
            DesktopDemoTests.Render(window, "sync-" + id + "-small");
            window.Width = 1180; window.Height = 760;
        }
        await vm.SectionStateActionCommand.ExecuteAsync("pair");
        Assert.True(vm.IsPairingPage);
        Assert.False(vm.HasDevice);
        Assert.False(vm.IsSectionStatePreview);
        await vm.ShowSyncCommand.ExecuteAsync(null);
        vm.SelectedSyncScenario = vm.SyncPreviewOptions.Single(s => s.Id == "network");
        await vm.SectionStateActionCommand.ExecuteAsync("retry");
        Assert.Equal("not-paired", vm.ActiveSyncScenario!.Id);
        Assert.Equal("not-paired", vm.SelectedSyncScenario!.Id);
        Assert.Equal(tokens, (await api.GetOverviewAsync()).TotalTokens);
        window.Close();
    }
}
