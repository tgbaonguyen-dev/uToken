using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using UToken.Desktop.App.Models;
namespace UToken.Desktop.App.ViewModels;

public partial class MainViewModel
{
    [ObservableProperty, NotifyPropertyChangedFor(nameof(SetupRows)), NotifyPropertyChangedFor(nameof(SetupAction)), NotifyPropertyChangedFor(nameof(PageTitle)), NotifyPropertyChangedFor(nameof(Subtitle))]
    private FirstRunData? _firstRun;
    [ObservableProperty, NotifyPropertyChangedFor(nameof(SetupRows)), NotifyPropertyChangedFor(nameof(SetupAction)), NotifyPropertyChangedFor(nameof(CanSkipSetup)), NotifyCanExecuteChangedFor(nameof(SkipSetupCommand))]
    private int _setupStepIndex;
    public bool CanNavigate => !IsFirstRunPage && !IsScanningSources;
    public bool CanSkipSetup => IsFirstRunPage && SetupStepIndex > 0;
    private Task NavigateAsync(Func<Task> action) => CanNavigate ? RunAsync(action) : Task.CompletedTask;
    public bool IsFirstRunPage => Page == "first-run";
    public SetupRow[] SetupRows => FirstRun?.Steps.Select((s, i) =>
        new SetupRow(s.Number, s.Title, s.Description, i < SetupStepIndex)).ToArray() ?? [];
    public string SetupAction => FirstRun?.Steps.ElementAtOrDefault(SetupStepIndex)?.Action ?? "Continue";

    [RelayCommand] private Task ShowFirstRunAsync() => RunAsync(async () =>
    {
        FirstRun = await api.GetFirstRunAsync();
        SetupStepIndex = 0; Page = "first-run";
    });
    [RelayCommand] private Task ContinueSetupAsync() => RunAsync(async () =>
    {
        if (FirstRun is null) return;
        if (IsRealPairing && SetupStepIndex == 0 && googleAuth is not null)
        {
            try { await googleAuth.TokenAsync(default); }
            catch (InvalidOperationException) { await googleAuth.SignInAsync(); }
            GoogleAccount = googleAuth.Account;
        }
        if (SetupStepIndex < FirstRun.Steps.Length - 1) { SetupStepIndex++; return; }
        await LoadPairingPageCoreAsync();
        await api.CompleteSetupAsync();
        Page = "pairing";
    });
    [RelayCommand(CanExecute = nameof(CanSkipSetup))] private Task SkipSetupAsync() => RunAsync(async () =>
    {
        if (!CanSkipSetup) return;
        await api.CompleteSetupAsync();
        Page = "overview";
    });
}
