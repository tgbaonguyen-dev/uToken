using UToken.Desktop.App.Models;
namespace UToken.Desktop.App.Services;
public sealed partial class MockDesktopApi
{
    public Task<OverviewScenario[]> GetOverviewScenariosAsync(CancellationToken ct = default) =>
        ReadAsync<OverviewScenario[]>("overview-states.json", ct);
    public async Task<OverviewPreview> GetOverviewPreviewAsync(string id, CancellationToken ct = default)
    {
        var scenario = (await GetOverviewScenariosAsync(ct)).FirstOrDefault(s => s.Id == id)
            ?? throw new InvalidDataException("Unknown overview scenario.");
        var data = await GetOverviewAsync(ct);
        if (scenario.EmptyUsage) data = data with { TotalTokens = 0, EstimatedCost = 0, Cached = 0, Activity = [] };
        data = data with { Collector = data.Collector with { State = scenario.CollectorState } };
        return new(scenario, data);
    }
}
