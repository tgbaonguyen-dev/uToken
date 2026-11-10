using Avalonia;

namespace UToken.Desktop.App;

internal static class Program
{
    [STAThread]
    public static int Main(string[] args)
    {
        if (args.Contains("--scan") || args.Contains("--judge"))
            return CliScan.Run(args); // chạy core không mở giao diện
        return BuildAvaloniaApp().StartWithClassicDesktopLifetime(args);
    }

    public static AppBuilder BuildAvaloniaApp() =>
        AppBuilder.Configure<App>()
            .UsePlatformDetect()
            .WithInterFont()
            // Binding đã được kiểm tra lúc build (compiled bindings); mức Warning chỉ còn "Value is null"
            // của view đang ẩn, ghi hàng nghìn dòng mỗi lần chuyển trang. Chỉ giữ lỗi thật.
            .LogToTrace(Avalonia.Logging.LogEventLevel.Error);
}
