namespace UToken.Desktop.App.Models;

public record PermissionScenario(string Id, string Name, bool MissingAccess, string RetryResult, bool SourcesNotFound = false, bool RestoreSourcesOnScan = false)
{
    public override string ToString() => Name;
}
public record SourcePermissionConfig(string Headline, string Description, string SourceId,
    SetupStep[] Instructions, PermissionScenario[] Scenarios);
public record SourcePermissionData(SourcePermissionConfig Config, PermissionScenario Scenario, SourcesData Sources);
public record PermissionProvider(string Name, string Logo, bool MissingAccess)
{
    public string Status => MissingAccess ? "Permission missing" : "Collecting";
    public string Color => MissingAccess ? "#FFAD38" : "#2EC790";
}
