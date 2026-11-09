using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using UToken.Desktop.App.Models;
namespace UToken.Desktop.App.ViewModels;

/// <summary>
/// D01 first-run, mỗi bước làm thật: (1) đăng nhập Google, (2) quét thư mục log và báo nguồn đọc được/thiếu quyền,
/// (3) hoàn tất — mobile đăng nhập cùng tài khoản để xem số liệu. Có thể bỏ qua để chỉ dùng trên máy.
/// </summary>
public partial class MainViewModel
{
    [ObservableProperty, NotifyPropertyChangedFor(nameof(SetupRows)), NotifyPropertyChangedFor(nameof(SetupAction)), NotifyPropertyChangedFor(nameof(PageTitle)), NotifyPropertyChangedFor(nameof(Subtitle))]
    private FirstRunData? _firstRun;
    [ObservableProperty, NotifyPropertyChangedFor(nameof(SetupRows)), NotifyPropertyChangedFor(nameof(SetupAction)), NotifyPropertyChangedFor(nameof(CanSkipSetup)), NotifyCanExecuteChangedFor(nameof(SkipSetupCommand))]
    private int _setupStepIndex;
    [ObservableProperty, NotifyPropertyChangedFor(nameof(HasSetupMessage))] private string _setupMessage = "";
    [ObservableProperty] private string _setupMessageColor = "#2EC790";
    public bool HasSetupMessage => !string.IsNullOrEmpty(SetupMessage);
    public bool CanNavigate => !IsFirstRunPage && !IsScanningSources;
    public bool CanSkipSetup => IsFirstRunPage;
    private Task NavigateAsync(Func<Task> action) => CanNavigate ? RunAsync(action) : Task.CompletedTask;
    public bool IsFirstRunPage => Page == "first-run";
    public SetupRow[] SetupRows => FirstRun?.Steps.Select((s, i) =>
        new SetupRow(s.Number, s.Title, s.Description, i < SetupStepIndex)).ToArray() ?? [];
    public string SetupAction => FirstRun?.Steps.ElementAtOrDefault(SetupStepIndex)?.Action ?? "Continue";

    [RelayCommand] private Task ShowFirstRunAsync() => RunAsync(async () =>
    {
        FirstRun = await api.GetFirstRunAsync();
        SetupStepIndex = 0; SetupMessage = ""; Page = "first-run";
    });

    [RelayCommand] private Task ContinueSetupAsync() => RunAsync(async () =>
    {
        if (FirstRun is null) return;
        switch (SetupStepIndex)
        {
            case 0: // Đăng nhập Google
                Sync = await api.GetSyncAsync();
                if (!HasDevice)
                {
                    Pairing = await api.GetPairingInfoAsync();
                    PairingScenarios = await api.GetPairingScenariosAsync();
                    if (!await SignInCoreAsync())
                    {
                        SetupMessage = PairingMessage + " You can also skip setup and use uToken on this computer only.";
                        SetupMessageColor = "#F26039";
                        return;
                    }
                }
                SetupMessage = $"Signed in as {Sync!.Device!.Name}."; SetupMessageColor = "#2EC790";
                SetupStepIndex = 1;
                break;

            case 1: // Kiểm tra thư mục log và quét lần đầu
                var sources = await api.RescanSourcesAsync();
                ApplySourcePermission((await api.GetSourcePermissionAsync()) with { Sources = sources });
                Overview = await api.GetOverviewAsync();
                var readable = sources.Sources.Where(s => s.CollectorState == "running").Select(s => s.Name).ToArray();
                var blocked = sources.Sources.Where(s => s.CollectorState == "permission_required").Select(s => s.Name).ToArray();
                SetupMessage = readable.Length == 0
                    ? "No supported tool logs were found yet. Use Codex or Claude Code, then rescan from Sources."
                    : $"Reading {string.Join(", ", readable)} · {Overview.Health.FirstOrDefault(h => h.Label == "Local database")?.Value ?? "0 events"} stored on this computer."
                      + (blocked.Length > 0 ? $" Permission required: {string.Join(", ", blocked)}." : "");
                SetupMessageColor = readable.Length == 0 || blocked.Length > 0 ? "#FFAD38" : "#2EC790";
                SetupStepIndex = 2;
                break;

            default: // Hoàn tất
                await api.CompleteSetupAsync();
                SetupMessage = "";
                Page = "overview";
                Notice = HasDevice
                    ? "Setup complete. Sign in to uToken mobile with the same Google account."
                    : "Setup complete. Usage is tracked on this computer.";
                break;
        }
    });

    [RelayCommand(CanExecute = nameof(CanSkipSetup))] private Task SkipSetupAsync() => RunAsync(async () =>
    {
        if (!CanSkipSetup) return;
        await api.CompleteSetupAsync();
        SetupMessage = "";
        Page = "overview";
    });
}
