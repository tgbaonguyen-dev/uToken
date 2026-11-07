using UToken.Desktop.App.Models;

namespace UToken.Desktop.App.ViewModels;

/// <summary>Điền các dòng chi tiết của màn trạng thái bằng số liệu thật (JSON chỉ giữ nhãn và câu chữ).</summary>
public partial class MainViewModel
{
    private OverviewScenario WithLiveDetails(OverviewScenario s)
    {
        string Health(string label) => Overview?.Health.FirstOrDefault(h => h.Label == label)?.Value ?? "—";
        var sources = SourceList?.Sources ?? [];
        string readable = $"{sources.Count(x => x.Health.HasLogAccess && x.CollectorState == "running")} of {sources.Length} folders readable";
        string lastUpload = Sync?.Device?.LastSync ?? "Never";
        string pending = $"{Sync?.NextSync.Events ?? 0} daily summaries";

        HealthData[]? details = s.Id switch
        {
            "offline" =>
            [
                new("Collector process", Overview?.Collector.Label ?? "Stopped", "#F04D57"),
                new("Log access", readable, "#9096A1"),
                new("Local database", Health("Local database"), "#2EC790"),
                new("Cloud sync", HasDevice ? "Signed in" : "Not signed in", "#9096A1"),
            ],
            "empty" => [new("Collector", Overview?.Collector.Label ?? "—", Overview?.Collector.Color ?? "#9096A1"), new("Log access", readable, "#9096A1")],
            "not-found" => sources.Select(x => new HealthData(x.Name, x.CollectorState == "not_found" ? "Not found" : "Found", x.CollectorState == "not_found" ? "#F26039" : "#2EC790")).ToArray(),
            "up-to-date" => [new("Last scan", "Just now", "#9096A1"), new("New records", "0", "#9096A1")],
            "update" => [new("Installed", Health("App version"), "#9096A1"), new("Log format", "Not recognized by this version", "#F26039")],
            "network" => [new("Last successful upload", lastUpload, "#F04D57"), new("Pending", pending, "#F04D57")],
            "revoked" => [new("Local history", "Preserved", "#2EC790"), new("Cloud sync", "Paused until you sign in", "#F26039"), new("Pending", pending, "#FFAD38")],
            "not-paired" => [new("Google account", "Not signed in", "#F26039"), new("Pending", pending, "#FFAD38")],
            _ => null,
        };
        return details is null ? s : s with { Details = details };
    }
}
