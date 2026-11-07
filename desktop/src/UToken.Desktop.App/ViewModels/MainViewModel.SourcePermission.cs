using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using UToken.Desktop.App.Models;
namespace UToken.Desktop.App.ViewModels;

public partial class MainViewModel
{
    public event Action<string>? PermissionInstructionsRequested;
    [ObservableProperty, NotifyPropertyChangedFor(nameof(SourcePreviewOptions))] private SourcePermissionData? _sourcePermission;
    public PermissionScenario[] SourcePreviewOptions => [.. SourcePermission?.Config.Scenarios ?? [], .. OverviewScenarios.Where(s => s.Id is "scanning" or "up-to-date").Select(s => new PermissionScenario(s.Id, s.Name, false, "granted"))];
    [ObservableProperty] private PermissionScenario? _selectedPermissionScenario;
    [ObservableProperty, NotifyPropertyChangedFor(nameof(HasPermissionRetryFailure)),
        NotifyPropertyChangedFor(nameof(PermissionAccent)), NotifyPropertyChangedFor(nameof(PermissionBadgeLabel))]
    private string? _permissionRetryFailure;
    public bool HasPermissionRetryFailure => PermissionRetryFailure is not null;
    public string PermissionAccent => HasPermissionRetryFailure ? "#F04D57" : "#FFAD38";
    public string PermissionBadgeLabel => HasPermissionRetryFailure ? "RETRY FAILED" : "ACTION REQUIRED";
    [RelayCommand] private void DismissPermissionRetryFailure() => PermissionRetryFailure = null;
    private bool _restoringPermissionSelection;
    public bool HasPermissionIssue => SourceList?.Sources.Any(s => s.CollectorState != "not_found" && (!s.Health.HasLogAccess || s.CollectorState == "permission_required")) == true;
    public bool IsPermissionRequired => IsSources && HasPermissionIssue && !IsScanningSources && !IsSourcesStatePreview;
    public bool IsSourcesNormal => IsSources && !HasPermissionIssue && !HasNoSupportedSources && !IsScanningSources && !IsSourcesStatePreview;
    public SourceData? PermissionSource => SourceList?.Sources.FirstOrDefault(s => s.CollectorState != "not_found" && (!s.Health.HasLogAccess || s.CollectorState == "permission_required"));
    public PermissionProvider[] PermissionProviders => SourceList?.Sources.Select(s =>
        new PermissionProvider(s.Name, s.Logo, !s.Health.HasLogAccess || s.CollectorState == "permission_required")).ToArray() ?? [];

    private void ApplySourcePermission(SourcePermissionData data)
    {
        SourcePermission = data;
        SourceList = data.Sources;
        _restoringPermissionSelection = true;
        SelectedPermissionScenario = data.Config.Scenarios.FirstOrDefault(s => s.Id == data.Scenario.Id);
        _restoringPermissionSelection = false;
    }
    partial void OnSelectedPermissionScenarioChanged(PermissionScenario? value)
    {
        if (!_restoringPermissionSelection && value is not null && IsSources && !IsBusy)
            _ = ChangePermissionScenarioCommand.ExecuteAsync(null);
    }
    [RelayCommand] private async Task ChangePermissionScenarioAsync()
    {
        if (!CanNavigate || !IsSources) return;
        if (SelectedPermissionScenario?.Id == "scanning")
        {
            await RescanSourcesCommand.ExecuteAsync(null);
            ApplySourcePermission(SourcePermission!);
            return;
        }
        if (SelectedPermissionScenario?.Id == "up-to-date")
        {
            SectionScenario = OverviewScenarios.Single(s => s.Id == "up-to-date");
            return;
        }
        SectionScenario = null;
        await RunAsync(async () =>
        {
            ApplySourcePermission(await api.SetSourcePermissionScenarioAsync(SelectedPermissionScenario?.Id ?? "normal"));
            Notice = "Sources demo - no system permissions or sample usage are changed.";
        });
        if (HasError && SourcePermission is not null)
        {
            _restoringPermissionSelection = true;
            SelectedPermissionScenario = SourcePermission.Config.Scenarios.FirstOrDefault(s => s.Id == SourcePermission.Scenario.Id);
            _restoringPermissionSelection = false;
        }
    }
    [RelayCommand] private Task RetrySourcePermissionAsync() => NavigateAsync(async () =>
    {
        if (PermissionSource is not { } source) return;
        ApplySourcePermission(await api.RetrySourcePermissionAsync(source.Id));
        if (HasPermissionIssue)
            PermissionRetryFailure = $"Access to {source.Name} is still denied. Review the permissions and try again.";
        Notice = HasPermissionIssue ? "Demo check: access is still denied. Review the instructions and try again."
            : "Demo access restored. Existing usage history is retained.";
    });
    [RelayCommand] private void ShowPermissionInstructions(string mode)
    {
        if (IsBusy || !CanNavigate || SourcePermission is null) return;
        var introduction = mode == "system"
            ? "System Settings simulation: no operating-system settings are opened or changed."
            : "Permission instructions (UI demo)";
        var steps = string.Join("\n\n", SourcePermission.Config.Instructions.Select(s => $"{s.Number}. {s.Title}\n{s.Description}"));
        PermissionInstructionsRequested?.Invoke($"{introduction}\n\nAffected source: {PermissionSource?.Name ?? "All supported sources"}\nLog path (sample): {PermissionSource?.Path ?? string.Join("; ", SourceList?.Sources.Select(s => s.Path) ?? [])}\n\n{steps}");
    }
}
