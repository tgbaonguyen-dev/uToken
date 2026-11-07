using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Markup.Xaml;
using Avalonia.Platform;
using UToken.Desktop.App.Services;
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
            var vm = new MainViewModel(new MockDesktopApi(localSettings: store), showSetupOnStart: true, uiStateStore: uiState);
            var window = new MainWindow { DataContext = vm };
            var placementController = new WindowPlacementController(window, uiState);
            window.Closing += (_, _) => vm.SaveUiPreferences();
            desktop.Exit += (_, _) => { vm.SaveUiPreferences(); placementController.Save(); };
            desktop.MainWindow = window;
            TrayIcon? tray = null;
            // Only hide windows on platforms where this demo installs a native tray.
            if (OperatingSystem.IsWindows())
            {
                tray = new TrayIcon
                {
                    Icon = new WindowIcon(AssetLoader.Open(new Uri("avares://UToken.Desktop.App/Assets/tray.ico"))),
                    ToolTipText = "uToken - Desktop Companion (demo)",
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
}
