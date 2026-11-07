using System.Runtime.Versioning;

namespace UToken.Desktop.App.Services;

/// <summary>
/// "Launch at startup" thật: Linux dùng ~/.config/autostart/utoken.desktop (XDG), Windows dùng
/// HKCU\Software\Microsoft\Windows\CurrentVersion\Run. Chỉ ghi cho tài khoản hiện tại, không cần quyền admin.
/// </summary>
public sealed class StartupRegistration(string? linuxAutostartDirectory = null, string? executablePath = null)
{
    private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string AppName = "uToken";

    private string AutostartFile => Path.Combine(
        linuxAutostartDirectory ?? Path.Combine(
            Environment.GetEnvironmentVariable("XDG_CONFIG_HOME") is { Length: > 0 } x ? x
                : Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".config"),
            "autostart"),
        "utoken.desktop");

    /// <summary>Lệnh khởi động app. Khi chạy bằng "dotnet UToken.Desktop.App.dll" thì ghi cả dotnet lẫn đường dẫn dll.</summary>
    private string Command
    {
        get
        {
            var exe = executablePath ?? Environment.ProcessPath ?? "UToken.Desktop.App";
            var dll = Path.Combine(AppContext.BaseDirectory, "UToken.Desktop.App.dll");
            return Path.GetFileNameWithoutExtension(exe).Equals("dotnet", StringComparison.OrdinalIgnoreCase)
                ? $"\"{exe}\" \"{dll}\" --background"
                : $"\"{exe}\" --background";
        }
    }

    public bool IsSupported => OperatingSystem.IsWindows() || OperatingSystem.IsLinux() || linuxAutostartDirectory is not null;

    public bool IsEnabled()
    {
        if (OperatingSystem.IsWindows() && linuxAutostartDirectory is null) return WindowsIsEnabled();
        return File.Exists(AutostartFile);
    }

    public void Apply(bool enabled)
    {
        if (OperatingSystem.IsWindows() && linuxAutostartDirectory is null) { WindowsApply(enabled); return; }
        if (!enabled)
        {
            if (File.Exists(AutostartFile)) File.Delete(AutostartFile);
            return;
        }
        Directory.CreateDirectory(Path.GetDirectoryName(AutostartFile)!);
        File.WriteAllText(AutostartFile, $"""
            [Desktop Entry]
            Type=Application
            Name=uToken
            Comment=Track AI coding token usage
            Exec={Command}
            Terminal=false
            X-GNOME-Autostart-enabled=true

            """);
    }

    [SupportedOSPlatform("windows")]
    private static bool WindowsIsEnabled()
    {
        using var key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(RunKey);
        return key?.GetValue(AppName) is string;
    }

    [SupportedOSPlatform("windows")]
    private void WindowsApply(bool enabled)
    {
        using var key = Microsoft.Win32.Registry.CurrentUser.CreateSubKey(RunKey);
        if (enabled) key.SetValue(AppName, Command);
        else key.DeleteValue(AppName, throwOnMissingValue: false);
    }
}
