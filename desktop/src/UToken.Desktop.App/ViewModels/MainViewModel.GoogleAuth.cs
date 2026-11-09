using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace UToken.Desktop.App.ViewModels;

public partial class MainViewModel
{
    private bool _refreshingConnection;
    public async Task RefreshPairingConnectionAsync()
    {
        if (!IsRealPairing || !IsSyncSection || googleAuth?.Uid is null || IsBusy || _refreshingConnection) return;
        _refreshingConnection = true;
        var uid = googleAuth.Uid;
        try { var result = await api.GetSyncAsync(); if (googleAuth.Uid == uid && !IsBusy) Sync = result; }
        catch (Services.FirebaseSessionExpiredException ex) { if ((googleAuth.Uid == uid || googleAuth.Uid is null) && !IsBusy) { Sync = null; GoogleAccount = ex.Message; Error = ex.Message; } }
        catch (Exception ex) when (ex is HttpRequestException or OperationCanceledException or InvalidOperationException or System.Text.Json.JsonException)
        { if (IsSyncSection) { SyncMessage = "Connection status unavailable. Check the network and refresh."; SyncMessageColor = "#F26039"; } }
        finally { _refreshingConnection = false; }
    }
    public bool IsRealPairing => googleAuth is not null;
    public bool IsDemoSync => IsSyncPage && !IsRealPairing;
    public bool IsDemoPairing => IsPairingPage && !IsRealPairing;
    public string SyncActionLabel => IsRealPairing ? "Refresh connection" : "Sync now";
    public string SyncHistoryLabel => IsRealPairing ? "Usage sync not enabled" : "Demo history";
    public string SetupModeLabel => IsRealPairing ? "Usage and log permissions are sample data. Sign in with Google in Sync to pair your phone." : "UI demo: Google sign-in and log permissions are simulated. No account or provider files are accessed.";
    [ObservableProperty] private string _googleAccount = "Sign in with the same Google account as your phone.";
    [RelayCommand] private Task SignInGoogleAsync() => RunAsync(async () =>
    {
        if (googleAuth is null) return;
        await googleAuth.SignInAsync();
        GoogleAccount = googleAuth.Account;
        Sync = await api.GetSyncAsync();
    });
    [RelayCommand] private Task SignOutGoogleAsync() => RunAsync(() =>
    {
        googleAuth?.SignOut(); Sync = null;
        GoogleAccount = "Signed out. Sign in with the same Google account as your phone.";
        return Task.CompletedTask;
    });
}
