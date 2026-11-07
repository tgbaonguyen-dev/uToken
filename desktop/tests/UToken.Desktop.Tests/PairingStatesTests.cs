using Avalonia.Controls;
using Avalonia.Headless.XUnit;
using Avalonia.VisualTree;
using UToken.Desktop.App.Services;
using UToken.Desktop.App.ViewModels;
using UToken.Desktop.App.Views;
using Xunit;

namespace UToken.Desktop.Tests;

public class PairingStatesTests
{
    [AvaloniaFact]
    public async Task Preview_states_render_without_changing_the_paired_device()
    {
        var api = new MockDesktopApi();
        var vm = new MainViewModel(api);
        await vm.LoadCommand.ExecuteAsync(null);
        var window = new MainWindow { DataContext = vm };
        window.Show();
        while (vm.IsBusy) await Task.Delay(20);
        await vm.ShowPairingCommand.ExecuteAsync(null);
        var before = await api.GetSyncAsync();
        var selector = window.FindControl<ComboBox>("PairingScenarioSelector")!;
        Assert.Equal(6, selector.Items.Count);
        foreach (var id in new[] { "waiting", "verifying", "expired", "rejected", "success" })
        {
            selector.SelectedItem = vm.PairingScenarios.Single(s => s.Id == id);
            Assert.Equal(id, vm.ActivePairingScenario!.Id);
            Assert.True(vm.IsPairingStateVisible);
            Assert.True(vm.IsPairingPreview);
            Assert.False(vm.IsPairingFormVisible);
            Assert.False(vm.ShowPairedDeviceSummary);
            DesktopDemoTests.Render(window, "pair-state-" + id);
            Assert.Contains(window.GetVisualDescendants().OfType<TextBlock>(), t => t.IsVisible && t.Text == vm.ActivePairingScenario.Headline);
            window.Width = 1020; window.Height = 650;
            DesktopDemoTests.Render(window, "pair-state-" + id + "-small");
            window.Width = 1180; window.Height = 760;
            Assert.False(DataValidationErrors.GetHasErrors(selector));
        }
        Assert.Equal(before, await api.GetSyncAsync());
        await vm.PairingStateActionCommand.ExecuteAsync("form");
        Assert.True(vm.IsPairingFormVisible);
        Assert.Equal("Device information", vm.PageTitle);
        window.Close();
    }

    [AvaloniaFact]
    public async Task Actual_pairing_transitions_verify_reject_expire_restart_and_succeed()
    {
        var api = new MockDesktopApi();
        var vm = new MainViewModel(api);
        await vm.LoadCommand.ExecuteAsync(null);
        await vm.ShowSyncCommand.ExecuteAsync(null);
        var history = vm.Sync!.History;
        var tokens = vm.Overview!.TotalTokens;
        await vm.DisconnectCommand.ExecuteAsync(null);
        await vm.ShowPairingCommand.ExecuteAsync(null);
        Assert.True(vm.IsPairingFormVisible);
        SetCode(vm, "111111");
        var verification = vm.PairDeviceCommand.ExecuteAsync(null);
        Assert.True(vm.IsBusy);
        Assert.True(vm.IsPairingVerifying);
        Assert.False(vm.IsPairingPreview);
        await verification;
        Assert.Equal("rejected", vm.ActivePairingScenario!.Id);
        Assert.Equal("rejected", vm.SelectedPairingScenario!.Id);
        Assert.False(vm.HasDevice);
        await vm.PairingStateActionCommand.ExecuteAsync("form");
        Assert.True(vm.IsPairingFormVisible);
        SetCode(vm, "000000");
        await vm.PairDeviceCommand.ExecuteAsync(null);
        Assert.Equal("expired", vm.ActivePairingScenario!.Id);
        await vm.PairingStateActionCommand.ExecuteAsync("restart");
        Assert.True(vm.IsPairingFormVisible);
        Assert.All(vm.PairingDigits, d => Assert.Empty(d.Text));
        SetCode(vm, "482913");
        await vm.PairDeviceCommand.ExecuteAsync(null);
        Assert.True(vm.IsPairingSuccess);
        Assert.True(vm.ShowPairedDeviceSummary);
        Assert.False(vm.IsPairingPreview);
        Assert.False(vm.CanEnterPairing);
        Assert.Equal(history, (await api.GetSyncAsync()).History);
        await vm.PairingStateActionCommand.ExecuteAsync("sync");
        Assert.True(vm.IsSyncPage);
        Assert.True(vm.HasDevice);
        await vm.ShowPairingCommand.ExecuteAsync(null);
        Assert.Equal("Device information", vm.PageTitle);
        Assert.True(vm.IsPairingFormVisible);
        Assert.Equal(tokens, (await api.GetOverviewAsync()).TotalTokens);
    }

    private static void SetCode(MainViewModel vm, string code)
    {
        foreach (var (digit, value) in vm.PairingDigits.Zip(code)) digit.Text = value.ToString();
    }
}
