using System.Reflection;
using Avalonia.Headless.XUnit;
using UToken.Desktop.App.Models;
using UToken.Desktop.App.Services;
using UToken.Desktop.App.ViewModels;
using Xunit;

namespace UToken.Desktop.Tests;

public class NavigationRaceTests : IDisposable
{
    private readonly RealHome _home = new();
    public class DelayedApi : DispatchProxy
    {
        public IDesktopApi Inner = null!;
        public Func<MethodInfo, object?[], object?>? Delay;
        protected override object? Invoke(MethodInfo? method, object?[]? args) =>
            Delay?.Invoke(method!, args ?? []) ?? method!.Invoke(Inner, args);
    }
    private static IDesktopApi Wrap(IDesktopApi api, out DelayedApi delayed)
    {
        var proxy = DispatchProxy.Create<IDesktopApi, DelayedApi>();
        delayed = (DelayedApi)proxy; delayed.Inner = api; return proxy;
    }
    [AvaloniaFact]
    public async Task Restored_upload_time_reaches_the_topbar_and_clears_on_sign_out()
    {
        var uploaded = _home.Clock.Now;
        using (var first = _home.Api())
        {
            await first.SignInAsync();
            await first.SyncNowAsync();
        }
        _home.Clock.Now += TimeSpan.FromHours(1);
        using var api = _home.Api();
        var vm = new MainViewModel(api);
        await vm.LoadCommand.ExecuteAsync(null);
        Assert.Equal(uploaded, vm.DisplayedCollector!.LastSyncAt);
        await vm.DisconnectCommand.ExecuteAsync(null);
        Assert.Null(vm.DisplayedCollector!.LastSyncAt);
    }

    [AvaloniaFact]
    public async Task Old_activity_response_cannot_replace_new_filter_or_return_after_navigation()
    {
        using var api = _home.Api();
        var vm = new MainViewModel(Wrap(api, out var delayed));
        await vm.LoadCommand.ExecuteAsync(null);
        var oldData = await api.GetActivityAsync(new());
        var pending = new TaskCompletionSource<ActivityPageData>();
        delayed.Delay = (method, _) => method.Name == nameof(IDesktopApi.GetActivityAsync) ? pending.Task : null;
        var first = vm.ShowActivityCommand.ExecuteAsync(null);
        delayed.Delay = null;
        await vm.ShowWarningsCommand.ExecuteAsync(null);
        var latest = vm.ActivityPage;
        pending.SetResult(oldData);
        await first;
        Assert.Same(latest, vm.ActivityPage);
        Assert.True(vm.WarningsOnly);
        pending = new();
        delayed.Delay = (method, _) => method.Name == nameof(IDesktopApi.GetActivityAsync) ? pending.Task : null;
        var refresh = vm.RefreshActivityCommand.ExecuteAsync(null);
        vm.ShowSourcesCommand.Execute(null);
        pending.SetResult(oldData);
        await refresh;
        Assert.True(vm.IsSources);
        Assert.Same(latest, vm.ActivityPage);
    }
    [AvaloniaFact]
    public async Task Old_account_read_cannot_restore_signed_out_ui()
    {
        using var api = _home.Api();
        await api.SignInAsync();
        var vm = new MainViewModel(Wrap(api, out var delayed));
        await vm.LoadCommand.ExecuteAsync(null);
        var oldData = await api.GetSyncAsync();
        var pending = new TaskCompletionSource<SyncData>();
        var entered = new TaskCompletionSource();
        delayed.Delay = (method, _) =>
        {
            if (method.Name != nameof(IDesktopApi.GetSyncAsync)) return null;
            entered.SetResult(); return pending.Task;
        };
        var load = vm.ShowPairingCommand.ExecuteAsync(null);
        await entered.Task;
        delayed.Delay = null;
        await vm.DisconnectCommand.ExecuteAsync(null);
        pending.SetResult(oldData);
        await load;
        Assert.False(vm.HasDevice);
        Assert.Equal("waiting", vm.PairingState);
    }
    [AvaloniaFact]
    public async Task Old_source_response_cannot_replace_a_new_period()
    {
        using var api = _home.Api();
        var vm = new MainViewModel(Wrap(api, out var delayed));
        await vm.LoadCommand.ExecuteAsync(null);
        vm.SelectedPeriod = "Week";
        var source = vm.SourceList!.Sources[0];
        var week = await api.GetSourceAsync(source.Id, "Week");
        var pending = new TaskCompletionSource<SourceData>();
        delayed.Delay = (method, _) => method.Name == nameof(IDesktopApi.GetSourceAsync) ? pending.Task : null;
        var first = vm.OpenSourceCommand.ExecuteAsync(source);
        delayed.Delay = null;
        vm.SelectedPeriod = "1 day";
        await vm.ChangePeriodCommand.ExecutionTask!;
        var latest = vm.SelectedSource;
        pending.SetResult(week);
        await first;
        Assert.Same(latest, vm.SelectedSource);
        Assert.Equal("1 day", vm.SelectedPeriod);
    }
    [AvaloniaFact]
    public async Task Mobile_sync_blocks_manual_background_and_duplicate_polls_then_releases_busy()
    {
        using var api = _home.Api();
        var vm = new MainViewModel(Wrap(api, out var delayed));
        await vm.LoadCommand.ExecuteAsync(null);
        var pending = new TaskCompletionSource<SyncResult?>();
        var polls = 0;
        var syncs = 0;
        delayed.Delay = (method, _) =>
        {
            if (method.Name == nameof(IDesktopApi.SyncNowAsync)) syncs++;
            if (method.Name != nameof(IDesktopApi.ServeMobileSyncRequestsAsync)) return null;
            polls++;
            return pending.Task;
        };
        var serving = vm.ServeMobileSyncRequestsAsync();
        Assert.True(vm.IsBusy);
        await vm.SyncNowCommand.ExecuteAsync(null);
        await vm.BackgroundSyncAsync();
        await vm.ServeMobileSyncRequestsAsync();
        Assert.Equal(0, syncs);
        Assert.Equal(1, polls);
        pending.SetException(new HttpRequestException("offline"));
        await serving;
        Assert.False(vm.IsBusy);
        delayed.Delay = null;
        await vm.SyncNowCommand.ExecuteAsync(null);
        Assert.False(vm.IsBusy);
        Assert.Null(vm.Error);
    }

    [AvaloniaFact]
    public async Task Mobile_sync_refreshes_sources_and_open_provider_without_changing_period()
    {
        using var api = _home.Api();
        var vm = new MainViewModel(Wrap(api, out var delayed));
        await vm.LoadCommand.ExecuteAsync(null);
        await vm.OpenSourceCommand.ExecuteAsync(vm.SourceList!.Sources.Single(s => s.Id == "claude"));
        vm.SelectedPeriod = "Week";
        if (vm.ChangePeriodCommand.ExecutionTask is { } loading) await loading;
        var before = vm.SelectedSource!.Tokens;
        _home.AddClaudeUsage(2);
        var result = await api.SyncNowAsync();
        delayed.Delay = (method, _) => method.Name == nameof(IDesktopApi.ServeMobileSyncRequestsAsync)
            ? Task.FromResult<SyncResult?>(result) : null;
        await vm.ServeMobileSyncRequestsAsync();
        Assert.True(vm.SelectedSource!.Tokens > before);
        Assert.Equal("Week", vm.SelectedPeriod);
        Assert.Equal("claude", vm.SelectedSource.Id);
        Assert.Equal(vm.SourceList!.Sources.Sum(s => s.Tokens), vm.Overview!.TotalTokens);
        Assert.False(vm.IsBusy);
    }

    public void Dispose() => _home.Dispose();
}
