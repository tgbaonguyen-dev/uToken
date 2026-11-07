using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using UToken.Desktop.App.Models;

namespace UToken.Desktop.App.ViewModels;

/// <summary>
/// Màn tài khoản (thay cho ghép đôi bằng mã): desktop và mobile kết nối khi đăng nhập cùng tài khoản Google.
/// Màn trạng thái theo kết quả đăng nhập thật: verifying (đang chờ trình duyệt), success, rejected, expired.
/// </summary>
public partial class MainViewModel
{
    [ObservableProperty] private OverviewScenario[] _pairingScenarios = [];
    public OverviewScenario? ActivePairingScenario => !IsPairingPage ? null
        : PairingScenarios.FirstOrDefault(s => s.Id == PairingState && s.Id is "verifying" or "expired" or "rejected" or "success");
    public bool IsPairingStateVisible => ActivePairingScenario is not null;
    public bool IsPairingFormVisible => IsPairingPage && !IsPairingStateVisible;
    public bool IsPairingVerifying => ActivePairingScenario?.Id == "verifying";
    public bool IsPairingSuccess => ActivePairingScenario?.Id == "success";
    public bool ShowPairedDeviceSummary => IsPairingSuccess && HasDevice;

    private void NotifyPairingState()
    {
        foreach (var name in new[] { nameof(ActivePairingScenario), nameof(IsPairingStateVisible), nameof(IsPairingFormVisible),
            nameof(IsPairingVerifying), nameof(IsPairingSuccess), nameof(ShowPairedDeviceSummary), nameof(PageTitle), nameof(Subtitle) }) OnPropertyChanged(name);
    }

    [RelayCommand] private async Task PairingStateActionAsync(string action)
    {
        if (IsBusy || !IsPairingPage) return;
        switch (action)
        {
            case "settings": await ShowSettingsCommand.ExecuteAsync(null); return;
            case "sync": await ShowSyncCommand.ExecuteAsync(null); return;
            case "restart": await SignInCommand.ExecuteAsync(null); return;
            default:
                PairingState = HasDevice ? "connected" : "waiting";
                return;
        }
    }
}
