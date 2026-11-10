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
    public async Task Page_enter_animation_runs_and_settles()
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
            double minOpacity = 1, maxShift = 0;
            for (var i = 0; i < 30; i++)
            {
                await Task.Delay(10); Dispatcher.UIThread.RunJobs(); AvaloniaHeadlessPlatform.ForceRenderTimerTick();
                minOpacity = Math.Min(minOpacity, host.Opacity);
                maxShift = Math.Max(maxShift, ((TranslateTransform)host.RenderTransform!).Y);
            }
            Assert.InRange(minOpacity, 0, 0.9);
            Assert.InRange(maxShift, 1, 8);
            Assert.Equal(1, host.Opacity, 3);
            Assert.Equal(0, ((TranslateTransform)host.RenderTransform!).Y, 3);
        }
        finally { window.Close(); }
    }

    public void Dispose() => _home.Dispose();
}
