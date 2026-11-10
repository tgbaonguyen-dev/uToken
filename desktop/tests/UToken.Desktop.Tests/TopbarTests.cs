using Avalonia.Headless.XUnit;
using UToken.Desktop.App.ViewModels;
using Xunit;

namespace UToken.Desktop.Tests;

public sealed class TopbarTests : IDisposable
{
    private readonly RealHome _home = new();

    [AvaloniaFact]
    public async Task Breadcrumb_shows_section_and_returns_to_it()
    {
        using var api = _home.Api();
        var vm = new MainViewModel(api);
        await vm.LoadCommand.ExecuteAsync(null);

        vm.ShowSourcesCommand.Execute(null);
        Assert.Equal("Sources", vm.SectionName);
        Assert.False(vm.IsSubPage);

        await vm.OpenSourceCommand.ExecuteAsync(vm.SourceList!.Sources[0]);
        Assert.True(vm.IsSubPage);
        Assert.Equal(vm.SourceList.Sources[0].Name, vm.PageTitle);
        await vm.GoToSectionCommand.ExecuteAsync(null);
        Assert.True(vm.IsSources);

        await vm.ShowActivityCommand.ExecuteAsync(null);
        Assert.Equal("Overview", vm.SectionName);
        await vm.GoToSectionCommand.ExecuteAsync(null);
        Assert.True(vm.IsOverview);
    }

    [AvaloniaFact]
    public async Task Topbar_sync_is_locked_during_setup()
    {
        using var api = _home.Api();
        var vm = new MainViewModel(api);
        await vm.LoadCommand.ExecuteAsync(null);
        Assert.True(vm.CanSyncFromTopbar);
        await vm.ShowFirstRunCommand.ExecuteAsync(null);
        Assert.False(vm.CanSyncFromTopbar);
        Assert.Equal("Setup", vm.SectionName);
    }

    public void Dispose() => _home.Dispose();
}
