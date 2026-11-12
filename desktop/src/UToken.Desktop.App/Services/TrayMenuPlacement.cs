using Avalonia;
using Avalonia.Controls;

namespace UToken.Desktop.App.Services;

public static class TrayMenuPlacement
{
    public static IDisposable Install(string tooltip) =>
        Window.WindowOpenedEvent.AddClassHandler<Window>((window, _) =>
        {
            // shortcut: Avalonia 11.3 names its Win32 tray popup this way; review on framework upgrades.
            if (window.Name != "AvaloniaTrayPopupRoot_" + tooltip) return;
            var anchor = window.Position;
            void Reposition(object? sender, EventArgs args)
            {
                var screen = window.Screens.ScreenFromPoint(anchor) ?? window.Screens.Primary;
                if (screen is null || window.Bounds.Width <= 0 || window.Bounds.Height <= 0) return;
                var size = new PixelSize((int)Math.Ceiling(window.Bounds.Width * screen.Scaling),
                    (int)Math.Ceiling(window.Bounds.Height * screen.Scaling));
                var position = Above(anchor, size, screen.WorkingArea, (int)Math.Ceiling(8 * screen.Scaling));
                if (window.Position != position) window.Position = position;
            }
            window.LayoutUpdated += Reposition;
            window.Opened += Reposition;
            window.Closed += (_, _) =>
            {
                window.LayoutUpdated -= Reposition;
                window.Opened -= Reposition;
            };
        });

    public static PixelPoint Above(PixelPoint anchor, PixelSize size, PixelRect workArea, int gap)
    {
        var right = Math.Max(workArea.X, workArea.Right - size.Width);
        var bottom = Math.Max(workArea.Y, workArea.Bottom - size.Height);
        return new PixelPoint(Math.Clamp(anchor.X, workArea.X, right),
            Math.Clamp(Math.Min(anchor.Y - gap - size.Height, bottom - gap), workArea.Y, bottom));
    }
}
