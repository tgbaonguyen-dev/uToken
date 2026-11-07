using UToken.Desktop.App.Models;
namespace UToken.Desktop.App.Services;

public sealed partial class MockDesktopApi
{
    public async Task<SourcesData> RescanSourcesAsync(CancellationToken ct = default,
        IProgress<SourceScanProgress>? progress = null)
    {
        var config = await ReadAsync<SourceScanConfig>("source-scan.json", ct);
        if (config.StepDelayMs is < 0 or > 5000)
            throw new InvalidDataException("Mock scan delay must be between 0 and 5000 ms.");
        var sources = await GetSourcesAsync(ct);
        var restoreAfterScan = _restoreSourcesOnScan;
        var items = sources.Sources.Select(s => new SourceScanItem(s.Name, s.Logo, "waiting")).ToArray();
        progress?.Report(new(config, 0, items.Length, items.Length == 0 ? "None" : items[0].Name, items.ToArray()));
        for (var i = 0; i < items.Length; i++)
        {
            ct.ThrowIfCancellationRequested();
            var source = sources.Sources[i];
            items[i] = items[i] with { State = "scanning" };
            progress?.Report(new(config, i, items.Length, source.Name, items.ToArray()));
            await Task.Delay(config.StepDelayMs, ct);
            var state = !source.Health.HasLogAccess || source.CollectorState == "permission_required" ? "permission"
                : source.CollectorState == "not_found" && !restoreAfterScan ? "not-found" : "complete";
            items[i] = items[i] with { State = state };
            progress?.Report(new(config, i + 1, items.Length, source.Name, items.ToArray()));
        }
        ct.ThrowIfCancellationRequested();
        if (restoreAfterScan)
        {
            _sourceDiscoveryOverride = true;
            _restoreSourcesOnScan = false;
            _permissionScenarioId = "normal";
            sources = WithDiscovery(sources, true);
        }
        return sources;
    }
}
