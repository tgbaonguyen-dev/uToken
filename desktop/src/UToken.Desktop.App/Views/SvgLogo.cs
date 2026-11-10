using System.Collections.Concurrent;
using System.Globalization;
using Avalonia.Data.Converters;
using Avalonia.Media;
using Avalonia.Svg.Skia;
using Avalonia.Threading;

namespace UToken.Desktop.App.Views;

/// <summary>
/// Đổi đường dẫn logo (/Assets/x.svg) thành ảnh dùng chung. Svg.Path parse lại file mỗi lần gán,
/// tốn ~140ms lần đầu vào Sources; ở đây mỗi file chỉ parse một lần cho cả app.
/// Parse (SvgSource) chạy được trên thread nền; SvgImage là AvaloniaObject nên chỉ tạo trên UI thread.
/// </summary>
public sealed class SvgLogo : IValueConverter
{
    public static readonly SvgLogo Instance = new();
    private static readonly ConcurrentDictionary<string, Lazy<SvgSource?>> Sources = new();
    private static readonly Dictionary<string, IImage?> Images = new(); // chỉ truy cập trên UI thread

    public object? Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        if (value is not string { Length: > 0 } path) return null;
        Dispatcher.UIThread.VerifyAccess();
        if (Images.TryGetValue(path, out var image)) return image;
        var source = SourceOf(path);
        image = source is null ? null : new SvgImage { Source = source };
        Images[path] = image;
        return image;
    }

    /// <summary>Parse sẵn logo trên thread nền khi cửa sổ vừa mở, để lần đầu vào Sources không khựng.</summary>
    public static Task WarmAsync(params string[] ids) => Task.Run(() =>
    {
        foreach (var id in ids) _ = SourceOf($"/Assets/{id}.svg");
    });

    private static SvgSource? SourceOf(string path) =>
        Sources.GetOrAdd(path, p => new Lazy<SvgSource?>(() => Parse(p))).Value;

    private static SvgSource? Parse(string path)
    {
        try { return SvgSource.Load("avares://UToken.Desktop.App" + path, null); }
        catch (Exception ex) when (ex is IOException or ArgumentException or UriFormatException) { return null; } // file thiếu/hỏng
    }

    public object? ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture) => throw new NotSupportedException();
}
