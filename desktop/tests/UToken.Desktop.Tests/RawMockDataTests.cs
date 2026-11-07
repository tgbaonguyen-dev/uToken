using System.Text.Json.Nodes;
using UToken.Desktop.App.Models;
using UToken.Desktop.App.Services;
using UToken.Desktop.App.ViewModels;
using Xunit;

namespace UToken.Desktop.Tests;

public class RawMockDataTests
{
    [Fact]
    public async Task Overview_and_monthly_detail_use_the_same_numeric_source_data()
    {
        var api = new MockDesktopApi();
        var sources = await api.GetSourcesAsync();
        var overview = await api.GetOverviewAsync();
        Assert.Equal(6_830_000, overview.TotalTokens);
        Assert.Equal(42.18m, overview.EstimatedCost);
        Assert.Equal(33_400, overview.Cached);
        Assert.Equal(sources.Sources.Sum(s => s.Tokens), overview.TotalTokens);
        Assert.Equal(sources.Sources.Sum(s => s.EstimatedCost), overview.EstimatedCost);
        foreach (var source in sources.Sources)
        {
            var detail = await api.GetSourceAsync(source.Id);
            Assert.Equal(source.Tokens, detail.Tokens);
            Assert.Equal(source.ModelCount, detail.Models.Length);
            Assert.Equal(source.Tokens, detail.Models.Sum(m => m.Tokens));
            Assert.Equal(source.Tokens, detail.Trend.Sum(p => p.Tokens));
            Assert.Equal(144, detail.ChartBars.Max(b => b.Height), 5);
            Assert.All(detail.ChartBars, bar => Assert.InRange(bar.CachedHeight, 0, bar.Height));
        }
        var activity = await api.GetActivityAsync(new());
        Assert.Equal(activity.Events.Take(5).Select(e => e.TotalTokens), overview.Activity.Select(e => e.Tokens));
    }

    [Fact]
    public async Task Catalog_collector_and_source_health_are_independent_of_discovery()
    {
        using var fixture = new JsonFixture();
        fixture.Edit("sources.json", root =>
        {
            root["sources"]!.AsArray().RemoveAt(2);
            root["sources"]![0]!["health"]!["hasLogAccess"] = false;
            root["sources"]![0]!["collectorState"] = "permission_required";
        });
        fixture.Edit("overview.json", root => root["collector"]!["state"] = "stopped");
        var vm = new MainViewModel(new MockDesktopApi(fixture.Directory));
        await vm.LoadCommand.ExecuteAsync(null);
        Assert.Null(vm.Error);
        Assert.Equal(2, vm.SourceList!.Sources.Length);
        Assert.Equal(3, vm.SupportedSources.Length);
        Assert.Contains(vm.SupportedSources, s => s.Id == "claude");
        Assert.Equal("Stopped", vm.Overview!.Collector.Label);
        Assert.Equal("#9096A1", vm.Overview.Collector.Color);
        Assert.Equal("Permission required", vm.SourceList.Sources[0].CollectorHealthLabel);
        Assert.Equal("Permission required", (vm.SourceList.Sources[0] with { Health = vm.SourceList.Sources[0].Health with { HasLogAccess = true } }).StatusLabel);
        Assert.Equal("#F26039", vm.SourceList.Sources[0].StatusColor);
        Assert.Equal(vm.SourceList.Sources.Sum(s => s.Tokens), vm.Overview.TotalTokens);
        Assert.Equal(100, vm.SourceList.Sources.Sum(s => s.Share), 5);
    }

    [Fact]
    public async Task Paired_offline_device_stays_paired_and_cannot_add_sync_history()
    {
        using var fixture = new JsonFixture();
        fixture.Edit("sync.json", root => root["device"]!["isOnline"] = false);
        var api = new MockDesktopApi(fixture.Directory);
        var initial = await api.GetSyncAsync();
        var result = await api.SyncNowAsync();
        Assert.Equal("offline", result.State);
        Assert.NotNull(result.Data.Device);
        Assert.Equal("Offline", result.Data.Device.ConnectionLabel);
        Assert.Equal(initial.History.Length, result.Data.History.Length);
        Assert.Equal(initial.Device!.TransferredBytes, result.Data.Device.TransferredBytes);
        var vm = new MainViewModel(api);
        await vm.ShowPairingCommand.ExecuteAsync(null);
        Assert.True(vm.IsPaired);
        Assert.False(vm.CanEnterPairing);
    }

    [Fact]
    public async Task Successful_sync_increments_bytes_and_keeps_raw_timestamps()
    {
        var clock = new FixedClock();
        var api = new MockDesktopApi(timeProvider: clock);
        var initial = await api.GetSyncAsync();
        var result = await api.SyncNowAsync();
        Assert.Equal("success", result.State);
        Assert.Equal(initial.Device!.TransferredBytes + initial.NextSync.Bytes, result.Data.Device!.TransferredBytes);
        Assert.Equal(clock.GetUtcNow(), result.Data.Device.LastSyncAt);
        Assert.Equal(clock.GetUtcNow(), result.Data.History[0].OccurredAt);
        Assert.Equal("Just now", result.Data.Device.LastSync);
        Assert.Equal(result.Data.Device.LastSyncAt, (await api.GetOverviewAsync()).Collector.LastSyncAt);
    }

    [Fact]
    public async Task Empty_zero_usage_is_safe_and_invalid_cached_tokens_are_rejected()
    {
        var source = await new MockDesktopApi().GetSourceAsync("gemini");
        var zero = source with { Tokens = 0, Models = [], Trend = [], LastEventAt = null };
        Assert.Equal("0", zero.TokenLabel);
        Assert.Equal(0, zero.ModelCount);
        Assert.Empty(zero.ChartBars);
        Assert.Equal("No data", zero.LastEventLabel);
        var emptyBar = zero with { Trend = [new(source.PeriodStart, 0, 0)] };
        Assert.Equal(0, emptyBar.ChartBars[0].Height);
        Assert.Equal(0, emptyBar.ChartBars[0].CachedHeight);
        using var fixture = new JsonFixture();
        fixture.Edit("sources.json", root => root["sources"]![0]!["trend"]![0]!["cached"] = long.MaxValue);
        await Assert.ThrowsAsync<InvalidDataException>(() => new MockDesktopApi(fixture.Directory).GetSourcesAsync());
    }

    private sealed class FixedClock : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => DateTimeOffset.Parse("2026-11-06T08:10:00Z");
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
