using System.Text.Json.Nodes;
using Avalonia.Controls;
using Avalonia.Headless.XUnit;
using Avalonia.VisualTree;
using UToken.Desktop.App.Services;
using UToken.Desktop.App.ViewModels;
using UToken.Desktop.App.Views;
using Xunit;

namespace UToken.Desktop.Tests;

public class SyncStatesTests
{
    [AvaloniaFact]
    public async Task Sync_previews_render_without_changing_connection_or_usage()
    {
        var api = new MockDesktopApi();
        var vm = new MainViewModel(api);
        await vm.LoadCommand.ExecuteAsync(null);
        var window = new MainWindow { DataContext = vm };
        window.Show();
        while (vm.IsBusy) await Task.Delay(20);
        await vm.ShowSyncCommand.ExecuteAsync(null);
        var original = await api.GetSyncAsync();
        var tokens = (await api.GetOverviewAsync()).TotalTokens;
        var selector = window.FindControl<ComboBox>("SyncScenarioSelector")!;
        foreach (var id in new[] { "sync-failed", "not-paired", "syncing" })
        {
            selector.SelectedItem = vm.SyncPreviewOptions.Single(s => s.Id == id);
            Assert.Equal(id, vm.ActiveSyncScenario!.Id);
            Assert.True(vm.IsSyncDetailState);
            Assert.False(vm.IsSectionStatePreview);
            Assert.False(vm.IsSyncNormal);
            Assert.Contains(window.GetVisualDescendants().OfType<TextBlock>(), t => t.IsVisible && t.Text == vm.ActiveSyncScenario.Headline);
            DesktopDemoTests.Render(window, "sync-state-" + id);
            window.Width = 1020; window.Height = 650;
            DesktopDemoTests.Render(window, "sync-state-" + id + "-small");
            window.Width = 1180; window.Height = 760;
            Assert.False(DataValidationErrors.GetHasErrors(selector));
        }
        Assert.Equal(18, vm.SyncStateConfig!.Queue.Sum(q => q.Events));
        Assert.Equal(original, await api.GetSyncAsync());
        await vm.SectionStateActionCommand.ExecuteAsync("sync");
        Assert.True(vm.IsSyncNormal);
        selector.SelectedItem = vm.SyncPreviewOptions.Single(s => s.Id == "not-paired");
        await vm.SectionStateActionCommand.ExecuteAsync("pair");
        Assert.True(vm.IsPairingPage);
        Assert.False(vm.HasDevice);
        Assert.Equal(original.History, (await api.GetSyncAsync()).History);
        await vm.ShowSyncCommand.ExecuteAsync(null);
        Assert.Equal("not-paired", vm.ActiveSyncScenario!.Id);
        Assert.Equal(tokens, (await api.GetOverviewAsync()).TotalTokens);
        window.Close();
    }

    [AvaloniaFact]
    public async Task Sync_action_shows_progress_then_failure_and_can_retry_successfully()
    {
        var directory = Path.Combine(AppContext.BaseDirectory, "sync-state-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(directory);
        try
        {
            foreach (var file in Directory.EnumerateFiles(Path.Combine(AppContext.BaseDirectory, "MockData"), "*.json"))
                File.Copy(file, Path.Combine(directory, Path.GetFileName(file)));
            var path = Path.Combine(directory, "sync.json");
            var data = JsonNode.Parse(await File.ReadAllTextAsync(path))!;
            data["nextSync"]!["state"] = "failed";
            await File.WriteAllTextAsync(path, data.ToJsonString());
            var api = new MockDesktopApi(directory);
            var vm = new MainViewModel(api);
            await vm.LoadCommand.ExecuteAsync(null);
            await vm.ShowSyncCommand.ExecuteAsync(null);
            var history = vm.Sync!.History.Length;
            var task = vm.SyncNowCommand.ExecuteAsync(null);
            Assert.True(vm.IsSyncing);
            Assert.True(vm.IsSyncProgress);
            Assert.Equal("syncing", vm.ActiveSyncScenario!.Id);
            await task;
            Assert.False(vm.IsSyncing);
            Assert.True(vm.IsSyncFailure);
            Assert.Equal("sync-failed", vm.SelectedSyncScenario!.Id);
            Assert.Equal(history, vm.Sync.History.Length);
            await vm.SectionStateActionCommand.ExecuteAsync("retry");
            Assert.True(vm.IsSyncFailure);
            Assert.Equal(history, vm.Sync.History.Length);
            data["nextSync"]!["state"] = "success";
            await File.WriteAllTextAsync(path, data.ToJsonString());
            await vm.SectionStateActionCommand.ExecuteAsync("retry");
            Assert.True(vm.IsSyncNormal);
            Assert.Equal(history + 1, vm.Sync.History.Length);
            Assert.Equal("normal", vm.SelectedSyncScenario!.Id);
            await vm.DisconnectCommand.ExecuteAsync(null);
            Assert.Equal("not-paired", vm.ActiveSyncScenario!.Id);
        }
        finally
        {
            foreach (var file in Directory.EnumerateFiles(directory)) File.Delete(file);
            Directory.Delete(directory);
        }
    }
}
