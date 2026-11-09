using CommunityToolkit.Mvvm.ComponentModel;

namespace UToken.Desktop.App.ViewModels;

public partial class MainViewModel
{
    private readonly TimeProvider _uiClock = timeProvider ?? TimeProvider.System;
    private bool _uiPreferencesLoaded;
    [ObservableProperty, NotifyPropertyChangedFor(nameof(PairingCountdownLabel))]
    private TimeSpan _pairingRemaining;
    public string PairingCountdownLabel => IsRealPairing ? "Check the code expiry on your phone." : $"Code expires in {(int)Math.Ceiling(PairingRemaining.TotalSeconds) / 60:00}:{(int)Math.Ceiling(PairingRemaining.TotalSeconds) % 60:00}";

    public void UpdatePairingCountdown()
    {
        if (IsRealPairing || !IsPairingPage || HasDevice || IsPairingPreview || Pairing is null) return;
        var now = _uiClock.GetUtcNow();
        PairingRemaining = Pairing.ExpiresAt > now ? Pairing.ExpiresAt - now : TimeSpan.Zero;
        if (PairingRemaining == TimeSpan.Zero && !IsBusy && PairingState is "waiting" or "rejected" or "invalid" or "error")
        {
            PairingState = "expired";
            PairingMessage = PairingScenarios.FirstOrDefault(s => s.Id == "expired")?.Description ?? "Pairing code expired. Start a new session.";
        }
    }
    partial void OnPairingChanged(Models.PairingData? value) => UpdatePairingCountdown();

    private void RestoreUiPreferences()
    {
        if (_uiPreferencesLoaded || uiStateStore is null) return;
        var saved = uiStateStore.State;
        if (!ActivityProviders.Contains(saved.Activity.Provider)) ActivityProviders.Add(saved.Activity.Provider);
        if (!ActivityModels.Contains(saved.Activity.Model)) ActivityModels.Add(saved.Activity.Model);
        if (!ActivityPeriods.Contains(saved.Activity.Period)) ActivityPeriods.Add(saved.Activity.Period);
        ActivityProvider = saved.Activity.Provider; ActivityModel = saved.Activity.Model;
        ActivityPeriod = saved.Activity.Period; ActivitySearch = saved.Activity.Search; WarningsOnly = saved.Activity.WarningsOnly;
        SelectedPeriod = saved.SourcePeriod;
        _uiPreferencesLoaded = true;
    }
    public void SaveUiPreferences()
    {
        if (_uiPreferencesLoaded && uiStateStore is not null && !uiStateStore.SaveFilters(CurrentActivityQuery, SelectedPeriod))
            Notice = "Could not save UI preferences. Your usage data is unchanged.";
    }
}
