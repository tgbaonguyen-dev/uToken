using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using UToken.Desktop.App.Models;
namespace UToken.Desktop.App.ViewModels;

/// <summary>D10: nguồn có thư mục log nhưng app không đọc được (kiểm tra thật bằng cách đọc thư mục).</summary>
public partial class MainViewModel
{
    public event Action<string>? PermissionInstructionsRequested;
    /// <summary>Yêu cầu mở thư mục trong trình quản lý file của hệ điều hành.</summary>
    public event Action<string>? OpenFolderRequested;
    [ObservableProperty] private SourcePermissionData? _sourcePermission;
    [ObservableProperty, NotifyPropertyChangedFor(nameof(HasPermissionRetryFailure)),
        NotifyPropertyChangedFor(nameof(PermissionAccent)), NotifyPropertyChangedFor(nameof(PermissionBadgeLabel))]
    private string? _permissionRetryFailure;
    public bool HasPermissionRetryFailure => PermissionRetryFailure is not null;
    public string PermissionAccent => HasPermissionRetryFailure ? "#F04D57" : "#FFAD38";
    public string PermissionBadgeLabel => HasPermissionRetryFailure ? "RETRY FAILED" : "ACTION REQUIRED";
    [RelayCommand] private void DismissPermissionRetryFailure() => PermissionRetryFailure = null;
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
    }

    [RelayCommand] private Task RetrySourcePermissionAsync() => NavigateAsync(async () =>
    {
        if (PermissionSource is not { } source) return;
        ApplySourcePermission(await api.RetrySourcePermissionAsync(source.Id));
        Overview = await api.GetOverviewAsync();
        PermissionRetryFailure = HasPermissionIssue ? $"uToken still cannot read {source.Path}. Check the folder permissions and try again." : null;
        Notice = HasPermissionIssue ? "Access is still denied." : $"Access to {source.Name} restored. Usage collection resumed.";
    });

    /// <summary>"system": mở thư mục log của nguồn bị chặn; còn lại: hiện hướng dẫn kèm đường dẫn thật.</summary>
    [RelayCommand] private void ShowPermissionInstructions(string mode)
    {
        if (IsBusy || !CanNavigate || SourcePermission is null) return;
        var source = PermissionSource ?? SourceList?.Sources.FirstOrDefault();
        if (mode == "system" && source is not null)
        {
            OpenFolderRequested?.Invoke(Path.GetDirectoryName(api.GetSourceFolder(source.Id)) ?? api.GetSourceFolder(source.Id));
            return;
        }
        var steps = string.Join("\n\n", SourcePermission.Config.Instructions.Select(s => $"{s.Number}. {s.Title}\n{s.Description}"));
        var folder = source is null ? string.Join("\n", SourceList?.Sources.Select(s => api.GetSourceFolder(s.Id)) ?? []) : api.GetSourceFolder(source.Id);
        PermissionInstructionsRequested?.Invoke(
            $"Affected source: {source?.Name ?? "All supported sources"}\nLog folder: {folder}\n\n{steps}\n\n" +
            (OperatingSystem.IsWindows()
                ? "Windows: right-click the folder → Properties → Security, and allow Read for your account."
                : $"Linux/macOS: run  chmod -R u+rX \"{folder}\"  then press Retry access."));
    }
}
