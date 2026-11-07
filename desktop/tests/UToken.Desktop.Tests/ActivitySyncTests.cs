using System.Text.Json.Nodes;
using Avalonia.Controls;
using Avalonia.Headless.XUnit;
using Avalonia.Threading;
using Avalonia.VisualTree;
using UToken.Desktop.App.Models;
using UToken.Desktop.App.Services;
using UToken.Desktop.App.ViewModels;
using UToken.Desktop.App.Views;
using Xunit;

namespace UToken.Desktop.Tests;

public class ActivitySyncTests
{
    [Fact]
    public async Task Activity_filters_by_source_model_period_search_and_warning_status()
    {
        var api = new MockDesktopApi();
        Assert.Equal(9, (await api.GetActivityAsync(new())).Events.Length);
        Assert.Equal(10, (await api.GetActivityAsync(new(Period: "Last 7 days"))).Events.Length);
        Assert.All((await api.GetActivityAsync(new(Provider: "Claude"))).Events, e => Assert.Equal("Claude", e.Provider));
        Assert.Equal(3, (await api.GetActivityAsync(new(Model: "gpt-5.3-codex"))).Events.Length);
        Assert.Single((await api.GetActivityAsync(new(Search: "EVT_7F3A82"))).Events);
        Assert.Single((await api.GetActivityAsync(new(WarningsOnly: true))).Events);
        Assert.Empty((await api.GetActivityAsync(new(Search: "no such model"))).Events);
        var csv = await api.ExportActivityAsync(new(Provider: "Claude"));
        Assert.Equal(3, csv.Split('\n', StringSplitOptions.RemoveEmptyEntries).Length);
        Assert.DoesNotContain("Gemini", csv);
    }

    [Fact]
    public async Task Sync_failures_and_no_new_usage_do_not_add_success_history()
    {
        using var fixture = new JsonFixture();
        var api = new MockDesktopApi(fixture.Directory);
        var initial = await api.GetSyncAsync();
        foreach (var state in new[] { "failed", "no_new_usage" })
        {
            fixture.Edit("sync.json", root => root["nextSync"]!["state"] = state);
            var result = await api.SyncNowAsync();
            Assert.Equal(state, result.State);
            Assert.Equal(initial.History.Length, result.Data.History.Length);
        }
        fixture.Edit("sync.json", root => root["nextSync"]!["state"] = "success");
        Assert.Equal(initial.History.Length + 1, (await api.SyncNowAsync()).Data.History.Length);
        await api.DisconnectAsync();
        Assert.Equal("not_paired", (await api.SyncNowAsync()).State);
    }

    [Fact]
    public async Task Pairing_validates_digits_expiry_and_one_time_use()
    {
        var clock = new TestClock();
        var api = new MockDesktopApi(timeProvider: clock);
        await api.GetPairingInfoAsync();
        Assert.Equal("expired", (await api.PairDeviceAsync("482913")).State);
        await api.StartPairingAsync();
        foreach (var code in new[] { "", "12", "abcdef", "１２３４５６" })
            Assert.Equal("invalid", (await api.PairDeviceAsync(code)).State);
        Assert.Equal("rejected", (await api.PairDeviceAsync("111111")).State);
        Assert.Equal("expired", (await api.PairDeviceAsync("000000")).State);
        clock.Now = clock.Now.AddMinutes(11);
        Assert.Equal("expired", (await api.PairDeviceAsync("482913")).State);
        await api.StartPairingAsync();
        Assert.Equal("success", (await api.PairDeviceAsync("482913")).State);
        Assert.Equal("expired", (await api.PairDeviceAsync("482913")).State);
        Assert.NotNull((await api.GetSyncAsync()).Device);
    }

    [Fact]
    public async Task Connected_device_opens_information_until_disconnected()
    {
        var vm = new MainViewModel(new MockDesktopApi());
        await vm.ShowSyncCommand.ExecuteAsync(null);
        Assert.Equal("Device information", vm.PairingActionLabel);
        await vm.ShowPairingCommand.ExecuteAsync(null);
        Assert.True(vm.IsPaired);
        Assert.False(vm.CanEnterPairing);
        Assert.Equal("Device information", vm.PageTitle);
        Assert.Equal("connected", vm.PairingState);
        await vm.RestartPairingCommand.ExecuteAsync(null);
        await vm.PairDeviceCommand.ExecuteAsync(null);
        Assert.Equal("connected", vm.PairingState);
        await vm.LoadCommand.ExecuteAsync(null);
        Assert.False(vm.CanEnterPairing);
        await vm.ShowSyncCommand.ExecuteAsync(null);
        await vm.DisconnectCommand.ExecuteAsync(null);
        Assert.Equal("Pair new device", vm.PairingActionLabel);
        await vm.ShowPairingCommand.ExecuteAsync(null);
        Assert.True(vm.CanEnterPairing);
        Assert.Equal("Pair mobile device", vm.PageTitle);
        foreach (var (digit, value) in vm.PairingDigits.Zip("482913")) digit.Text = value.ToString();
        await vm.PairDeviceCommand.ExecuteAsync(null);
        Assert.True(vm.IsPaired);
        Assert.Equal("Collector connected", vm.PageTitle);
        Assert.Equal("#2EC790", vm.PairingMessageColor);
        await vm.ShowSyncCommand.ExecuteAsync(null);
        await vm.ShowPairingCommand.ExecuteAsync(null);
        Assert.False(vm.CanEnterPairing);
    }

    [Fact]
    public async Task Csv_escapes_quoted_fields_and_spreadsheet_formulas()
    {
        using var fixture = new JsonFixture();
        fixture.Edit("activity.json", root => root["events"]![0]!["provider"] = "=SUM(1,2)");
        fixture.Edit("activity.json", root => root["events"]![0]!["model"] = "model, \"quoted\"");
        var csv = await new MockDesktopApi(fixture.Directory).ExportActivityAsync(new());
        Assert.Contains("\"'=SUM(1,2)\"", csv);
        Assert.Contains("\"model, \"\"quoted\"\"\"", csv);
    }

    [AvaloniaFact]
    public async Task New_screens_render_filter_select_disconnect_and_pair_again()
    {
        var vm = new MainViewModel(new MockDesktopApi());
        await vm.LoadCommand.ExecuteAsync(null);
        var window = new MainWindow { DataContext = vm };
        window.Show();
        while (vm.IsBusy) await Task.Delay(20);
        await vm.ShowActivityCommand.ExecuteAsync(null);
        Assert.Null(vm.Error);
        Assert.Equal(9, vm.ActivityPage!.Events.Length);
        DesktopDemoTests.Render(window, "activity");
        var list = window.GetVisualDescendants().OfType<ListBox>().Single();
        list.SelectedItem = vm.ActivityPage.Events[1];
        Assert.Equal("Codex", vm.SelectedActivity!.Provider);
        vm.ActivitySearch = "nothing-matches";
        await vm.RefreshActivityCommand.ExecuteAsync(null);
        Assert.True(vm.IsActivityListEmpty);
        Assert.Null(vm.SelectedActivity);
        DesktopDemoTests.Render(window, "activity-empty");
        vm.ActivitySearch = "";
        await vm.ShowWarningsCommand.ExecuteAsync(null);
        Assert.Single(vm.ActivityPage.Events);
        DesktopDemoTests.Render(window, "activity-warnings");
        await vm.ShowSyncCommand.ExecuteAsync(null);
        Assert.True(vm.HasDevice);
        DesktopDemoTests.Render(window, "sync");
        var historyCount = vm.Sync!.History.Length;
        await vm.SyncNowCommand.ExecuteAsync(null);
        Assert.Equal(historyCount + 1, vm.Sync.History.Length);
        vm.RequestDisconnectCommand.Execute(null);
        Assert.True(vm.ConfirmDisconnect);
        vm.CancelDisconnectCommand.Execute(null);
        Assert.False(vm.ConfirmDisconnect);
        vm.RequestDisconnectCommand.Execute(null);
        await vm.DisconnectCommand.ExecuteAsync(null);
        Assert.True(vm.HasNoDevice);
        DesktopDemoTests.Render(window, "sync-disconnected");
        await vm.ShowPairingCommand.ExecuteAsync(null);
        DesktopDemoTests.Render(window, "pairing");
        var boxes = window.GetVisualDescendants().OfType<TextBox>().Where(b => b.DataContext is PairingDigit).ToArray();
        Assert.Equal(6, boxes.Length);
        boxes[0].Text = "111111";
        Dispatcher.UIThread.RunJobs();
        await vm.PairDeviceCommand.ExecuteAsync(null);
        Assert.Equal("rejected", vm.PairingState);
        DesktopDemoTests.Render(window, "pairing-rejected");
        boxes[0].Text = "000000";
        Dispatcher.UIThread.RunJobs();
        await vm.PairDeviceCommand.ExecuteAsync(null);
        Assert.Equal("expired", vm.PairingState);
        await vm.RestartPairingCommand.ExecuteAsync(null);
        boxes[0].Text = "482913";
        Dispatcher.UIThread.RunJobs();
        Assert.Equal("482913", string.Concat(vm.PairingDigits.Select(d => d.Text)));
        await vm.PairDeviceCommand.ExecuteAsync(null);
        Assert.True(vm.IsPaired);
        Assert.True(vm.HasDevice);
        DesktopDemoTests.Render(window, "pairing-success");
        await vm.ShowSyncCommand.ExecuteAsync(null);
        Assert.True(vm.HasDevice);
        window.Width = 1020; window.Height = 650;
        await Task.Delay(100);
        DesktopDemoTests.Render(window, "sync-small");
        await vm.ShowActivityCommand.ExecuteAsync(null);
        DesktopDemoTests.Render(window, "activity-small");
        await vm.ShowPairingCommand.ExecuteAsync(null);
        DesktopDemoTests.Render(window, "pairing-small");
        window.Close();
    }

    private sealed class TestClock : TimeProvider
    {
        public DateTimeOffset Now { get; set; } = DateTimeOffset.Parse("2026-11-06T15:00:00+07:00");
        public override DateTimeOffset GetUtcNow() => Now.ToUniversalTime();
    }

    private sealed class JsonFixture : IDisposable
    {
        public string Directory { get; } = Path.Combine(AppContext.BaseDirectory, "fixture-" + Guid.NewGuid().ToString("N"));
        public JsonFixture()
        {
            System.IO.Directory.CreateDirectory(Directory);
            foreach (var file in System.IO.Directory.EnumerateFiles(Path.Combine(AppContext.BaseDirectory, "MockData"), "*.json"))
                File.Copy(file, Path.Combine(Directory, Path.GetFileName(file)));
        }
        public void Edit(string file, Action<JsonNode> edit)
        {
            var path = Path.Combine(Directory, file);
            var root = JsonNode.Parse(File.ReadAllText(path))!;
            edit(root); File.WriteAllText(path, root.ToJsonString());
        }
        public void Dispose()
        {
            foreach (var file in System.IO.Directory.EnumerateFiles(Directory)) File.Delete(file);
            System.IO.Directory.Delete(Directory);
        }
    }
}
