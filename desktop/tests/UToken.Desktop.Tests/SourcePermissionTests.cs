using Avalonia.Controls;
using Avalonia.Headless.XUnit;
using Avalonia.VisualTree;
using UToken.Desktop.App.Services;
using UToken.Desktop.App.ViewModels;
using UToken.Desktop.App.Views;
using Xunit;

namespace UToken.Desktop.Tests;
public class SourcePermissionTests
{
    [AvaloniaFact]
    public async Task D10_renders_instructions_popup_and_both_retry_outcomes_preserve_usage()
    {
        var api = new MockDesktopApi();
        var vm = new MainViewModel(api);
        await vm.LoadCommand.ExecuteAsync(null);
        var tokens = vm.Overview!.TotalTokens;
        vm.ShowSourcesCommand.Execute(null);
        Assert.True(vm.IsSourcesNormal);
        var window = new MainWindow { DataContext = vm };
        window.Show();
        while (vm.IsBusy) await Task.Delay(20);
        var selector = window.FindControl<ComboBox>("PermissionScenarioSelector")!;
        selector.SelectedItem = vm.SourcePermission!.Config.Scenarios.Single(s => s.Id == "permission-denied");
        await vm.ChangePermissionScenarioCommand.ExecutionTask!;
        Assert.True(vm.IsPermissionRequired);
        Assert.False(vm.IsSourcesNormal);
        Assert.Equal("Gemini", vm.PermissionSource!.Name);
        Assert.Single(vm.PermissionProviders, p => p.MissingAccess);
        Assert.False((await api.GetSourceAsync("gemini")).Health.HasLogAccess);
        DesktopDemoTests.Render(window, "permission-required");
        window.Width = 1020; window.Height = 650;
        DesktopDemoTests.Render(window, "permission-required-small");
        foreach (var mode in new[] { "system", "guide" })
        {
            vm.ShowPermissionInstructionsCommand.Execute(mode);
            var popup = Assert.Single(window.OwnedWindows.OfType<DiagnosticsWindow>());
            var report = Assert.IsType<string>(popup.DataContext);
            Assert.Contains("Affected source: Gemini", report);
            Assert.Contains("\n", report);
            DesktopDemoTests.Render(popup, "permission-instructions-" + mode);
            popup.Close();
            Assert.True(vm.IsPermissionRequired);
        }
        var retry = vm.RetrySourcePermissionCommand.ExecuteAsync(null);
        Assert.True(vm.IsBusy);
        await retry;
        Assert.Null(vm.Error);
        Assert.True(vm.IsPermissionRequired);
        Assert.Contains("still denied", vm.Notice);
        Assert.True(vm.HasPermissionRetryFailure);
        Assert.Equal("#F04D57", vm.PermissionAccent);
        Assert.Equal("RETRY FAILED", vm.PermissionBadgeLabel);
        var alert = window.GetVisualDescendants().OfType<Border>().Single(b => b.Name == "PermissionRetryAlert");
        Assert.True(alert.IsVisible);
        DesktopDemoTests.Render(window, "permission-retry-failed");
        await vm.RescanSourcesCommand.ExecuteAsync(null);
        Assert.True(vm.IsPermissionRequired);
        Assert.True(vm.HasPermissionRetryFailure);
        Assert.True(alert.IsVisible);
        vm.DismissPermissionRetryFailureCommand.Execute(null);
        Assert.False(alert.IsVisible);
        Assert.False(vm.HasPermissionRetryFailure);
        Assert.True(vm.IsPermissionRequired);
        Assert.Equal("#FFAD38", vm.PermissionAccent);
        Assert.Equal("ACTION REQUIRED", vm.PermissionBadgeLabel);
        selector.SelectedItem = vm.SourcePermission!.Config.Scenarios.Single(s => s.Id == "permission-required");
        await vm.ChangePermissionScenarioCommand.ExecutionTask!;
        await vm.RetrySourcePermissionCommand.ExecuteAsync(null);
        Assert.Null(vm.Error);
        Assert.True(vm.IsSourcesNormal);
        Assert.False(vm.IsPermissionRequired);
        Assert.Equal("normal", vm.SelectedPermissionScenario!.Id);
        Assert.True((await api.GetSourceAsync("gemini")).Health.HasLogAccess);
        Assert.Equal(tokens, (await api.GetOverviewAsync()).TotalTokens);
        DesktopDemoTests.Render(window, "permission-restored");
        window.Close();
    }

    [Fact]
    public async Task Mock_permission_state_does_not_edit_fixtures_or_other_providers()
    {
        var path = Path.Combine(AppContext.BaseDirectory, "MockData", "sources.json");
        var original = await File.ReadAllTextAsync(path);
        var api = new MockDesktopApi();
        var data = await api.SetSourcePermissionScenarioAsync("permission-required");
        Assert.False(data.Sources.Sources.Single(s => s.Id == "gemini").Health.HasLogAccess);
        Assert.All(data.Sources.Sources.Where(s => s.Id != "gemini"), s => Assert.True(s.Health.HasLogAccess));
        await Assert.ThrowsAsync<InvalidDataException>(() => api.SetSourcePermissionScenarioAsync("invalid"));
        await Assert.ThrowsAsync<InvalidDataException>(() => api.RetrySourcePermissionAsync("invalid"));
        var restored = await api.RetrySourcePermissionAsync("gemini");
        Assert.All(restored.Sources.Sources, s => Assert.True(s.Health.HasLogAccess));
        Assert.Equal(original, await File.ReadAllTextAsync(path));
    }
}
