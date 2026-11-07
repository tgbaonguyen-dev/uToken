using Avalonia;
using Avalonia.Controls;
using Avalonia.Headless;
using Avalonia.Headless.XUnit;
using Avalonia.Threading;
using Avalonia.VisualTree;
using UToken.Desktop.App.Services;
using UToken.Desktop.App.ViewModels;
using UToken.Desktop.App.Views;
using Xunit;

[assembly: AvaloniaTestApplication(typeof(UToken.Desktop.Tests.TestApp))]
namespace UToken.Desktop.Tests;

public static class TestApp
{
    public static AppBuilder BuildAvaloniaApp() => AppBuilder.Configure<App.App>()
        .WithInterFont().UseSkia().UseHeadless(new AvaloniaHeadlessPlatformOptions { UseHeadlessDrawing = false });
}

public class DesktopDemoTests
{
    [AvaloniaFact]
    public async Task Demo_loads_json_navigates_each_source_and_renders_at_two_sizes()
    {
        var vm = new MainViewModel(new MockDesktopApi());
        await vm.LoadCommand.ExecuteAsync(null);
        Assert.Null(vm.Error);
        Assert.Equal(6_830_000, vm.SourceList!.Sources.Sum(s => s.Tokens));
        Assert.Equal(100, vm.SourceList.Sources.Sum(s => s.Share), 1);
        var window = new MainWindow { DataContext = vm };
        window.Show();
        // Opened reloads asynchronously, wait for it before exercising commands.
        while (vm.IsBusy) await Task.Delay(20);
        Render(window, "dashboard");
        vm.ShowSourcesCommand.Execute(null);
        Assert.True(vm.IsSources);
        Render(window, "sources");
        var sourceButtons = window.GetVisualDescendants().OfType<Button>().Where(b => b.Classes.Contains("source")).ToArray();
        Assert.Equal(3, sourceButtons.Length);
        Assert.All(sourceButtons, b =>
        {
            Assert.Same(vm.OpenSourceCommand, b.Command);
            Assert.IsType<App.Models.SourceData>(b.CommandParameter);
        });
        foreach (var source in vm.SourceList.Sources)
        {
            await vm.OpenSourceCommand.ExecuteAsync(source);
            Assert.True(vm.IsDetail);
            Assert.Equal(source.Name, vm.PageTitle);
            Assert.Contains(window.GetVisualDescendants().OfType<TextBlock>(), t => t.IsVisible && t.Text == source.TokenLabel);
            Render(window, source.Id);
            var selector = window.FindControl<ComboBox>("PeriodSelector")!;
            Assert.Equal("30 days", selector.SelectedItem);
            foreach (var period in new[] { "1 day", "Week", "Total", "30 days" })
            {
                selector.SelectedItem = period;
                Assert.NotNull(vm.ChangePeriodCommand.ExecutionTask);
                await vm.ChangePeriodCommand.ExecutionTask;
                Assert.Null(vm.Error);
                Assert.Equal(period, vm.SelectedPeriod);
                var expected = await new MockDesktopApi().GetSourceAsync(source.Id, period);
                Assert.Equal(expected.Tokens, vm.SelectedSource!.Tokens);
                Assert.Equal(expected.EstimatedCost, vm.SelectedSource.EstimatedCost);
                Assert.Equal(expected.Trend.Length, vm.SelectedSource.Trend.Length);
                Render(window, source.Id + "-" + period.Replace(' ', '-'));
            }
            vm.ShowSourcesCommand.Execute(null);
        }
        await vm.RescanSourcesCommand.ExecuteAsync(null);
        Assert.Contains("3 sources", vm.Notice);
        window.Width = 1020; window.Height = 650;
        await Task.Delay(100);
        Render(window, "sources-small");
        await vm.OpenSourceCommand.ExecuteAsync(vm.SourceList.Sources[0]);
        Render(window, "detail-small");
        window.Close();
    }

    internal static void Render(Window window, string name)
    {
        window.UpdateLayout();
        Dispatcher.UIThread.RunJobs();
        AvaloniaHeadlessPlatform.ForceRenderTimerTick();
        using var bitmap = window.CaptureRenderedFrame();
        Assert.NotNull(bitmap);
        var directory = Path.Combine(AppContext.BaseDirectory, "Screenshots");
        Directory.CreateDirectory(directory);
        bitmap.Save(Path.Combine(directory, name + ".png"));
    }

    [Fact]
    public async Task Api_supports_cancellation_and_unknown_source_errors()
    {
        var api = new MockDesktopApi();
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => api.GetSourcesAsync(cancellation.Token));
        await Assert.ThrowsAsync<InvalidDataException>(() => api.GetSourceAsync("missing"));
        await Assert.ThrowsAsync<InvalidDataException>(() => api.GetSourceAsync("gemini", "invalid"));
    }

    [Fact]
    public async Task Failed_period_change_restores_the_loaded_selection_and_data()
    {
        var vm = new MainViewModel(new MockDesktopApi());
        await vm.LoadCommand.ExecuteAsync(null);
        await vm.OpenSourceCommand.ExecuteAsync(vm.SourceList!.Sources[0]);
        var previous = vm.SelectedSource;
        vm.SelectedPeriod = "invalid";
        await vm.ChangePeriodCommand.ExecutionTask!;
        Assert.True(vm.HasError);
        Assert.False(vm.IsBusy);
        Assert.Equal("30 days", vm.SelectedPeriod);
        Assert.Same(previous, vm.SelectedSource);
        vm.SelectedPeriod = "Week";
        await vm.ChangePeriodCommand.ExecutionTask!;
        Assert.False(vm.HasError);
        Assert.NotEqual(previous!.Tokens, vm.SelectedSource!.Tokens);
    }

    [Fact]
    public async Task Missing_json_shows_error_and_allows_retry()
    {
        var vm = new MainViewModel(new MockDesktopApi(Path.Combine(AppContext.BaseDirectory, "missing")));
        await vm.LoadCommand.ExecuteAsync(null);
        Assert.True(vm.HasError);
        Assert.False(vm.IsBusy);
        await vm.LoadCommand.ExecuteAsync(null);
        Assert.True(vm.HasError);
        Assert.False(vm.IsBusy);
    }

    [Fact]
    public async Task Invalid_json_can_be_fixed_and_retried_then_empty_states_are_available()
    {
        var directory = Path.Combine(AppContext.BaseDirectory, "fixture-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(directory);
        try
        {
            var overviewFile = Path.Combine(directory, "overview.json");
            await File.WriteAllTextAsync(overviewFile, "{}");
            var vm = new MainViewModel(new MockDesktopApi(directory));
            await vm.LoadCommand.ExecuteAsync(null);
            Assert.True(vm.HasError);
            foreach (var file in Directory.EnumerateFiles(Path.Combine(AppContext.BaseDirectory, "MockData"), "*.json"))
                File.Copy(file, Path.Combine(directory, Path.GetFileName(file)), true);
            await vm.LoadCommand.ExecuteAsync(null);
            Assert.False(vm.HasError);
            vm.Overview = vm.Overview! with { Activity = [] };
            vm.SourceList = vm.SourceList! with { Sources = [] };
            Assert.True(vm.IsActivityEmpty);
            Assert.True(vm.IsSourceListEmpty);
        }
        finally
        {
            foreach (var file in Directory.EnumerateFiles(directory)) File.Delete(file);
            Directory.Delete(directory);
        }
    }
}
