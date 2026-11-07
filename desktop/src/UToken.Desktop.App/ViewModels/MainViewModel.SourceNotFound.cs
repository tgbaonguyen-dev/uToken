using CommunityToolkit.Mvvm.Input;
using UToken.Desktop.App.Models;
namespace UToken.Desktop.App.ViewModels;

public partial class MainViewModel
{
    public event Action<string>? SourceSetupGuideRequested;
    public bool HasNoSupportedSources => SourceList is not null &&
        (SourceList.Sources.Length == 0 || SourceList.Sources.All(s => s.CollectorState == "not_found"));
    public bool IsSourceNotFound => IsSources && HasNoSupportedSources && !IsScanningSources && !IsSourcesStatePreview;
    public OverviewScenario? NotFoundScenario => OverviewScenarios.FirstOrDefault(s => s.Id == "not-found");
    public SourceScanItem[] DiscoveryProviders => SupportedSources.Select(s =>
        new SourceScanItem(s.Name, s.Logo, SourceList?.Sources.Any(p => p.Id == s.Id && p.CollectorState != "not_found") == true
            ? "complete" : "not-found")).ToArray();

    [RelayCommand] private void ConfigureSources()
    {
        if (IsBusy || !CanNavigate || NotFoundScenario is null) return;
        var guide = string.Join("\n\n", NotFoundScenario.Guide.Select(s => $"{s.Number}. {s.Title}\n{s.Description}"));
        var paths = string.Join("\n", SourceList?.Sources.Select(s => $"{s.Name}: {s.Path}") ?? []);
        SourceSetupGuideRequested?.Invoke($"Supported source setup (UI demo)\n\n{guide}\n\nExpected paths (sample):\n{paths}\n\nNo provider files or system settings are accessed.");
    }
}
