using Avalonia.Controls;
using Avalonia.Headless.XUnit;
using Avalonia.VisualTree;
using UToken.Desktop.App.Services;
using UToken.Desktop.App.ViewModels;
using UToken.Desktop.App.Views;
using Xunit;

namespace UToken.Desktop.Tests;
public class SettingsTests
{
    [AvaloniaFact]
    public async Task Settings_render_save_reopen_reset_and_export_without_changing_usage()
    {
        var api = new MockDesktopApi();
        var vm = new MainViewModel(api);
        await vm.LoadCommand.ExecuteAsync(null);
        var tokens = vm.Overview!.TotalTokens;
        await vm.ShowSettingsCommand.ExecuteAsync(null);
        Assert.True(vm.IsSettingsPage);
        Assert.Equal("Settings", vm.PageTitle);
        var defaults = vm.Settings!.Values;
        var window = new MainWindow { DataContext = vm };
        window.Show();
        while (vm.IsBusy) await Task.Delay(20);
        DesktopDemoTests.Render(window, "settings");
        Assert.Equal(4, window.GetVisualDescendants().OfType<ToggleSwitch>().Count());
        vm.LaunchAtStartup = false; vm.RetentionDays = 7;
        await vm.SaveSettingsCommand.ExecuteAsync(null);
        Assert.Null(vm.Error);
        vm.ShowOverviewCommand.Execute(null);
        await vm.ShowSettingsCommand.ExecuteAsync(null);
        Assert.False(vm.LaunchAtStartup);
        Assert.Equal(7, vm.RetentionDays);
        vm.RequestClearDataCommand.Execute(null);
        Assert.True(vm.ConfirmClearData);
        vm.CancelClearDataCommand.Execute(null);
        Assert.False(vm.ConfirmClearData);
        await vm.OpenDiagnosticsCommand.ExecuteAsync(null);
        Assert.Contains("Mock usage service", vm.DiagnosticsReport);
        DesktopDemoTests.Render(window, "settings-diagnostics");
        Assert.Contains(window.GetVisualDescendants().OfType<SelectableTextBlock>(),
            text => text.IsVisible && text.Text == vm.DiagnosticsReport);
        vm.CloseDiagnosticsCommand.Execute(null);
        Assert.Equal(tokens, (await api.GetOverviewAsync()).TotalTokens);
        var csv = await vm.ExportSettingsCsvAsync();
        var events = (await api.GetActivityAsync(new(Period: "All time"))).Events
            .Concat((await api.GetActivityAsync(new(Period: "All time", WarningsOnly: true))).Events);
        Assert.All(events, item => Assert.Contains(item.Id, csv));
        await vm.ResetSettingsCommand.ExecuteAsync(null);
        Assert.Equal(defaults, vm.Settings!.Values);
        var selector = window.GetVisualDescendants().OfType<ComboBox>()
            .Single(c => c.Name == "RetentionSelector");
        foreach (var days in new[] { 7, 90, 30 })
        {
            selector.SelectedItem = days;
            Assert.Equal(days, vm.RetentionDays);
            await vm.ResetSettingsCommand.ExecuteAsync(null);
            Avalonia.Threading.Dispatcher.UIThread.RunJobs();
            Assert.Equal(defaults.RetentionDays, selector.SelectedItem);
            Assert.False(DataValidationErrors.GetHasErrors(selector));
        }
        window.Width = 1020; window.Height = 650;
        DesktopDemoTests.Render(window, "settings-small");
        window.Close();
    }

    [Fact]
    public async Task Invalid_retention_cannot_replace_saved_settings()
    {
        var api = new MockDesktopApi();
        var original = await api.GetSettingsAsync();
        await Assert.ThrowsAsync<InvalidDataException>(() =>
            api.SaveSettingsAsync(original.Values with { RetentionDays = -1 }));
        Assert.Equal(original.Values, (await api.GetSettingsAsync()).Values);
    }
}
