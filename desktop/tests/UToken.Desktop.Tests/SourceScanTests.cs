using System.Text.Json.Nodes;
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
public class SourceScanTests
{
    [AvaloniaFact]
    public async Task Rescan_shows_progress_blocks_navigation_and_cancel_preserves_previous_results()
    {
        var vm = new MainViewModel(new MockDesktopApi());
        await vm.LoadCommand.ExecuteAsync(null);
        vm.ShowSourcesCommand.Execute(null);
        var window = new MainWindow { DataContext = vm };
        window.Show();
        while (vm.IsBusy) await Task.Delay(20);
        var previous = vm.SourceList;
        var scan = vm.RescanSourcesCommand.ExecuteAsync(null);
        Assert.True(vm.IsScanningSources);
        Assert.False(vm.CanNavigate);
        Assert.False(window.FindControl<Button>("RescanSourcesButton")!.IsEnabled);
        Assert.True(window.GetVisualDescendants().OfType<SourceScanView>().Single().IsVisible);
        var deadline = DateTime.UtcNow.AddSeconds(10);
        while (vm.SourceScan?.Providers.Any(p => p.State == "scanning") != true && DateTime.UtcNow < deadline)
            await Task.Delay(20);
        Assert.NotNull(vm.SourceScan);
        Assert.Equal(3, vm.SourceScan!.Total);
        Assert.Contains(vm.SourceScan.Providers, p => p.State == "scanning");
        DesktopDemoTests.Render(window, "sources-scanning");
        window.Width = 1020; window.Height = 650;
        DesktopDemoTests.Render(window, "sources-scanning-small");
        var cancel = window.GetVisualDescendants().OfType<Button>()
            .Single(b => b.Command == vm.CancelSourceScanCommand);
        var cancelPosition = cancel.TranslatePoint(default, window);
        Assert.NotNull(cancelPosition);
        Assert.True(cancelPosition!.Value.Y + cancel.Bounds.Height < window.ClientSize.Height);
        vm.ShowOverviewCommand.Execute(null);
        Assert.True(vm.IsSources);
        await vm.RescanSourcesCommand.ExecuteAsync(null);
        Assert.True(vm.IsScanningSources);
        vm.CancelSourceScanCommand.Execute(null);
        await scan;
        Assert.False(vm.IsScanningSources);
        Assert.False(vm.IsBusy);
        Assert.True(vm.CanNavigate);
        Assert.True(vm.IsSourcesNormal);
        Assert.Null(vm.Error);
        Assert.Same(previous, vm.SourceList);
        Assert.Contains("canceled", vm.Notice);
        window.Close();
    }

    [AvaloniaFact]
    public async Task Completed_scan_reports_permission_problem_and_returns_to_D10()
    {
        var api = new MockDesktopApi();
        await api.SetSourcePermissionScenarioAsync("permission-denied");
        var vm = new MainViewModel(api);
        await vm.LoadCommand.ExecuteAsync(null);
        vm.ShowSourcesCommand.Execute(null);
        var tokens = vm.Overview!.TotalTokens;
        Assert.True(vm.IsPermissionRequired);
        var scan = vm.RescanSourcesCommand.ExecuteAsync(null);
        Assert.True(vm.IsScanningSources);
        Assert.False(vm.IsPermissionRequired);
        await scan;
        Assert.False(vm.IsScanningSources);
        Assert.True(vm.IsPermissionRequired);
        Assert.Equal(3, vm.SourceScan!.Completed);
        Assert.Equal(100, vm.SourceScan.Percent);
        Assert.Contains(vm.SourceScan.Providers, p => p.Name == "Gemini" && p.State == "permission");
        Assert.Equal(tokens, vm.Overview!.TotalTokens);
        Assert.False(vm.PermissionSource!.Health.HasLogAccess);
    }

    [AvaloniaFact]
    public async Task Failed_scan_restores_previous_view_and_can_be_retried()
    {
        using var fixture = new ScanFixture();
        var vm = new MainViewModel(new MockDesktopApi(fixture.DirectoryPath));
        await vm.LoadCommand.ExecuteAsync(null);
        vm.ShowSourcesCommand.Execute(null);
        var previous = vm.SourceList;
        var path = Path.Combine(fixture.DirectoryPath, "source-scan.json");
        var valid = await File.ReadAllTextAsync(path);
        await File.WriteAllTextAsync(path, "{invalid");
        await vm.RescanSourcesCommand.ExecuteAsync(null);
        Assert.True(vm.HasError);
        Assert.False(vm.IsScanningSources);
        Assert.True(vm.CanNavigate);
        Assert.Same(previous, vm.SourceList);
        await File.WriteAllTextAsync(path, valid);
        await vm.RescanSourcesCommand.ExecuteAsync(null);
        Assert.Null(vm.Error);
        Assert.True(vm.IsSourcesNormal);
    }

    [Fact]
    public async Task Service_reports_ordered_snapshots_handles_zero_sources_and_cancellation()
    {
        using var fixture = new ScanFixture();
        var api = new MockDesktopApi(fixture.DirectoryPath);
        var snapshots = new List<SourceScanProgress>();
        var result = await api.RescanSourcesAsync(progress: new CaptureProgress(snapshots));
        Assert.Equal(3, result.Sources.Length);
        Assert.Equal(0, snapshots[0].Completed);
        Assert.Equal(3, snapshots[^1].Completed);
        Assert.All(snapshots[0].Providers, p => Assert.Equal("waiting", p.State));
        Assert.All(snapshots[^1].Providers, p => Assert.Equal("complete", p.State));
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => api.RescanSourcesAsync(cancellation.Token));
        var path = Path.Combine(fixture.DirectoryPath, "sources.json");
        var root = JsonNode.Parse(await File.ReadAllTextAsync(path))!;
        root["sources"] = new JsonArray();
        await File.WriteAllTextAsync(path, root.ToJsonString());
        snapshots.Clear();
        Assert.Empty((await api.RescanSourcesAsync(progress: new CaptureProgress(snapshots))).Sources);
        Assert.Equal(0, snapshots.Single().Percent);
    }

    private sealed class CaptureProgress(List<SourceScanProgress> snapshots) : IProgress<SourceScanProgress>
    {
        public void Report(SourceScanProgress value) => snapshots.Add(value);
    }

    private sealed class ScanFixture : IDisposable
    {
        public string DirectoryPath { get; } = Path.Combine(AppContext.BaseDirectory, "scan-" + Guid.NewGuid().ToString("N"));
        public ScanFixture()
        {
            Directory.CreateDirectory(DirectoryPath);
            foreach (var file in Directory.GetFiles(Path.Combine(AppContext.BaseDirectory, "MockData"), "*.json"))
                File.Copy(file, Path.Combine(DirectoryPath, Path.GetFileName(file)));
            var path = Path.Combine(DirectoryPath, "source-scan.json");
            var config = JsonNode.Parse(File.ReadAllText(path))!;
            config["stepDelayMs"] = 0;
            File.WriteAllText(path, config.ToJsonString());
        }
        public void Dispose()
        {
            foreach (var file in Directory.GetFiles(DirectoryPath)) File.Delete(file);
            Directory.Delete(DirectoryPath);
        }
    }
}
