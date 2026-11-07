using Avalonia;
using Avalonia.Controls;

namespace UToken.Desktop.App.Services;

public sealed class WindowPlacementController
{
    private readonly Window _window;
    private readonly DesktopUiStateStore _store;
    private WindowPlacement _normal;
    private bool _restoring;
    private bool _opened;
    private bool _maximized;
    public WindowPlacementController(Window window, DesktopUiStateStore store)
    {
        _window = window; _store = store; _normal = store.State.Window;
        window.Opened += (_, _) => Restore();
        window.SizeChanged += (_, _) => CaptureNormal();
        window.PositionChanged += (_, _) => CaptureNormal();
        window.PropertyChanged += (_, e) =>
        {
            if (e.Property == Window.WindowStateProperty && window.WindowState != WindowState.Minimized)
                _maximized = window.WindowState == WindowState.Maximized;
        };
        window.Closing += (_, _) => Save();
    }
    private void CaptureNormal()
    {
        if (!_opened || _restoring || _window.WindowState != WindowState.Normal || _window.Bounds.Width <= 0 || _window.Bounds.Height <= 0) return;
        _normal = new(_window.Bounds.Width, _window.Bounds.Height, _window.Position.X, _window.Position.Y);
    }
    private void Restore()
    {
        if (_opened) return;
        _restoring = true;
        var saved = _store.State.Window;
        var screen = saved.X is { } x && saved.Y is { } y ? _window.Screens.ScreenFromPoint(new PixelPoint(x, y)) : null;
        screen ??= _window.Screens.Primary ?? _window.Screens.All.FirstOrDefault();
        var restored = screen is null ? saved : Fit(saved, screen.WorkingArea, screen.Scaling, _window.MinWidth, _window.MinHeight);
        _window.Width = Math.Max(_window.MinWidth, restored.Width);
        _window.Height = Math.Max(_window.MinHeight, restored.Height);
        if (restored.X is { } rx && restored.Y is { } ry) _window.Position = new PixelPoint(rx, ry);
        _normal = restored;
        if (saved.Maximized) _window.WindowState = WindowState.Maximized;
        _restoring = false; _opened = true;
    }
    public void Save()
    {
        CaptureNormal();
        _store.SaveWindow(_normal with { Maximized = _maximized });
    }
    public static WindowPlacement Fit(WindowPlacement value, PixelRect area, double scale, double minWidth, double minHeight)
    {
        if (area.Width <= 0 || area.Height <= 0 || !double.IsFinite(scale) || scale <= 0) return value;
        var width = Math.Clamp(value.Width, minWidth, Math.Max(minWidth, area.Width / scale));
        var height = Math.Clamp(value.Height, minHeight, Math.Max(minHeight, area.Height / scale));
        var right = Math.Max(area.X, area.Right - (int)Math.Ceiling(width * scale));
        var bottom = Math.Max(area.Y, area.Bottom - (int)Math.Ceiling(height * scale));
        return value with { Width = width, Height = height,
            X = Math.Clamp(value.X ?? area.X + (area.Width - (int)(width * scale)) / 2, area.X, right),
            Y = Math.Clamp(value.Y ?? area.Y + (area.Height - (int)(height * scale)) / 2, area.Y, bottom) };
    }
}
