using Microsoft.Extensions.Configuration;
using UToken.Sync;

namespace UToken.Desktop.App;

public sealed class SyncSettings
{
    public int IntervalMinutes { get; init; } = 15;
    public int MaxRetry { get; init; } = 5;
}

public sealed class SourceCollectorSettings
{
    public string CodexHome { get; init; } = "~/.codex";
    public string ClaudeHome { get; init; } = "~/.claude";
    // Để trống làm mặc định: binder nối thêm vào mảng có sẵn chứ không thay thế.
    public string[] Enabled { get; init; } = [];
}

public sealed class StorageSettings
{
    /// <summary>Tên file SQLite, nằm trong thư mục dữ liệu của app (xem DataDirectory).</summary>
    public string DatabaseFile { get; init; } = "utoken.db";
}

public sealed class AppSettings
{
    public FirebaseOptions Firebase { get; init; } = new();
    public SyncSettings Sync { get; init; } = new();
    public SourceCollectorSettings Collectors { get; init; } = new();
    public StorageSettings Storage { get; init; } = new();

    /// <summary>Windows: %LOCALAPPDATA%\uToken. Linux: ~/.local/share/uToken.</summary>
    public static string DataDirectory =>
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "uToken");

    public string DatabasePath => Path.Combine(DataDirectory, Storage.DatabaseFile);

    /// <summary>
    /// Thứ tự đọc (sau ghi đè trước): appsettings.json → appsettings.Local.json → biến môi trường UTOKEN_*.
    /// Ví dụ biến môi trường: UTOKEN_Firebase__UseEmulator=false
    /// </summary>
    public static AppSettings Load(string? baseDirectory = null)
    {
        var config = new ConfigurationBuilder()
            .SetBasePath(baseDirectory ?? AppContext.BaseDirectory)
            .AddJsonFile("appsettings.json", optional: false)
            .AddJsonFile("appsettings.Local.json", optional: true)
            .AddEnvironmentVariables("UTOKEN_")
            .Build();

        var settings = config.Get<AppSettings>() ?? new AppSettings();
        Directory.CreateDirectory(DataDirectory);
        return settings;
    }

    /// <summary>Đổi "~/..." thành đường dẫn thật trong thư mục home.</summary>
    public static string ExpandHome(string path) =>
        path.StartsWith('~')
            ? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), path.TrimStart('~', '/', '\\'))
            : path;
}
