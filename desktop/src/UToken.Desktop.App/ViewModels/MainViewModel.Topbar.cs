using CommunityToolkit.Mvvm.Input;

namespace UToken.Desktop.App.ViewModels;

/// <summary>
/// Topbar: breadcrumb (mục › trang con, bấm mục để quay lại — thay cho các nút "Back to …"),
/// trạng thái sync và tài khoản dùng chung cho mọi trang.
/// </summary>
public partial class MainViewModel
{
    public string SectionName => Page switch
    {
        "overview" or "activity" => "Overview",
        "first-run" => "Setup",
        "sources" or "detail" => "Sources",
        "pricing" => "Pricing",
        "sync" or "pairing" => "Sync",
        "settings" => "Settings",
        _ => "",
    };

    /// <summary>Trang con có đường quay lại mục cha qua breadcrumb.</summary>
    public bool IsSubPage => Page is "detail" or "activity" or "pairing";

    [RelayCommand]
    private Task GoToSectionAsync()
    {
        switch (Page)
        {
            case "detail": ShowSources(); return Task.CompletedTask;
            case "activity": ShowOverview(); return Task.CompletedTask;
            case "pairing": return ShowSyncAsync();
            default: return Task.CompletedTask;
        }
    }

    public string AccountInitial => Sync?.Device?.Initial is { Length: > 0 } i ? i : "G";
    /// <summary>Nút đăng nhập ở header trang Sync chỉ khi chưa đăng nhập; đã đăng nhập thì dùng chip tài khoản trên topbar.</summary>
    public bool ShowSyncSignIn => IsSyncNormal && !HasDevice;
    public string AccountLabel => Sync?.Device?.Name is { Length: > 0 } name ? name : "Sign in";
    /// <summary>Sync now trên topbar: khóa trong lúc thiết lập/quét nguồn (như điều hướng) và khi đang bận.</summary>
    public bool CanSyncFromTopbar => CanNavigate && !IsBusy;
    public string TopbarSyncLabel => IsSyncing ? "Syncing…" : SidebarStatusCaption;

    private void NotifyTopbar()
    {
        foreach (var name in new[] { nameof(SectionName), nameof(IsSubPage), nameof(ShowSyncSignIn), nameof(CanSyncFromTopbar), nameof(AccountInitial), nameof(AccountLabel), nameof(TopbarSyncLabel) })
            OnPropertyChanged(name);
    }
}
