using Avalonia.Controls;
using Avalonia.Headless;
using Avalonia.Headless.XUnit;
using Avalonia.Media;
using Avalonia.Threading;
using UToken.Desktop.App.ViewModels;
using UToken.Desktop.App.Views;
using Xunit;

namespace UToken.Desktop.Tests;

/// <summary>Chuyển trang: nội dung mờ dần + trượt vào, rồi kết thúc ở trạng thái đầy đủ (không kẹt mờ).</summary>
public sealed class PageTransitionTests : IDisposable
{
    private readonly RealHome _home = new();

    [AvaloniaFact]
    public async Task Rapid_navigation_does_not_leave_content_faded_or_scrolled()
    {
        using var api = _home.Api();
        var vm = new MainViewModel(api);
        var window = new MainWindow { DataContext = vm };
        window.Show();
        try
        {
            await TestApp.WaitIdle(vm);
            var host = window.FindControl<ScrollViewer>("PageHost")!;
            vm.ShowSourcesCommand.Execute(null);
            host.Offset = new Avalonia.Vector(0, 100);
            await vm.ShowSyncCommand.ExecuteAsync(null);
            vm.ShowSourcesCommand.Execute(null);
            // Check the user-visible final state; wall-clock sampling can miss a 180ms animation under load.
            for (var i = 0; i < 30; i++)
            {
                await Task.Delay(20);
                Dispatcher.UIThread.RunJobs();
                AvaloniaHeadlessPlatform.ForceRenderTimerTick();
            }
            Assert.Equal(default, host.Offset);
            Assert.Equal(1, host.Opacity, 3);
            Assert.Equal(0, ((TranslateTransform)host.RenderTransform!).Y, 3);
        }
        finally { window.Close(); }
    }

    public void Dispose() => _home.Dispose();
}
