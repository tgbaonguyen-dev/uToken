using UToken.Desktop.App.Models;
namespace UToken.Desktop.App.Services;

public sealed partial class MockDesktopApi
{
    private readonly Dictionary<string, bool> _sourceLogAccess = new();
    private bool? _sourceDiscoveryOverride;
    private bool _restoreSourcesOnScan;
    private string _permissionScenarioId = "normal";

    public async Task<SourcePermissionData> GetSourcePermissionAsync(CancellationToken ct = default)
    {
        var config = await ReadAsync<SourcePermissionConfig>("source-permission.json", ct);
        var scenario = config.Scenarios.FirstOrDefault(s => s.Id == _permissionScenarioId)
            ?? throw new InvalidDataException("Permission scenario missing.");
        return new(config, scenario, await GetSourcesAsync(ct));
    }

    public async Task<SourcePermissionData> SetSourcePermissionScenarioAsync(string id, CancellationToken ct = default)
    {
        var current = await GetSourcePermissionAsync(ct);
        var scenario = current.Config.Scenarios.FirstOrDefault(s => s.Id == id)
            ?? throw new InvalidDataException("Unknown permission scenario.");
        if (scenario.MissingAccess && !current.Sources.Sources.Any(s => s.Id == current.Config.SourceId))
            throw new InvalidDataException("Permission source missing.");
        ct.ThrowIfCancellationRequested();
        _permissionScenarioId = id;
        _sourceLogAccess[current.Config.SourceId] = !scenario.MissingAccess;
        _sourceDiscoveryOverride = !scenario.SourcesNotFound;
        _restoreSourcesOnScan = scenario.RestoreSourcesOnScan;
        return new(current.Config, scenario, WithDiscovery(
            WithPermission(current.Sources, current.Config.SourceId, !scenario.MissingAccess), !scenario.SourcesNotFound));
    }

    public async Task<SourcePermissionData> RetrySourcePermissionAsync(string sourceId, CancellationToken ct = default)
    {
        var current = await GetSourcePermissionAsync(ct);
        if (!current.Sources.Sources.Any(s => s.Id == sourceId))
            throw new InvalidDataException("Unknown permission source.");
        if (current.Scenario.RetryResult is not ("granted" or "denied"))
            throw new InvalidDataException("Unknown permission retry result.");
        await Task.Delay(600, ct);
        var granted = current.Scenario.RetryResult == "granted";
        var scenario = granted ? current.Config.Scenarios.FirstOrDefault(s => s.Id == "normal")
            ?? throw new InvalidDataException("Normal permission scenario missing.") : current.Scenario;
        _sourceLogAccess[sourceId] = granted;
        _permissionScenarioId = scenario.Id;
        return current with { Scenario = scenario, Sources = WithPermission(current.Sources, sourceId, granted) };
    }
    private static SourcesData WithDiscovery(SourcesData sources, bool found) =>
        sources with { Sources = sources.Sources.Select(s => s with
        {
            CollectorState = !found ? "not_found" : s.CollectorState == "not_found" ? "running" : s.CollectorState,
        }).ToArray() };
    private static SourcesData WithPermission(SourcesData sources, string sourceId, bool allowed) =>
        sources with { Sources = sources.Sources.Select(s => s.Id == sourceId ? s with
        {
            Health = s.Health with { HasLogAccess = allowed },
            CollectorState = allowed && s.CollectorState == "permission_required" ? "running" : s.CollectorState,
        } : s).ToArray() };
}
