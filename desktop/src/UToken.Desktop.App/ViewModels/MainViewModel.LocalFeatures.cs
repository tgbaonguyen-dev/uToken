using CommunityToolkit.Mvvm.ComponentModel;

namespace UToken.Desktop.App.ViewModels;

public partial class MainViewModel
{
    private readonly TimeProvider _uiClock = timeProvider ?? TimeProvider.System;
    private bool _uiPreferencesLoaded;
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
    /// <summary>Tiếng click khi bấm nút (Settings). Lưu ngay vào ui-state.json, không cần Save changes.</summary>
    public bool ClickSounds
    {
        get => uiStateStore?.State.ClickSounds ?? Services.ClickSound.Enabled;
        set
        {
            if (value == ClickSounds) return;
            Services.ClickSound.Enabled = value;
            if (uiStateStore is not null && !uiStateStore.SaveClickSounds(value))
                Notice = "Could not save UI preferences. Your usage data is unchanged.";
            OnPropertyChanged();
            if (value) Services.ClickSound.Play();
        }
    }
    public void SaveUiPreferences()
    {
        if (_uiPreferencesLoaded && uiStateStore is not null && !uiStateStore.SaveFilters(CurrentActivityQuery, SelectedPeriod))
            Notice = "Could not save UI preferences. Your usage data is unchanged.";
    }
}
