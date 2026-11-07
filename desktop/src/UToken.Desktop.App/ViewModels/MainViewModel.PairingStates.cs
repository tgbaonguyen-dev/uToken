using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using UToken.Desktop.App.Models;

namespace UToken.Desktop.App.ViewModels;

public partial class MainViewModel
{
    [ObservableProperty] private OverviewScenario[] _pairingScenarios = [];
    [ObservableProperty] private OverviewScenario? _selectedPairingScenario;
    private bool _restoringPairingSelection;
    private bool _pairingPreview;
    public OverviewScenario? ActivePairingScenario => !IsPairingPage ? null
        : IsPairingPreview ? SelectedPairingScenario
        : PairingScenarios.FirstOrDefault(s => s.Id == PairingState && s.Id is "verifying" or "expired" or "rejected" or "success");
    public bool IsPairingStateVisible => ActivePairingScenario is not null;
    public bool IsPairingFormVisible => IsPairingPage && !IsPairingStateVisible;
    public bool IsPairingVerifying => ActivePairingScenario?.Id == "verifying";
    public bool IsPairingSuccess => ActivePairingScenario?.Id == "success";
    public bool IsPairingPreview => _pairingPreview;
    public bool ShowPairedDeviceSummary => IsPairingSuccess && !IsPairingPreview && HasDevice;

    partial void OnSelectedPairingScenarioChanged(OverviewScenario? value)
    {
        if (_restoringPairingSelection) return;
        _pairingPreview = value is { Id: not "normal" };
        if (!_pairingPreview && IsPairingPage && !IsBusy)
        {
            PairingState = HasDevice ? "connected" : "waiting";
            PairingMessage = "";
        }
        NotifyPairingState();
    }
    private void SyncPairingSelection()
    {
        _pairingPreview = false;
        _restoringPairingSelection = true;
        SelectedPairingScenario = PairingScenarios.FirstOrDefault(s => s.Id == PairingState && PairingState != "waiting")
            ?? PairingScenarios.FirstOrDefault(s => s.Id == "normal");
        _restoringPairingSelection = false;
        NotifyPairingState();
    }
    private void NotifyPairingState()
    {
        foreach (var name in new[] { nameof(ActivePairingScenario), nameof(IsPairingStateVisible), nameof(IsPairingFormVisible),
            nameof(IsPairingVerifying), nameof(IsPairingSuccess), nameof(IsPairingPreview), nameof(ShowPairedDeviceSummary), nameof(PageTitle), nameof(Subtitle) }) OnPropertyChanged(name);
    }
    private void ResetPairingPreview()
    {
        _restoringPairingSelection = true;
        _pairingPreview = false;
        SelectedPairingScenario = PairingScenarios.FirstOrDefault(s => s.Id == "normal");
        _restoringPairingSelection = false;
        NotifyPairingState();
    }
    [RelayCommand] private async Task PairingStateActionAsync(string action)
    {
        if (IsBusy || !IsPairingPage) return;
        if (action == "settings") { await ShowSettingsCommand.ExecuteAsync(null); return; }
        if (action == "sync") { await ShowSyncCommand.ExecuteAsync(null); return; }
        ResetPairingPreview();
        if (action == "restart")
            await RestartPairingCommand.ExecuteAsync(null);
        else if (action == "form")
        {
            PairingState = HasDevice ? "connected" : "waiting";
            PairingMessage = "";
        }
    }
}
