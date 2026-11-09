using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Markup.Xaml;
using Avalonia.Platform;
using Avalonia.Threading;
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
            InitializeDesktop(desktop);
        }
        base.OnFrameworkInitializationCompleted();
    }

    private void InitializeDesktop(IClassicDesktopStyleApplicationLifetime desktop)
    {
            DesktopFirebaseConfig? firebase;
            try { firebase = DesktopFirebaseConfig.Load(); }
            catch (Exception ex) when (ex is System.Text.Json.JsonException or IOException or InvalidDataException or UnauthorizedAccessException)
            {
                if (desktop.MainWindow is not null) return;
                var retry = new Button { Content = "Retry configuration" };
                var message = new TextBlock { Text = "Firebase configuration could not load. Check firebase.desktop.json: ProjectId, ApiKey, Desktop OAuth client and UseEmulator: false. Fix the file, then retry.", TextWrapping = Avalonia.Media.TextWrapping.Wrap };
                desktop.MainWindow = new Window { Title = "uToken - Firebase configuration", Width = 560, Height = 260,
                    Content = new StackPanel { Margin = new Thickness(24), Spacing = 20, Children = { message, retry } } };
                retry.Click += (_, _) => { message.Text = "Rechecking firebase.desktop.json..."; InitializeDesktop(desktop); message.Text = "Configuration still could not load. Check the file and retry."; };
                return;
            }
            var previousWindow = desktop.MainWindow;
            var store = new LocalSettingsStore(LocalSettingsStore.DefaultDirectory);
            var uiState = new DesktopUiStateStore(store);
            var http = new HttpClient { Timeout = TimeSpan.FromSeconds(30) };
            var auth = firebase is null ? null : new DesktopGoogleAuth(firebase, http);
            var pairing = firebase is null ? null : new FirebasePairing(firebase, auth!, http);
            var vm = new MainViewModel(new MockDesktopApi(localSettings: store, realPairing: pairing), showSetupOnStart: true, uiStateStore: uiState, googleAuth: auth);
            var window = new MainWindow { DataContext = vm };
            var placementController = new WindowPlacementController(window, uiState);
            window.Closing += (_, _) => vm.SaveUiPreferences();
            desktop.Exit += (_, _) => { vm.SaveUiPreferences(); placementController.Save(); http.Dispose(); };
            desktop.MainWindow = window;
            if (previousWindow is not null) { window.Show(); previousWindow.Close(); }
            var refresh = new DispatcherTimer { Interval = TimeSpan.FromSeconds(4) };
            refresh.Tick += async (_, _) => await vm.RefreshPairingConnectionAsync();
            if (auth is not null) refresh.Start();
            desktop.Exit += (_, _) => refresh.Stop();
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
}
