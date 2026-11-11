using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Markup.Xaml;
using Avalonia.Platform;
using UToken.Desktop.App.Services;
using UToken.Engine;
using UToken.Desktop.App.ViewModels;
using UToken.Desktop.App.Views;

namespace UToken.Desktop.App;

public partial class App : Application
{
    public override void Initialize() => AvaloniaXamlLoader.Load(this);

    public override void OnFrameworkInitializationCompleted()
    {
        PressFeedback.Install();
        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            TryStartDesktop(desktop);
        }
        base.OnFrameworkInitializationCompleted();
    }

    private void TryStartDesktop(IClassicDesktopStyleApplicationLifetime desktop)
    {
        AppSettings settings;
        try { settings = AppSettings.Load(); }
        catch (Exception ex) when (ex is System.IO.IOException or UnauthorizedAccessException
            or InvalidOperationException or System.FormatException or System.Text.Json.JsonException)
        {
            var previous = desktop.MainWindow;
            var recovery = new ConfigurationRecoveryWindow(() => TryStartDesktop(desktop));
            desktop.MainWindow = recovery;
            if (previous is not null) { recovery.Show(); previous.Close(); }
            return;
        }
        StartDesktop(desktop, settings);
    }

    private void StartDesktop(IClassicDesktopStyleApplicationLifetime desktop, AppSettings settings)
    {
        var previous = desktop.MainWindow;
        var store = new LocalSettingsStore(LocalSettingsStore.DefaultDirectory);
        var uiState = new DesktopUiStateStore(store);
        ClickSound.Enabled = uiState.State.ClickSounds; // chỉ app thật; test headless không vào nhánh này
        var api = CreateApi(store, settings);
        desktop.Exit += (_, _) => api.Dispose();
        _ = api.UpdatePricesAsync(); // chạy nền; lỗi mạng chỉ ghi log, giá cũ vẫn dùng
        var vm = new MainViewModel(api, showSetupOnStart: true, uiStateStore: uiState);
        var window = new MainWindow { DataContext = vm };
        var placementController = new WindowPlacementController(window, uiState);
        window.Closing += (_, _) => vm.SaveUiPreferences();
        desktop.Exit += (_, _) => { vm.SaveUiPreferences(); placementController.Save(); };
        desktop.MainWindow = window;
        // Mở bởi autostart (--background): bắt đầu ở dạng thu nhỏ.
        if (Environment.GetCommandLineArgs().Contains("--background")) window.WindowState = WindowState.Minimized;
        // Thu thập nền: quét log và đẩy lên cloud theo chu kỳ Sync:IntervalMinutes khi Background collection bật.
        var backgroundTimer = new Avalonia.Threading.DispatcherTimer
        {
            Interval = TimeSpan.FromMinutes(Math.Clamp(settings.Sync.IntervalMinutes, 1, 24 * 60)),
        };
        backgroundTimer.Tick += async (_, _) => await vm.BackgroundSyncAsync();
        backgroundTimer.Start();
        var mobileRequestTimer = new Avalonia.Threading.DispatcherTimer { Interval = TimeSpan.FromSeconds(15) };
        mobileRequestTimer.Tick += async (_, _) => await vm.ServeMobileSyncRequestsAsync();
        mobileRequestTimer.Start();
        desktop.Exit += (_, _) => { backgroundTimer.Stop(); mobileRequestTimer.Stop(); };
        TrayIcon? tray = null;
        // Only hide windows on platforms where the app installs a native tray.
        if (OperatingSystem.IsWindows())
        {
            tray = new TrayIcon
            {
                Icon = new WindowIcon(AssetLoader.Open(new Uri("avares://UToken.Desktop.App/Assets/tray.ico"))),
                ToolTipText = "uToken - Desktop Companion",
                IsVisible = true,
            };
            TrayIcon.SetIcons(this, new TrayIcons { tray });
        }
        var controller = new DesktopWindowController(window, vm, () => desktop.Shutdown(), tray is not null);
        if (tray is not null)
        {
            var placement = TrayMenuPlacement.Install(tray.ToolTipText!);
            var open = new NativeMenuItem("Open uToken");
            open.Click += (_, _) => controller.Open();
            var quit = new NativeMenuItem("Quit");
            quit.Click += (_, _) => controller.Quit();
            tray.Menu = new NativeMenu { Items = { open, new NativeMenuItemSeparator(), quit } };
            tray.Clicked += (_, _) => controller.Open();
            desktop.Exit += (_, _) => { placement.Dispose(); tray.Dispose(); };
        }

        if (previous is not null) { desktop.MainWindow!.Show(); previous.Close(); }
    }


    /// <summary>
    /// Dựng API dữ liệu thật: appsettings → SQLite trong thư mục dữ liệu của app → UsageEngine;
    /// FirebaseCloudSync khi đã cấu hình OAuth client (appsettings.Local.json), nếu không thì chỉ dùng trên máy.
    /// </summary>
    private static RealDesktopApi CreateApi(LocalSettingsStore store, AppSettings settings)
    {
        var codexHome = AppSettings.ExpandHome(settings.Collectors.CodexHome);
        var claudeHome = AppSettings.ExpandHome(settings.Collectors.ClaudeHome);
        var (engine, sqlite) = EngineFactory.Create(settings.DatabasePath, settings.Collectors.Enabled, codexHome, claudeHome);
        var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        var locations = RealDesktopApi.DefaultLocations(codexHome, claudeHome, home, settings.Collectors.Enabled);

        Sync.ICloudSync? cloud = null;
        var problems = settings.Firebase.Validate();
        if (problems.Count == 0)
        {
            var http = new HttpClient { Timeout = TimeSpan.FromSeconds(30) };
            http.DefaultRequestHeaders.UserAgent.ParseAdd("uToken-desktop");
            cloud = new Sync.FirebaseCloudSync(http, settings.Firebase, Path.Combine(AppSettings.DataDirectory, "auth.json"));
        }
        else foreach (var p in problems) store.Record("Cloud sync disabled: " + p);

        return new RealDesktopApi(engine, sqlite, locations, settings.DatabasePath, store, cloud: cloud)
        {
            Startup = new StartupRegistration(),
            JudgeDirectory = AppSettings.DataDirectory,
        };
    }
}
