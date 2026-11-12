using Avalonia;
using Avalonia.Controls;
using Avalonia.Headless;
using Avalonia.Headless.XUnit;
using Avalonia.Input;
using Avalonia.Threading;
using Xunit;
using Xunit.Abstractions;

namespace UToken.Desktop.Tests;

/// <summary>Bấm nút: co lại trong lúc animation rồi trở về đúng kích thước, nút vẫn Click bình thường.</summary>
public sealed class PressFeedbackTests(ITestOutputHelper output)
{
    private static double ScaleOf(Button b) => (b.RenderTransform as Avalonia.Media.ScaleTransform)?.ScaleX ?? 1;

    [AvaloniaFact]
    public async Task Press_bounces_and_returns_to_normal_size()
    {
        UToken.Desktop.App.Views.PressFeedback.Install();
        int clicks = 0;
        var button = new Button { Content = "Go", Width = 120, Height = 40, HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Left, VerticalAlignment = Avalonia.Layout.VerticalAlignment.Top };
        button.Click += (_, _) => clicks++;
        var window = new Window { Width = 300, Height = 120, Content = button };
        window.Show(); window.UpdateLayout();
        try
        {
            window.MouseDown(new Point(40, 20), MouseButton.Left);
            double min = 1;
            for (var i = 0; i < 30; i++)
            {
                await Task.Delay(10);
                Dispatcher.UIThread.RunJobs(); AvaloniaHeadlessPlatform.ForceRenderTimerTick();
                min = Math.Min(min, ScaleOf(button));
            }
            window.MouseUp(new Point(40, 20), MouseButton.Left);
            for (var i = 0; i < 10; i++) { await Task.Delay(10); Dispatcher.UIThread.RunJobs(); AvaloniaHeadlessPlatform.ForceRenderTimerTick(); }
            output.WriteLine($"min scale {min}, end {ScaleOf(button)}");
            Assert.InRange(min, 0.9, 0.99);
            Assert.Equal(1, ScaleOf(button), 3);
            Assert.Equal(1, clicks);
        }
        finally { window.Close(); }
    }
}
