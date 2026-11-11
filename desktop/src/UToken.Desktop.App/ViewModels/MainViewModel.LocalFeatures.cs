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
    /// <summary>
    /// Tiếng Việt cho giao diện và đánh giá AI. Lưu vào language.txt và áp dụng ngay cho cửa sổ đang mở
    /// (trang hiện tại và dữ liệu đang sửa giữ nguyên); lần AI review kế tiếp viết theo ngôn ngữ mới.
    /// </summary>
    public bool UseVietnamese
    {
        get => Localization.Loc.Vietnamese;
        set
        {
            if (value == UseVietnamese) return;
            var language = value ? "vi" : "en";
            var saved = true;
            try { Localization.Loc.Save(language); }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException) { saved = false; }
            Localization.Loc.Use(language);
            OnPropertyChanged();
            Notice = !saved
                ? "Could not save UI preferences. Your usage data is unchanged."
                : value ? "Language set to Vietnamese." : "Language set to English.";
        }
    }

    public void SaveUiPreferences()
    {
        if (_uiPreferencesLoaded && uiStateStore is not null && !uiStateStore.SaveFilters(CurrentActivityQuery, SelectedPeriod))
            Notice = "Could not save UI preferences. Your usage data is unchanged.";
    }
}
