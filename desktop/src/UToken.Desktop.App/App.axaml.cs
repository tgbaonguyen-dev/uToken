using Avalonia;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Markup.Xaml;
using UToken.Desktop.App.ViewModels;
using UToken.Desktop.App.Views;
using UToken.Sync.Auth;
using System.Net.Http;

namespace UToken.Desktop.App;

public partial class App : Application
{
    private HttpClient? _authHttp;
    public override void Initialize() => AvaloniaXamlLoader.Load(this);

    public override void OnFrameworkInitializationCompleted()
    {
        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            // TODO(FR-SYNC-002): khởi động CollectorHost chạy nền + tray icon khi đóng cửa sổ.
            var settings = AppSettings.Load();
            _authHttp = new HttpClient { Timeout = TimeSpan.FromSeconds(30) };
            var auth = new FirebaseAuthService(_authHttp, settings.Firebase,
                new GoogleOAuthClient(_authHttp, settings.Firebase),
                new SecureRefreshTokenStore(AppSettings.DataDirectory, settings.Firebase.SessionKey));
            var viewModel = new MainViewModel(auth);
            var window = new MainWindow { DataContext = viewModel };
            window.Opened += async (_, _) => await viewModel.RestoreSessionCommand.ExecuteAsync(null);
            desktop.Exit += (_, _) => _authHttp.Dispose();
            desktop.MainWindow = window;
        }
        base.OnFrameworkInitializationCompleted();
    }
}
