using Avalonia;
using Avalonia.Controls;
using Avalonia.Headless.XUnit;
using UToken.Desktop.App.Services;
using Xunit;

namespace UToken.Desktop.Tests;
public class TrayMenuPlacementTests
{
    [Theory]
    [InlineData(1900, 1055, 160, 90, 0, 0, 1920, 1040, 1760, 942)]
    [InlineData(-100, 1055, 240, 135, -1920, 0, 1920, 1040, -240, 897)]
    [InlineData(500, 500, 160, 90, 0, 0, 1920, 1040, 500, 402)]
    [InlineData(5, 5, 160, 90, 0, 0, 1920, 1040, 5, 0)]
    public void Menu_is_above_anchor_and_inside_work_area(int x, int y, int width, int height,
        int left, int top, int areaWidth, int areaHeight, int expectedX, int expectedY)
    {
        Assert.Equal(new PixelPoint(expectedX, expectedY),
            TrayMenuPlacement.Above(new(x, y), new(width, height), new(left, top, areaWidth, areaHeight), 8));
    }

    [AvaloniaFact]
    public void Placement_targets_only_our_tray_popup()
    {
        using var registration = TrayMenuPlacement.Install("test-tray");
        var ordinary = new Window { Position = new PixelPoint(200, 200), Width = 160, Height = 90 };
        ordinary.Show();
        Assert.Equal(new PixelPoint(200, 200), ordinary.Position);
        var popup = new Window
        {
            Name = "AvaloniaTrayPopupRoot_test-tray", Position = new PixelPoint(500, 500),
            Width = 160, Height = 90, SystemDecorations = SystemDecorations.None,
        };
        popup.Show();
        popup.UpdateLayout();
        Assert.True(popup.Position.Y < 500);
        var position = popup.Position;
        popup.UpdateLayout();
        Assert.Equal(position, popup.Position);
        popup.Close();
        ordinary.Close();
    }
}
