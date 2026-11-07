using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Avalonia.Threading;
using UToken.Sync.Auth;

namespace UToken.Desktop.App.ViewModels;

/// <summary>Màn D02 Overview (FR-ACT-001). Các màn khác: Sources, Sync, Settings.</summary>
public partial class MainViewModel : ObservableObject
{
    private readonly IAuthService _auth;
    [ObservableProperty] private string _status = "Chưa đăng nhập";
    [ObservableProperty] private long _totalTokens;
    [ObservableProperty] private string _lastSync = "Chưa đồng bộ";
    [ObservableProperty] private string _account = "";
    [ObservableProperty] private string _authMessage = "Đăng nhập cùng tài khoản Google trên desktop và điện thoại.";
    [ObservableProperty] private bool _isSignedIn;
    [ObservableProperty] private bool _authBusy;
    [ObservableProperty] private bool _retrySignOut;

    public MainViewModel(IAuthService auth)
    {
        _auth = auth;
        _auth.UserChanged += (_, _) => Dispatcher.UIThread.Post(UpdateAccount);
    }

    private void UpdateAccount()
    {
        IsSignedIn = _auth.CurrentUser is not null;
        Account = _auth.CurrentUser?.Email ?? _auth.CurrentUser?.DisplayName ?? "";
        Status = IsSignedIn ? "Đã đăng nhập · Chưa ghép nối" : "Chưa đăng nhập";
    }

    [RelayCommand]
    private Task RestoreSessionAsync(CancellationToken ct) => RunAuthAsync(() => _auth.RestoreSessionAsync(ct));

    [RelayCommand(IncludeCancelCommand = true)]
    private Task SignInAsync(CancellationToken ct) => RunAuthAsync(() => _auth.SignInWithGoogleAsync(ct));

    [RelayCommand]
    private async Task SignOutAsync(CancellationToken ct)
    {
        if (AuthBusy) return;
        RetrySignOut = !await RunAuthAsync(() => _auth.SignOutAsync(ct));
        if (RetrySignOut && !IsSignedIn)
            AuthMessage = "Phiên đã khóa trên ứng dụng nhưng chưa xóa được phiên đã lưu. Hãy thử đăng xuất lại.";
    }

    private async Task<bool> RunAuthAsync(Func<Task> action)
    {
        if (AuthBusy) return false;
        AuthBusy = true;
        AuthMessage = "Đang xử lý đăng nhập…";
        try
        {
            await action();
            UpdateAccount();
            AuthMessage = IsSignedIn ? "Đăng nhập thành công. Bạn có thể tiếp tục ghép nối." : "Đăng nhập cùng tài khoản Google trên desktop và điện thoại.";
            return true;
        }
        catch (AuthException ex) { AuthMessage = ex.Message; }
        catch (OperationCanceledException) { AuthMessage = "Đã hủy hoặc hết thời gian đăng nhập. Vui lòng thử lại."; }
        catch (HttpRequestException) { AuthMessage = "Không kết nối được dịch vụ đăng nhập. Kiểm tra mạng và thử lại."; }
        catch (Exception ex) when (ex is System.IO.IOException or UnauthorizedAccessException)
        { AuthMessage = "Không truy cập được kho lưu phiên. Kiểm tra quyền ghi và thử lại."; }
        finally { UpdateAccount(); AuthBusy = false; }
        return false;
    }

    [RelayCommand]
    private Task RescanSourcesAsync() => Task.CompletedTask; // TODO(FR-SRC-001)
}
