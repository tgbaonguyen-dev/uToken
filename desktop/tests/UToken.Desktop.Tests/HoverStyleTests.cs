using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Presenters;
using Avalonia.Headless;
using Avalonia.Headless.XUnit;
using Avalonia.Input;
using Avalonia.Media;
using Avalonia.Threading;
using Avalonia.VisualTree;
using Xunit;

namespace UToken.Desktop.Tests;

/// <summary>Hover phải sáng lên khi rê vào và trả đúng màu khi rời ra (không kẹt, không tắt giữa chừng).</summary>
public sealed class HoverStyleTests
{
    private static Color? Background(Button button) =>
        (button.GetVisualDescendants().OfType<ContentPresenter>().First(c => c.Name == "PART_ContentPresenter")
            .Background as ISolidColorBrush)?.Color;

    private static void Settle()
    {
        for (var i = 0; i < 5; i++) { Dispatcher.UIThread.RunJobs(); AvaloniaHeadlessPlatform.ForceRenderTimerTick(); }
    }

    [AvaloniaTheory]
    [InlineData("", "#191C20", "#22262B")]
    [InlineData("nav", "#00FFFFFF", "#16181B")]
    [InlineData("primary", "#F3F4F7", "#FFFFFF")]
    public void Hover_applies_and_reverts(string cssClass, string rest, string hover)
    {
        var button = new Button { Content = "Button", Width = 120, Height = 40, HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Left, VerticalAlignment = Avalonia.Layout.VerticalAlignment.Top };
        if (cssClass.Length > 0) button.Classes.Add(cssClass);
        var window = new Window { Width = 300, Height = 120, Content = button };
        window.Show(); window.UpdateLayout();
        try
        {
            Settle();
            Assert.Equal(Color.Parse(rest), Background(button));
            window.MouseMove(new Point(40, 20), RawInputModifiers.None); Settle();
            Assert.True(button.IsPointerOver);
            Assert.Equal(Color.Parse(hover), Background(button));
            window.MouseMove(new Point(260, 100), RawInputModifiers.None); Settle();
            Assert.Equal(Color.Parse(rest), Background(button));
        }
        finally { window.Close(); }
    }
}
