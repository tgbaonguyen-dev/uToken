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
        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            var store = new LocalSettingsStore(LocalSettingsStore.DefaultDirectory);
            var uiState = new DesktopUiStateStore(store);
            var api = CreateApi(store);
            desktop.Exit += (_, _) => api.Dispose();
            var vm = new MainViewModel(api, showSetupOnStart: true, uiStateStore: uiState);
            var window = new MainWindow { DataContext = vm };
            var placementController = new WindowPlacementController(window, uiState);
            window.Closing += (_, _) => vm.SaveUiPreferences();
            desktop.Exit += (_, _) => { vm.SaveUiPreferences(); placementController.Save(); };
            desktop.MainWindow = window;
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
        }
        base.OnFrameworkInitializationCompleted();
    }

    /// <summary>Dựng API dữ liệu thật: appsettings → SQLite trong thư mục dữ liệu của app → UsageEngine.</summary>
    private static RealDesktopApi CreateApi(LocalSettingsStore store)
    {
        var settings = AppSettings.Load();
        var codexHome = AppSettings.ExpandHome(settings.Collectors.CodexHome);
        var claudeHome = AppSettings.ExpandHome(settings.Collectors.ClaudeHome);
        var (engine, sqlite) = EngineFactory.Create(settings.DatabasePath, settings.Collectors.Enabled, codexHome, claudeHome);
        var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        var locations = RealDesktopApi.DefaultLocations(codexHome, claudeHome, home, settings.Collectors.Enabled);
        return new RealDesktopApi(engine, sqlite, locations, settings.DatabasePath, store);
    }
}
